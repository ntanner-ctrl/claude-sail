---
description: You MUST use this when requirements are fuzzy, the problem space is unclear, or you're about to plan something you don't fully understand. Skipping leads to blueprints built on assumptions.
arguments:
  - name: topic
    description: What needs clarification (problem, feature, or area of uncertainty)
    required: false
---

# Clarify

Guided pre-planning workflow that walks through clarification steps based on what's actually unclear. Not every step runs every time — assess the situation and skip what's already resolved.

## Overview

```
Step 1: Assess    → What's fuzzy? (requirements, approaches, boundaries, prior art)
Step 2: Brainstorm → /brainstorm (if multiple viable approaches exist)
Step 3: Discover   → /requirements-discovery (if requirements are unclear)
Step 4: Check      → /design-check (if implementation boundaries are fuzzy)
Step 5: Search     → /prior-art (if building something that might already exist)
Step 6: Summary    → Present what was clarified and recommend next action
```

## Process

### Step 1: Assess What's Fuzzy

Before running anything, assess which dimensions are unclear. Ask the user:

```
What's unclear about this work?

  [A] Multiple approaches — not sure which direction to take
  [B] Requirements — not sure what "done" looks like
  [C] Boundaries — not sure what's in scope or what components are involved
  [D] Prior art — not sure if this already exists as a library/tool
  [E] All of the above / I don't know what I don't know

Pick one or more (e.g., "A and C"), or describe what feels fuzzy.
```

If $ARGUMENTS was provided, infer from context which dimensions apply. Present your assessment and ask for confirmation:

```
Based on "[topic]", it looks like:
  ✓ [A] Approaches — [reason this seems unclear]
  ✗ [B] Requirements — [reason this seems resolved]
  ...

Does this match your sense of what's fuzzy?
```

### Step 2: Brainstorm (if approaches are unclear)

**Trigger:** User selected [A] or you assessed multiple viable approaches exist.
**Skip if:** The approach is obvious or already decided.

Run `/brainstorm $ARGUMENTS` — structured problem analysis that explores root causes, constraints, and solution alternatives.

After brainstorm completes, capture the key output:
- Recommended approach (or top 2-3 if still ambiguous)
- Constraints identified
- Questions surfaced

### Step 3: Requirements Discovery (if requirements are unclear)

**Trigger:** User selected [B] or requirements lack testable acceptance criteria.
**Skip if:** Requirements are already concrete and testable.

Run `/requirements-discovery $ARGUMENTS` — extracts validated requirements through structured questioning.

After discovery completes, capture:
- Validated requirements (with acceptance criteria)
- Assumptions that were surfaced and resolved
- Remaining open questions

### Step 4: Design Check (if boundaries are fuzzy)

**Trigger:** User selected [C] or scope/components are uncertain.
**Skip if:** Architecture, interfaces, and error strategy are already clear.

Run `/design-check $ARGUMENTS` — 6-point prerequisite validation (requirements, architecture, interfaces, errors, data, algorithms).

After check completes, capture:
- READY or BLOCKED verdict
- Specific gaps identified (if any)

### Step 5: Prior Art Search (if building something new)

**Trigger:** User selected [D] or the work involves building a component that might already exist as a library/tool.
**Skip if:** This is clearly project-specific work with no general-purpose equivalent.

Run `/prior-art $ARGUMENTS` — searches GitHub and package registries for existing solutions.

After search completes, capture:
- Build vs. adopt recommendation
- Top candidates (if any)

### Step 6: Summary & Next Action

Present a structured summary of everything that was clarified:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CLARIFY │ Summary
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Topic: [topic]

  Steps completed:
    [✓/✗] Brainstorm      [1-line outcome or "skipped — approach was clear"]
    [✓/✗] Requirements     [1-line outcome or "skipped — requirements concrete"]
    [✓/✗] Design Check     [1-line outcome or "skipped — boundaries clear"]
    [✓/✗] Prior Art        [1-line outcome or "skipped — project-specific work"]

  Key findings:
    - [finding 1]
    - [finding 2]
    - ...

  Open questions (if any):
    - [question]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Recommended next step:
    /describe-change [topic]  → Triage and determine planning depth
    /blueprint [topic]        → Jump to full planning if depth is obvious

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Integration

- **Feeds into:** `/describe-change`, `/blueprint`
- **Fed by:** Conversation context, user uncertainty
- **Called by:** `/blueprint` pre-stage (suggested when problem is fuzzy)
- **Insight capture:** Clarification often surfaces architectural insights. Run `/collect-insights` after completion.
