# Pre-Mortem: critique-architecture

## Premise

Critique mode was implemented and deployed two weeks ago. It failed. P1 severity — feature effectively unusable for majority of users after day 3.

## Primary Failure: Context Window Exhaustion in Clash Phase

**Classification: NEW**

blueprint.md is ~1600 lines. By the time Clash begins, context contains: full command file + Orient output + all Diverge positions + state.json + conversation history. For any project with >4 WUs, this routinely exceeds usable context before the first Clash cross-examination completes.

**Why silent:** Claude degrades, doesn't error. Clash agents drop earlier threads from working context, producing locally coherent but globally disconnected responses. debate-log.md looks populated. Verdicts are issued. Users have no signal.

**Severity amplifier:** Distributional conformity (F1) + context loss = doubly masked failure. Output looks like polite disagreement rather than truncated incoherence.

## Contributing Factors

### CF-1: Turn-Level Checkpointing Missing (NEW)

state.json phase marker only updates at phase completion, not at each agent turn. Session compaction mid-Clash loses granular progress. Resume either restarts Clash entirely (wasting tokens, different results) or tries to continue from debate-log.md (adding more context pressure).

**What was covered:** E5 caught stage-level handoff persistence. This is intra-stage turn-level — a different granularity.

### CF-2: Tier Auto-Select Distributional Collapse (NEW)

Heuristic assigns Standard to ~80% of projects. Light never exercised in production. When users try Light explicitly, they find it silently skips cross-examination — a regression never caught because Light had zero traffic.

**What was covered:** F5 caught scope vs risk proxy problem. This is about the output distribution — the heuristic doesn't differentiate.

### CF-3: adversarial.md Cognitive Overload (NEW)

Standard-tier critique on a 5-WU feature produces 800-1200 lines of markdown. Users open, scroll, close. Actionable signal buried. Document leads with methodology, puts verdicts at the end.

**What was covered:** F7 caught Converge tension dissolution. This is upstream — even sound verdicts can't be found.

### CF-4: Install Path Migration UX (PARTIALLY COVERED by F6)

install.sh overwrites blueprint.md silently. Users with in-flight blueprints get critique-mode logic running against family-mode state files. Confused partial-mode execution writes mixed artifacts.

**F6 covered:** Detection absence. This is the UX consequence at deploy time.

## Early Warning Signs Missed

1. **No production-scale token accounting** — No one ran a token count on realistic Orient+Diverge+Clash. Back-of-envelope would have shown Clash context pressure was inevitable.
2. **O(N²) context growth in Clash** — N Diverge positions × N cross-examinations. Not modeled.
3. **test.sh had no critique-mode fixture** — Zero behavioral coverage. Deferred-testing trap.
4. **Refine fix (F3) created an untested conditional path** — High-confidence-contested branch existed on paper only.

## Recommendations

### Immediate (before deployment)

| ID | Recommendation | Classification |
|----|---------------|---------------|
| R1 | Context budget check at Clash entry — estimate accumulated tokens, abort or compress if >60% window | NEW |
| R2 | Turn-level checkpointing in state.json — each Clash agent writes completion before next begins | NEW |
| R3 | adversarial.md leads with verdict summary table — users who read first page know what changed | NEW |
| R4 | Critique-mode behavioral evals in test.sh — Standard contested, Light cross-exam, resume mid-Clash | NEW |
| R5 | install.sh warns on active in-progress plans | EXTENDS F6 |

### Near-term

| ID | Recommendation | Classification |
|----|---------------|---------------|
| R6 | Tier auto-select validation — log selections, review distribution after 20 runs | NEW |
| R7 | Light tier gated as explicit-only until manually validated (3 real runs) | NEW |
| R8 | Converge observability — mandatory reasoning_chain field showing which Clash exchanges drove verdict | NEW |

## Structural Finding

The spec had adversarial rigor at the **design** level but not the **operational** level. Design review asked "is the architecture sound?" The operational question: "what does this look like under realistic load, partial failure, and user behavior?"

**Single most important change:** Require at least one end-to-end manual run on a real project before merging, with run artifacts committed to the repo.

## Overlap Check

| Finding | Covered by Stage 3-4? | Status |
|---------|----------------------|--------|
| Context exhaustion in Clash | No | NEW |
| Turn-level checkpointing | E5 caught stage-level only | NEW |
| Tier distributional collapse | F5 caught proxy type only | NEW |
| adversarial.md readability | F7 caught dissolution only | NEW |
| Install migration UX | F6 caught detection | EXTENDS |
| No token accounting | No | NEW |
| No critique-mode evals | No | NEW |
| Light tier untested | No | NEW |
| Refine fix untested | No | NEW |

**Overlap ratio:** 1 EXTENDS / 9 total = 11% overlap (LOW). Pre-mortem found a nearly orthogonal failure class, consistent with Adversarial Review Taxonomy pattern.
