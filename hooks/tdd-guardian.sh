#!/bin/bash
#
# TDD Guardian Hook - blocks implementation edits during RED phase
#
# Matcher: PreToolUse (Edit|Write)
# Reads: .claude/tdd-sessions/active.json in working directory
# Exit codes: 0=allow, 2=block with feedback
#
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Audit logging — no-op fallback if utility not installed
audit_block() { :; }
source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

# Read tool input from stdin
input=$(cat)

# Check for active TDD session in current project
SESSION_FILE=".claude/tdd-sessions/active.json"
if [ ! -f "$SESSION_FILE" ]; then
    exit 0  # No active TDD session
fi

# Parse session state
PHASE=$(jq -r '.phase // empty' "$SESSION_FILE" 2>/dev/null)
MODE=$(jq -r '.mode // "advisory"' "$SESSION_FILE" 2>/dev/null)
TARGET=$(jq -r '.target // empty' "$SESSION_FILE" 2>/dev/null)
TEST_FILE=$(jq -r '.test_file // empty' "$SESSION_FILE" 2>/dev/null)

# Only enforce during RED phase
if [ "$PHASE" != "red" ]; then
    exit 0
fi

# Get the file being edited
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.filePath // empty' 2>/dev/null)
if [ -z "$file_path" ]; then
    exit 0  # Can't determine file, allow
fi

# Normalize paths for comparison
file_base=$(basename "$file_path")
file_lower="${file_base,,}"

# Allow test/spec file edits (these are expected in RED phase)
if [[ "$file_lower" == *"test"* ]] || [[ "$file_lower" == *"spec"* ]] || [[ "$file_lower" == *"_test."* ]]; then
    exit 0
fi

# Allow edits to files outside the target path
if [ -n "$TARGET" ]; then
    # Check if the edited file matches or is within the target path
    target_dir=$(dirname "$TARGET")
    if [[ "$file_path" != "$TARGET" ]] && [[ "$file_path" != "$target_dir"/* ]]; then
        exit 0  # Not targeting the TDD subject
    fi
fi

# At this point: RED phase + implementation file edit detected

if [ "$MODE" = "advisory" ]; then
    # Advisory: warn but allow
    echo "⚠️  TDD ADVISORY: Implementation edit during RED phase." >&2
    echo "   File: $file_path" >&2
    echo "   Write tests first: $TEST_FILE" >&2
    echo "   This violation has been logged." >&2
    # Log violation to session
    if command -v jq &>/dev/null; then
        tmp=$(mktemp)
        jq --arg f "$file_path" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            '.violations = (.violations // []) + [{"file": $f, "time": $t}]' \
            "$SESSION_FILE" > "$tmp" && mv "$tmp" "$SESSION_FILE"
    fi
    exit 0  # Allow in advisory
fi

# Strict or Aggressive: block
echo "🚫 TDD VIOLATION: Cannot edit implementation during RED phase." >&2
echo "" >&2
echo "   File: $file_path" >&2
echo "   Phase: RED (tests must fail first)" >&2
echo "   Mode: $MODE" >&2
echo "" >&2
echo "   To proceed:" >&2
echo "     1. Write tests in: $TEST_FILE" >&2
echo "     2. Run tests to confirm they FAIL" >&2
echo "     3. Implementation unlocks in GREEN phase" >&2

if [ "$MODE" = "aggressive" ]; then
    echo "" >&2
    echo "   ⚠️  Aggressive mode: continued violations will trigger code deletion." >&2
fi

audit_block "$HOOK_NAME" "TDD" "Implementation edit blocked during RED phase ($MODE mode)" "Edit|Write" "${file_path:0:100}"
exit 2  # Block
