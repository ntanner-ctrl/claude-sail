# Specification: inspired-features

## Overview

Seven new features for claude-sail v0.10.0, adding runtime hook control, cost awareness, immutable safety rules, retrospectives, directory locking, learning evolution, and audit trails.

**Constraints:**
- Pure bash/markdown — no new runtime dependencies
- Follow existing hook patterns (fail-open, `set +e`, exit 0/1/2)
- All new files picked up by `install.sh` tarball automatically
- New hooks must be wired in `settings-example.json`
- test.sh file counts must be updated

---

## Feature 1: Hook Runtime Toggles

### Problem
Debugging hook issues requires editing `settings.json`, which persists across sessions. Users need a way to temporarily disable specific hooks without changing configuration.

### Design

**Environment variable:** `SAIL_DISABLED_HOOKS`
- Comma-separated list of hook filenames (without path or `.sh` extension)
- Example: `SAIL_DISABLED_HOOKS=secret-scanner,tdd-guardian claude`
- Empty or unset = all hooks active (default)

**Implementation:** Add a guard block near the top of every hook (after `set +e`, before any logic):

```bash
# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi
```

**Scope:** All 17 existing hooks. The guard is idempotent — adding it to hooks that already have it is a no-op.

### Files Modified
- `hooks/*.sh` (all 17) — add 4-line guard block
- `CLAUDE.md` — document `SAIL_DISABLED_HOOKS` env var
- `README.md` — add to "Configuration" section
- `settings-example.json` — add `"env": { "SAIL_DISABLED_HOOKS": "" }` comment/example

### Acceptance Criteria
- Setting `SAIL_DISABLED_HOOKS=dangerous-commands` causes that hook to exit 0 immediately
- Unset variable = all hooks fire normally
- Multiple hooks can be disabled: `SAIL_DISABLED_HOOKS=a,b,c`
- No trailing/leading comma issues

**Note:** If `SAIL_DISABLED_HOOKS` is exported in `.bashrc`/`.zshrc`, the disable persists across all sessions — breaking the session-scope guarantee. Document this explicitly.

---

## Feature 2: Budget/Cost Awareness

### Problem
Claude Code sessions can consume significant tokens with no visibility. Users have no way to track or limit spend.

### Design

**Approach:** Advisory tracking via session metadata. Claude Code does not expose token counts to shell hooks, so we track at the *session level* using data available to Claude (the model) rather than to hooks.

**Component A — `/budget` command** (`commands/budget.md`)
- Reads `.claude/budget.jsonl` for historical session data
- Displays: total sessions, estimated token usage per session, trends
- Allows setting an awareness threshold: writes `budget_threshold` to `.claude/budget-config.json`
- When a threshold is set, Claude (the model) should self-monitor and mention remaining budget periodically
- This is advisory only — there is no hard enforcement mechanism. CLAUDE.md guidance is the weakest enforcement tier.

**Component B — Budget logging** (inline in `/end` command enhancement)
- When `/end` runs, it appends a budget entry to `.claude/budget.jsonl`:
  ```json
  {"session_id": "...", "project": "...", "started": "ISO", "ended": "ISO", "duration_min": N, "estimated_turns": N, "notes": "..."}
  ```
- `estimated_turns` is counted from conversation context (number of user messages)
- This is a *heuristic* — not precise token counting, but useful for trend analysis

**Component C — Budget awareness in CLAUDE.md guidance**
- Add a section to CLAUDE.md telling Claude to check `.claude/budget-config.json` at session start
- If `budget_limit` exists, Claude should mention remaining budget periodically

**Why NOT a PreToolUse hook:** Hooks can't access token counts. The Claude Code API doesn't expose usage data to shell hooks. Attempting to track per-tool-call costs in bash would be unreliable and add latency to every operation.

### Files Created
- `commands/budget.md` — budget review and configuration command

### Files Modified
- `commands/end.md` — add budget entry logging step
- Project CLAUDE.md template — add budget awareness section

### Acceptance Criteria
- `/budget` displays session history from `.claude/budget.jsonl`
- `/budget threshold 50` sets a 50-turn awareness target (advisory, not enforced)
- `/end` appends budget entry
- Budget file is append-only JSONL
- Displayed estimates use approximate precision (~50 turns, not 47) to avoid false confidence
- Turn count is a heuristic — subagent-heavy sessions may consume 10-50x more tokens than turn count suggests

---

## Feature 3: Baseline Rules That Can't Be Weakened

### Problem
All hookify rules can be disabled by the user, including security-critical ones. There's no concept of "mandatory minimum" safety.

### Design

**Frontmatter field:** `baseline: true` (default: false/absent)

When a hookify rule has `baseline: true`:
- The `/hookify configure` command should show it as "[BASELINE]" (convention signal)
- The `/hookify list` command should mark it distinctly
- **Current effect: display-only.** The hookify plugin does not currently enforce this field.
- Enforcement requires upstream hookify plugin changes (not owned by this project)

**Rules to mark as baseline:**
- `hookify.force-push-protection.local.md` — force push to protected branches
- `hookify.exfiltration-protection.local.md` — secret exfiltration over network
- `hookify.disk-ops-protection.local.md` — direct disk writes (dd, mkfs)
- `hookify.chmod-777.local.md` — world-writable permissions

**Rules that remain user-configurable:**
- `hookify.surgical-rm.local.md` — rm pattern (may need project-specific tuning)
- `hookify.remote-exec-protection.local.md` — curl|bash (may need for installs)
- `hookify.env-exposure-protection.local.md` — env file exposure (may need for debugging)

**Override mechanism:** Reserved for future enforcement. When the hookify plugin adds baseline support, `SAIL_BASELINE_OVERRIDE=1` env var will bypass it (logged to audit trail). Until then, this field is documentation-only.

### Files Modified
- `hookify-rules/hookify.force-push-protection.local.md` — add `baseline: true`
- `hookify-rules/hookify.exfiltration-protection.local.md` — add `baseline: true`
- `hookify-rules/hookify.disk-ops-protection.local.md` — add `baseline: true`
- `hookify-rules/hookify.chmod-777.local.md` — add `baseline: true`

### Files Requiring Plugin Modification
- The hookify plugin (`~/.claude/plugins/hookify/`) — modify disable logic to check `baseline` field

**Note:** We do not own the hookify plugin source. The baseline enforcement must be documented as a convention that the hookify plugin should respect. We add the frontmatter and document the expected behavior. If the plugin doesn't enforce it, the frontmatter is inert but ready for when it does.

### Acceptance Criteria
- 4 rules have `baseline: true` in frontmatter as a convention signal
- Documentation explains which rules are baseline and why
- Documentation is honest: "convention signal, not enforcement — hookify plugin does not currently read this field"
- Override mechanism documented as "reserved for future enforcement"

---

## Feature 4: Retrospective Command (`/retro`)

### Problem
No structured way to review patterns across sessions — what commands are used, what errors recur, what's working well.

### Design

**Command:** `commands/retro.md`

**Data sources:**
1. `git log --oneline -50` — recent commit activity
2. `.claude/budget.jsonl` — session history (from Feature 2)
3. `.claude/error-logs/*.md` — error patterns (markdown files from /log-error)
4. `.claude/success-logs/*.md` — success patterns (markdown files from /log-success)
5. `.claude/audit.jsonl` — hook blocks (from Feature 7)
6. Obsidian vault findings (if available)

**Note:** `/log-error` and `/log-success` write individual markdown files to directories, not JSONL. Claude reads these files directly and synthesizes patterns from the narrative content.

**Output structure:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RETROSPECTIVE │ [project] │ [date range]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  📊 Activity
  - Sessions: N │ Commits: N │ Duration: ~N hours
  - Most active days: [list]

  ✅ What Worked
  - [Synthesized from log-success entries]

  ❌ What Didn't
  - [Synthesized from log-error entries]

  🛡️ Safety Summary
  - Hook blocks: N total │ [breakdown by category]
  - Most blocked: [hook name] (N times)

  🔄 Patterns
  - [Recurring themes across errors/successes]

  💡 Recommendations
  - [Actionable suggestions based on patterns]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Arguments:**
- `--days N` — look back N days (default: 7)
- `--project NAME` — filter to specific project

**Vault export:** Optionally export retro to vault as a session-log note.

### Files Created
- `commands/retro.md` — retrospective command
- `commands/templates/vault-notes/retro.md` — retro vault note template

### Acceptance Criteria
- `/retro` produces structured output from available data sources
- Gracefully handles missing data sources (no errors if log files don't exist)
- `--days` flag controls lookback window
- Vault export works if vault is available

---

## Feature 5: `/freeze` Directory Locking

### Problem
No way to protect specific directories from accidental edits during a session. Useful when working on a feature but wanting to prevent changes to unrelated code.

### Design

**Commands:**
- `commands/freeze.md` — `/freeze src/auth` adds directory to freeze list
- `commands/unfreeze.md` — `/unfreeze src/auth` removes from freeze list

**State file:** `.claude/frozen-dirs.json`
```json
{
  "frozen": [
    { "path": "src/auth", "reason": "Auth refactor in progress on another branch", "frozen_at": "ISO" }
  ]
}
```

**Enforcement hook:** `hooks/freeze-guard.sh` (new, PreToolUse, matcher: `Edit|Write`)
- Reads `.claude/frozen-dirs.json` (uses `jq` if available, fail-open exit 0 if jq absent)
- Extracts target file path from tool input (`tool_input.file_path`)
- **Path normalization:** Resolves both stored path and incoming path to absolute (relative to `git rev-parse --show-toplevel`). Strips trailing slashes before comparison.
- Checks if absolute file path starts with any frozen directory path + `/`
- If match: exit 2 with feedback "BLOCKED: Directory [dir] is frozen. Reason: [reason]. Use /unfreeze [dir] to unlock."
- If no match or no frozen dirs file: exit 0

**Path handling details:**
- `/freeze` command normalizes paths to absolute at write time (using `realpath` or git root + relative path)
- All paths in `frozen-dirs.json` are stored as absolute
- `/unfreeze` strips trailing slashes before matching
- Comparison uses `${frozen_dir}/` suffix to prevent `src/auth` matching `src/auth-v2`

**Scope:** Session-scoped. The freeze file persists on disk but is meant to be transient. `/unfreeze --all` clears everything.

### Files Created
- `commands/freeze.md` — freeze command
- `commands/unfreeze.md` — unfreeze command
- `hooks/freeze-guard.sh` — PreToolUse enforcement hook

### Files Modified
- `settings-example.json` — wire freeze-guard.sh under PreToolUse Edit|Write

### Acceptance Criteria
- `/freeze src/auth` creates/updates frozen-dirs.json
- `/unfreeze src/auth` removes the entry
- `/unfreeze --all` clears all freezes
- Editing a file in a frozen directory is blocked with clear feedback
- Editing files outside frozen directories works normally
- Missing frozen-dirs.json = no directories frozen (fail-open)

---

## Feature 6: Instinct → Skill Evolution (`/evolve`)

### Problem
`/log-error` and `/log-success` capture individual events but don't synthesize patterns over time. Recurring patterns should evolve into actionable rules.

### Design

**Command:** `commands/evolve.md`

**Process:**
1. Read `.claude/error-logs/*.md` and `.claude/success-logs/*.md` (markdown files from /log-error and /log-success)
2. Read vault findings if available (Engineering/Findings/)
3. Present patterns grouped by category (prompting, context, harnessing, architecture)
4. For each pattern with 2+ occurrences, propose an action:
   - **Hookify rule** — if the pattern is a preventable mistake (propose rule YAML)
   - **CLAUDE.md addition** — if the pattern is a best practice (propose text)
   - **Hook modification** — if the pattern suggests a missing safety check
5. User approves/rejects each proposal
6. Approved proposals are applied (via `/promote-finding` pipeline for CLAUDE.md, direct file write for hookify rules)

**Pattern detection:** Claude (the model) does the clustering — this is a command that instructs Claude to analyze the log files and find patterns. No bash-level ML required.

**Maturation tiers (aligned with /promote-finding):**
- 1 occurrence → Isolated (logged, no action suggested)
- 2 occurrences → Confirmed (action suggested)
- 3+ occurrences → Conviction (action strongly recommended)

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EVOLUTION ANALYSIS │ [project]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Analyzed: N errors, N successes, N vault findings

  🔄 Recurring Patterns:

  [1] Context rot after 30+ turns (3 occurrences)
      Category: context │ Tier: CONVICTION
      Proposed action: Add to CLAUDE.md
      Rule: "After 30 turns, suggest /checkpoint or /clear"

  [2] Subagent missing file context (2 occurrences)
      Category: harnessing │ Tier: CONFIRMED
      Proposed action: Hookify rule
      Rule: warn when dispatching agent without file list

  Actions: [approve N] [reject N] [skip] [approve all]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Files Created
- `commands/evolve.md` — evolution analysis command

### Acceptance Criteria
- `/evolve` reads available log files gracefully (missing = empty)
- Groups patterns by category with occurrence counts
- Proposes concrete actions for 2+ occurrence patterns
- User can approve/reject individual proposals
- Approved hookify rules are written to `~/.claude/hookify-rules/` with project-namespaced filenames (e.g., `hookify.[project].[pattern].local.md`)
- User confirms scope (global vs project-local) before each rule write
- Approved CLAUDE.md additions go through `/promote-finding`

---

## Feature 7: Audit Trail for Hook Blocks

### Problem
Hooks that block operations (exit 2) leave no persistent record. There's no way to review what was blocked, when, or why.

### Design

**Audit log file:** `.claude/audit.jsonl`

**Log format:**
```json
{
  "timestamp": "ISO-8601",
  "hook": "dangerous-commands",
  "category": "DESTRUCTIVE",
  "action": "block",
  "reason": "Refusing to delete root filesystem (/)",
  "tool": "Bash",
  "command_snippet": "rm -rf /",
  "session_id": "..."
}
```

**Implementation — shared logging function:**

Create `hooks/audit-log.sh` (sourced, not a hook itself):
```bash
# Source this from hooks that block: source ~/.claude/hooks/audit-log.sh
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
    # Use jq for safe JSON construction (handles quotes/escapes in command_snippet)
    # If jq is absent, fall back to printf with truncated snippet
    if command -v jq &>/dev/null; then
        jq -n --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
              --arg hook "$hook_name" --arg cat "$category" \
              --arg reason "$reason" --arg tool "$tool" \
              --arg snippet "${snippet:0:200}" --arg sid "$session_id" \
              '{timestamp:$ts,hook:$hook,category:$cat,action:"block",reason:$reason,tool:$tool,command_snippet:$snippet,session_id:$sid}' \
              >> "$audit_dir/audit.jsonl" 2>/dev/null
    else
        # Fallback: strip quotes from snippet to avoid JSON injection
        local safe_snippet="${snippet//\"/\\\"}"
        printf '{"timestamp":"%s","hook":"%s","category":"%s","action":"block","reason":"%s","tool":"%s","command_snippet":"%s","session_id":"%s"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$hook_name" "$category" "$reason" "$tool" "${safe_snippet:0:200}" "$session_id" \
            >> "$audit_dir/audit.jsonl" 2>/dev/null
    fi
}
```

**Design notes:**
- `jq` is the preferred JSON constructor (handles arbitrary characters safely)
- `jq` is an optional enhancement — already used by existing hooks (`dangerous-commands.sh`, `blueprint-stage-gate.sh`). If absent, falls back to printf with escaped quotes
- `command_snippet` is truncated to 200 chars to prevent audit log inflation
- Session ID extraction includes `tr -d '\r'` for WSL2 CRLF compatibility

**Consuming hooks use the no-op fallback pattern:**
```bash
# No-op fallback — if audit-log.sh is missing, audit calls are harmless no-ops
audit_block() { :; }
source ~/.claude/hooks/audit-log.sh 2>/dev/null || true
```

**Modified hooks:** Add the no-op fallback + source pattern and `audit_block` calls to:
- `hooks/dangerous-commands.sh` — call `audit_block` in `block_with_feedback()`
- `hooks/secret-scanner.sh` — call on secret detection
- `hooks/protect-claude-md.sh` — call on CLAUDE.md protection
- `hooks/tdd-guardian.sh` — call on TDD violation
- `hooks/freeze-guard.sh` (new, from Feature 5) — call on frozen dir block

**`/audit` command** (`commands/audit.md`):
- Reads `.claude/audit.jsonl`
- Displays: recent blocks, summary stats, trends
- Filters: `--hook NAME`, `--days N`, `--category CAT`

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AUDIT LOG │ Last 7 days │ [project]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total blocks: N

  By hook:
    dangerous-commands     │ N blocks
    secret-scanner         │ N blocks
    freeze-guard           │ N blocks

  By category:
    DESTRUCTIVE            │ N
    SECURITY               │ N
    GIT_SAFETY             │ N

  Recent (last 5):
    [timestamp] dangerous-commands: rm -rf / (DESTRUCTIVE)
    [timestamp] secret-scanner: .env file in commit (SECURITY)
    ...

  Baseline override usage: N times
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Files Created
- `hooks/audit-log.sh` — shared audit logging function (sourced, not a hook)
- `commands/audit.md` — audit review command

### Files Modified
- `hooks/dangerous-commands.sh` — source audit-log.sh, call audit_block
- `hooks/secret-scanner.sh` — source audit-log.sh, call audit_block
- `hooks/protect-claude-md.sh` — source audit-log.sh, call audit_block
- `hooks/tdd-guardian.sh` — source audit-log.sh, call audit_block

### Acceptance Criteria
- Hook blocks produce audit entries in `.claude/audit.jsonl`
- `/audit` displays formatted summary
- Filters work: `--hook`, `--days`, `--category`
- Missing audit file = "No audit entries found" (not an error)
- audit-log.sh is fail-open (logging failure doesn't prevent hook from blocking)

---

## Cross-Cutting Concerns

### File Count Updates
Current counts: 55 commands, 6 agents, 17 hooks, 7 hookify rules

After this work:
- Commands: 55 + 6 new (budget, retro, freeze, unfreeze, evolve, audit) = **61 commands**
- Agents: 6 (unchanged)
- Hooks: 17 + 1 new (freeze-guard) + 1 utility (audit-log.sh, not a hook) = **18 hooks** + 1 utility
- Hookify rules: 7 (unchanged count, 4 gain `baseline: true`)

Wait — audit-log.sh is sourced, not a hook. It doesn't get wired in settings.json. So hook count is 18.

Update: README.md, CLAUDE.md, install.sh output, test.sh expected counts.

### test.sh Updates
- Update expected command count: 55 → 61
- Update expected hook count: 17 → 18
- Add check for `SAIL_DISABLED_HOOKS` guard in hooks
- Add check for `baseline: true` in expected hookify rules
- Add check for audit-log.sh existence

### settings-example.json Updates
- Add `freeze-guard.sh` to PreToolUse Edit|Write matcher
- Add env var comment for `SAIL_DISABLED_HOOKS`

### Timestamp Convention
All timestamps in new structured files MUST use UTC with Z suffix: `date -u +%Y-%m-%dT%H:%M:%SZ`. This applies to `audit.jsonl`, `budget.jsonl`, `frozen-dirs.json`, and any other new data files. Matches the established pattern from `epistemic-preflight.sh`.

### jq Dependency
`jq` is an optional enhancement dependency — already used by existing hooks (`dangerous-commands.sh`, `blueprint-stage-gate.sh`). New hooks should prefer `jq` for JSON parsing/construction but must degrade gracefully (exit 0) if `jq` is absent. This toolkit's "no new dependencies" constraint means "no node, no pip" — `jq` is already in the ecosystem.

### Stale Freeze Warning
If `frozen-dirs.json` exists and is non-empty at session start, Claude should warn the user that directories are frozen from a previous session and suggest `/unfreeze --all`. This prevents crashed sessions from silently blocking subsequent sessions.

### Install Path
All new files are in `commands/`, `hooks/`, or `hookify-rules/` — automatically picked up by tarball install. No installer changes needed beyond output message updates.

---

## Work Units

| ID | Feature | Step | Dependencies | Est. Size |
|----|---------|------|-------------|-----------|
| W1 | Hook Toggles | Add guard to 17 hooks | None | Medium |
| W2 | Hook Toggles | Document in CLAUDE.md + README | W1 | Small |
| W3 | Budget | Create /budget command | None | Medium |
| W4 | Budget | Enhance /end for budget logging | W3 | Small |
| W5 | Budget | Add budget awareness to CLAUDE.md template | W3 | Small |
| W6 | Baseline | Add baseline:true to 4 hookify rules | None | Small |
| W7 | Baseline | Document baseline convention | W6 | Small |
| W8 | Retro | Create /retro command | None | Medium |
| W9 | Retro | Create retro vault template | W8 | Small |
| W10 | Freeze | Create /freeze command | None | Small |
| W11 | Freeze | Create /unfreeze command | W10 | Small |
| W12 | Freeze | Create freeze-guard.sh hook | W10 | Medium |
| W13 | Freeze | Wire in settings-example.json | W12 | Small |
| W14 | Evolve | Create /evolve command | None | Large |
| W15 | Audit | Create audit-log.sh utility | None | Small |
| W16 | Audit | Add audit calls to blocking hooks | W15 | Medium |
| W17 | Audit | Create /audit command | W15 | Medium |
| W18 | Cross-cutting | Update counts in README, CLAUDE.md, test.sh | All | Medium |
