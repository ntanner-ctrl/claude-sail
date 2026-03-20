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

set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"
CURRENT_SESSION="${HOME}/.claude/.current-session"

# If no session marker, nothing to do
if [ ! -f "$CURRENT_SESSION" ]; then
    exit 0
fi

SESSION_ID=$(grep "^SESSION_ID=" "$CURRENT_SESSION" 2>/dev/null | cut -d= -f2)

# If no session ID, clean up and exit
if [ -z "$SESSION_ID" ]; then
    rm -f "$CURRENT_SESSION" 2>/dev/null
    exit 0
fi

# Check if postflight was already submitted (session is paired)
ALREADY_PAIRED="false"
if [ -s "$EPISTEMIC_FILE" ] && command -v jq &>/dev/null; then
    ALREADY_PAIRED=$(jq --arg id "$SESSION_ID" \
        '[.sessions[] | select(.id == $id and .paired == true)] | length > 0' \
        "$EPISTEMIC_FILE" 2>/dev/null)
fi

if [ "$ALREADY_PAIRED" = "true" ]; then
    # Postflight already submitted — clean up marker
    rm -f "$CURRENT_SESSION" 2>/dev/null
    exit 0
fi

# Postflight NOT submitted — output reminder
cat >&2 << EOF

[Epistemic Tracking — Session End]
Postflight vectors were NOT submitted for session ${SESSION_ID}.
This session will be stored as unpaired and excluded from calibration.

To capture postflight in future: use /end before closing the session.

EOF

# Clean up the session marker (stale marker prevention)
rm -f "$CURRENT_SESSION" 2>/dev/null

exit 0
