#!/usr/bin/env bash
# epistemic-preflight.sh — SessionStart hook for native epistemic tracking
#
# Reads SessionStart stdin JSON for the canonical session_id (probe v2
# confirmed: {session_id, source, transcript_path, ...}) and writes a
# per-claude-PID marker via scripts/epistemic-marker.sh. Migrates the
# pre-rev2 single-file marker on first encounter.
#
# Trigger: SessionStart event
# Exit code: Always 0 (fail-open — never block session start)
# Output: stderr → injected into Claude's conversation context
#
# Must complete in < 2 seconds. Enforced via timeout wrapper.

set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"

# ── Source helper (single mechanism — no inline fallback per CF-10) ──
HELPER_SOURCED=0
for try_dir in \
    "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" 2>/dev/null && pwd)" \
    "${HOME}/.claude/scripts"; do
    if [ -f "$try_dir/epistemic-marker.sh" ]; then
        # shellcheck disable=SC1091
        source "$try_dir/epistemic-marker.sh"
        HELPER_SOURCED=1
        break
    fi
done

if [ "$HELPER_SOURCED" -eq 0 ]; then
    echo "[epistemic] helper scripts/epistemic-marker.sh not found — session not tracked." >&2
    exit 0
fi

# ── Ensure ~/.claude exists ──────────────────────────────────────────
mkdir -p "${HOME}/.claude" 2>/dev/null

# ── Non-Linux warning (FM3) ──────────────────────────────────────────
if [ ! -d /proc ]; then
    echo "[epistemic] /proc unavailable; per-PID isolation degraded — concurrent claude sessions on this platform may cross-contaminate epistemic.json. macOS/BSD support is a separate blueprint." >&2
fi

# ── Migrate legacy single-file marker if present ─────────────────────
epistemic_migrate_legacy_marker

# ── Read SessionStart stdin JSON for session_id and source ───────────
# Stdin is consumed once. Other consumers MUST read session_id via the
# marker (epistemic_get_session_id), not stdin.
STDIN_JSON=""
if [ ! -t 0 ]; then
    STDIN_JSON=$(cat)
fi

SESSION_ID=""
SOURCE_VALUE="startup"  # default if stdin parse fails or field missing
if [ -n "$STDIN_JSON" ] && command -v jq &>/dev/null; then
    SESSION_ID=$(printf '%s' "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null)
    SOURCE_VALUE=$(printf '%s' "$STDIN_JSON" | jq -r '.source // "startup"' 2>/dev/null)
fi

# ── No session_id → no marker written, no uuidgen fallback (CF-7) ────
if [ -z "$SESSION_ID" ]; then
    echo "[epistemic] SessionStart stdin missing session_id — session not tracked. Calibration block skipped." >&2
    # Continue to no-data exit path below; calibration cannot run without an ID
    exit 0
fi

# ── Source-branching (CF-5: defensive default) ───────────────────────
case "$SOURCE_VALUE" in
    startup|resume|clear) ;;  # known values
    *)
        echo "[epistemic] Unrecognized SessionStart source='$SOURCE_VALUE' — treating as startup." >&2
        SOURCE_VALUE="startup"
        ;;
esac

# ── Detect project ───────────────────────────────────────────────────
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(basename "$(pwd)" 2>/dev/null)
fi

# ── Determine STARTED (preserve on resume/clear if marker exists, E3) ─
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
STARTED="$NOW"
if [ "$SOURCE_VALUE" != "startup" ]; then
    EXISTING_STARTED=$(epistemic_get_marker_field STARTED 2>/dev/null)
    if [ -n "$EXISTING_STARTED" ]; then
        STARTED="$EXISTING_STARTED"
    fi
fi

# ── Sweep orphan markers (PID-reuse defense) before writing ─────────
epistemic_sweep_orphans

# ── Write per-claude-PID marker ─────────────────────────────────────
if ! epistemic_write_marker "$SESSION_ID" "$PROJECT_NAME" "$STARTED"; then
    echo "[epistemic] Marker write failed; session will not be tracked." >&2
fi

# ── Detect "preflight already submitted" (NEW-2 constraint) ──────────
# On resume/clear, suppress the "Submit preflight vectors" instruction
# if epistemic.json already has a non-null preflight for this session_id.
PREFLIGHT_ALREADY_SUBMITTED="false"
if [ "$SOURCE_VALUE" != "startup" ] && [ -s "$EPISTEMIC_FILE" ] && command -v jq &>/dev/null; then
    PREFLIGHT_ALREADY_SUBMITTED=$(jq --arg id "$SESSION_ID" \
        '[.sessions[]? | select(.id == $id and .preflight != null)] | length > 0' \
        "$EPISTEMIC_FILE" 2>/dev/null)
    [ "$PREFLIGHT_ALREADY_SUBMITTED" = "true" ] || PREFLIGHT_ALREADY_SUBMITTED="false"
fi

# ── Fast path: no calibration data yet ───────────────────────────────
if [ ! -s "$EPISTEMIC_FILE" ]; then
    cat >&2 << EOF
[Epistemic Tracking]
Session: ${SESSION_ID}
Project: ${PROJECT_NAME} (familiarity: new)

No calibration data yet. This is your first tracked session.

Submit preflight vectors using /epistemic-preflight with 13 scores (0.0-1.0):
  engagement, know, do, context, clarity, coherence, signal,
  density, state, change, completion, impact, uncertainty
EOF
    exit 0
fi

# ── Compute calibration (with timeout) ───────────────────────────────
_compute_calibration() {
    if ! command -v jq &>/dev/null; then
        cat >&2 << EOF
[Epistemic Tracking]
Session: ${SESSION_ID}
Project: ${PROJECT_NAME}

Calibration unavailable (jq not installed). Install jq for calibration feedback.

Submit preflight vectors using /epistemic-preflight with 13 scores (0.0-1.0):
  engagement, know, do, context, clarity, coherence, signal,
  density, state, change, completion, impact, uncertainty
EOF
        return 0
    fi

    local session_count familiarity
    session_count=$(jq --arg p "$PROJECT_NAME" \
        '.projects[$p].session_count // 0' "$EPISTEMIC_FILE" 2>/dev/null)

    if [ "$session_count" -ge 10 ] 2>/dev/null; then
        familiarity="high"
    elif [ "$session_count" -ge 3 ] 2>/dev/null; then
        familiarity="medium"
    else
        familiarity="low"
    fi

    local SCRIPT_DIR=""
    for try_dir in \
        "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" 2>/dev/null && pwd)" \
        "${HOME}/.claude/scripts"; do
        if [ -f "$try_dir/epistemic-feedback.sh" ]; then
            SCRIPT_DIR="$try_dir"
            break
        fi
    done

    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/epistemic-feedback.sh" ]; then
        # shellcheck disable=SC1091
        source "$SCRIPT_DIR/epistemic-feedback.sh"
        [ -f "$SCRIPT_DIR/epistemic-safe-write.sh" ] && source "$SCRIPT_DIR/epistemic-safe-write.sh"
        epistemic_format_calibration_block "$SESSION_ID" "$PROJECT_NAME" "$familiarity" >&2
    else
        cat >&2 << EOF
[Epistemic Tracking]
Session: ${SESSION_ID}
Project: ${PROJECT_NAME} (familiarity: ${familiarity})

Calibration feedback script not found. Raw data available in:
  ${EPISTEMIC_FILE}

Submit preflight vectors using /epistemic-preflight with 13 scores (0.0-1.0):
  engagement, know, do, context, clarity, coherence, signal,
  density, state, change, completion, impact, uncertainty
EOF
    fi

    # If preflight already submitted (resume), suppress the submit
    # instruction by appending a continuity note. The calibration block
    # itself is harmless to repeat; only the call-to-action would cause
    # confusion.
    if [ "$PREFLIGHT_ALREADY_SUBMITTED" = "true" ]; then
        echo "" >&2
        echo "[Note] Preflight already submitted for this session_id ($SOURCE_VALUE). Continuity preserved; no need to re-run /epistemic-preflight." >&2
    fi

    # Update project session count only on startup (resume reuses).
    if [ "$SOURCE_VALUE" = "startup" ]; then
        jq --arg p "$PROJECT_NAME" --arg now "$NOW" \
            '.projects[$p].session_count = ((.projects[$p].session_count // 0) + 1) |
             .projects[$p].last_session = $now |
             .projects[$p].familiarity = (
               if (.projects[$p].session_count >= 10) then "high"
               elif (.projects[$p].session_count >= 3) then "medium"
               else "low" end
             )' \
            "$EPISTEMIC_FILE" > "${EPISTEMIC_FILE}.tmp" 2>/dev/null
        local _jq_exit=$?
        if command -v epistemic_safe_swap >/dev/null 2>&1; then
            epistemic_safe_swap "$EPISTEMIC_FILE" "${EPISTEMIC_FILE}.tmp" "$_jq_exit" 2>/dev/null
        else
            if [ "$_jq_exit" -eq 0 ] && [ -s "${EPISTEMIC_FILE}.tmp" ] && \
               jq -e . "${EPISTEMIC_FILE}.tmp" >/dev/null 2>&1; then
                cp "$EPISTEMIC_FILE" "${EPISTEMIC_FILE}.bak" 2>/dev/null
                mv "${EPISTEMIC_FILE}.tmp" "$EPISTEMIC_FILE" 2>/dev/null
            else
                rm -f "${EPISTEMIC_FILE}.tmp" 2>/dev/null
            fi
        fi
    fi
}

# Run with timeout (1.5s budget) — sub-shell needs the helper too
if command -v timeout &>/dev/null; then
    timeout 1.5 bash -c "
        $(declare -f _compute_calibration _feedback_template _classify_direction _classify_magnitude epistemic_format_calibration_block epistemic_generate_feedback 2>/dev/null)
        EPISTEMIC_FILE='$EPISTEMIC_FILE'
        EPISTEMIC_TMP='${EPISTEMIC_FILE}.tmp'
        SESSION_ID='$SESSION_ID'
        PROJECT_NAME='$PROJECT_NAME'
        NOW='$NOW'
        SOURCE_VALUE='$SOURCE_VALUE'
        PREFLIGHT_ALREADY_SUBMITTED='$PREFLIGHT_ALREADY_SUBMITTED'
        _compute_calibration
    " 2>&1 >&2
    if [ $? -eq 124 ]; then
        echo "[Epistemic Tracking] Calibration unavailable (timeout)." >&2
        echo "Session: ${SESSION_ID}" >&2
        if [ "$PREFLIGHT_ALREADY_SUBMITTED" != "true" ]; then
            echo "" >&2
            echo "Submit preflight vectors using /epistemic-preflight with 13 scores (0.0-1.0):" >&2
            echo "  engagement, know, do, context, clarity, coherence, signal," >&2
            echo "  density, state, change, completion, impact, uncertainty" >&2
        fi
    fi
else
    _compute_calibration
fi

# Always exit 0 — fail-open
exit 0
