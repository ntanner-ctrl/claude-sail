#!/bin/bash
# Claude Code Freeze Guard - PreToolUse Hook
# Blocks Edit/Write operations targeting directories frozen by /freeze.
#
# Frozen directories are stored in .claude/frozen-dirs.json (relative to
# the project root). Each entry is an absolute path written by /freeze.
#
# Exit Codes:
#   0 = Allow operation (file not in any frozen directory, or no frozen dirs)
#   2 = Block with feedback TO CLAUDE (file is inside a frozen directory)
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

# Audit integration — no-op fallback if audit log hook not installed
audit_block() { :; }
source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

# Require jq — fail-open if absent
if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

# Read JSON input from stdin
input=$(cat)

# Extract file path from tool input (fail-open if not present)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$file_path" ]]; then
    exit 0  # No file path, allow
fi

# Resolve to absolute path for reliable comparison
abs_file=$(realpath "$file_path" 2>/dev/null || echo "$file_path")

# Locate frozen-dirs.json — search from git root or cwd
git_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
frozen_dirs_file="${git_root}/.claude/frozen-dirs.json"

if [[ ! -f "$frozen_dirs_file" ]]; then
    exit 0  # No frozen dirs configured, allow
fi

# Parse frozen directories list (fail-open if malformed JSON)
frozen_dirs=$(jq -r '.[] // empty' "$frozen_dirs_file" 2>/dev/null)

if [[ -z "$frozen_dirs" ]]; then
    exit 0  # Empty or unparseable list, allow
fi

# Check if the target file lives inside any frozen directory
while IFS= read -r frozen_dir; do
    [[ -z "$frozen_dir" ]] && continue

    # Resolve stored path to absolute (should already be absolute from /freeze,
    # but normalize to be safe)
    abs_frozen=$(realpath "$frozen_dir" 2>/dev/null || echo "$frozen_dir")

    # Use trailing-slash prefix check to prevent src/auth matching src/auth-v2
    if [[ "$abs_file" == "${abs_frozen}/"* || "$abs_file" == "${abs_frozen}" ]]; then
        audit_block "freeze-guard" "$file_path" "inside frozen directory: $frozen_dir"

        echo "BLOCKED [FREEZE-GUARD]: File is inside a frozen directory" >&2
        echo "" >&2
        echo "Target file:      $file_path" >&2
        echo "Frozen directory: $frozen_dir" >&2
        echo "" >&2
        echo "This directory has been frozen to protect it from modification." >&2
        echo "To unfreeze, ask the user to run /unfreeze on the directory," >&2
        echo "or use /freeze --list to see all currently frozen directories." >&2
        exit 2
    fi
done <<< "$frozen_dirs"

# All checks passed — file is not in any frozen directory
exit 0
