---
name: compaction-safety
description: Lightweight nudge to save important state before context compaction
hooks:
  - event: PreToolUse
    tools:
      - Write
      - Edit
      - Bash
---

# Compaction Safety Nudge

If the conversation has been long (many tool calls, large code explorations, multiple implementation steps), pause and consider whether important context could be lost if compaction occurs.

## When to Act

This nudge applies when ALL of these are true:
- You have been working for a while (10+ tool calls in this session)
- You have accumulated important state: decisions made, findings discovered, progress on a multi-step plan
- You have NOT recently saved that state to disk

If the conversation is short or you have already saved state recently, ignore this nudge.

## What to Save

If you determine state should be preserved, save it to a file the next session can find. Good locations:

- **`.claude/session-state.md`** -- General scratchpad for current work state
- **`.claude/plans/<name>/state.json`** -- If working within a blueprint plan
- **Project CLAUDE.md** -- For permanent discoveries about the project (add to relevant section)

### What counts as important state:

- **Decisions made** -- "We chose approach X over Y because Z"
- **Findings** -- "The auth module uses pattern X, not Y as expected"
- **Progress** -- "Completed steps 1-3, step 4 is in progress, step 5 remaining"
- **Gotchas discovered** -- "The API returns 200 even on failure, check the `success` field"
- **Partial work** -- If you are mid-implementation, note what is done and what remains

### What does NOT need saving:

- Information already in the codebase (file contents, function signatures)
- Generic knowledge (how Python imports work, what REST is)
- Things you can re-derive quickly by reading files

## How to Save

Keep it minimal. A few bullet points is better than a long narrative:

```markdown
## Session State (saved at [timestamp])

### Current Task
[What we are working on]

### Progress
- [x] Step 1: [done]
- [x] Step 2: [done]
- [ ] Step 3: [in progress -- details]
- [ ] Step 4: [not started]

### Key Decisions
- Chose X over Y because [reason]

### Discoveries
- [Non-obvious thing learned during this session]
```

## Fail-Soft

This is a nudge, not a gate. If saving state would interrupt critical work flow (e.g., you are in the middle of a multi-file edit that must be atomic), finish the current operation first, then save.
