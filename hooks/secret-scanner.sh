#!/bin/bash
# Claude Code Secret Scanner - PreToolUse (for git commit/push)
# Scans staged files for hardcoded secrets before commits
# Adapted from TheDecipherist/claude-code-mastery
#
# Installation: Add to ~/.claude/settings.json:
# {
#   "hooks": {
#     "PreToolUse": [{
#       "matcher": "Bash",
#       "hooks": [{ "type": "command", "command": "~/.claude/hooks/secret-scanner.sh" }]
#     }]
#   }
# }

# Fail-open for non-commit operations
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Audit logging — no-op fallback if utility not installed
audit_block() { :; }
source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

# Read JSON input from stdin
input=$(cat)

# Extract the bash command
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

if [[ -z "$cmd" ]]; then
    exit 0  # No command to check
fi

# Only run scanner for git commit/push operations
if ! echo "$cmd" | grep -qE 'git\s+(commit|push)'; then
    exit 0  # Not a commit/push, allow
fi

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0  # Not a git repo, allow
fi

# Secret patterns to detect
# Format: "PATTERN_NAME|REGEX"
SECRET_PATTERNS=(
    "API_KEY|(api[_-]?key|apikey)\s*[:=]\s*['\"][A-Za-z0-9_\-]{16,}['\"]"
    "SECRET|(secret|password|passwd|pwd)\s*[:=]\s*['\"][^'\"]{8,}['\"]"
    "TOKEN|(token|auth[_-]?token|access[_-]?token)\s*[:=]\s*['\"][A-Za-z0-9_\-\.]{16,}['\"]"
    "AWS_KEY|AKIA[0-9A-Z]{16}"
    "PRIVATE_KEY|-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
    "GITHUB_TOKEN|gh[pousr]_[A-Za-z0-9_]{36,}"
    "SLACK_TOKEN|xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*"
    "STRIPE_KEY|sk_live_[0-9a-zA-Z]{24,}"
    "SENDGRID_KEY|SG\.[a-zA-Z0-9]{22}\.[a-zA-Z0-9-_]{43}"
    "TWILIO_KEY|SK[0-9a-fA-F]{32}"
    "GENERIC_SECRET|(client[_-]?secret|db[_-]?password|database[_-]?url)\s*[:=]\s*['\"][^'\"]{8,}['\"]"
)

# Get staged files
staged_files=$(git diff --cached --name-only 2>/dev/null)

if [[ -z "$staged_files" ]]; then
    exit 0  # No staged files, allow
fi

# Check for .env files in staging
env_files=$(echo "$staged_files" | grep -E '\.env($|\.)' || true)
if [[ -n "$env_files" ]]; then
    echo "WARNING: .env file(s) are staged for commit:" >&2
    echo "$env_files" | sed 's/^/  - /' >&2
    echo "" >&2
    echo "Consider removing them with: git reset HEAD <file>" >&2
    echo "Add to .gitignore to prevent future accidents." >&2
    echo "" >&2
    # Exit 2 to block with feedback to Claude
    audit_block "$HOOK_NAME" "SECURITY" ".env file staged for commit" "Bash" "${cmd:0:100}"
    exit 2
fi

# Scan staged content for secrets
found_secrets=()

while IFS= read -r file; do
    [ -z "$file" ] && continue
    # Skip binary files and common non-code files
    if [[ "$file" =~ \.(png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|pdf|zip|tar|gz)$ ]]; then
        continue
    fi

    # Get staged content for this file
    content=$(git show ":$file" 2>/dev/null || true)

    if [[ -z "$content" ]]; then
        continue
    fi

    # Check each pattern
    for pattern_def in "${SECRET_PATTERNS[@]}"; do
        pattern_name="${pattern_def%%|*}"
        pattern_regex="${pattern_def#*|}"

        if echo "$content" | grep -qEi "$pattern_regex" 2>/dev/null; then
            found_secrets+=("$file: Potential $pattern_name detected")
        fi
    done
done <<< "$staged_files"

# Report findings
if [[ ${#found_secrets[@]} -gt 0 ]]; then
    echo "SECURITY WARNING: Potential secrets detected in staged files!" >&2
    echo "" >&2
    for finding in "${found_secrets[@]}"; do
        echo "  - $finding" >&2
    done
    echo "" >&2
    echo "Review these files before committing." >&2
    echo "If these are false positives, you can:" >&2
    echo "  1. Add patterns to .gitignore" >&2
    echo "  2. Use environment variables instead" >&2
    echo "  3. Explicitly confirm to proceed" >&2
    echo "" >&2
    # Exit 2 to block with feedback to Claude
    audit_block "$HOOK_NAME" "SECURITY" "Potential secrets in staged files" "Bash" "${cmd:0:100}"
    exit 2
fi

# No secrets found, allow the commit
exit 0
