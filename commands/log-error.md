---
description: Use after Claude makes a mistake you want to learn from. Structured self-interview that identifies what YOU did wrong.
arguments:
  - name: what-happened
    description: Brief description of what went wrong
    required: false
---

# Log Error

Structured self-interview that turns agentic coding failures into learning. The primary goal is identifying what **you** (the user) did wrong in prompting, context management, or harness configuration — not cataloging model failures.

## Core Philosophy

Errors in agentic coding are almost always traceable to:

- **Bad Prompt** — Ambiguous, missing constraints, too verbose, wrong structure
- **Context Rot** — Didn't /clear, conversation too long, stale context polluting responses
- **Bad Harnessing** — Wrong agent type, didn't pass context to subagents, missing guardrails

The model is the constant. Your input is the variable. Focus on the variable.

## When to Use

- Claude hallucinates something that doesn't exist
- Claude builds something you didn't ask for
- An anti-pattern or bug appears in Claude's output
- An instruction gets ignored or misinterpreted
- Context gets lost mid-conversation
- Claude gets stuck in a loop
- A subagent chain produces garbage
- Anything that could be attributed to misuse of context, prompting, or harnesses

## Process

### Step 1: Review Context

Review the recent conversation to understand what went wrong. Look for:
- The specific failure point
- What was in context at the time
- What Claude appeared to misunderstand

### Step 2: Interview the User

Ask 5-8 **pointed questions focused on USER behavior**. Be specific to what actually happened — not generic.

Examples of good questions:
- "Your prompt was [N] words. What were the 3 most important requirements?"
- "Did you specify what NOT to do, or only what to do?"
- "When did you last /clear? How full was context?"
- "Did you verify the subagents received the critical context?"
- "Was this reference material or explicit requirements?"
- "What constraints were in your head but not in the prompt?"
- "How many sessions deep are you? Has context been compacted?"
- "Did you read the output from the previous step before prompting the next?"

**Be critical.** The user invoked this command to learn, not to feel good. 80% focus on user error, 20% on model behavior.

### Step 3: Trace the Triggering Prompt

Get the **exact prompt** that led to failure. This is critical — paraphrased prompts hide the actual issue. Ask the user to confirm or paste the verbatim prompt if you can't find it in context.

### Step 4: Categorize and Log

After the interview, classify the error and create the log.

#### Error Taxonomy

**Prompt Errors:**
- **Ambiguous instruction** — Could be interpreted multiple ways
- **Missing constraints** — Didn't specify what NOT to do
- **Too verbose** — Buried key requirements in walls of text
- **Reference vs requirements** — Gave reference material, expected extracted requirements
- **Implicit expectations** — Had requirements in head, not in prompt
- **No success criteria** — Didn't define what "done" looks like
- **Wrong abstraction level** — Too high-level or too detailed for the task

**Context Errors:**
- **Context rot** — Conversation too long, should have /cleared
- **Stale context** — Old information polluting new responses
- **Context overflow** — Too much info degraded performance
- **Missing context** — Assumed Claude remembered something it didn't
- **Wrong context** — Irrelevant information drowning signal

**Harness Errors:**
- **Subagent context loss** — Critical info didn't reach subagents
- **Wrong agent type** — Used wrong specialized agent for task
- **No guardrails** — Didn't constrain agent behavior appropriately
- **Parallel when sequential needed** — Launched agents that had dependencies
- **Sequential when parallel possible** — Slow execution due to unnecessary serialization
- **Missing validation** — No check that agent output was correct
- **Trusted without verification** — Accepted agent output without review

**Meta Errors:**
- **Didn't ask clarifying questions** — Could have caught this earlier
- **Rushed to implementation** — Skipped planning/verification
- **Assumed competence** — Expected Claude to infer too much

### Step 5: Write the Log

Create the error log file:

```bash
# Ensure directory exists
mkdir -p .claude/error-logs
```

Write to `.claude/error-logs/error-YYYY-MM-DD-HHMM.md`:

```markdown
# Error: [Short Descriptive Name]
**Date:** [YYYY-MM-DD]
**Project:** [project name]

## What Happened
[2-3 sentences — what went wrong specifically]

## User Error Category
**Primary cause:** [One category from taxonomy above]

## The Triggering Prompt
```
[Exact prompt — verbatim]
```

## What Was Wrong With This Prompt
[Specific and critical. What should have been different?]

## What The User Should Have Said Instead
```
[Rewritten prompt that would have prevented this error]
```

## The Gap
- **Expected:** [Expected outcome]
- **Got:** [Actual outcome]
- **Why:** [Direct connection to user error above]

## Impact
- **Time wasted:** [estimate]
- **Rework required:** [what needs to be redone]

## Prevention
1. [Specific action to take next time]
2. [Another specific action]
3. [Consider adding to CLAUDE.md or workflow]

## Pattern Check
- **Seen before?** [Yes/No — if yes, this is a habit to break]
- **Predictable?** [Should user have anticipated this?]

## One-Line Lesson
[Actionable takeaway about prompting/context/harnessing — NOT about model behavior]
```

### Step 6: Epistemic Tracking

If an epistemic session is active (`~/.claude/.current-session` exists):
1. Append to `.epistemic/insights.jsonl`:
   ```json
   {"timestamp": "ISO-8601", "type": "mistake", "input": {"mistake": "one-line lesson", "impact": "brief impact"}}
   ```
2. This feeds the calibration loop — preflight/postflight deltas show whether error patterns are improving

### Step 7: Vault Export (if available)

If vault is configured:
1. Source vault config: `source ~/.claude/hooks/vault-config.sh 2>/dev/null`
2. Create a finding note at `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-error-slug.md`
3. Use the finding template with `category: error-log`, `severity: warning`

### Step 8: Pattern Analysis

Check `.claude/error-logs/` for previous errors:
- Same category appearing 3+ times? Flag it: "This is a recurring pattern. Consider creating a hookify rule or CLAUDE.md instruction to prevent it."
- Same project area? Flag it: "Errors clustering around [area] — may indicate a deeper context or architecture gap."

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ERROR LOGGED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  File:      .claude/error-logs/error-YYYY-MM-DD-HHMM.md
  Category:  [primary cause]
  Lesson:    [one-line lesson]
  Pattern:   [N previous errors in this category / first occurrence]

  Epistemic: [logged / skipped]
  Vault:     [exported / skipped]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Integration

After logging, consider:
- Same mistake recurring? If `hookify` plugin is installed, `/hookify` creates a prevention hook
- Is this a CLAUDE.md gap? Add a project-level instruction to prevent recurrence
- Should this change a workflow? If a planning/review step would have caught this, note it

Also available (user-initiated):
- `/debug` — If the error produced a bug that needs systematic investigation
- `/checkpoint` — Save current state if you're about to retry with a different approach
- `/evolve` — After accumulating 5+ error logs, synthesize patterns into workflow improvements

## Notes

- Error logs are append-only — never modify old logs
- The interview is the most valuable part. Skip it and you're just filing paperwork
- Be honest about the category. "Model was wrong" is almost never the real answer
- Over time, your error log becomes a personalized agentic coding curriculum
