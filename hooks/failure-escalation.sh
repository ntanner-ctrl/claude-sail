#!/bin/bash
# failure-escalation.sh — PostToolUse hook for Bash
# Tracks consecutive test/build failures and escalates at thresholds.
#
# Exit Codes:
#   0 = allow (advisory only for Yellow/Orange)
#   2 = block with feedback to Claude (Red level)
#
# To disable: remove the PostToolUse entry for failure-escalation.sh from ~/.claude/settings.json
#
# Known Limitations:
#   - Compound commands (`cd /project && npm test`) won't match (starts with `cd`)
#   - Piped commands (`npm test | tee log`) may report wrong exit code without pipefail
#   - First tool call before statusline update has no signal files (sub-second gap, harmless)
#
# To disable: remove the PostToolUse entry for failure-escalation.sh from ~/.claude/settings.json

# Fail-open: Don't let hook bugs block work
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# --- Read tool result from stdin ---
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // empty' 2>/dev/null)
COMMAND=$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null)

# Fail-open: if parsing fails, allow
[ -z "$TOOL_NAME" ] && exit 0
[ "$TOOL_NAME" != "Bash" ] && exit 0
[ -z "$EXIT_CODE" ] && exit 0

# --- Strip leading whitespace from command ---
COMMAND=$(echo "$COMMAND" | sed 's/^[[:space:]]*//')

# --- Check if command matches test/build patterns ---
# CRITICAL: Prefix matching only. Enumerated patterns — no catchall.
#   "test -f somefile" does NOT match.
#   "build/run.sh" does NOT match.
#   "make test_data" does NOT match (make only with no args or all/build/test targets).
IS_MATCH=false
CMD_TYPE=""

case "$COMMAND" in
    # Test runners
    "npm test"*|"npx test"*|"yarn test"*|"bun test"*)
        IS_MATCH=true; CMD_TYPE="test" ;;
    "pytest"*|"python -m pytest"*)
        IS_MATCH=true; CMD_TYPE="test" ;;
    "cargo test"*|"go test"*)
        IS_MATCH=true; CMD_TYPE="test" ;;
    "jest"*|"vitest"*|"npx jest"*|"npx vitest"*)
        IS_MATCH=true; CMD_TYPE="test" ;;
    # Build tools
    "npm run build"*|"yarn build"*|"bun build"*)
        IS_MATCH=true; CMD_TYPE="build" ;;
    "cargo build"*)
        IS_MATCH=true; CMD_TYPE="build" ;;
    "tsc --build"*)
        IS_MATCH=true; CMD_TYPE="build" ;;
    "tsc"|"tsc "*)
        IS_MATCH=true; CMD_TYPE="build" ;;
    # make: only bare `make`, or `make all`, `make build`, `make test` (exact targets)
    "make")
        IS_MATCH=true; CMD_TYPE="build" ;;
    "make all"*|"make build"*|"make test"*)
        IS_MATCH=true; CMD_TYPE="build" ;;
esac

# Exclude make with targets that merely START with all/build/test but are different words
# e.g., "make test_data" should NOT match — only "make test" or "make test " (with flags)
if [ "$IS_MATCH" = true ] && [ -n "$CMD_TYPE" ]; then
    case "$COMMAND" in
        "make test_"*|"make test-"*|"make build_"*|"make build-"*|"make all_"*|"make all-"*)
            IS_MATCH=false ;;
        "make tester"*|"make builder"*|"make alloc"*)
            IS_MATCH=false ;;
    esac
fi

# Non-matched commands: exit immediately, don't touch counter
[ "$IS_MATCH" = false ] && exit 0

# --- Determine session-scoped counter file path ---
if [ "$PPID" -eq 1 ] 2>/dev/null; then
    SIG_SUFFIX="${USER}-$(pwd | md5sum | cut -c1-8)"
else
    SIG_SUFFIX="$PPID"
fi
COUNTER_FILE="/tmp/.claude-fail-count-${SIG_SUFFIX}"
DEBUG_RESET="/tmp/.claude-debug-reset-${SIG_SUFFIX}"

# --- Check for debug reset signal ---
if [ -f "$DEBUG_RESET" ]; then
    rm -f "$DEBUG_RESET" 2>/dev/null
    echo "0" > "$COUNTER_FILE"
    # Still process this command normally (don't exit early)
fi

# --- Read current counter ---
COUNT=0
[ -f "$COUNTER_FILE" ] && COUNT=$(cat "$COUNTER_FILE" 2>/dev/null)
COUNT=${COUNT:-0}
# Sanitize: ensure COUNT is numeric
case "$COUNT" in
    ''|*[!0-9]*) COUNT=0 ;;
esac

# --- Process result ---
if [ "$EXIT_CODE" = "0" ]; then
    # Success — reset counter
    echo "0" > "$COUNTER_FILE"
    exit 0
fi

# Failure — increment counter
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

# --- Escalation thresholds ---
if [ "$COUNT" -ge 4 ]; then
    # Red — block
    echo "4+ consecutive failures on the same type of command. You MUST run /debug or explain your approach to the user before continuing to retry." >&2
    exit 2
elif [ "$COUNT" -eq 3 ]; then
    # Orange — advisory
    echo "3 consecutive failures. Stop and analyze: is this the same root cause? Run /debug if stuck." >&2
    exit 0
elif [ "$COUNT" -eq 2 ]; then
    # Yellow — advisory
    echo "2 consecutive failures on ${CMD_TYPE}. Consider a different approach." >&2
    exit 0
fi

# Green (count=1) — no output
exit 0
