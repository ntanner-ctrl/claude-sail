---
description: Use when you want to synthesize error logs, success logs, and vault findings into actionable workflow improvements. Clusters recurring patterns and proposes hookify rules, CLAUDE.md additions, or hook modifications for user approval.
arguments:
  - name: project
    description: Project name to scope the analysis (default: auto-detect from git)
    required: false
---

# Evolve

Synthesizes accumulated error logs, success logs, and vault findings into actionable workflow improvements. Clusters recurring patterns by maturation tier, proposes targeted interventions (hookify rules, CLAUDE.md additions, hook modifications), and presents each proposal for individual user approval before writing anything.

## When to Use

- After accumulating several error or success logs and wanting to extract systemic lessons
- When the same mistake or pattern feels like it keeps recurring
- Before a long project phase, to harden your workflow based on prior evidence
- Periodically (e.g., after 10+ logged sessions) as a calibration ritual

## Process

### Step 1: Detect Project Context

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
PROJECT=$(basename "$GIT_ROOT")
```

If `$project` argument provided, use it. Otherwise use `$PROJECT` from git root basename.

### Step 2: Collect Evidence

Read log files from the current project. Handle all missing directories and files gracefully — absence is not an error.

**Error logs** — read all `*.md` files in `.claude/error-logs/`:

```bash
ls .claude/error-logs/*.md 2>/dev/null
```

For each file found, extract:
- `## User Error Category` → primary cause category
- `## One-Line Lesson` → lesson text
- `## Pattern Check` → whether it was seen before
- Date from filename or `**Date:**` field

**Success logs** — read all `*.md` files in `.claude/success-logs/`:

```bash
ls .claude/success-logs/*.md 2>/dev/null
```

For each file found, extract:
- `## Pattern` → success pattern category
- `## One-Line Lesson` → lesson text
- Date from filename or `**Date:**` field

**Vault findings** — if vault is available:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

If `$VAULT_ENABLED` is set and `$VAULT_PATH` is defined, use `mcp__obsidian__search_notes` or `mcp__obsidian__intelligent_search` to find findings in `Engineering/Findings/` tagged with or related to the current project. Extract finding text, tags, and tier from frontmatter.

If vault is unavailable, skip silently — do not error.

Display collection summary:

```
  Collecting evidence...
    Error logs:    N files
    Success logs:  N files
    Vault findings: N notes [or: vault unavailable — skipped]
```

If all sources are empty (zero logs, zero vault findings):

```
  No logs or findings found.

  To build evidence for /evolve, use:
    /log-error   — after mistakes you want to learn from
    /log-success — after things that worked unusually well

  Nothing to analyze.
```

Stop here if no evidence.

### Step 3: Cluster Patterns

Read all collected evidence. As the model, identify recurring themes by:

1. **Grouping by category** — use the error taxonomy from `/log-error`:
   - **Prompting** — Ambiguous instruction, missing constraints, too verbose, wrong abstraction level, implicit expectations, no success criteria
   - **Context** — Context rot, stale context, context overflow, missing context, wrong context
   - **Harnessing** — Subagent context loss, wrong agent type, no guardrails, parallel/sequential ordering mistakes, missing validation
   - **Architecture** — Structural patterns (CLAUDE.md gaps, repeated design decisions, recurring planning failures)

2. **Counting occurrences** — across all sources. Count a vault finding as 1 occurrence. Count a log file as 1 occurrence. Do not double-count if the same event appears in both vault and log (use date/content to detect duplicates).

3. **Applying maturation tiers** — aligned with `/promote-finding`:

   | Occurrences | Tier | Behavior |
   |-------------|------|----------|
   | 1 | ISOLATED | Log and surface — no action proposed |
   | 2 | CONFIRMED | Propose an action |
   | 3+ | CONVICTION | Strongly recommend an action |

4. **Determining action type** — for each CONFIRMED or CONVICTION pattern:

   | Pattern Characteristic | Proposed Action |
   |------------------------|-----------------|
   | Preventable mistake (something Claude or the workflow did wrong that could be mechanically blocked) | Hookify rule |
   | Best practice (something that worked or should always be done) | CLAUDE.md addition |
   | Missing safety check in a workflow step | Hook modification |

   When ambiguous, lean toward CLAUDE.md addition (lower blast radius).

5. **Drafting proposals** — for each CONFIRMED or CONVICTION pattern, draft the specific artifact:
   - **Hookify rule**: YAML block ready to write
   - **CLAUDE.md addition**: Exact text, section, and placement
   - **Hook modification**: Which hook, what change, and why

### Step 4: Present Analysis

Display the evolution analysis report:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EVOLUTION ANALYSIS │ [project]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Analyzed: N errors, N successes, N vault findings

  Isolated Patterns (1 occurrence — no action):

  [i] Pattern description
      Category: X | Source: error-logs / success-logs / vault

  Recurring Patterns:

  [1] Pattern description (N occurrences)
      Category: X | Tier: CONFIRMED/CONVICTION
      Proposed action: hookify-rule / claude-md / hook-modification
      Proposal: "description of what will be written"

  [2] Pattern description (N occurrences)
      Category: X | Tier: CONFIRMED/CONVICTION
      Proposed action: hookify-rule / claude-md / hook-modification
      Proposal: "description of what will be written"

  [If no recurring patterns:]
  No recurring patterns detected yet. Keep logging — patterns
  emerge after 2+ occurrences of the same category.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If there are no recurring patterns (all ISOLATED), stop here. Display the report and exit — no approval flow needed.

### Step 5: Approval Flow

For each recurring pattern with a proposal, present it individually and wait for user response before moving to the next.

**Per-pattern prompt:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PROPOSAL [N of M]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Pattern:  [description]
  Tier:     CONFIRMED (2 occurrences) / CONVICTION (N occurrences)
  Category: [prompting / context / harnessing / architecture]

  Evidence:
    - [source 1: date, file/vault note]
    - [source 2: date, file/vault note]

  Proposed action: [hookify-rule / claude-md / hook-modification]

  [If hookify-rule:]
  Rule file: hookify.[project].[pattern-slug].local.md
  Content:
  ---
  description: [trigger condition]
  pattern: [what to watch for]
  action: WARN | BLOCK
  message: |
    [Message shown to user when pattern is triggered]
  ---

  Scope: [global (~/.claude/hookify-rules/) | project-local (.claude/hookify-rules/)]
  !! Confirm scope before applying — global rules affect ALL projects.

  [If claude-md:]
  File: [.claude/CLAUDE.md or CLAUDE.md]
  Section: [target section]
  Text to add:
    "[exact text]"

  [If hook-modification:]
  Hook: hooks/[hook-name].sh
  Change: [description of modification needed]
  Note: Hook modifications require manual edit — I will show the diff.

  Actions: [approve] [reject] [skip]
  Or: approve-all (approves this and all remaining)
>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**User responses:**
- `approve` — apply this proposal, move to next
- `reject` — discard this proposal, move to next
- `skip` — defer this proposal (no write), move to next
- `approve-all` — approve this and all remaining proposals without further prompts (still confirm scope for hookify rules individually)

**Critical: For hookify rules**, even under `approve-all`, PAUSE and confirm scope for each rule:

```
  Hookify rule scope for [pattern-slug]:
    [1] Global  — ~/.claude/hookify-rules/hookify.[project].[slug].local.md
                  Affects ALL future Claude Code sessions
    [2] Project — .claude/hookify-rules/hookify.[slug].local.md
                  Affects this project only

  Select scope [1/2]:
>
```

Wait for explicit scope selection before writing the rule.

### Step 6: Apply Approved Proposals

Apply proposals in the order approved. For each:

**Hookify rule (after scope confirmed):**

If global scope:
```bash
mkdir -p ~/.claude/hookify-rules
```
Write to `~/.claude/hookify-rules/hookify.[project].[slug].local.md`.

If project-local scope:
```bash
mkdir -p .claude/hookify-rules
```
Write to `.claude/hookify-rules/hookify.[slug].local.md`.

**CLAUDE.md addition:**

If the pattern is CONVICTION tier (3+ occurrences), route through `/promote-finding` for evidence tracking and capacity checking. Invoke `/promote-finding [pattern description]` and let it manage the CLAUDE.md write.

If the pattern is CONFIRMED tier (2 occurrences), draft the addition and apply directly — no capacity check bypass. Check CLAUDE.md line count first:

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
wc -l "$GIT_ROOT/.claude/CLAUDE.md" 2>/dev/null || wc -l "$GIT_ROOT/CLAUDE.md" 2>/dev/null || echo "NO_CLAUDE_MD"
```

Respect `/promote-finding` capacity rules — warn at 150+ lines, require paired retirement at 200+.

**Hook modification:**

Show the exact diff of what needs to change. Do NOT apply automatically. Display:

```
  Hook modification requires manual edit.
  File: hooks/[hook-name].sh

  Change needed:
  [description and diff]

  Apply this change manually, then re-run /evolve to verify.
```

### Step 7: Completion Summary

After all proposals are processed:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EVOLUTION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Patterns analyzed: N total (N isolated, N recurring)

  Proposals:
    Approved:  N
    Rejected:  N
    Skipped:   N
    Deferred (manual):  N

  Applied:
    Hookify rules written: N
      [list filenames]
    CLAUDE.md additions:   N
      [list sections]
    Hook modifications:    N (manual — shown above)

  Next run: /evolve has no memory between runs.
  Each run re-reads logs from scratch. Patterns grow
  naturally as you keep using /log-error and /log-success.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Epistemic Capture

If an epistemic session is active (`epistemic_session_active` returns 0 — checks the per-claude-PID marker in `~/.claude/.current-session/`), and any CONVICTION-tier patterns were found, append to `.epistemic/insights.jsonl`:

```json
{"timestamp": "ISO-8601", "type": "finding", "input": {"finding": "[Evolve] CONVICTION pattern identified: [pattern description]. N occurrences across error/success logs. Action: [proposed action type]."}}
```

## Fail-Soft Behavior

| Condition | Behavior |
|-----------|----------|
| `.claude/error-logs/` missing | Skip silently — not an error |
| `.claude/success-logs/` missing | Skip silently — not an error |
| Vault unavailable | Skip vault findings — note in collection summary |
| Zero evidence found | Exit with setup guidance |
| No recurring patterns | Display ISOLATED list only — no approval flow |
| CLAUDE.md not found | Skip CLAUDE.md proposals — warn user |
| Hookify rules directory not writable | Show rule content — ask user to create manually |
| `/promote-finding` unavailable | Apply CLAUDE.md addition directly — note that evidence tracking was skipped |

## Integration

- **Feeds from:** `/log-error`, `/log-success`, vault findings (Engineering/Findings/)
- **Feeds into:** `/promote-finding` (for CONVICTION-tier CLAUDE.md additions), `~/.claude/hookify-rules/` (for approved hookify rules)
- **Complements:** `/vault-curate` (vault-level triage), `/hookify` (ad-hoc rule creation)
- **Rhythm:** Run after accumulating 5-10 sessions of logs, or whenever patterns feel like they're recurring

$ARGUMENTS
