#!/bin/bash
# Claude Code CLAUDE.md Protection - PreToolUse Hook
# Prevents accidental modification of CLAUDE.md files that contain
# critical project instructions.
#
# Approval flow:
#   1. First write attempt → blocked (exit 2), feedback sent to Claude
#   2. Claude asks user for approval
#   3. User approves → Claude creates approval file via Bash
#   4. Claude retries Write → hook sees approval, allows, cleans up
#
# Approval file: /tmp/.claude-md-approved-<uid>
#   Contains the approved file path. Expires after 5 minutes.
#   Consumed on use (single-use approval).
#
# Inspired by ZacheryGlass/.claude protect_claude_md.py
#
# Exit Codes:
#   0 = Allow operation (not a CLAUDE.md file, or approved)
#   2 = Block with feedback TO CLAUDE (requires user confirmation)
#
# Installation: Add to ~/.claude/settings.json PreToolUse hooks
#   matcher: "Edit|Write"

# Fail-open: Don't let hook bugs block work
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Audit logging — no-op fallback if utility not installed
audit_block() { :; }
source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

APPROVAL_FILE="/tmp/.claude-md-approved-$(id -u)"
APPROVAL_MAX_AGE=300  # 5 minutes

# Read JSON input from stdin
input=$(cat)

# Extract file path from tool input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$file_path" ]]; then
    exit 0  # No file path, allow
fi

# Get just the filename
filename=$(basename "$file_path")

# Check if it's a CLAUDE.md file (case-insensitive)
if [[ "${filename,,}" == "claude.md" ]]; then
    # Check for approval file
    if [[ -f "$APPROVAL_FILE" ]]; then
        approved_path=$(cat "$APPROVAL_FILE" 2>/dev/null)
        approval_mtime=$(stat -c %Y "$APPROVAL_FILE" 2>/dev/null || echo 0)
        now=$(date +%s)
        approval_age=$(( now - approval_mtime ))

        if [[ "$approved_path" == "$file_path" && $approval_age -lt $APPROVAL_MAX_AGE ]]; then
            # Valid approval — allow and consume
            rm -f "$APPROVAL_FILE"
            exit 0
        fi
        # Stale or wrong path — clean up and block
        rm -f "$APPROVAL_FILE"
    fi

    # Determine context for feedback message
    if [[ "$file_path" == *"/.claude/"* ]]; then
        location="project-level (.claude/)"
    elif [[ "$file_path" == *"$HOME/.claude/"* ]] || [[ "$file_path" == *"$HOME/"* && "$file_path" == *"CLAUDE.md" ]]; then
        location="user-level (~/.claude/)"
    else
        location="$(dirname "$file_path")"
    fi

    echo "PROTECTED FILE: CLAUDE.md modification detected" >&2
    echo "" >&2
    echo "Target: $file_path" >&2
    echo "Location: $location" >&2
    echo "" >&2
    echo "CLAUDE.md files contain critical project instructions that guide" >&2
    echo "Claude's behavior. Accidental modifications can break workflows." >&2
    echo "" >&2
    echo "To approve this edit, ask the user for confirmation, then run:" >&2
    echo "  echo '$file_path' > $APPROVAL_FILE" >&2
    echo "Then retry the Write/Edit operation." >&2
    audit_block "$HOOK_NAME" "GIT_SAFETY" "CLAUDE.md modification blocked pending approval" "Edit|Write" "${file_path:0:100}"
    exit 2
fi

exit 0
