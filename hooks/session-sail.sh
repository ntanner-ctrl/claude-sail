#!/bin/bash
# Claude Sail - Session Start Hook
# Injects awareness of available commands at session start.
#
# Philosophy: Superpowers (obra/superpowers) proved that a <2000 token
# bootstrap injection dramatically increases command usage. The key insight
# is using MUST language and trigger conditions, not suggestions.
#
# This hook makes Claude aware it has structured workflows available
# and creates obligation to use them when applicable.
#
# Installation: Add to ~/.claude/settings.json SessionStart hooks
# Output: Stdout is injected into conversation context
set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# Detect available commands
COMMANDS_DIR="${HOME}/.claude/commands"
PROJECT_COMMANDS=".claude/commands"

# Count available commands
global_count=0
project_count=0

if [ -d "$COMMANDS_DIR" ]; then
    global_count=$(find "$COMMANDS_DIR" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
fi

if [ -d "$PROJECT_COMMANDS" ]; then
    project_count=$(find "$PROJECT_COMMANDS" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l)
fi

total=$((global_count + project_count))

# Only inject if commands actually exist
if [ "$total" -eq 0 ]; then
    exit 0
fi

# Build command categories for awareness
planning_cmds=""
safety_cmds=""
testing_cmds=""
other_cmds=""

for cmd_file in "$COMMANDS_DIR"/*.md "$PROJECT_COMMANDS"/*.md; do
    [ -f "$cmd_file" ] || continue
    name=$(basename "$cmd_file" .md)
    case "$name" in
        blueprint|spec-change|describe-change|brainstorm|preflight|decision|design-check)
            planning_cmds="${planning_cmds}  /${name}\n"
            ;;
        push-safe|security-checklist|setup-hooks|checkpoint|end)
            safety_cmds="${safety_cmds}  /${name}\n"
            ;;
        test|spec-to-tests|tdd|debug)
            testing_cmds="${testing_cmds}  /${name}\n"
            ;;
        start|toolkit|status|blueprints|approve|dashboard)
            ;; # Skip meta commands from the list
        *)
            other_cmds="${other_cmds}  /${name}\n"
            ;;
    esac
done

ACTIVE_WORK=""

# Epistemic tracking is handled by hooks/epistemic-preflight.sh (SessionStart hook).
# No Empirica session creation needed — native system uses ~/.claude/epistemic.json.

# Check state-index for active work context
if [ -f ".claude/state-index.json" ]; then
    plan=$(jq -r '.active_blueprint // .active_plan // empty' .claude/state-index.json 2>/dev/null)
    stage=$(jq -r '.active_blueprint_stage // .active_plan_stage // empty' .claude/state-index.json 2>/dev/null)
    tdd_phase=$(jq -r '.active_tdd_phase // empty' .claude/state-index.json 2>/dev/null)
    checkpoint=$(jq -r '.last_checkpoint // empty' .claude/state-index.json 2>/dev/null)

    if [ -n "$plan" ] || [ -n "$tdd_phase" ]; then
        ACTIVE_WORK="\nACTIVE WORK:"
        if [ -n "$plan" ]; then
            ACTIVE_WORK="${ACTIVE_WORK}\n  Blueprint: ${plan} (Stage ${stage}/7). Resume: /blueprint ${plan}"
        fi
        if [ -n "$tdd_phase" ]; then
            ACTIVE_WORK="${ACTIVE_WORK}\n  TDD: Phase ${tdd_phase}. Resume: /tdd"
        fi
        if [ -n "$checkpoint" ]; then
            ACTIVE_WORK="${ACTIVE_WORK}\n  Last checkpoint: ${checkpoint}"
        fi
    fi
fi

# Write session-start timestamp (used by /end to scope "this session" artifacts)
date -Iseconds > "/tmp/.claude-session-start-$(id -u)" 2>/dev/null

# Check for Obsidian vault and inject recent context
VAULT_CONTEXT=""
if [ -f "${HOME}/.claude/hooks/vault-config.sh" ]; then
    source "${HOME}/.claude/hooks/vault-config.sh" 2>/dev/null
    if [ "$VAULT_ENABLED" = "1" ] && vault_is_available; then
        # Get current project name for filtering
        VAULT_PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)

        # Project-filtered search: grep frontmatter for project match, sort by mtime, limit 7
        # Timeout after 2s to protect SessionStart <2s budget on slow WSL-to-NTFS mounts
        RECENT_NOTES=""
        VAULT_LABEL="recent"
        if [ -n "$VAULT_PROJECT" ]; then
            RECENT_NOTES=$(timeout 2 grep -rl "^project:.*${VAULT_PROJECT}" "$VAULT_PATH" --include="*.md" \
                2>/dev/null | grep -v '/.obsidian/' | grep -v '/_Templates/' | grep -v '/CLAUDE.md' \
                | xargs -d '\n' ls -t 2>/dev/null | head -7)
            VAULT_LABEL="for ${VAULT_PROJECT}"
        fi

        # Fall back to global recent if no project-specific notes found
        if [ -z "$RECENT_NOTES" ]; then
            RECENT_NOTES=$(timeout 2 find "$VAULT_PATH" -maxdepth 3 -name "*.md" \
                -not -path "*/.obsidian/*" -not -path "*/_Templates/*" -not -name "CLAUDE.md" \
                2>/dev/null | xargs -d '\n' ls -t 2>/dev/null | head -7)
            VAULT_LABEL="recent (no project match)"
        fi

        if [ -n "$RECENT_NOTES" ]; then
            VAULT_CONTEXT=$(printf '\nOBSIDIAN VAULT (project knowledge):\n  Vault: %s\n  Notes %s:' "$VAULT_PATH" "$VAULT_LABEL")
            while IFS= read -r note_path; do
                [ -f "$note_path" ] || continue
                REL_PATH="${note_path#$VAULT_PATH/}"
                # Extract first H1 title for context
                TITLE=$(awk '/^# /{print; exit}' "$note_path" 2>/dev/null | sed 's/^# //')
                if [ -n "$TITLE" ]; then
                    VAULT_CONTEXT=$(printf '%s\n    %s\n      "%s"' "$VAULT_CONTEXT" "$REL_PATH" "$TITLE")
                else
                    VAULT_CONTEXT=$(printf '%s\n    %s' "$VAULT_CONTEXT" "$REL_PATH")
                fi
            done <<< "$RECENT_NOTES"
            VAULT_CONTEXT=$(printf '%s\n  Use /vault-query to search for specific topics.\n  Use /vault-save to capture ideas or findings.' "$VAULT_CONTEXT")
        fi

        # Curation cadence check
        if [ -f "$VAULT_PATH/.vault-last-curated" ]; then
            LAST_CURATED=$(cat "$VAULT_PATH/.vault-last-curated" 2>/dev/null)
            if [ -n "$LAST_CURATED" ]; then
                CURATED_EPOCH=$(date -d "$LAST_CURATED" +%s 2>/dev/null || echo 0)
                if [ "$CURATED_EPOCH" -gt 0 ]; then
                    DAYS_SINCE=$(( ($(date +%s) - CURATED_EPOCH) / 86400 ))
                    if [ "$DAYS_SINCE" -gt 30 ]; then
                        VAULT_CONTEXT=$(printf '%s\n  Vault maintenance: Last curated %s days ago. Consider /vault-curate.' "$VAULT_CONTEXT" "$DAYS_SINCE")
                    fi
                fi
            fi
        else
            # Never curated — only mention if vault has notes
            if [ -n "$RECENT_NOTES" ]; then
                VAULT_CONTEXT=$(printf '%s\n  Vault maintenance: Never curated. Consider /vault-curate --quick.' "$VAULT_CONTEXT")
            fi
        fi
    fi
fi

cat << EOF
You have structured workflows available via claude-sail (${total} commands).

BEFORE writing ANY implementation code, you MUST check if a workflow applies:

PLANNING (use BEFORE implementation):
$(echo -e "$planning_cmds")
SAFETY (use BEFORE destructive operations):
$(echo -e "$safety_cmds")
TESTING (use to verify work):
$(echo -e "$testing_cmds")

Rules:
1. If a planning command applies, you MUST use it first
2. If pushing code, you MUST run /push-safe
3. For non-trivial changes (>3 files OR risk flags), use /describe-change to triage
4. Announce which command you're using before proceeding

Run /toolkit for complete command reference.
$([ -n "$ACTIVE_WORK" ] && echo -e "$ACTIVE_WORK")
$([ -n "$VAULT_CONTEXT" ] && echo -e "$VAULT_CONTEXT")
EOF
