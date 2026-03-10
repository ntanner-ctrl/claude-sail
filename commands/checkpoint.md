---
description: Use before ending a session or when context is getting large. Saves decision rationale for future sessions.
arguments:
  - name: summary
    description: Brief summary of current state (prompted if not provided)
    required: false
---

# Checkpoint

Manual context-save for decision continuity across sessions. Captures what you're doing, why, and what comes next — so future sessions can resume without re-deriving context.

## When to Use

- Before ending a long session
- When context window is getting large (compaction risk)
- After making a non-obvious decision (save the rationale)
- Before switching to a different task
- When you'd be upset if this context was lost

## Process

### Step 1: Gather Context

If no `--summary` provided, ask:
1. "What are you currently working on?"
2. "What key decisions were made (and why)?"
3. "What's the next action?"

### Step 2: Determine Location

```bash
# If active plan exists, checkpoint goes with the plan
if [ -f ".claude/state-index.json" ]; then
    plan=$(jq -r '.active_plan // empty' .claude/state-index.json)
    if [ -n "$plan" ]; then
        # Plan-scoped checkpoint
        mkdir -p ".claude/plans/${plan}/checkpoints"
        DEST=".claude/plans/${plan}/checkpoints/$(date -u +%Y%m%dT%H%M%SZ).json"
    fi
fi

# Otherwise, global checkpoint
if [ -z "${DEST:-}" ]; then
    mkdir -p ".claude/checkpoints"
    DEST=".claude/checkpoints/$(date -u +%Y%m%dT%H%M%SZ).json"
fi
```

### Step 3: Write Checkpoint

> **Atomic write requirement:** Checkpoint JSON MUST be written atomically: write to a temp file first (`checkpoint.json.tmp`), then rename to the final path. This prevents partial reads if the guardian or a subagent reads the checkpoint mid-write.

Create JSON:
```json
{
  "timestamp": "ISO-8601",
  "summary": "Working on X because Y",
  "decisions": [
    "Chose A over B because [rationale]",
    "Deferred C until [condition]"
  ],
  "next_action": "What to do next when resuming",
  "blockers": [],
  "context": {
    "active_plan": "[name or null]",
    "active_plan_stage": "[N or null]",
    "active_tdd_phase": "[phase or null]",
    "files_in_progress": ["file1.ts", "file2.ts"]
  },
  "empirica": {
    "session_id": "uuid or null",
    "preflight_complete": true,
    "last_finding_count": 5
  },
  "compaction_context": {
    "triggered_by_guardian": true,
    "context_percentage_at_checkpoint": 76,
    "key_context": {
      "current_task": "Implementing JWT refresh token rotation",
      "blocking_question": "Whether to use sliding or fixed expiry windows",
      "last_file_edited": "src/auth/refresh.ts",
      "next_intended_action": "Write the token rotation middleware",
      "confidence_caveat": "At 76% context — early conversation details may already be compressed"
    }
  }
}
```

### Step 3.5: Write Guardian Signal (if triggered by guardian)

If this checkpoint was triggered by the compaction guardian, write the completion signal:

```bash
# Write checkpoint-done signal for the guardian
echo "$(date +%s)" > "/tmp/.claude-checkpoint-done-${GUARDIAN_SIG_SUFFIX}"
```

Where `GUARDIAN_SIG_SUFFIX` is the literal signal path provided by the guardian's block message.

### Step 4: Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CHECKPOINT SAVED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Location: [path]
  Summary:  [summary]
  Decisions: [N] recorded
  Next:     [next_action]

  This context will be surfaced on next session start.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 5: Update State Index

If state-index.json exists, update `last_checkpoint`:

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '.last_checkpoint = $ts' .claude/state-index.json > tmp.$$ && mv tmp.$$ .claude/state-index.json
```

## Reading Checkpoints

On session resume, the session-sail hook reads the latest checkpoint and surfaces it. Checkpoints can also be read manually:

```bash
# Latest checkpoint for active plan
cat .claude/plans/[name]/checkpoints/*.json | jq -s 'sort_by(.timestamp) | last'

# Latest global checkpoint
cat .claude/checkpoints/*.json | jq -s 'sort_by(.timestamp) | last'
```

## Notes

- Checkpoints are append-only (never modified, only new ones created)
- Old checkpoints are NOT deleted (they're cheap and provide history)
- The session-sail hook only shows the LATEST checkpoint
- Pair with `/dashboard` to see full active state
- **`empirica` field:** Captures Empirica session state so a resumed session can reconnect to the same epistemic tracking. `session_id` is the active Empirica session UUID (or null if none). `preflight_complete` indicates whether preflight assessment was submitted. `last_finding_count` is the number of findings logged so far (helps the resumed session gauge how much was captured).
- **`compaction_context` field:** Only populated when the checkpoint is triggered by the compaction guardian (context >= 75%). Contains `triggered_by_guardian` (boolean), `context_percentage_at_checkpoint` (integer), and `key_context` (object with `current_task`, `blocking_question`, `last_file_edited`, `next_intended_action`, and `confidence_caveat`). The `confidence_caveat` should note that high-context checkpoints may have lossy early-conversation recall.
