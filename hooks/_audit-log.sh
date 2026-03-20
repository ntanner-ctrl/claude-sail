#!/bin/bash
# Audit logging utility — sourced by blocking hooks, NOT a standalone hook
# Usage in hooks:
#   audit_block() { :; }  # no-op fallback
#   source ~/.claude/hooks/_audit-log.sh 2>/dev/null || true

audit_block() {
    local hook_name="$1" category="$2" reason="$3" tool="${4:-Bash}" snippet="${5:-}"
    local session_id=""
    if [[ -f ~/.claude/.current-session ]]; then
        session_id=$(grep "^SESSION_ID=" ~/.claude/.current-session | cut -d= -f2 | tr -d '\r')
    fi
    local project_root
    project_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
    local audit_dir="${project_root}/.claude"
    mkdir -p "$audit_dir" 2>/dev/null

    # Truncate snippet to 200 chars
    local safe_snippet="${snippet:0:200}"

    # Use jq for safe JSON construction (handles quotes/escapes)
    if command -v jq &>/dev/null; then
        jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              --arg hook "$hook_name" --arg cat "$category" \
              --arg reason "$reason" --arg tool "$tool" \
              --arg snippet "$safe_snippet" --arg sid "$session_id" \
              '{timestamp:$ts,hook:$hook,category:$cat,action:"block",reason:$reason,tool:$tool,command_snippet:$snippet,session_id:$sid}' \
              >> "$audit_dir/audit.jsonl" 2>/dev/null
    else
        # Fallback: escape quotes in snippet for basic JSON safety
        safe_snippet="${safe_snippet//\\/\\\\}"
        safe_snippet="${safe_snippet//\"/\\\"}"
        printf '{"timestamp":"%s","hook":"%s","category":"%s","action":"block","reason":"%s","tool":"%s","command_snippet":"%s","session_id":"%s"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hook_name" "$category" "$reason" "$tool" "$safe_snippet" "$session_id" \
            >> "$audit_dir/audit.jsonl" 2>/dev/null
    fi
}
