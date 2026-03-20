#!/bin/bash
# Blueprint Stage Gate - PostToolUse Hook (Edit|Write matcher)
# Enforces epistemic integration during blueprint workflow.
#
# Checks for required epistemic data before allowing stage transitions.
# Blocking (exit 2) — prevents stage transitions when epistemic data is missing.
# Promoted from advisory mode after initial confidence period.
#
# Fires on Write operations to state.json within .claude/plans/*/
# Checks:
#   1. epistemic_session_id (or legacy empirica_session_id) exists and is non-null
#   2. Previous stage has a confidence score
#   3. On Stage 1→2 transition: preflight assessment exists
#   4. manifest_stale flag is not set [H5]
#
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Installation: PostToolUse hook with matcher "Edit|Write"

TOOL_INPUT="${CLAUDE_TOOL_INPUT:-}"
FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty' 2>/dev/null)

[ -z "$FILE_PATH" ] && exit 0

# Only care about blueprint state files
case "$FILE_PATH" in
    */.claude/plans/*/state.json) ;;
    *) exit 0 ;;
esac

# Only act if the file actually exists and is valid JSON
[ -f "$FILE_PATH" ] || exit 0
jq empty "$FILE_PATH" 2>/dev/null || exit 0

# Check if this is a blueprint v2 plan
VERSION=$(jq -r '.blueprint_version // empty' "$FILE_PATH" 2>/dev/null)
[ -z "$VERSION" ] && exit 0  # Pre-v2 plan, skip checks

# Check if workflow is active (not complete or halted)
EXECUTE_STATUS=$(jq -r '.stages.execute.status // empty' "$FILE_PATH" 2>/dev/null)
case "$EXECUTE_STATUS" in
    complete|halted) exit 0 ;;  # Workflow finished, no enforcement needed
esac

# Collect missing items
MISSING=()
PRESENT=()

# Check 1: epistemic session_id
SESSION_ID=$(jq -r '.epistemic_session_id // .empirica_session_id // empty' "$FILE_PATH" 2>/dev/null)
if [ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "null" ]; then
    MISSING+=("epistemic_session_id in state.json")
else
    PRESENT+=("epistemic_session_id in state.json")
fi

# Check 2: Previous completed stage has confidence score
CURRENT_STAGE=$(jq -r '.current_stage // 1' "$FILE_PATH" 2>/dev/null)

# Map stage numbers to names for confidence checking
check_confidence_for_stage() {
    local stage_name=$1
    local conf
    conf=$(jq -r ".stages.${stage_name}.confidence // empty" "$FILE_PATH" 2>/dev/null)
    if [ -n "$conf" ] && [ "$conf" != "null" ]; then
        PRESENT+=("confidence score for ${stage_name}")
    else
        local status
        status=$(jq -r ".stages.${stage_name}.status // empty" "$FILE_PATH" 2>/dev/null)
        if [ "$status" = "complete" ]; then
            MISSING+=("confidence score for ${stage_name}")
        fi
    fi
}

# Check confidence for completed stages
for stage in describe specify challenge edge_cases premortem review test; do
    check_confidence_for_stage "$stage"
done

# Check 3: Preflight assessment (required before Stage 2)
if [ "$CURRENT_STAGE" -ge 2 ] 2>/dev/null; then
    PREFLIGHT=$(jq -r '.epistemic_preflight_complete // .empirica_preflight_complete // false' "$FILE_PATH" 2>/dev/null)
    if [ "$PREFLIGHT" = "true" ]; then
        PRESENT+=("preflight assessment")
    else
        MISSING+=("preflight assessment")
    fi
fi

# Check 4: Manifest staleness [H5]
MANIFEST_STALE=$(jq -r '.manifest_stale // false' "$FILE_PATH" 2>/dev/null)
if [ "$MANIFEST_STALE" = "true" ]; then
    MISSING+=("manifest is stale — resolve before advancing")
fi

# Report if anything is missing
if [ ${#MISSING[@]} -gt 0 ]; then
    echo ""
    echo "BLOCKED: Blueprint stage gate — missing epistemic data."
    for item in "${PRESENT[@]}"; do
        echo "  - [x] $item"
    done
    for item in "${MISSING[@]}"; do
        echo "  - [ ] $item"
    done
    echo ""
    echo "Run the required epistemic calls before advancing to the next stage."
    echo ""
    # Exit 2 = block the tool use (promoted from advisory)
    exit 2
fi

exit 0
