# Adversarial Findings: research-pipeline

## Family Round 1

### Synthesis (Mother)

Core architecture is sound. The coverage manifest as machine-readable routing and the optional-enrichment pattern as named convention are the spec's strongest contributions.

Two issues require spec revision before implementation:
1. MUST/optional contradiction on enforcement tier
2. Name-linkage fragility undermining coverage manifest determinism

### Analysis (Father)

**8 proposed changes — 4 required, 4 acceptable risk:**

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| F1 | Enforcement tier: MUST language contradicts optional-enrichment philosophy | critical | needs-spec-update |
| F2 | Name mismatch: research topic ≠ blueprint name breaks linkage silently | critical | needs-spec-update |
| F3 | Progressive vault capture: no significance filter creates noise over time | medium | acceptable risk — tier findings (working vs durable) |
| F4 | WU5 is documentation overhead: solution-clarity rubric is unchanged from today | medium | needs-spec-update — collapse into WU4 |
| F5 | Deep-mode staleness: no resume threshold for multi-session research | medium | acceptable risk — add 48h warning |
| F6 | No lightweight pre-planning replacement after /clarify deprecation | high | needs-spec-update — surface brainstorm/design-check explicitly |
| F7 | Coverage booleans lack quality signal (ran ≠ thorough) | medium | acceptable risk — gate_score + mode carry quality |
| F8 | /clarify redirect lacks decision criterion for choosing replacement | medium | needs-spec-update — add 3-case table |

**Additional observations:**
- Remove `design_check: false` from coverage block (dead field)
- Add mode selection decision criterion
- Acknowledge vault-absent two-tier experience in docs

### Historical Review (Elder Council)

| Vault Source | Lesson | Relevance |
|---|---|---|
| enforcement-tier-honesty.md | MUST in markdown erodes credibility without hook backing | supports F1 |
| meta-blueprint-coordination blueprint | Tier 2.5 (behavioral + schema) is the established precedent | refines F1: tier 2.5, not Utility |
| workflow-orphan-analysis.md | /clarify solved orphan problem; removal must preserve lightweight path | supports F6 |
| source-of-truth-drift pattern | Dual naming = future drift bug | supports F2 |
| spec-deployment-gap.md | Spec can describe artifacts test.sh never verifies | warns: WU9 must verify paths |
| premortem-catches-process-failures.md | Pre-mortem catches orthogonal failures to design review | warns: pre-mortem is high value here |

**Elder Verdict:** CONVERGED
**Confidence:** 0.78
**Carry Forward:** Tier 2.5 refinement for F1. Pre-mortem should be prioritized.

---

## Required Spec Revisions (Pre-Implementation)

1. **F1 — Enforcement tier**: Change from Process-Critical (MUST) to tier 2.5. Description becomes: `Use when investigating a problem space before planning. Unvalidated assumptions entering a blueprint cause expensive mid-implementation discoveries.` Body uses behavioral guidance + `skippable: false` schema signal, no MUST quantifier.

2. **F2 — Linkage mechanism**: Add `linked_blueprint` field to research brief YAML frontmatter. Populated during research (from argument or prompt). Blueprint reads this field for detection, not path inference. Mismatch produces visible prompt, not silent failure.

3. **F4 — WU5 collapse**: Merge WU5 into WU4. Parameterized gate concept documented in `docs/OPTIONAL-ENRICHMENT.md` or new `docs/GATE-RUBRICS.md`. No standalone WU.

4. **F6 — Lightweight path**: Blueprint pre-stage (no research brief) explicitly surfaces: "Complex problem? → /research" and "Quick question? → /brainstorm or /design-check". Clarify redirect includes same 3-case decision table.

5. **F8 — Redirect criterion**: Clarify deprecation message includes: problem unclear → /research, solution unclear → /design-check, quick low-stakes → /brainstorm.

6. **Dead field removal**: Remove `design_check: false` from coverage block schema.

7. **Gate score display**: Blueprint enrichment displays `gate_score` and `mode` alongside coverage when research brief detected.

---

## Edge Cases — Family Round 1

### New Findings (not covered by Stage 3)

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| E1 | Topic sanitization: special chars (/, &, :) in topic break vault paths and YAML frontmatter | critical | needs-spec-update |
| E2 | research.md overwrite: re-running research silently destroys prior brief | critical | needs-spec-update |
| E3 | Multiple active research sessions: resume prompt doesn't list all, may select wrong one | high | needs-spec-update |
| E4 | Vault write failure in progressive capture: findings_count increments on attempt not success | medium | needs-spec-update |
| E5 | Mid-blueprint research: blueprint doesn't re-read brief on resume | medium | needs-spec-update |

### Unmerged Family Findings (confirmed by Edge Cases)

| ID | Original | Status |
|----|----------|--------|
| F2 | linked_blueprint field in brief frontmatter | Still not in spec body §2.2 |
| F5 | 48h staleness warning for deep-mode resume | Still not in spec body §1.6 |

### Required Spec Amendments (Edge Cases)

1. **§1.7 Storage**: Add topic sanitization rule — `[a-z0-9-_]` for paths, original preserved in YAML as quoted string
2. **§1.7 Storage / §3 Synthesize**: Add conflict-check before writing research.md — prompt if exists
3. **§2.2 Brief Format**: Add `linked_blueprint` field (F2 merge) + note sanitized slug vs display topic
4. **§1.6 State Management**: Multi-session listing (show all active by topic), staleness warning (48h threshold), `linked_blueprint` standalone case (`null` or `"standalone"`)
5. **§1.5 Stage 2**: findings_count increments only on confirmed vault write
6. **§5.2 Describe**: Blueprint re-reads brief at each stage start, not just first invocation

### Historical Validation (Elder Council)

Vault precedents confirm all MUST FIX items:
- notion-html-publisher E1+E7: slug sanitization + silent overwrite are a paired failure class
- vault-data-pipeline F2: overwrite without confirmation destroys user state (flagged critical before)
- wizard-state-management: positive state assertion for resume is the established pattern

### Complexity Review

Edge case amendments are additive (behavioral sentences, not structural redesign). No regression to Stage 2. Work graph unchanged except WU5 already collapsed into WU4.

**Post-edge-case confidence: 0.86**

---

## Pre-Mortem (Stage 4.5)

Focus: operational failures (deployment, monitoring, rollback).

| ID | Finding | Status | Severity |
|----|---------|--------|----------|
| PM-1 | WU9 should include behavioral evals (not just counts) | NEW | medium |
| PM-2 | Blueprint.md multi-section edit risk | COVERED (work graph) | low |
| PM-3 | Clarify wizard state in target projects | COVERED (§6.3) | low |
| PM-4 | Vault Research/ directory creation before first write | NEW | medium |

No critical operational failures identified. Two medium additions:
1. Behavioral eval fixtures for WU9
2. Directory creation before vault write in §1.7
