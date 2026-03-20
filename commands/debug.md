---
description: Use when a bug resists quick fixes. Prevents random-change debugging.
arguments:
  - name: issue
    description: Description of the bug or unexpected behavior
    required: false
---

# Scientific Debugging

Structured debugging that prevents the "random change and hope" antipattern. Each phase builds on the previous — no jumping ahead.

## When to Use

- Bug isn't obvious from reading the code
- You've already tried the obvious fix and it didn't work
- The issue is intermittent or environment-dependent
- Multiple systems interact and you're unsure which is at fault

## Process

### Phase 1: OBSERVE

**Goal:** Establish exactly what happens, not what you think happens.

```
What to capture:
  1. Exact error message (full text, not paraphrased)
  2. Reproduction steps (minimal sequence)
  3. Expected vs actual behavior
  4. When it started (commit, change, or "always")
  5. Environment (OS, versions, config)
```

Display:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DEBUG │ Phase 1: OBSERVE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Error:    [exact message]
  Repro:    [steps]
  Expected: [what should happen]
  Actual:   [what does happen]
  Since:    [when it started]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Vault Check (if vault available)

Before hypothesizing, check if this issue has been seen before:

1. Source vault config:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null
   ```
2. If vault available, search for findings related to the error message, component name, or behavior:
   - Use Grep to search `$VAULT_PATH/Engineering/Findings/` for key terms from the observation
   - If matches found: "Vault has prior findings that may be relevant:" with titles and 1-line summaries
   - This can immediately shortcut debugging if the issue was previously documented
3. Skip silently if vault unavailable

### Phase 2: HYPOTHESIZE

**Goal:** Generate 3+ possible causes. Rank by likelihood.

```
Rules:
  - Generate AT LEAST 3 hypotheses
  - Include at least one "unlikely but catastrophic" option
  - Rank by: likelihood × ease of testing
  - DO NOT test yet — just list
```

Display:
```
  Hypotheses (ranked):
    1. [Most likely] — because [evidence]
    2. [Next likely] — because [evidence]
    3. [Less likely] — because [evidence]
    4. [Unlikely but worth checking] — because [consequence if true]
```

### Phase 3: PREDICT

**Goal:** For the top hypothesis, predict what ELSE should be true if it's correct.

```
If hypothesis "[X]" is correct, then:
  1. [prediction 1] should also be true
  2. [prediction 2] should also be true
  3. [prediction 3] should be FALSE (differentiates from hypothesis 2)
```

This is the key step most developers skip. Predictions make hypotheses **falsifiable**.

### Phase 4: EXPERIMENT

**Goal:** Test ONE prediction. Record the result.

```
Rules:
  - Test the CHEAPEST prediction first
  - Change ONLY ONE thing
  - Record: what you did, what happened, what it means
  - If prediction confirmed: hypothesis gains confidence
  - If prediction falsified: eliminate hypothesis, try next
```

Display:
```
  Experiment: [what you did]
  Prediction: [what you expected]
  Result:     [what actually happened]
  Conclusion: [hypothesis confirmed/falsified/inconclusive]
```

Repeat Phase 3-4 for remaining hypotheses if needed.

### Phase 5: CONCLUDE

**Goal:** Identify the confirmed cause and fix.

```
  Root cause: [confirmed hypothesis]
  Evidence:   [which predictions confirmed it]
  Fix:        [specific change needed]
  Verify:     [how to confirm the fix worked]
  Prevent:    [how to prevent recurrence — test, guard, etc.]
```

## Anti-Patterns to Avoid

| Anti-Pattern | Why It's Wrong | Instead |
|---|---|---|
| Changing multiple things at once | Can't tell what fixed it | One change per experiment |
| Fixing without understanding | May mask the real issue | Confirm root cause first |
| Assuming the obvious cause | Obvious cause is often wrong | Generate 3+ hypotheses |
| Skipping prediction | Can't falsify without predictions | Always predict before testing |
| Stopping at first fix | Fix may be coincidental | Verify with prediction |

## Integration

After debugging completes, consider:
- Should there be a test for this? (prevents regression)
- Is this a symptom of a deeper issue? (architectural)
- Should this be documented? (if non-obvious)
- **Was this a user error?** If the bug traces back to a bad prompt, stale context, or wrong harness choice — `/log-error` captures the lesson so the same mistake doesn't repeat
- **Insight capture:** Root causes and fix patterns are high-value findings. Run `/collect-insights` to flush them to vault + epistemic tracking — debugging insights prevent repeat failures across sessions

**Full learning loop:** Run `/pipeline run learn-from-failure` to chain debug → log-error → evolve in sequence. Captures the mistake and synthesizes it into workflow improvements.

Also available (user-initiated):
- Same mistake recurring? If `hookify` plugin is installed, `/hookify` creates a prevention hook
- Deep investigation needed? If `code-analysis` plugin is installed, `/analyze` or the `detective` agent traces code paths across the codebase
- Bug was your fault? `/log-error` interviews you about what went wrong in your prompting/context/harnessing
