#!/bin/bash
# Claude Code Auto-Format Hook - PostToolUse
# Runs formatters automatically after Edit/Write operations
# Adapted from TheDecipherist/claude-code-mastery
#
# Installation: Add to ~/.claude/settings.json:
# {
#   "hooks": {
#     "PostToolUse": [{
#       "matcher": "Edit|Write",
#       "hooks": [{ "type": "command", "command": "~/.claude/hooks/after-edit.sh" }]
#     }]
#   }
# }

# Fail-open: formatting errors shouldn't block work
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Timeout for formatters (prevent runaway processes)
TIMEOUT=10

# Read JSON input from stdin
input=$(cat)

# Extract file path (fail-open: exit if can't parse)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null)

if [[ -z "$file_path" || ! -f "$file_path" ]]; then
    exit 0  # No file to format
fi

# Get file extension
ext="${file_path##*.}"
filename=$(basename "$file_path")

# Run formatter with timeout (non-blocking)
run_formatter() {
    local name="$1"
    local cmd="$2"

    if timeout "$TIMEOUT" bash -c "$cmd" 2>/dev/null; then
        [[ -n "$CLAUDE_HOOK_VERBOSE" ]] && echo "✓ $name" >&2
    else
        # Timeout (124) or failure - both non-blocking
        [[ -n "$CLAUDE_HOOK_VERBOSE" ]] && echo "✗ $name (non-blocking)" >&2
    fi
}

# Detect and run appropriate formatter
case "$ext" in
    # JavaScript/TypeScript ecosystem (Prettier)
    js|jsx|ts|tsx|mjs|cjs)
        if command -v prettier &>/dev/null; then
            run_formatter "prettier" "prettier --write '$file_path'"
        elif command -v npx &>/dev/null && [[ -f "package.json" ]]; then
            run_formatter "prettier (npx)" "npx prettier --write '$file_path'"
        fi
        ;;

    # JSON/YAML/Config files
    json)
        if command -v prettier &>/dev/null; then
            run_formatter "prettier" "prettier --write '$file_path'"
        elif command -v jq &>/dev/null; then
            # jq can format JSON in-place via temp file
            run_formatter "jq" "jq '.' '$file_path' > '$file_path.tmp' && mv '$file_path.tmp' '$file_path'"
        fi
        ;;

    yaml|yml)
        if command -v prettier &>/dev/null; then
            run_formatter "prettier" "prettier --write '$file_path'"
        fi
        ;;

    # CSS/HTML/Markdown
    css|scss|less|html|htm|md)
        if command -v prettier &>/dev/null; then
            run_formatter "prettier" "prettier --write '$file_path'"
        fi
        ;;

    # Python (Black + Ruff)
    py)
        if command -v black &>/dev/null; then
            run_formatter "black" "black --quiet '$file_path'"
        fi
        if command -v ruff &>/dev/null; then
            run_formatter "ruff" "ruff format --quiet '$file_path'"
        fi
        ;;

    # Go
    go)
        if command -v gofmt &>/dev/null; then
            run_formatter "gofmt" "gofmt -w '$file_path'"
        fi
        if command -v goimports &>/dev/null; then
            run_formatter "goimports" "goimports -w '$file_path'"
        fi
        ;;

    # Rust
    rs)
        if command -v rustfmt &>/dev/null; then
            run_formatter "rustfmt" "rustfmt '$file_path'"
        fi
        ;;

    # Shell scripts
    sh|bash)
        if command -v shfmt &>/dev/null; then
            run_formatter "shfmt" "shfmt -w '$file_path'"
        fi
        ;;

    # SQL
    sql)
        if command -v sqlfluff &>/dev/null; then
            run_formatter "sqlfluff" "sqlfluff fix --force '$file_path'"
        elif command -v pg_format &>/dev/null; then
            run_formatter "pg_format" "pg_format -i '$file_path'"
        fi
        ;;

    # Terraform
    tf|tfvars)
        if command -v terraform &>/dev/null; then
            run_formatter "terraform" "terraform fmt '$file_path'"
        fi
        ;;
esac

# Always exit 0 (fail-open) - formatting failures shouldn't block edits
exit 0
