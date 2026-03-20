---
description: Use when you want to flush pending insights to Obsidian vault and epistemic tracking. Captures ★ Insight blocks and orphaned disk findings.
---

# Collect Insights

Flush pending insights to both the Obsidian vault and epistemic tracking. Reads orphaned disk findings from `.epistemic/insights.jsonl`, captures any ★ Insight blocks from the current conversation, and writes each to vault (as finding notes) and marks them as synced in the disk store.

## Why This Exists

Insights accumulate in two places during a session: in-conversation ★ Insight blocks (ephemeral) and `.epistemic/insights.jsonl` (disk safety net from the PostToolUse hook). Without explicit collection, these remain fragmented — vault has no record, and the disk store may have partial data. This command reconciles both stores.

## Process

### Step 1: Source Vault Config

Use the Bash tool to source vault-config.sh and extract config values:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
```

Note the result. If vault is unavailable, continue anyway — disk writes can still proceed (fail-soft).

### Step 2: Check for Active Epistemic Session

```bash
if [ -f "$HOME/.claude/.current-session" ]; then
    cat "$HOME/.claude/.current-session"
else
    echo "NO_SESSION"
fi
```

Note the session ID. If no session, session-linked writes will be skipped (fail-soft).

### Step 3: Gather Insights from Disk

Read `.epistemic/insights.jsonl` (at git root). Each line is a JSON object:

```json
{"timestamp": "ISO-8601", "type": "finding", "input": {"finding": "text"}}
```

Parse each line. Collect all entries that have NOT already been synced (check for `"synced": true` field — unsynced entries lack this field).

### Step 4: Gather Insights from Conversation

Scan the current conversation for any ★ Insight blocks that were NOT already captured to disk. These are blocks formatted like:

```
★ Insight: <title or summary>
<body text>
```

Deduplicate against the disk entries from Step 3 by comparing the finding text (fuzzy match on content — exact match not required, but the core insight should match).

### Step 5: Merge and Deduplicate

Combine disk insights (Step 3) and conversation insights (Step 4) into a single list. Remove duplicates. Each insight needs:

- **title**: Short descriptive title (extract from finding text or ★ Insight header)
- **description**: Full insight text
- **severity**: From the JSON if present, or "info" as default
- **timestamp**: From the JSON `timestamp`, or current time for conversation-only insights
- **confidence**: From the JSON if present, or 0.7 as default for unassessed insights

### Step 6: Write to Obsidian Vault

If vault is available (Step 1):

1. Ensure target directory exists:

```bash
mkdir -p "$VAULT_PATH/Engineering/Findings"
```

2. Read the finding template from `~/.claude/commands/templates/vault-notes/finding.md`.

3. For each insight, create a vault note:

   - Get the project name: `basename $(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")`
   - Generate slug via Bash: `echo "TITLE_HERE" | tr -cd '[:alnum:] ._-' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | head -c 80`
   - Replace template placeholders:
     - `{{date}}`: Today's date (YYYY-MM-DD)
     - `{{project}}`: Project name
     - `{{category}}`: "insight" (default for all insights collected here)
     - `{{severity}}`: From insight data
     - `{{title}}`: Insight title
     - `{{description}}`: Full insight text
     - `{{session_link}}`: Session ID from Step 2 (or "no-session")
     - `{{implications}}`: Brief note on why this matters (Claude-generated from context)
   - Add epistemic confidence frontmatter (conditional fields — omit line entirely if no value):
     - `epistemic_confidence`: From insight confidence value
     - `epistemic_assessed`: Today's date (YYYY-MM-DD)
     - `epistemic_session`: Session ID from Step 2
     - `epistemic_status`: "active"
   - Write to: `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-slug.md`

4. Use the Write tool for each note. Do NOT use Obsidian MCP for writes.

If vault is unavailable, log: "Vault write skipped (vault disabled or not accessible). Disk-only mode."

### Step 7: Ensure Disk Capture

Verify all insights are captured in `.epistemic/insights.jsonl`. For any insight that was only in conversation (not already on disk), append it now:

```json
{"timestamp": "ISO-8601", "type": "finding", "input": {"finding": "[Insight] the insight text"}}
```

This ensures all insights survive session boundaries regardless of vault availability.

### Step 8: Mark Disk Entries as Synced

Update `.epistemic/insights.jsonl` to mark processed entries. For each processed line, add `"synced": true` to the JSON object. Write the updated file back.

If the file contained ONLY the entries that were just processed, the file can be cleared to an empty file to avoid unbounded growth.

### Step 9: Present Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  COLLECT INSIGHTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Sources:
    Disk (.epistemic/insights.jsonl):  N entries
    Conversation (★ Insight blocks):  N entries
    Duplicates removed:               N

  Written:
    Vault:    N notes → Engineering/Findings/
    Disk:     N findings captured

  Skipped:
    [reason, if any — e.g., "Vault unavailable"]

  Files:
    [list of vault note paths written]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Examples

```
/collect-insights                # Flush all pending insights
```

## Notes

- This command dual-writes: Obsidian vault is the primary data store, `.epistemic/insights.jsonl` is the disk safety net
- Fail-soft: if vault is unavailable, disk writes still proceed (and vice versa)
- If vault is unavailable, insights are captured on disk only
- All vault writes use the Write tool (no Obsidian MCP dependency)
- Filenames use vault_sanitize_slug for NTFS safety
- The PostToolUse insight hooks are the write-through safety net that populates insights.jsonl
- **Relationship to `/end`:** The `/end` command runs this same insight sweep automatically (Step 3). Use `/collect-insights` for mid-session flushes; `/end` handles the final sweep at session close.
