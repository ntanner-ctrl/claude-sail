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
EMPIRICA_INSTRUCTION=""

# Check for Empirica CLI and auto-create session
# This makes session creation deterministic — no reliance on Claude following instructions
EMPIRICA_BIN=""
if command -v empirica &>/dev/null; then
    EMPIRICA_BIN="empirica"
elif [ -x "${HOME}/.local/bin/empirica" ]; then
    EMPIRICA_BIN="${HOME}/.local/bin/empirica"
fi

if [ -n "$EMPIRICA_BIN" ]; then
    # Always resolve git root (needed for project name even in global DB mode)
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")

    # Resolve data dir: EMPIRICA_DATA_DIR takes priority (global DB mode),
    # then git root, then cwd fallback. Must match path_resolver.py priority.
    if [ -n "$EMPIRICA_DATA_DIR" ]; then
        EMPIRICA_ROOT="$EMPIRICA_DATA_DIR"
    else
        EMPIRICA_ROOT="$GIT_ROOT/.empirica"
    fi
    ACTIVE_SESSION_FILE="$EMPIRICA_ROOT/active_session"
    DB_PATH="$EMPIRICA_ROOT/sessions/sessions.db"

    # Close previous active session if one exists
    if [ -f "$ACTIVE_SESSION_FILE" ]; then
        OLD_SESSION_ID=$(cat "$ACTIVE_SESSION_FILE" 2>/dev/null)
        if [ -n "$OLD_SESSION_ID" ] && [ -f "$DB_PATH" ] && command -v sqlite3 &>/dev/null; then
            sqlite3 "$DB_PATH" \
                "UPDATE sessions SET end_time=datetime('now') WHERE session_id='$OLD_SESSION_ID' AND end_time IS NULL" \
                2>/dev/null || true
        fi
    fi

    # Set resolver context before session-create.
    # session-create internally calls get_active_project_path() which checks
    # instance_projects/{instance_id}.json for the project path. Without this
    # file, session-create fails with "Cannot resolve project path" after DB
    # rebuilds or when resolver context files are stale/missing.
    #
    # We write the file directly rather than calling project-switch because
    # project-switch writes to active_work.json (canonical) which
    # get_active_project_path() doesn't check — it only reads instance-keyed files.
    PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
    INSTANCE_ID="claude_sail_hook"
    # One-shot migration: copy old instance file if it exists and new one doesn't
    OLD_INSTANCE_FILE="${HOME}/.empirica/instance_projects/claude_bootstrap_hook.json"
    NEW_INSTANCE_FILE="${HOME}/.empirica/instance_projects/${INSTANCE_ID}.json"
    if [ -f "$OLD_INSTANCE_FILE" ] && [ ! -f "$NEW_INSTANCE_FILE" ]; then
        mkdir -p "${HOME}/.empirica/instance_projects"
        cp "$OLD_INSTANCE_FILE" "$NEW_INSTANCE_FILE" 2>/dev/null || true
    fi
    if [ -n "$PROJECT_NAME" ] && [ -n "$GIT_ROOT" ]; then
        # Ensure project is registered (idempotent)
        "$EMPIRICA_BIN" project-create --name "$PROJECT_NAME" --output json 2>/dev/null || true

        # Resolve project_id from workspace.db
        PROJECT_ID=""
        WORKSPACE_DB="${HOME}/.empirica/workspace/workspace.db"
        if [ -f "$WORKSPACE_DB" ] && command -v sqlite3 &>/dev/null; then
            PROJECT_ID=$(sqlite3 "$WORKSPACE_DB" \
                "SELECT id FROM global_projects WHERE name='$PROJECT_NAME' LIMIT 1" 2>/dev/null)
        fi

        # Write instance_projects file for get_active_project_path()
        if [ -n "$PROJECT_ID" ]; then
            mkdir -p "${HOME}/.empirica/instance_projects"
            echo "{\"project_path\": \"$GIT_ROOT\", \"project_id\": \"$PROJECT_ID\"}" \
                > "${HOME}/.empirica/instance_projects/${INSTANCE_ID}.json"
        fi
    fi

    # Create new session via CLI (with instance ID so it finds the resolver context)
    mkdir -p "$EMPIRICA_ROOT"
    SESSION_OUTPUT=$(EMPIRICA_INSTANCE_ID=$INSTANCE_ID "$EMPIRICA_BIN" session-create --ai-id claude-code --output json 2>/dev/null)
    SESSION_EXIT=$?

    if [ $SESSION_EXIT -eq 0 ] && [ -n "$SESSION_OUTPUT" ]; then
        # Parse session_id — try jq first, fall back to grep
        SESSION_ID=""
        if command -v jq &>/dev/null; then
            SESSION_ID=$(echo "$SESSION_OUTPUT" | jq -r '.session_id // empty' 2>/dev/null)
        fi
        if [ -z "$SESSION_ID" ]; then
            SESSION_ID=$(echo "$SESSION_OUTPUT" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | grep -o '"[^"]*"$' | tr -d '"')
        fi

        if [ -n "$SESSION_ID" ]; then
            # Write active session file
            echo "$SESSION_ID" > "$ACTIVE_SESSION_FILE"

            # Export session ID as environment variable for other hooks/commands
            if [ -n "$CLAUDE_ENV_FILE" ]; then
                echo "export EMPIRICA_SESSION_ID=${SESSION_ID}" >> "$CLAUDE_ENV_FILE"
            fi

            EMPIRICA_INSTRUCTION="\nEMPIRICA (epistemic tracking — REQUIRED):
  SESSION PRE-CREATED: ${SESSION_ID}. Do NOT call mcp__empirica__session_create.
  Call mcp__empirica__submit_preflight_assessment with session_id: ${SESSION_ID} and honest self-assessment vectors.
  Store session_id ${SESSION_ID} for use throughout this conversation.
  Before ending the session, suggest /end to close Empirica with a proper postflight assessment."
        else
            # Clear stale pointer so empirica-session-guard.sh doesn't deadlock
            # (guard blocks MCP session_create when file exists, even if session is closed)
            rm -f "$ACTIVE_SESSION_FILE" 2>/dev/null
            EMPIRICA_INSTRUCTION="\nEMPIRICA (epistemic tracking — REQUIRED):
  Session auto-creation failed (JSON parse error). You MUST call mcp__empirica__session_create (ai_id: \"claude-code\") as your FIRST action.
  Then call mcp__empirica__submit_preflight_assessment with honest self-assessment vectors.
  Before ending the session, suggest /end to close Empirica with a proper postflight assessment."
        fi
    else
        # Clear stale pointer so empirica-session-guard.sh doesn't deadlock
        rm -f "$ACTIVE_SESSION_FILE" 2>/dev/null
        EMPIRICA_INSTRUCTION="\nEMPIRICA (epistemic tracking — REQUIRED):
  Session auto-creation failed (exit code: ${SESSION_EXIT}). You MUST call mcp__empirica__session_create (ai_id: \"claude-code\") as your FIRST action.
  Then call mcp__empirica__submit_preflight_assessment with honest self-assessment vectors.
  Before ending the session, suggest /end to close Empirica with a proper postflight assessment."
    fi
fi

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
$([ -n "$EMPIRICA_INSTRUCTION" ] && echo -e "$EMPIRICA_INSTRUCTION")
$([ -n "$ACTIVE_WORK" ] && echo -e "$ACTIVE_WORK")
$([ -n "$VAULT_CONTEXT" ] && echo -e "$VAULT_CONTEXT")
EOF
