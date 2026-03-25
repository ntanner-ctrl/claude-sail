# Debrief: research-pipeline

## Ship Reference
- Commit(s): pending (implementation complete, awaiting commit)
- Date: 2026-03-25

## Spec Delta
- Revisions: 1 (no regressions)
- 15 adversarial amendments merged into spec before WU1
- Key changes: tier 2.5 enforcement, linked_blueprint field, topic sanitization, overwrite confirmation, multi-session listing, staleness warning, WU5 collapsed into WU4
- Work graph: 9 WUs → 8 WUs (net simplification through challenge)

## Deferred Items
- **Behavioral eval fixtures (E-NEW-1 through E-NEW-4)**: Test specs written, but fixture files (fixtures/*.md) and evals.json entries need a dedicated session. Comment in test.sh documents the gap.
- **Clarify wizard progression markers**: Intentionally dropped for deprecated command. Warnings in test.sh are acceptable — a deprecated command doesn't need full wizard chrome.

## Discoveries
- **Deferred items are invisible without structured capture.** Nick noted he's unsure how often previous blueprints deferred items without this callout. The debrief stage makes deferred items a first-class artifact — previously they were silent implementation decisions.
- **Unmerged adversarial findings as a failure class.** The edge case stage found 2 of its 3 MUST FIX items were Family round findings (F2, F5) that existed in adversarial.md but were never written back into spec.md. The `required_revisions_before_wu1` manifest list is the current workaround. A structural fix might be a merge checkpoint between adversarial stages and execute.
- **Elder Council vault integration delivers calibration, not just validation.** The tier 2.5 refinement (correcting Father's "drop to Utility" using the meta-blueprint-coordination precedent) demonstrates that historical context calibrates analytical reasoning — it doesn't just confirm it.

## Reflection

### Wrong Assumptions
- No major wrong assumptions. The pre-session brief was well-prepared and the design decisions held through adversarial review. The closest: the initial spec used MUST enforcement tier, which the family debate correctly identified as contradicting the optional-enrichment philosophy.

### Difficulty Calibration
- **Easier than expected**: The family debate converged in 1 round on both Stage 3 and Stage 4 (max allowed: 2). The spec was well-formed enough that the children found refinements, not structural problems.
- **Harder than expected**: Merging 15 adversarial amendments into spec.md before WU1 was tedious but necessary. This is the "merge checkpoint" gap — the adversarial stages produce findings, but nothing enforces they're integrated before implementation begins.
- **Exactly as expected**: Blueprint.md multi-section editing required care but the work graph sequencing (WU4 → WU6) prevented conflicts.

### Advice for Next Planner
- **Keep a critical eye on workflow complexity.** The pyramid (research → blueprint → TDD → dispatch → prism) is getting taller. Each layer must be MORE navigable as the portfolio grows, not just more capable. The lightweight path surfacing pattern (showing brainstorm/design-check alongside /research) is the right instinct — make the portfolio self-documenting at decision points.
- **Test the optional-enrichment pattern in real usage.** The convention is documented, the first instance is implemented, but the real validation happens when someone runs `/research` then `/blueprint` on a real task and observes whether the skip logic, soft nudge, and coverage display work as intended.
- **Behavioral eval fixtures are load-bearing deferred work.** The test specs exist but the infrastructure to run them doesn't. This should be a near-term session, not a someday item.
