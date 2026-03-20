---
description: Use when you want to review hook block history for the current project. Displays recent blocks, summary stats, and trends from .claude/audit.jsonl.
arguments:
  - name: hook
    description: Filter results to a specific hook name (e.g. dangerous-commands, secret-scanner)
    required: false
  - name: days
    description: Lookback window in days (default 30)
    required: false
  - name: category
    description: "Filter by block category: DESTRUCTIVE, SECURITY, GIT_SAFETY, TDD, FREEZE"
    required: false
---

# Audit

Display hook block history for the current project. Reads `.claude/audit.jsonl`, applies filters, and renders a summary of recent blocks, per-hook counts, per-category counts, and a recent-event log.

## Process

### Step 1: Locate the Audit File

Determine the project root:

```bash
git rev-parse --show-toplevel 2>/dev/null || pwd
```

Set `AUDIT_FILE="<project-root>/.claude/audit.jsonl"`.

Check whether the file exists and is non-empty:

```bash
[ -s "$AUDIT_FILE" ] && echo "found" || echo "missing"
```

If the file is missing or empty, output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AUDIT LOG │ <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  No audit entries found.
  Hook blocks are recorded here when safety hooks fire.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then stop.

### Step 2: Determine Parameters

Resolve argument values:

- `DAYS` = `$days` argument if provided, else `30`
- `HOOK_FILTER` = `$hook` argument if provided, else empty (no filter)
- `CAT_FILTER` = `$category` argument if provided, else empty (no filter)
- `PROJECT` = basename of project root

Compute the cutoff timestamp in UTC (ISO-8601):

```bash
date -u -d "$DAYS days ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null \
  || date -u -v-"${DAYS}d" +"%Y-%m-%dT%H:%M:%SZ"
```

(The first form handles GNU date on Linux; the second handles BSD date on macOS. Use whichever succeeds.)

### Step 3: Parse and Filter Entries

Use `jq` to read and filter the JSONL. Each audit entry is a JSON object on its own line. Expected fields:

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | string | ISO-8601 UTC timestamp of the block event |
| `hook` | string | Hook name that fired (e.g. `dangerous-commands`) |
| `category` | string | Block category (e.g. `DESTRUCTIVE`) |
| `reason` | string | Human-readable reason for the block |

Run the filter pipeline with `jq`:

```bash
jq -c 'select(.timestamp >= "'"$CUTOFF"'")
       | select(if "'"$HOOK_FILTER"'" != "" then .hook == "'"$HOOK_FILTER"'" else true end)
       | select(if "'"$CAT_FILTER"'" != "" then .category == "'"$CAT_FILTER"'" else true end)' \
  "$AUDIT_FILE"
```

Assign the filtered result set to memory for subsequent aggregation steps. If `jq` is not installed, stop and report:

```
Error: jq is required to parse audit.jsonl. Install jq and retry.
```

If the filter produces zero entries, display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AUDIT LOG │ Last $DAYS days │ <project>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  No entries match the current filters.

  Filters applied:
    Days:     $DAYS
    Hook:     <$HOOK_FILTER or "all">
    Category: <$CAT_FILTER or "all">

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Then stop.

### Step 4: Compute Aggregates

From the filtered entry set, compute:

**Total blocks:**
```bash
jq -s 'length' <<< "$FILTERED"
```

**By hook** (sorted descending by count):
```bash
jq -rs 'group_by(.hook) | map({hook: .[0].hook, count: length}) | sort_by(-.count)[] | "\(.hook) \(.count)"' <<< "$FILTERED"
```

**By category** (sorted descending by count):
```bash
jq -rs 'group_by(.category) | map({cat: .[0].category, count: length}) | sort_by(-.count)[] | "\(.cat) \(.count)"' <<< "$FILTERED"
```

**Most recent 5 entries** (sorted by timestamp descending):
```bash
jq -rs 'sort_by(.timestamp) | reverse | .[0:5][]
        | "\(.timestamp) \(.hook): \(.reason) (\(.category))"' <<< "$FILTERED"
```

For human-readable timestamps in the recent entries list, reformat each ISO-8601 string to `YYYY-MM-DD HH:MM UTC` using string slicing inside `jq`:

```bash
jq -r '(.timestamp | .[0:10] + " " + .[11:16] + " UTC")
       + "  " + .hook + ": " + .reason + " (" + .category + ")"'
```

### Step 5: Render Output

Display the formatted report:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AUDIT LOG │ Last N days │ [project]
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
    TDD                    │ N
    FREEZE                 │ N

  Recent (last 5):
    YYYY-MM-DD HH:MM UTC  hook-name: reason (CATEGORY)
    YYYY-MM-DD HH:MM UTC  hook-name: reason (CATEGORY)
    ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If a filter was active, note it below the header separator:

```
  Filters: hook=<name>  category=<CAT>
```

Omit filter lines for dimensions that were not filtered.

If total blocks is zero after filter evaluation (e.g. file exists but all entries are outside the date window), display the no-match output from Step 3 instead of the full report.

## Examples

```
/audit                                 # Last 30 days, all hooks
/audit --days 7                        # Last 7 days
/audit --hook dangerous-commands       # Only dangerous-commands blocks
/audit --category SECURITY             # Only SECURITY category blocks
/audit --days 14 --category GIT_SAFETY # Combined filters
```

## Notes

- All timestamp comparisons use UTC. The cutoff is computed at invocation time.
- `jq` is required. The command will fail explicitly if `jq` is absent rather than producing incorrect output.
- Entries are expected to conform to the schema above. Malformed lines (invalid JSON or missing fields) are silently skipped by `jq`'s `select` filter — this is intentional to handle partial writes without crashing the audit view.
- The audit file is append-only and written by hooks; this command is read-only and never modifies it.
- Category values are case-sensitive: `DESTRUCTIVE`, `SECURITY`, `GIT_SAFETY`, `TDD`, `FREEZE`.

$ARGUMENTS
