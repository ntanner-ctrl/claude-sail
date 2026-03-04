---
description: REQUIRED after completing a blueprint on the Full path. External perspective catches what familiarity blinds you to.
arguments:
  - name: target
    description: Blueprint name, file path, or 'current' for active context
    required: false
---

# Review

Focused adversarial review workflow. Use this when you have a blueprint or implementation and want to systematically challenge it without going through full planning stages.

## Overview

```
Stage 1: Devil's Advocate  → Challenge assumptions
Stage 2: Simplify          → Question complexity
Stage 3: Edge Cases        → Probe boundaries
Stage 4: External (opt)    → GPT review for blind spots
Stage 5: Deep Analysis (opt) → Plugin-enhanced specialized review
```

Stage 5 only appears when specialized review plugins are detected.

## Process

### Step 1: Identify Target

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 1 of 4: Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

What are you reviewing?

  [1] An existing blueprint (provide name or path)
  [2] Current implementation (describe scope)
  [3] An idea or approach (describe it)

>
```

### Step 2: Run Adversarial Stages

**Stage 1: Devil's Advocate**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 1 of 4: Devil's Advocate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Challenging assumptions...
```

Run `/devils-advocate` on the target.

**Stage 2: Simplify**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 2 of 4: Simplify
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Questioning complexity...
```

Run `/overcomplicated` on the target.

**Stage 3: Edge Cases**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 3 of 4: Edge Cases
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Probing boundaries...
```

Run `/edge-cases` on the target.

**Stage 4: External Review (Optional)**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 4 of 4: External Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Would you like an external perspective via /gpt-review?
This can catch blind spots that local review missed.

  [1] Yes - run external review
  [2] No - skip, local review is sufficient

>
```

If yes, run `/gpt-review` with all local findings included.

**Stage 5: Deep Analysis (Optional)**

After completing the core 4 stages, check for plugin enhancements:

1. Read `commands/plugin-enhancers.md`. If file not found, skip this stage entirely.
2. Follow the Detection Protocol (Section 1) to check for review-capable plugins.
3. If NO review plugins detected, skip this stage entirely (don't show the option).
4. Build options list from detected plugins:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Stage 5 of 5: Deep Analysis (optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Core adversarial review complete.

  Deep analysis available (select one or more, comma-separated):

  [If pr-review-toolkit detected:]
    [1] PR Toolkit — 6 specialized agents in parallel
        (silent failures, type design, test coverage,
         comments, simplification, conventions)

  [If security-pro detected:]
    [2] Security Audit — security-pro:security-auditor
        Deep vulnerability assessment and compliance

  [If performance-optimizer detected:]
    [3] Performance Audit — performance-optimizer:performance-engineer
        Bottleneck identification and optimization

  [If superpowers detected:]
    [4] Methodology Review — superpowers:code-reviewer
        Code review against project guidelines and best practices

  [If feature-dev detected:]
    [5] Conventions Review — feature-dev:code-reviewer
        Convention-focused review with confidence-based filtering

    [N] Skip — core review is sufficient

>
```

Options are dynamically numbered based on detected plugins. Multiple can be selected.

5. For each selected option:
   - Fast-fail probe: dispatch ONE agent from that plugin with 10-second timeout
   - If probe fails: Log `[PLUGIN] <plugin> probe failed; skipping`, continue to next selection
   - If probe passes: dispatch the plugin's review agent(s) (5-min timeout each)
   - For pr-review-toolkit: dispatch all 6 agents in parallel
   - For other plugins: dispatch the single registered review agent
   - Format results per plugin-enhancers.md Section 5
   - Circuit breaker: 3 consecutive failures from same plugin → abort remaining agents for that plugin
   - Add results to the Review Summary under "### Deep Analysis" section

6. Quick mode (`/review --quick`) skips this stage entirely.

### Step 3: Compile Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REVIEW │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Review Summary: [target]

### Devil's Advocate
- Gaps found: [N]
- Critical: [list]

### Simplify
- Simplification opportunities: [N]
- Recommended: [list]

### Edge Cases
- Unhandled: [N]
- High-risk: [list]

### External Review
[Included / Skipped]
[If included, key novel findings]

### Deep Analysis
[If run: plugin findings summary with [plugin-review] tags]
[If skipped: "Not run" or "No specialized plugins detected"]

## Overall Verdict

- [ ] Ready to proceed
- [ ] Address [N] issues first
- [ ] Needs significant rethinking

## Recommended Actions

1. [action]
2. [action]
3. [action]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Quick Mode

For faster review focusing on one dimension:

```
/review --quick devils-advocate [target]
/review --quick simplify [target]
/review --quick edge-cases [target]
```

Runs only the specified stage.

## Output Format

```markdown
# Adversarial Review: [target]

## Executive Summary

| Dimension | Issues | Critical? |
|-----------|--------|-----------|
| Assumptions | [N] gaps | [Yes/No] |
| Complexity | [N] opportunities | [Yes/No] |
| Edge Cases | [N] unhandled | [Yes/No] |
| External | [included/skipped] | — |
| Deep Analysis | [N] findings | [Yes/No] |

## Detailed Findings

### Assumptions (Devil's Advocate)
[findings]

### Complexity (Overcomplicated)
[findings]

### Boundaries (Edge Cases)
[findings]

### External Perspective
[findings if included]

### Deep Analysis (Plugin Review)
[findings if run — formatted per plugin-enhancers.md Section 5]

## Recommended Actions

1. [prioritized action]
2. [prioritized action]
...

## Verdict

[Ready / Needs Work / Rethink]
```

## Post-Review Actions

Based on the verdict:

| Verdict | Suggested Next |
|---------|----------------|
| Ready to proceed | `/design-check` → implementation |
| Address N issues | `/decision` to record trade-offs, then fix |
| Needs rethinking | `/brainstorm` to explore alternatives |

## Integration

- **Standalone:** Can be run on any blueprint, implementation, or idea
- **After /blueprint:** Provides deeper adversarial review post-planning
- **Before /push-safe:** Final check before shipping
- **Findings recorded:** Appended to `.claude/plans/[name]/adversarial.md` if blueprint context active
