#!/bin/bash
#
# Quick project setup check for session start
# Runs silently unless issues are found
#
set -euo pipefail

# Read input from stdin (session info as JSON)
input=$(cat)

# Extract working directory from session info
cwd=$(echo "$input" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

# Check if user has disabled session start checks
config_file="$HOME/.claude/sail-config.json"
if [ -f "$config_file" ]; then
    disabled=$(jq -r '.disableSessionCheck // false' "$config_file" 2>/dev/null || echo "false")
    if [ "$disabled" = "true" ]; then
        exit 0
    fi
fi

# Initialize suggestions array
suggestions=()

# Quick Check 1: Does .claude directory exist?
if [ ! -d "$cwd/.claude" ]; then
    suggestions+=("No .claude/ directory - consider running /bootstrap-project")
fi

# Quick Check 2: Does CLAUDE.md exist?
claude_md=""
if [ -f "$cwd/.claude/CLAUDE.md" ]; then
    claude_md="$cwd/.claude/CLAUDE.md"
elif [ -f "$cwd/CLAUDE.md" ]; then
    claude_md="$cwd/CLAUDE.md"
fi

if [ -z "$claude_md" ]; then
    suggestions+=("No CLAUDE.md found - consider running /bootstrap-project")
fi

# Quick Check 3: Is there a git repo? (indicates this is a real project)
if [ ! -d "$cwd/.git" ]; then
    # Not a git repo, might not be a project worth bootstrapping
    # Exit silently
    exit 0
fi

# Quick Check 4: Check manifest staleness (if it exists)
# Check both new and old manifest names (backward compatibility)
manifest="$cwd/.claude/sail-manifest.json"
if [ ! -f "$manifest" ]; then
    manifest="$cwd/.claude/bootstrap-manifest.json"
fi
if [ -f "$manifest" ]; then
    # Check if bootstrapped more than 30 days ago
    bootstrapped_at=$(jq -r '.bootstrapped_at // ""' "$manifest" 2>/dev/null || echo "")
    if [ -n "$bootstrapped_at" ]; then
        # Convert to epoch and compare
        if command -v date >/dev/null 2>&1; then
            bootstrap_epoch=$(date -d "$bootstrapped_at" +%s 2>/dev/null || echo "0")
            now_epoch=$(date +%s)
            days_ago=$(( (now_epoch - bootstrap_epoch) / 86400 ))
            if [ "$days_ago" -gt 30 ]; then
                suggestions+=("Setup is ${days_ago} days old - consider running /check-project-setup")
            fi
        fi
    fi
fi

# Output suggestions if any found
if [ ${#suggestions[@]} -gt 0 ]; then
    # Format as JSON for Claude Code to display
    message="Project setup: ${#suggestions[@]} suggestion(s). "
    if [ ${#suggestions[@]} -eq 1 ]; then
        message+="${suggestions[0]}"
    else
        message+="Run /check-project-setup for details."
    fi

    # Output as system message
    echo "{\"systemMessage\": \"$message\"}"
else
    # All good, exit silently
    exit 0
fi
