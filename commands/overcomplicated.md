---
description: REQUIRED after ANY architecture decision or design. You MUST check for over-engineering — complexity is the enemy of reliability.
arguments:
  - name: plan
    description: Plan name or path to simplify (optional, uses current context)
    required: false
---

# Overcomplicated

Challenge unnecessary complexity. Ask if there's a simpler path. The goal isn't minimalism for its own sake—it's ensuring every piece of complexity earns its place.

## Role

Systematically question complexity across three dimensions:
1. **Abstraction** — Do we need this layer?
2. **Build vs. Use** — Should we build or borrow?
3. **Necessity** — What's the MVP?

## Process

### Step 1: Identify the Plan

If a plan name/path is provided, load it. Otherwise, ask:

> **What plan or implementation should I review for complexity?**

### Step 2: List Complex Elements

Identify every abstraction, component, or non-trivial element:

> **Complex elements identified:**
>
> 1. [element] — [brief description]
> 2. [element] — [brief description]
> ...

### Step 3: Challenge Each Category

#### Abstraction Check

For each abstraction or layer:

- Do we need **[abstraction]**, or are we building for hypothetical future needs?
- What's the **simplest version** that solves the actual current problem?
- If we **removed [component]**, what breaks? If nothing, why is it there?
- Are we adding **indirection** without clear benefit?
- Is this **premature optimization**?

#### Build vs. Existing

- Does **[thing we're building]** already exist as a library/tool/service?
- What are we building that we could **buy/use instead**?
- Is our custom solution **better enough** to justify maintenance cost?
- Are we **reinventing** something well-solved?
- What's the **total cost of ownership** for building vs. using?

#### Necessity Check

- What's the **minimum viable version**?
- Which features could be **phase 2**?
- What would we **cut if we had half the time**?
- What's **gold-plating** vs. essential?
- Are we solving **problems we don't have yet**?

### Step 4: Compile Findings

For each complex element:

| Element | Justification | Simpler Alternative? | Verdict |
|---------|---------------|---------------------|---------|
| [element] | [why it's there] | [simpler option or "None obvious"] | Keep/Simplify/Remove |

### Step 5: Propose Simplifications

For elements marked "Simplify" or "Remove":

> **Proposed simplifications:**
>
> 1. **[element]** → [simpler alternative]
>    - Saves: [what we avoid]
>    - Loses: [what we give up]
>    - Verdict: [worth it / not worth it]

## Output Format

```markdown
# Overcomplicated Review: [plan name]

## Complex Elements Identified

1. [element] — [description]
2. [element] — [description]
...

## Complexity Analysis

| Element | Justification | Simpler Alternative? | Verdict |
|---------|---------------|---------------------|---------|
| ... | ... | ... | ... |

## Proposed Simplifications

### 1. [element] → [simpler version]
- **Saves:** [complexity avoided]
- **Loses:** [capability given up]
- **Recommendation:** [do it / skip it]

### 2. ...

## Minimum Viable Version

If we had to ship in half the time, we'd keep:
- [essential 1]
- [essential 2]

And defer:
- [nice-to-have 1]
- [nice-to-have 2]

## Build vs. Use Opportunities

| We're Building | Existing Alternative | Recommendation |
|----------------|---------------------|----------------|
| ... | ... | Use existing / Build custom |

## Verdict

- [ ] **Right-sized** — Complexity is justified
- [ ] **Over-engineered** — [N] elements can be simplified
- [ ] **Under-scoped** — Actually needs more (rare but possible)

---
Complexity review complete. Next:
  • Apply simplifications → update plan
  • More challenge types → /devils-advocate, /edge-cases
  • External review → /gpt-review
  • Proceed → /preflight
```

## Integration with /gpt-review

When `/gpt-review` is called after this review:

```markdown
## Local Adversarial Findings (Overcomplicated)

Complexity was challenged on these points:

[findings table]

Please identify complexity we've justified locally but an
outside perspective would question.
```

## The Three-Line Rule

A helpful heuristic: if three similar lines of code exist, that's fine. Don't abstract until you have a clear pattern across multiple uses. Premature abstraction is a common source of unnecessary complexity.

## Output Artifacts

If tracking:
- Append to `.claude/plans/[name]/adversarial.md`
- Update state
