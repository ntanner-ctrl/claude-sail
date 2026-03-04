---
description: REQUIRED before implementing ANY feature with user input, boundaries, or state transitions. Edge cases cause the bugs users find first.
arguments:
  - name: plan
    description: Plan name or path to probe (optional, uses current context)
    required: false
---

# Edge Cases

Systematically probe boundaries and edge conditions. While `/devils-advocate` challenges assumptions, this command maps the specific boundaries where things break.

## Role

Explore four boundary categories:
1. **Input Boundaries** — Empty, single, limit, over-limit, malformed
2. **State Boundaries** — Transitions, repeats, reverses, cold starts
3. **Concurrency Boundaries** — Simultaneous, interrupted, stale
4. **Time Boundaries** — Zones, leaps, skew

## Process

### Step 1: Identify the Plan

If a plan name/path is provided, load it. Otherwise, ask:

> **What plan or component should I probe for edge cases?**

### Step 2: Identify Inputs and State

List all inputs and state transitions:

> **Inputs identified:**
> - [input 1]: [type, expected range]
> - [input 2]: [type, expected range]
>
> **State transitions:**
> - [state A] → [state B]
> - [state B] → [state C]

### Step 3: Probe Each Category

#### Input Boundaries

For each input, test these conditions:

| Input | Empty | Single | Boundary | Over-limit | Malformed |
|-------|-------|--------|----------|------------|-----------|
| [input] | [handled?] | [handled?] | [handled?] | [handled?] | [handled?] |

**Specific probes:**
- **Empty:** null, undefined, empty string, empty array, 0
- **Single:** exactly 1 item (often forgotten edge case)
- **Boundary:** max int, max length, exactly at limit
- **Over-limit:** max + 1, overflow scenarios
- **Malformed:** wrong type, invalid encoding, injection attempts

#### State Boundaries

| State Transition | Valid? | Handled? |
|------------------|--------|----------|
| A → B (expected) | Yes | [how?] |
| A → A (repeat/idempotent) | [valid?] | [handled?] |
| B → A (reverse) | [valid?] | [handled?] |
| ∅ → A (cold start) | Yes | [handled?] |
| A → ∅ (reset) | [valid?] | [handled?] |

#### Concurrency Boundaries

- **Simultaneous:** Two operations on same resource at same time?
- **Interrupted:** Operation interrupted midway (crash, timeout)?
- **Stale read:** Read after concurrent write?
- **Lock contention:** Multiple actors waiting for same resource?
- **Race condition:** Order-dependent outcomes?

| Scenario | Handled? | Mechanism |
|----------|----------|-----------|
| [concurrent scenario] | [yes/no] | [lock/queue/idempotent/etc] |

#### Time Boundaries

- **Timezone:** User in different zone than server?
- **DST transition:** Operation spans DST change?
- **Leap year/second:** Date math across Feb 29 or leap second?
- **Clock skew:** Different systems have different times?
- **Midnight/boundaries:** Operation at day/month/year boundary?
- **Timeout:** Operation takes longer than expected?

| Scenario | Handled? | Notes |
|----------|----------|-------|
| [time scenario] | [yes/no] | [how/why not] |

### Step 4: Compile Unhandled Cases

> **Unhandled edge cases:**
>
> | Edge Case | Risk Level | Recommendation |
> |-----------|------------|----------------|
> | [case] | High/Med/Low | [action] |

### Step 5: Risk Assessment

For each unhandled case, assess:
- **Likelihood:** How often will this actually happen?
- **Impact:** What breaks if it does?
- **Detection:** Will we know it happened?
- **Recovery:** Can we fix it after the fact?

## Output Format

```markdown
# Edge Case Analysis: [plan name]

## Inputs Analyzed

| Input | Type | Expected Range |
|-------|------|----------------|
| ... | ... | ... |

## Input Boundary Probes

| Input | Empty | Single | Boundary | Over-limit | Malformed |
|-------|-------|--------|----------|------------|-----------|
| ... | ... | ... | ... | ... | ... |

## State Transitions

| Transition | Valid? | Handled? | Mechanism |
|------------|--------|----------|-----------|
| ... | ... | ... | ... |

## Concurrency Scenarios

| Scenario | Handled? | Mechanism |
|----------|----------|-----------|
| ... | ... | ... |

## Time Boundaries

| Scenario | Handled? | Notes |
|----------|----------|-------|
| ... | ... | ... |

## Unhandled Edge Cases

| # | Edge Case | Likelihood | Impact | Risk | Recommendation |
|---|-----------|------------|--------|------|----------------|
| 1 | ... | High/Med/Low | ... | H/M/L | ... |

## Verdict

- [ ] **Well-bounded** — Edge cases adequately handled
- [ ] **Gaps exist** — [N] edge cases need addressing
- [ ] **Fundamental issues** — Core design doesn't handle boundaries

---
Edge case analysis complete. Next:
  • Address gaps → update spec or implementation
  • More challenge types → /devils-advocate, /overcomplicated
  • External review → /gpt-review (includes these findings)
  • Proceed → /preflight
```

## Integration with /gpt-review

When `/gpt-review` is called after this review:

```markdown
## Local Adversarial Findings (Edge Cases)

Edge cases examined:

[findings table]

Please identify edge cases outside our normal thinking patterns—
the ones we didn't think to probe.
```

## Common Forgotten Edge Cases

Keep these in mind—they're frequently missed:

1. **The empty case** — Zero items is valid input
2. **The single case** — Exactly one item often has special behavior
3. **Unicode** — Names, paths, and data with non-ASCII characters
4. **Very long strings** — Buffer limits, display truncation
5. **Negative numbers** — When only positive expected
6. **Timezone hell** — Especially around DST transitions
7. **Concurrent first access** — Two users hitting uninitialized state
8. **Partial failure** — 3 of 5 operations succeed, then crash

## Output Artifacts

If tracking:
- Append to `.claude/plans/[name]/adversarial.md`
- Update state
