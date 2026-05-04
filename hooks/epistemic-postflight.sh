#!/usr/bin/env bash
# epistemic-postflight.sh — SessionEnd hook for native epistemic tracking
#
# If postflight vectors haven't been submitted (session marker still exists
# and session is unpaired), output a reminder to stderr.
#
# This is the SECONDARY mechanism. The PRIMARY mechanism is /end invoking
# /epistemic-postflight. This hook is a fallback for sessions that end
# without /end (terminal close, context expiry, etc.).
#
# Trigger: SessionEnd event
# Exit code: Always 0 (fail-open)
#
# Read order: per-claude-PID marker (via epistemic_get_session_id) first,
# stdin JSON session_id second (probe v2 confirmed SessionEnd stdin
# contains session_id). Marker cleanup is SCOPED to the current claude
# PID's file only — never bare `rm -f` on the marker directory.

set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"

# ── Source helper ────────────────────────────────────────────────────
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
    # Helper missing — cannot resolve session. Fail-open silently.
    exit 0
fi

# ── Read SessionEnd stdin (fallback for session_id) ──────────────────
STDIN_JSON=""
if [ ! -t 0 ]; then
    STDIN_JSON=$(cat)
fi

# ── Resolve session_id: marker first, stdin fallback ─────────────────
SESSION_ID=$(epistemic_get_session_id 2>/dev/null)

if [ -z "$SESSION_ID" ] && [ -n "$STDIN_JSON" ] && command -v jq &>/dev/null; then
    SESSION_ID=$(printf '%s' "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null)
fi

if [ -z "$SESSION_ID" ]; then
    # No session resolvable. AC11 path: warn, exit 0.
    echo "[epistemic] SessionEnd: no marker, no stdin session_id — postflight skipped." >&2
    exit 0
fi

# ── Compute marker path for SCOPED cleanup ──────────────────────────
MARKER_PATH=$(epistemic_marker_path 2>/dev/null)

# ── Check if postflight was already submitted (paired) ──────────────
ALREADY_PAIRED="false"
if [ -s "$EPISTEMIC_FILE" ] && command -v jq &>/dev/null; then
    ALREADY_PAIRED=$(jq --arg id "$SESSION_ID" \
        '[.sessions[]? | select(.id == $id and .paired == true)] | length > 0' \
        "$EPISTEMIC_FILE" 2>/dev/null)
fi

if [ "$ALREADY_PAIRED" = "true" ]; then
    # Postflight already submitted — clean up THIS process's marker only
    [ -n "$MARKER_PATH" ] && [ -f "$MARKER_PATH" ] && rm -f -- "$MARKER_PATH" 2>/dev/null
    exit 0
fi

# ── Postflight NOT submitted — output reminder ───────────────────────
cat >&2 << EOF

[Epistemic Tracking — Session End]
Postflight vectors were NOT submitted for session ${SESSION_ID}.
This session will be stored as unpaired and excluded from calibration.

To capture postflight in future: use /end before closing the session.

EOF

# ── Clean up THIS process's marker only (scoped delete) ─────────────
# Bare `rm -f $CURRENT_SESSION` would now target a directory; the helper
# resolves to the specific per-claude-PID file inside the directory.
if [ -n "$MARKER_PATH" ] && [ -f "$MARKER_PATH" ]; then
    rm -f -- "$MARKER_PATH" 2>/dev/null
fi

exit 0
