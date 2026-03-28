# Challenge Analysis: critique-architecture

## Family Mode Challenge — 2 Rounds (CONVERGED at 0.91)

### Summary

Architecture (Orient→Diverge→Clash→Refine→Converge) is structurally sound. No architectural redesign needed. Nine targeted spec changes identified in Round 1, four refined in Round 2. All changes are additive or clarifying.

---

## Findings

### Critical

*None identified.*

### High

| ID | Finding | Confidence | Direction |
|----|---------|-----------|-----------|
| F1 | **Distributional conformity unaddressed** — Anonymization addresses social conformity but same-model agents share distributional priors. Clash may produce superficial elaboration, not genuine cross-examination. | 0.85 | Three-point layered intervention: (a) pre-Diverge independence calibration targeting prompt-similarity risk, (b) pre-Clash convergence flag when all lenses produce same severity tier, (c) post-Clash Judge coverage check for unprobed sections. |
| F2 | **Compound-failure detection has no structural home** — Family mode's signature capability ("compound failures where two individually-safe things interact dangerously"). Converge mentions it but Diverge lenses don't surface raw material. | 0.82 | Add "Interaction Scan" micro-step post-Diverge, pre-Clash. Prompt instruction in Judge context (not sub-agent). Read-only scan of findings matrix → flag interaction failures → passed to Clash as additional input. |
| F3 | **Refine gate misses highest-stakes disagreements** — 0.4-0.6 confidence range captures uncertainty but skips high-confidence contested findings (both sides ≥0.6, opposing). | 0.78 | Two Refine branches: (a) uncertainty path for resolution, (b) contested path for articulation (document tension, don't force conclusion). Add conflict classification taxonomy: severity/existence/direction types. Type (b)+(c) get escalation priority. |

### Medium

| ID | Finding | Confidence | Direction |
|----|---------|-----------|-----------|
| F4 | **Orient sourcing bias** — Word cap addresses quantity, not quality. Generated context risks confirmation bias without sourcing constraint. | 0.72 | Structural prompt at Light/Standard ("state one known risk, one success"). User-approved inputs at Full tier. Risk must be categorized (operational/technical/integration/domain) to force specificity. |
| F5 | **Auto-select uses scope proxy, not risk proxy** — WU count misclassifies high-risk small changes (1-WU auth change warrants Full). | 0.70 | Risk-pattern list (auth, security, data migration, external API, schema change). Tier = max(scope_tier, risk_tier). Ship with defaults + override via project config. |
| F6 | **Migration detection absent** — Legacy plans with challenge_mode: "family" silently migrate without notice. Trust violation. | 0.75 | One-line notice on plan load: "This plan uses [family/default] challenge mode. Continuing with critique mode." No block, no auto-convert. |
| F7 | **Converge may dissolve tensions for narrative coherence** — Opus synthesis model produces confident-sounding output that papers over genuine uncertainty. | 0.68 | Explicit Converge instruction: unresolved tensions surfaced as named items, not dissolved. Disposition requirement (accept/mitigate/watch/escalate) + trigger conditions per finding. Two-part overlap test for deduplication. |
| F8 | **debate-log.md lacks parseable schema** — Raw transcript is narrative blob, not downstream-parseable. | 0.65 | Per-entry structure: lens label + round + position summary + confidence + outcome. Enough for downstream filtering without full parsing. |

### Low

| ID | Finding | Confidence | Direction |
|----|---------|-----------|-----------|
| F9 | **"Orthogonal" lens framing oversells geometry** — Correctness/Completeness/Coherence are partially correlated probes, not independent axes. | 0.80 | Labeling fix: replace "orthogonal" with "partially correlated probes designed to maximize surface coverage." No architecture change. |
| F10 | **Orient word cap not tier-scaled** — 500 words may truncate non-trivially at Full tier. | 0.55 | Tier-scaled caps (300/500/800). Full tier requires structured output schema (problem statement / prior art / known risks). |

---

## Spec Changes Summary

### From Round 1 (9 changes):

| # | Change | Type | Priority |
|---|--------|------|----------|
| 1 | Three-point anti-sycophancy intervention (pre-Diverge calibration, pre-Clash flag, post-Clash coverage check) | Structural addition | High |
| 2 | Interaction Scan micro-step post-Diverge, pre-Clash | Structural addition | High |
| 3 | Two-branch Refine gate (uncertainty + contested) | Mechanism fix | High |
| 4 | Orient sourcing constraint + risk categorization | Prompt enhancement | Medium |
| 5 | Risk-pattern list for tier auto-select | Mechanism addition | Medium |
| 6 | Legacy migration notice on plan load | UX fix | Medium |
| 7 | Converge tension-surfacing instruction + disposition requirement | Prompt enhancement | Medium |
| 8 | debate-log.md per-entry schema | Format addition | Low |
| 9 | "Orthogonal" → "partially correlated probes" | Labeling fix | Low |

### From Round 2 (4 refinements):

| # | Refinement | Resolution |
|---|-----------|------------|
| R1 | Conflict Classification taxonomy in Judge instructions | Three types (severity/existence/direction). Judge owns classification. Not a gate. |
| R2 | Interaction Scan executor and scope | Prompt instruction in Judge context. Read-only, flag-only, no synthesis. |
| R3 | Disposition overlap test | Same disposition AND same primary subject → merge. When in doubt, keep separate. |
| R4 | Anti-sycophancy rationale correction | Addresses prompt-similarity risk, not cross-contamination. Lenses are genuinely parallel. |

### Human Decisions Required (tuning, not design):

1. **Standard tier soft cap number** — Elder recommends 15, instrument, adjust after 3 runs
2. **Tier selection mechanism** — Elder recommends system-driven with human override

---

## Verdict: READY (with spec updates)

**Rationale:** Architecture is sound. No critical findings. Nine targeted additive changes, four refined to precision. All changes are prompt enhancements, format additions, or mechanism fixes — no architectural redesign required. Two tuning parameters deferred to human decision.

**Regression target:** None. Proceed to Stage 4 (Edge Cases).

---

## Process Notes

- Challenge mode: Family (2 rounds, complexity-adaptive max was 3)
- Round 1: Full family cycle (Children → Mother → Father → Elder). Elder issued CONTINUE on 4 specifics.
- Round 2: Focused cycle on carry-forward items. Elder issued CONVERGED at 0.91.
- Key dialectic: Defender's "Judge-led synthesis over mechanical gates" + Challenger's "pipeline placement matters" converged as complementary, not competing.
- Self-correction: Family corrected its own sycophancy rationale mid-debate (prompt homogeneity vs cross-contamination).

---

# Edge Case Analysis: critique-architecture

## Family Mode Edge Cases — 1 Round (CONVERGED at 0.92)

### Summary

7 boundary findings, all mechanical completions of a sound architecture. No phase restructuring needed. 6 targeted spec changes + 3 interaction clusters identified.

---

## Edge Case Findings

### High Severity

| ID | Edge Case | Failure Type | Direction |
|----|-----------|-------------|-----------|
| E1 | Zero intersecting findings → Clash hallucination | Silent | Add null-intersection skip condition to Clash (distinct from AC-14 zero-findings skip). Absence-as-signal note in adversarial.md. |
| E3 | Anonymization strips finding IDs → dedup conflates distinct issues | Silent | Anonymization strips agent identity but preserves finding identity. ID mapping table (anonymized→original) written to state.json before Clash dispatch. |
| E5 | Interaction Scan "read-only" + downstream dependency = incoherent handoff | Silent | Compound context persisted via ID mapping in state.json. Survives compaction/restart. |
| E6 | **Dedup destroys compound signal** — 3/3 agreement collapsed to 1 finding before compound detection | Silent | source_findings must keep ALL source IDs when deduplicating. Count = agreement signal for compound severity escalation. |

### Medium Severity

| ID | Edge Case | Failure Type | Direction |
|----|-----------|-------------|-----------|
| E2 | Stale WU count from interrupted Stage 2 → wrong tier | Silent | Tier stored in critique_progress.tier on first computation. Not recomputed on resume. |
| E4 | Race: Refine eligibility evaluated before all Clash outputs | Silent | Explicit barrier: "After ALL Clash agents have written to debate-log.md." |
| E7 | Converge prompt references Clash on Light tier where Clash didn't run | Silent | Tier-conditional Converge prompt. Omit Clash provenance on Light tier. |

### Interaction Clusters

| Cluster | Fixes | Why |
|---------|-------|-----|
| A: Identity chain | E3 + E6 | Anonymization creates ID mapping; dedup consumes it. Must co-implement. |
| B: Compaction resilience | E2 + E5 | Both "compute once, persist, respect" pattern. Independent but both needed. |
| C: Phase gate timing | E4 + Cluster A | Safe because E3 mapping written pre-Clash, E4 barrier fires post-Clash. |

### Novel Interaction (E1 × E3)

ID mapping needs three-state enum:
1. **Engaged** — lens participated in Clash
2. **Skipped (zero findings)** — lens produced nothing in Diverge
3. **Skipped (null intersection)** — lens had findings but no overlap with other lenses

State 3 is informationally distinct: lens found issues in sections no other lens examined (coverage signal).

---

## Human Decisions Deferred

| Decision | Recommendation |
|----------|---------------|
| T1: ID mapping location | state.json (more robust for compaction) |
| T2: Light tier Diverge reinforcement math | Tuning parameter — defer to post-launch |
| T3: adversarial.md finding count cap | Already resolved: disposition requirement, not cap |

---

## Process Notes

- Edge cases: Family mode, 1 round (consistent with historical pattern: Stage 4 always converges in 1 round)
- All 7 findings are mechanical completions, not architectural debates
- Father identified 3 interaction clusters + 1 novel interaction neither child found
- Elder confirmed all 6 fixes against historical vault findings

---

# Pre-Mortem Findings [pre-mortem]

## NEW Operational Failures (not caught by Stages 3-4)

| ID | Finding | Severity | Category |
|----|---------|----------|----------|
| PM-1 | **Context window exhaustion in Clash phase** — accumulated context (command + Orient + Diverge positions) exceeds usable budget before first Clash completes. Silent degradation, not error. | Critical | Token budget |
| PM-2 | **Turn-level checkpointing missing** — state.json only updates at phase completion, not per-agent turn. Compaction mid-Clash loses granular progress. | High | Resume/recovery |
| PM-3 | **Tier auto-select distributional collapse** — heuristic assigns Standard ~80% of time. Light never exercised. | High | Configuration |
| PM-4 | **adversarial.md cognitive overload** — 800-1200 lines for Standard. Verdicts buried at end. | High | UX |
| PM-5 | **No critique-mode behavioral evals** — test.sh Category 8 has zero coverage of new mode. | High | Testing |
| PM-6 | **O(N²) context growth in Clash** — N positions × N cross-examinations not modeled during design. | Medium | Token budget |
| PM-7 | **Light tier untested in production** — known silent regressions, zero validation. | Medium | Testing |
| PM-8 | **Refine F3 fix path untested** — high-confidence-contested branch never exercised in any fixture. | Medium | Testing |

## Recommendations

| ID | Action | Priority |
|----|--------|----------|
| R1 | Context budget check at Clash entry (abort/compress if >60% window) | Immediate |
| R2 | Turn-level checkpointing per Clash agent | Immediate |
| R3 | adversarial.md verdict summary table at top | Immediate |
| R4 | Critique-mode behavioral evals before deployment | Immediate |
| R5 | install.sh active-plan warning (extends F6) | Immediate |
| R6 | Tier selection logging + distribution review | Near-term |
| R7 | Light tier explicit-only until 3 real validations | Near-term |
| R8 | Converge reasoning_chain observability | Near-term |

## Pre-Mortem Overlap: 11% (LOW — orthogonal failure class confirmed)
