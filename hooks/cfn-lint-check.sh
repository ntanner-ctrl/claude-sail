#!/bin/bash
# =============================================================================
# CloudFormation Template Linter Hook (PostToolUse)
# =============================================================================
# Runs cfn-lint on CloudFormation YAML files after they are written/edited.
# Only activates on files containing AWSTemplateFormatVersion.
#
# Behavior:
#   - Fail-open (exit 0): lint issues don't block edits
#   - Checks for cfn-lint availability, prints install hint if missing
#   - Looks for .cfnlintrc in the file's directory tree for custom rules
#   - Sends feedback to Claude via stdout JSON
# =============================================================================

set +e  # Fail-open

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Read JSON input from stdin
input=$(cat)

# Extract file path from tool input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$file_path" || ! -f "$file_path" ]]; then
    exit 0
fi

# Only lint YAML files
if [[ "$file_path" != *.yaml && "$file_path" != *.yml ]]; then
    exit 0
fi

# Check if this is a CloudFormation template
if ! grep -q "AWSTemplateFormatVersion" "$file_path" 2>/dev/null; then
    exit 0
fi

# Check if cfn-lint is available
if ! command -v cfn-lint &>/dev/null; then
    echo "cfn-lint not found. Install with: pipx install cfn-lint" >&2
    exit 0
fi

# Find the nearest .cfnlintrc by walking up from the file's directory
config_dir=$(dirname "$file_path")
cfnlintrc=""
while [[ "$config_dir" != "/" ]]; do
    if [[ -f "$config_dir/.cfnlintrc" ]]; then
        cfnlintrc="$config_dir/.cfnlintrc"
        break
    fi
    config_dir=$(dirname "$config_dir")
done

# Build cfn-lint command
lint_cmd="cfn-lint"
if [[ -n "$cfnlintrc" ]]; then
    # cfn-lint auto-detects .cfnlintrc if we run from its directory
    lint_cmd="cd $(dirname "$cfnlintrc") && cfn-lint"
fi

# Run cfn-lint and capture output
lint_output=$(cd "$(dirname "${cfnlintrc:-$file_path}")" && cfn-lint "$file_path" 2>&1)
lint_exit=$?

if [[ $lint_exit -eq 0 ]]; then
    echo "cfn-lint: CloudFormation template is valid" >&2
    exit 0
fi

# Count errors vs warnings vs info
error_count=$(echo "$lint_output" | grep -c "^E" 2>/dev/null || echo "0")
warn_count=$(echo "$lint_output" | grep -c "^W" 2>/dev/null || echo "0")
info_count=$(echo "$lint_output" | grep -c "^I" 2>/dev/null || echo "0")

# Send structured feedback to Claude
echo "$lint_output" >&2

# Provide context back to Claude about the lint findings
if [[ $error_count -gt 0 ]]; then
    echo "cfn-lint found ${error_count} error(s), ${warn_count} warning(s), ${info_count} info in CloudFormation template. Review the issues above." >&2
fi

exit 0  # Fail-open: don't block the edit
