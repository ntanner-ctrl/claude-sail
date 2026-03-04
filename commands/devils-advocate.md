---
description: REQUIRED after completing ANY spec or plan. You MUST challenge assumptions — unchallenged plans fail in production.
arguments:
  - name: plan
    description: Plan name or path to challenge (optional, uses current context)
    required: false
---

# Devil's Advocate

Challenge every assumption in a plan. Find the "what ifs" that weren't considered. This is the first line of adversarial review—fast, local, and focused on assumptions.

## Role

Systematically challenge assumptions across four categories:
1. **Availability** — What if things aren't there?
2. **Scale** — What if there's way more or less?
3. **Timing** — What if timing is weird?
4. **Trust** — What if inputs can't be trusted?

## Process

### Step 1: Identify the Plan

If a plan name/path is provided, load it. Otherwise, ask:

> **What plan or approach should I challenge?**
>
> You can:
> - Provide a plan name (loads from `.claude/plans/[name]/`)
> - Paste the plan directly
> - Describe the approach you're considering

### Step 2: Extract Assumptions

List every implicit and explicit assumption in the plan:

> **Assumptions I've identified:**
>
> 1. [assumption]
> 2. [assumption]
> 3. [assumption]
> ...

### Step 3: Challenge Each Category

#### Availability Challenges

For each resource, service, or dependency:

- What if **[service/resource]** is unavailable?
- What if **[dependency]** has changed since we last checked?
- What if **[external system]** is slow or degraded?
- What if **[file/data]** doesn't exist or is corrupted?

#### Scale Challenges

- What if there are **0 items**? (empty case)
- What if there are **1 item**? (singleton edge case)
- What if there are **1M items**? (scale case)
- What if items arrive **faster than processing**? (backpressure)
- What if the data is **10x larger** than expected?

#### Timing Challenges

- What if this runs **during a deployment**?
- What if **two instances run simultaneously**? (race condition)
- What if this runs **after midnight**? (day boundary)
- What if this runs **during DST transition**?
- What if this runs **at year-end**?
- What if there's **clock skew** between systems?

#### Trust Challenges

- What if the input is **malformed**?
- What if the input is **malicious**? (injection, overflow)
- What if the input is **valid but unexpected**?
- What if the input **encoding is wrong**?
- What if **authentication is spoofed**?

### Step 4: Compile Findings

For each challenge, determine if the plan addresses it:

| Challenge | Plan's Answer | Gap? |
|-----------|---------------|------|
| [specific challenge] | [how plan handles it, or "Not addressed"] | Y/N |

### Step 5: Summarize Gaps

> **Unaddressed challenges (gaps):**
>
> 1. [challenge] — Impact: [severity], Recommendation: [action]
> 2. [challenge] — Impact: [severity], Recommendation: [action]

## Output Format

```markdown
# Devil's Advocate Review: [plan name]

## Assumptions Identified

1. [assumption]
2. [assumption]
3. ...

## Challenge Results

### Availability Challenges
| Challenge | Plan's Answer | Gap? |
|-----------|---------------|------|
| ... | ... | ... |

### Scale Challenges
| Challenge | Plan's Answer | Gap? |
|-----------|---------------|------|
| ... | ... | ... |

### Timing Challenges
| Challenge | Plan's Answer | Gap? |
|-----------|---------------|------|
| ... | ... | ... |

### Trust Challenges
| Challenge | Plan's Answer | Gap? |
|-----------|---------------|------|
| ... | ... | ... |

## Gap Summary

| # | Challenge | Impact | Recommendation |
|---|-----------|--------|----------------|
| 1 | ... | High/Med/Low | ... |

## Verdict

- [ ] **Ready** — No critical gaps
- [ ] **Address gaps** — [N] issues need resolution before proceeding
- [ ] **Rethink approach** — Fundamental assumptions are shaky

---
Adversarial review complete. Next:
  • Address findings → update spec with /spec-change
  • More challenge types → /overcomplicated, /edge-cases
  • External review → /gpt-review (includes these findings)
  • Satisfied → /preflight then implement
```

## Insight Capture

Every successful challenge that changes the approach is a high-value finding. After the challenge session completes, run `/collect-insights` to flush discoveries to vault + Empirica — assumption violations and edge cases caught here prevent costly rework.

## Integration with /gpt-review

When `/gpt-review` is called after this review, include findings:

```markdown
## Local Adversarial Findings (Devil's Advocate)

The following challenges were raised locally:

[findings table]

Please identify blind spots that this local review missed—
assumptions we didn't think to challenge.
```

## Output Artifacts

If tracking:
- Append to `.claude/plans/[name]/adversarial.md`
- Update state to reflect challenge stage complete
