---
description: Use after something works unusually well. Captures what YOU did right so you can reproduce it.
arguments:
  - name: what-worked
    description: Brief description of what went well
    required: false
---

# Log Success

Structured capture of what went right and why. Most people only log failures — but understanding why things work is just as important for building skill. Successes that go unexamined become unreproducible luck.

## When to Use

- Something worked on the first try that you expected to struggle with
- A complex workflow completed with minimal intervention
- A prompt produced exactly what you wanted
- A subagent chain worked cleanly end-to-end
- An approach or pattern clicked in a way worth remembering
- You tried a new technique and it paid off
- A blueprint stage completed faster or cleaner than expected

## Process

### Step 1: Review Context

Review the recent conversation to identify what went notably well. Look for:
- What task was accomplished smoothly
- What approach was used
- Moments where something just clicked
- Unusually fast completion or first-try successes
- Elegant solutions that emerged
- Minimal correction needed

### Step 2: Interview the User

Ask 4-6 **specific clarifying questions** about WHY it worked. Tailor to what actually happened.

Examples of good questions:
- "That [task] came together in under [N] minutes. What about the prompt setup made it work?"
- "You didn't have to correct me once during [task]. Was that the context in CLAUDE.md or the way you structured the request?"
- "The subagent chain worked cleanly. Did you do something specific to set up the context handoff?"
- "Was this approach something you planned, or did it emerge during the conversation?"
- "What would you do the same next time? What was the key ingredient?"
- "Could you reproduce this, or was there a luck element?"

Questions should cover:
- **What specifically went well** — precise, not generic
- **Why it worked** — contributing factors
- **The setup** — what context/prompt/approach was used
- **Key ingredient** — the one thing that made the difference
- **Reproducibility** — should this become standard practice?

### Step 3: Trace the Triggering Prompt

Identify and quote the **exact user prompt(s)** that led to the success. Ask the user to confirm or paste the exact prompt if you can't find it in context. Good prompts are worth preserving verbatim.

### Step 4: Write the Log

Create the success log file:

```bash
# Ensure directory exists
mkdir -p .claude/success-logs
```

Write to `.claude/success-logs/success-YYYY-MM-DD-HHMM.md`:

```markdown
# Success: [Short Descriptive Name]
**Date:** [YYYY-MM-DD]
**Project:** [project name]

## What Went Well
[2-3 sentences — what worked and why it's notable]

## Success Category
**Primary factor:** [Pick one]
- Prompt clarity — clear, constrained, right abstraction level
- Context freshness — clean session, relevant context only
- Good harnessing — right agent, right parallelization, good guardrails
- Workflow discipline — used planning/review steps that paid off
- Domain knowledge — user's expertise guided the prompt effectively
- Tool choice — right MCP/command/skill for the job

## The Triggering Prompt
```
[Exact prompt — verbatim]
```

## Why This Prompt Worked
[What made this effective? Structure, constraints, context setup?]

## Key Ingredient
[The ONE thing that made the biggest difference]

## Reproducibility
- **Can repeat?** [Yes/Likely/Maybe/Lucky]
- **Should standardize?** [Yes — add to workflow / No — context-specific]
- **Action:** [What to do with this knowledge]

## One-Line Takeaway
[Actionable pattern for future prompting/context/harnessing]
```

### Step 5: Epistemic Tracking

If an epistemic session is active (`~/.claude/.current-session` exists):
1. Append to `.epistemic/insights.jsonl`:
   ```json
   {"timestamp": "ISO-8601", "type": "finding", "input": {"finding": "[Success] one-line takeaway"}}
   ```
2. Successes are high-signal findings — they represent validated patterns

### Step 6: Vault Export (if available)

If vault is configured:
1. Source vault config: `source ~/.claude/hooks/vault-config.sh 2>/dev/null`
2. Create a finding note at `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-success-slug.md`
3. Use the finding template with `category: success-log`, `severity: info`

### Step 7: Pattern Reinforcement

Check `.claude/success-logs/` for previous successes:
- Same category appearing 3+ times? Flag it: "This is a confirmed strength. Consider formalizing it in CLAUDE.md or as a workflow step."
- Contrast with error logs: "Your successes cluster around [X] while errors cluster around [Y] — this suggests where to focus improvement."

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SUCCESS LOGGED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  File:      .claude/success-logs/success-YYYY-MM-DD-HHMM.md
  Category:  [primary factor]
  Takeaway:  [one-line takeaway]
  Pattern:   [N previous successes in this category / first occurrence]

  Epistemic: [logged / skipped]
  Vault:     [exported / skipped]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Integration

After logging, consider:
- Should this pattern become a CLAUDE.md instruction?
- Should this become a skill or command for consistent reuse?
- Does this success suggest a workflow improvement?

Also available (user-initiated):
- `/log-error` — If you want to contrast with a recent failure in the same area
- `/promote-finding` — If a success pattern has been validated 3+ times, promote it to a CLAUDE.md rule
- `/evolve` — After accumulating 5+ success logs, synthesize patterns into workflow improvements

## Notes

- Success logs are append-only — never modify old logs
- The interview matters. "It worked" is not a log — WHY it worked is
- Be specific about the key ingredient. Vague successes can't be reproduced
- Over time, success + error logs together reveal your personal skill profile
