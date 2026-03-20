---
description: Use after a work period ends to generate a structured retrospective from git history, session logs, error/success patterns, and hook blocks.
arguments:
  - name: days
    description: Lookback window in days (default 7)
    required: false
  - name: project
    description: Filter to a specific project name
    required: false
---

# Retro

Structured retrospective synthesized from multiple data sources: git history, session budget logs, error and success markdown logs, hook audit blocks, and (optionally) Obsidian vault findings. Produces a single consolidated report covering activity, patterns, safety posture, and actionable recommendations.

## When to Use

- At the end of a sprint, week, or milestone
- When you want a data-driven view of what is working and what is not
- Before a planning session to anchor the discussion in actual history
- When error or success patterns have accumulated and need synthesis

## Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `--days N` | 7 | Lookback window in days |
| `--project NAME` | (all) | Filter to a named project |

## Process

### Step 1: Establish Date Range

Compute the lookback window:

```
cutoff_date = today - --days days (UTC midnight)
date_range  = "[cutoff_date] → today"
```

If `--project` is provided, note it as the project filter. It will be applied to all data sources that carry a project field.

### Step 2: Gather Git Activity

Run git history for the lookback window:

```bash
git log --oneline --after="N days ago"
```

If not in a git repository, skip this step and note "Not a git repository — git activity unavailable."

Extract:
- **Commit count** — total lines returned
- **Commit messages** — for pattern analysis in Step 7

If `--project` is provided and the repo name (basename of `git rev-parse --show-toplevel`) does not match, note that git data is for a different project and include it with a caveat.

### Step 3: Gather Session Budget Data

Read `.claude/budget.jsonl` at the git root. Each line is a JSON object. Parse lines whose timestamp field falls within the cutoff window.

Expected field shapes (read gracefully — any missing field = skip that field):
- `timestamp` — ISO-8601 string (used for date filtering)
- `session_id` — session identifier
- `duration_minutes` or `duration_seconds` — session length
- `project` — project name (apply `--project` filter if provided)

Extract:
- **Session count** — distinct session_ids in range
- **Total duration** — sum of durations, converted to hours

If the file is absent or empty, session data = unavailable. Note it in output but do not stop.

### Step 4: Gather Error Patterns

List markdown files in `.claude/error-logs/`:

```bash
ls .claude/error-logs/*.md 2>/dev/null
```

For each file found, read it and extract:
- **Date** — from the `**Date:**` field in the file content (format `YYYY-MM-DD`). Compare this date (UTC) against the cutoff. Files whose content date is before the cutoff are excluded.
- **Short name** — from the `# Error:` heading
- **Primary cause** — from the `**Primary cause:**` line
- **One-line lesson** — from the `## One-Line Lesson` section

Do NOT use filesystem modification time for filtering — use the date embedded in the file content.

If `--project` is provided, check the `**Project:**` field and skip files that do not match.

If the directory is absent or no files match, error data = unavailable.

### Step 5: Gather Success Patterns

List markdown files in `.claude/success-logs/`:

```bash
ls .claude/success-logs/*.md 2>/dev/null
```

Apply the same content-date filtering as Step 4. Extract per file:
- **Date** — from `**Date:**` field in content
- **Short name** — from the `# Success:` or first `#` heading
- **What worked** — from a `## What Worked` or `## Key Win` section (take the first matching section)
- **Replicable pattern** — from a `## Pattern` or `## How to Replicate` section if present

If `--project` filter is set, apply it using the project field in content.

If the directory is absent or no files match, success data = unavailable.

### Step 6: Gather Hook Audit Blocks

Read `.claude/audit.jsonl` at the git root. Each line is a JSON object with a `timestamp` field. Filter to lines within the cutoff window.

Expected fields (read gracefully):
- `timestamp` — ISO-8601 (used for filtering)
- `hook` or `hook_name` — which hook fired
- `action` — `block`, `warn`, or `allow`
- `reason` — short description of why it fired
- `project` — apply `--project` filter if provided

Extract:
- **Total blocks** — count of entries where `action = "block"`
- **Category breakdown** — group blocks by `hook` or `hook_name`; count per hook
- **Warnings** — count of entries where `action = "warn"`

If the file is absent or empty, safety data = unavailable.

### Step 7: Gather Vault Findings (Optional)

Source vault config:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
```

If vault is unavailable or disabled, skip this step silently.

If vault is available, search for finding notes created within the lookback window:

```bash
find "$VAULT_PATH/Engineering/Findings" -name "*.md" -newer /tmp/cutoff_marker 2>/dev/null
```

Read each file found and extract:
- `title` from YAML frontmatter or `#` heading
- `severity` from YAML frontmatter
- `project` from YAML frontmatter (apply `--project` filter)

Limit to 10 most recent findings. If more exist, note "N additional findings omitted — see vault Engineering/Findings/."

### Step 8: Check for All-Empty State

If ALL of the following are true:
- Git: no commits found (or not a git repo)
- Budget: file absent or no sessions in range
- Error logs: no files in range
- Success logs: no files in range
- Audit: file absent or no entries in range
- Vault: unavailable or no findings in range

Output the minimal report:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RETROSPECTIVE │ [project or "all projects"] │ [date range]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  No data available for retrospective.

  Checked:
    - git log (last [N] days)
    - .claude/budget.jsonl
    - .claude/error-logs/*.md
    - .claude/success-logs/*.md
    - .claude/audit.jsonl
    - Obsidian vault findings

  Nothing found in the [N]-day window.
  Start logging errors and successes with /log-error and /log-success.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Stop here.

### Step 9: Synthesize Patterns

Before producing the report, synthesize across sources:

**Patterns** — recurring themes that appear in 2+ sources or 3+ log entries. Examples:
- Same error category appearing in multiple error logs
- A success pattern that aligns with a recent commit burst
- A hook firing repeatedly for the same reason

**Anomalies** — notable outliers worth calling out:
- Zero commits but many sessions (lots of exploration, no delivery)
- High hook-block rate (friction in the workflow)
- Only errors, no successes logged (or vice versa)

**Recommendations** — derive 2-4 actionable suggestions from the data. Ground each in specific evidence:
- "Error logs show 3 'missing constraints' entries — consider adding a constraints checklist to your prompting workflow"
- "Hook blocks are concentrated in [hook-name] — review whether its trigger condition is too broad"
- "N sessions logged but only N-2 commits — context rot or scope creep may be a factor"

### Step 10: Produce Report

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RETROSPECTIVE │ [project or "all projects"] │ [date range]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Activity
  - Sessions: [N] | Commits: [N] | Duration: ~[N] hours
  [If any data source was unavailable, note it here:
   "(budget.jsonl not found — session count unavailable)"]

  What Worked
  [Synthesized from success-logs/*.md entries in range.
   Bullet per distinct pattern. If none: "No success logs in range."]
  - [Pattern or win from a log entry]
  - [Another pattern]

  What Didn't
  [Synthesized from error-logs/*.md entries in range.
   Group by primary cause category. If none: "No error logs in range."]
  - [Category]: [brief description] (N occurrences)
  - [Category]: [brief description]

  Safety Summary
  - Hook blocks: [N] total [| "(audit.jsonl not found)" if unavailable]
  [If blocks > 0:]
    - [hook-name]: N blocks
    - [hook-name]: N blocks
  - Warnings: [N]

  Vault Findings
  [If vault available and findings found:]
  - [severity] [title] (YYYY-MM-DD)
  - ...
  [If vault unavailable or no findings: omit this section entirely]

  Patterns
  [Derived in Step 9. 2-4 bullets.]
  - [Recurring theme or anomaly]
  - [Another pattern]

  Recommendations
  [Derived in Step 9. Each grounded in evidence. 2-4 bullets.]
  - [Actionable suggestion based on data]
  - [Another suggestion]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Section suppression rules:**
- If a section has no data AND no "unavailable" note is warranted, omit the section header entirely rather than showing an empty section.
- Always show "Activity" even if all three sub-metrics are unavailable (show N/A for each).
- Always show "Recommendations" — if data is too sparse for evidence-grounded suggestions, recommend running `/log-error` and `/log-success` consistently.

### Step 11: Optional Vault Export

After displaying the report, ask:

```
Export this retrospective to vault as a session-log note? (y/N)
```

If the user confirms AND vault is available:

1. Determine the vault path:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null
   mkdir -p "$VAULT_PATH/Engineering/Session-Logs"
   ```

2. Generate a filename:
   ```
   YYYY-MM-DD-retro-[project-slug].md
   ```
   where project-slug is the `--project` argument (lowercased, spaces → hyphens) or "all-projects".

3. Write the note with YAML frontmatter:
   ```markdown
   ---
   date: YYYY-MM-DD
   type: retrospective
   project: [project or all]
   days: [N]
   tags: [retro, session-log]
   ---

   [Full report text]
   ```

4. Write using the Write tool (not Obsidian MCP).

5. Confirm: "Exported to: $VAULT_PATH/Engineering/Session-Logs/[filename]"

If vault is unavailable and user asked to export, note: "Vault not configured — export skipped."

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Not a git repository | Skip git step. Note in Activity: "Commits: N/A (not a git repo)". |
| `budget.jsonl` absent | Skip session count. Note: "(budget.jsonl not found — sessions unavailable)". |
| `error-logs/` absent | Skip. Note "No error logs found." in What Didn't section. |
| `success-logs/` absent | Skip. Note "No success logs found." in What Worked section. |
| `audit.jsonl` absent | Skip. Note "(audit.jsonl not found)" in Safety Summary. |
| File content date missing | Skip that file. Do not guess from filesystem mtime. |
| `--project` filter matches nothing | Produce report noting "No data matched project filter '[name]'." |
| All data sources empty | Produce minimal report (Step 8) and stop. |
| Vault unavailable | Omit Vault Findings section. Skip export option. |
| `--days 0` or negative | Treat as `--days 1` (today only). |
| `--days` > 365 | Cap at 365. Note: "Lookback capped at 365 days." |

## Integration

- **Feeds from:** `/log-error`, `/log-success` (markdown log sources)
- **Feeds into:** Planning sessions, CLAUDE.md refinement, hookify rule creation
- **Related:** `/collect-insights` (flush epistemic insights), `/end` (session close with insight sweep)
- **Suggested by:** End of sprint, end of week, before `/blueprint` planning

$ARGUMENTS
