#!/usr/bin/env bash
# epistemic-preflight.sh — SessionStart hook for native epistemic tracking
#
# Injects calibration context and prompts for preflight vectors.
# Replaces the Empirica session-creation logic in session-sail.sh.
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
CURRENT_SESSION="${HOME}/.claude/.current-session"

# ── Ensure directory exists ──────────────────────────────────
mkdir -p "${HOME}/.claude" 2>/dev/null

# ── Generate session ID ──────────────────────────────────────
SESSION_ID=""
if command -v uuidgen &>/dev/null; then
    SESSION_ID=$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]')
elif [ -f /proc/sys/kernel/random/uuid ]; then
    SESSION_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
fi
# Fallback: timestamp-based ID
if [ -z "$SESSION_ID" ]; then
    SESSION_ID="session-$(date +%Y%m%d-%H%M%S)-$$"
fi

# ── Detect project ───────────────────────────────────────────
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME=$(basename "$(pwd)" 2>/dev/null)
fi

# ── Write session marker (unconditional overwrite) ───────────
# Stale markers from crashed sessions are safe to replace — the crashed
# session will never submit postflight, so its marker is always expendable.
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)
{
    echo "SESSION_ID=${SESSION_ID}"
    echo "PROJECT=${PROJECT_NAME}"
    echo "STARTED=${NOW}"
} > "$CURRENT_SESSION" 2>/dev/null

if [ ! -f "$CURRENT_SESSION" ]; then
    echo "WARNING: .current-session write failed — session will not be tracked." >&2
fi

# ── Fast path: no data yet ───────────────────────────────────
# Use -s (exists AND non-empty). A 0-byte file from a crash is
# functionally equivalent to no file.
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

# ── Compute calibration context (with timeout) ───────────────
# Budget: 1.5s for computation, 0.5s headroom for shell startup
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

    # Determine project familiarity
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

    # Source feedback generator and format the block
    SCRIPT_DIR=""
    # Try repo location first (dev mode), then installed location
    for try_dir in \
        "$(cd "$(dirname "${BASH_SOURCE[0]}")/../scripts" 2>/dev/null && pwd)" \
        "${HOME}/.claude/scripts"; do
        if [ -f "$try_dir/epistemic-feedback.sh" ]; then
            SCRIPT_DIR="$try_dir"
            break
        fi
    done

    if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/epistemic-feedback.sh" ]; then
        source "$SCRIPT_DIR/epistemic-feedback.sh"
        epistemic_format_calibration_block "$SESSION_ID" "$PROJECT_NAME" "$familiarity" >&2
    else
        # Inline fallback if feedback script not found
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

    # Update project session count
    jq --arg p "$PROJECT_NAME" --arg now "$NOW" \
        '.projects[$p].session_count = ((.projects[$p].session_count // 0) + 1) |
         .projects[$p].last_session = $now |
         .projects[$p].familiarity = (
           if (.projects[$p].session_count >= 10) then "high"
           elif (.projects[$p].session_count >= 3) then "medium"
           else "low" end
         )' \
        "$EPISTEMIC_FILE" > "${EPISTEMIC_FILE}.tmp" 2>/dev/null && \
        mv "${EPISTEMIC_FILE}.tmp" "$EPISTEMIC_FILE" 2>/dev/null
}

# Run with timeout (1.5s budget)
if command -v timeout &>/dev/null; then
    timeout 1.5 bash -c "$(declare -f _compute_calibration _feedback_template _classify_direction _classify_magnitude epistemic_format_calibration_block epistemic_generate_feedback); EPISTEMIC_FILE='$EPISTEMIC_FILE'; EPISTEMIC_TMP='${EPISTEMIC_FILE}.tmp'; CURRENT_SESSION='$CURRENT_SESSION'; SESSION_ID='$SESSION_ID'; PROJECT_NAME='$PROJECT_NAME'; NOW='$NOW'; _compute_calibration" 2>&1 >&2
    if [ $? -eq 124 ]; then
        echo "[Epistemic Tracking] Calibration unavailable (timeout)." >&2
        echo "Session: ${SESSION_ID}" >&2
        echo "" >&2
        echo "Submit preflight vectors using /epistemic-preflight with 13 scores (0.0-1.0):" >&2
        echo "  engagement, know, do, context, clarity, coherence, signal," >&2
        echo "  density, state, change, completion, impact, uncertainty" >&2
    fi
else
    _compute_calibration
fi

# Always exit 0 — fail-open
exit 0
