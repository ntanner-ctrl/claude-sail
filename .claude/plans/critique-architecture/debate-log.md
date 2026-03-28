# Family Challenge Transcript: critique-architecture

## Round 1

### Child-Defend

**8 defended positions:**

1. **Orient Phase Front-Loads Historical Context** — Without this, every downstream agent becomes a blank-slate reasoner. The ≤500-word cap forces distillation. Placing context at START (not END) is the key insight — context after opinions form gets rationalized away.

2. **Three Orthogonal Analytical Lenses (Correctness/Completeness/Coherence)** — Lenses don't have social goals (unlike personas). Three is the minimum for genuine orthogonality without dilution. Covers: factual/logical errors, gaps/omissions, internal contradictions.

3. **Sparse Cross-Examination in Clash Phase** — Most defensible conformity mitigation because it's structural, not instructional. Anonymization removes social signals. Sparse interaction means agents respond to evidence conflicts, not authorities.

4. **Conditional Refine Gate (Full Tier, Mid-Range Confidence Only)** — 0.4-0.6 is precisely where additional deliberation has positive expected value. Below 0.4 = weak signal. Above 0.6 = firm enough. "Top 3" bound prevents full re-run. Full-tier-only is correct because only complex plans have load-bearing contested findings.

5. **Converge Phase Uses Opus** — Synthesis under genuine uncertainty is where reasoning depth difference between sonnet and opus is most material. Detecting compound failures requires holding more context simultaneously than single-lens analysis.

6. **Three-Tier Architecture** — WU count is reasonable proxy for complexity. Auto-selection removes a decision users will make badly. Light tier is correctly scoped, not degraded.

7. **Family Mode Backward Compatibility** — Migration strategy calibrated to where stakes are. In-progress plans protected, not-yet-started migrate silently, deprecation notice is minimum honest signal.

8. **Output Separation (adversarial.md + debate-log.md)** — Format parity with family mode means all downstream commands work without modification. Separation provides conformity defense: if Converge synthesis is wrong, raw log provides ground truth.

**Acknowledged weakness:** Anonymization may be fragile — agents may infer lens provenance from content semantics. Intent is still correct: partial conformity mitigation is better than none.

---

### Child-Assert

**4 challenges raised:**

1. **Anonymization is a no-op for same-model agents** (HIGH confidence)
   - Same-model, same-temperature agents trend toward agreement regardless of label-stripping
   - Failure: Clash produces superficial elaboration rather than genuine cross-examination
   - Want: Different models for different lenses, or explicitly scope-limited acknowledgment

2. **Refine gate's confidence range (0.4-0.6) creates perverse incentive** (MEDIUM confidence)
   - High-confidence contested findings (both sides ≥0.6) are highest-stakes disagreements, but skip Refine
   - Failure: Converge receives hard contradiction with no resolution attempt
   - Want: Gate condition should include high-confidence-contested, not just mid-range

3. **Orient's 500-word cap inadequate for Full-tier blueprints** (MEDIUM confidence)
   - 10-WU blueprints touching multiple systems need more context density
   - Failure: Diverge agents miss known constraints, re-litigate settled questions
   - Want: Tier-scaled context cap (300/500/800) or "context overflow" flag

4. **Schema migration path unspecified** (MEDIUM confidence)
   - No explicit version gate for family_progress → critique_progress
   - Failure: User installs update, command doesn't find critique_progress OR family_progress, re-initializes, loses progress
   - Want: Explicit challenge_mode field check — "family" → family path, absent/"critique" → critique path

---

### Mother (Strength Synthesizer)

**The Crux:** The architecture's skeleton — lenses over personas, phased deliberation, tiered depth, output separation — is sound. The load-bearing assumption that doesn't hold is that *same-model agents with different labels will produce genuine disagreement*. Fix the assumption, keep the structure.

**Synthesis map:**

| Element | Sound — Keep | Needs Work |
|---|---|---|
| Orient phase | Front-loading + word cap concept | Sourcing constraint; neutrality heuristic |
| Three lenses | Lens > persona framing | Overlap is correlated, not orthogonal — reframe honestly |
| Clash / anonymization | Addresses social conformity | Doesn't address distributional conformity — add diversity mechanism |
| Refine gate | Uncertain-verdict trigger | Add second branch for high-confidence-contested (articulation, not convergence) |
| Converge / Opus | Cost-proportionate reasoning depth | Explicit instruction to preserve unresolved tension |
| Three-tier auto-select | Removes bad user decision | WU count is scope proxy, not risk proxy — add high-risk pattern override |
| Backward compat | In-progress protection | Add migration detection log for legacy plans |
| Output separation | Format parity for downstream | Define debate-log.md minimal schema |
| Orient word cap | Cap is necessary | Tier-scale the cap (300/500/800); structure at Full tier |

**Key synthesis points:**
- Anonymization addresses *inter-agent social conformity* but not *distributional conformity*. Both exist; spec only addresses one.
- Refine gate needs TWO branches: uncertain verdicts (0.4-0.6) AND high-confidence-contested (both ≥0.6 opposing).
- Orient needs sourcing constraint — neutrality heuristic like "include at least one prior failure case."
- Three lenses aren't truly orthogonal. Honest framing: partially correlated probes, not independent axes.
- Converge prompt needs explicit instruction to preserve unresolved tension.

---

### Father (Weakness Analyst & Guide)

**Assessment: ~70% implementation readiness. Structural confidence high; mechanism confidence medium.**

**7 spec changes needed:**

| Item | Direction |
|------|-----------|
| Orient sourcing | User-approved inputs at Full tier; structural prompt ("state one known risk, one success") at Light/Standard |
| Lens framing | Remove orthogonality claim → "partially correlated probes" (labeling fix, not architecture) |
| Clash conformity | Disagreement priming at all tiers; temperature diversity as secondary lever; model diversity as future consideration |
| Refine gate | Two branches: uncertainty (resolve) vs contested (articulate). Contested path documents tension, doesn't force conclusion |
| Converge instruction | Explicit permission to surface unresolved tensions as named items, not dissolve them |
| Auto-select signal | Risk-pattern list (auth, security, data migration, external API, schema change) → tier = max(scope, risk) |
| Migration detection | Notice on legacy plan load; no block, no auto-convert |

**2 acceptable risks:**
- Three lenses partial correlation — redundant critique less harmful than gap blindness. Just fix the labeling.
- Orient word cap tier-scaling — defensible estimates, tune empirically. Full tier needs structure schema more than more words.

**Biggest unresolved risk:** Items 3 (distributional conformity) and 4 (contested Refine branch) interact. If same-model agents systematically agree on high-confidence items, the contested branch rarely triggers — not because disagreement doesn't exist, but because the model doesn't produce it. Spec needs a forcing function at Full tier: Clash must produce at least one contested item, or round flagged as suspect.

**3 unresolved tensions:**
1. **Auto-select ownership** — Who maintains the risk-pattern list? Hardcoded goes stale; user-configured gets under-populated. Governance question, not design.
2. **Refine mandatory vs conditional** — If distributional conformity suppresses disagreement, should Refine be mandatory at Full tier with mode (resolve/articulate) determined by output, not existence?
3. **Converge actionability floor** — If Converge surfaces all tensions honestly, what prevents an exhaustive tension list with no actionable synthesis? Need minimum-actionability constraint alongside tension-surfacing.

---

### Elder Council (Historical Validator)

**Verdict: CONTINUE** (confidence: 0.72)

**Historical analogies:**

| Source | Lesson | Supports/Warns |
|--------|--------|----------------|
| Research Brief — 8 family blueprints | Stage 4 converges in 1 round. Refine gate is historically justified as conditional. | supports |
| Adversarial Review Taxonomy | "Two techniques beat two rounds of same technique." Lens-based Diverge well-grounded. "Nearly orthogonal" confirms Father's relabeling. | supports |
| Taxonomy — debate convergence | Converges by Round 3. Refine must do different work than Clash+1. | supports |
| Research Brief — sycophancy dominant | Structural mitigations required. Disagreement priming is behavioral, not structural. Forcing function is right category but underspecified. | warns |
| Research Brief — pre-mortem load-bearing | Pre-mortem catches operational gaps debate misses. New architecture must preserve this capability explicitly. | warns |
| Research Brief — 8 agents/stage sweet spot | 3 lenses is fine IF each produces multiple items, not monolithic perspectives. | neutral |

**Father review summary:** 6/7 changes supported, 1 novel (auto-select risk patterns — ship with defaults + override). Item 3 (conformity) actively warned against by history.

**Continue reason:** Two critical specifics need resolution:
1. **"Contested" needs precise definition** — Proposed: two+ lenses assign opposing risk assessments (not just different severity — opposing direction). Prevents forcing function from being gamed by trivial disagreements.
2. **Pre-mortem compound-failure detection needs structural home** — Family mode's signature capability. One Diverge lens should explicitly frame as compound-interaction lens, or capability is lost.

**Additional carry-forward:**
3. Converge actionability floor: cap named tensions at 3, each with disposition (resolve-now, defer-with-monitor, accept-risk)
4. Anti-sycophancy escalation at Full tier: if Clash produces zero contested items, require conformity check — single prompt per lens asking "what is your strongest disagreement with the emerging consensus?"

---

## Round 2

*Elder carry-forward injected into children's context.*

### Child-Defend R2

**Item 1 (Contested definition):** Adopt as Judge detection heuristic, NOT gate criterion. Hard definition makes gate gameable (ritual disagreement). Concession: add heuristic to Judge's Clash instructions — "flag items where lenses disagree in direction, not just severity."

**Item 2 (Compound-failure home):** Converge stays primary — compound failures are emergent, can't be detected until full lens portfolio reports. Adding a compound-interaction Diverge lens forces premature synthesis or breaks parallel architecture. Concession: add `adjacent-risks` field to Diverge output format — items outside this lens's domain noticed in passing. Richer handoff without new lens.

**Item 3 (Actionability floor):** Cap is wrong mechanism — truncates genuine tensions arbitrarily. Concession: every tension requires explicit disposition (accept/mitigate/watch/escalate). Collapse same-disposition overlaps. No hard cap.

**Item 4 (Anti-sycophancy):** Conformity prompt demands manufactured opposition. Clash IS the adversarial phase — zero contested may mean spec is genuinely strong. Concession: coverage check at Full tier — Judge notes which spec sections received no adversarial scrutiny and why. Diagnostic, not forced disagreement.

**Theme:** Spec's design intent is Judge-led synthesis over mechanical gates. Each proposed change risks converting qualitative judgment into process theater.

---

### Child-Assert R2

**Item 1 (Contested definition):** Elder's "opposing direction" still too coarse — conflates severity disagreement with genuine contest. Define 3 incompatibility types: (a) severity disagreement on identical claim, (b) existence disagreement (present vs absent), (c) direction disagreement (change helps vs harms). Only (b) and (c) are truly contested. Type (a) is a weighting disagreement, resolved differently. **HIGH confidence.**

**Item 2 (Compound-failure home):** Elder's suggestion (compound Diverge lens) is wrong structural placement. Compound failures require synthesis across independent perspectives — impossible inside a parallel Diverge lens. Better: add compound-scan micro-step BETWEEN Diverge and Clash. Takes full findings matrix, asks "which pairs create failure modes neither creates alone?" 200-300 tokens, adds compound findings to pool before Clash. **HIGH confidence.**

**Item 3 (Actionability floor):** Agrees cap is wrong. Replace with disposition requirement (accept/mitigate/monitor/defer) + trigger condition for revisiting. Full tier gets full picture with honest uncertainty marking. Cap only as Standard-tier cost control. **MEDIUM confidence.**

**Item 4 (Anti-sycophancy):** Post-Clash conformity check fires too late and too rarely. Pre-Clash convergence is the disease, zero-contested is a symptom. Better: independence calibration BEFORE Diverge — "do not optimize for agreement; if genuinely problematic, what would top 3 issues be?" Plus structural check: if all three Diverge lenses produce same severity tier, flag as convergence indicator before Clash runs on pre-converged input. **HIGH confidence.**

**Theme:** Problems correctly identified but solutions misplaced in the pipeline. Compound detection needs inter-phase step, conformity needs pre-Diverge priming, contested needs semantic typing.

---

### Mother R2 (Synthesis)

**Convergent positions across all 4 items:**

1. **Contested definition:** Three-type taxonomy (severity/existence/direction) as Judge VOCABULARY, not gate. Type (b)+(c) get escalation priority. Unresolved: classification sits at Judge, not lens.

2. **Compound-failure home:** Compound-scan micro-step post-Diverge, pre-Clash. Reads full findings matrix, flags interaction failures, does NOT synthesize. Unresolved: who runs it.

3. **Actionability floor:** Disposition requirement + trigger conditions. Deduplication by same-disposition overlap. Standard soft cap; Full uncapped. Unresolved: overlap definition.

4. **Anti-sycophancy:** Three-point layered intervention: pre-Diverge independence calibration, pre-Clash convergence flag, post-Clash coverage check. Unresolved: conformity risk may be prompt similarity, not cross-contamination.

**Cross-cutting:** Judge-led synthesis + pipeline placement are complementary.

---

### Father R2 (Guide)

**All 4 items resolved with concrete direction:**

1. **Contested:** Add "Conflict Classification" subsection to Judge instructions. Judge owns classification (lenses can't pre-classify divergence from lenses they haven't seen). Taxonomy is descriptive, not evaluative.

2. **Compound-failure:** Add named "Interaction Scan" micro-step. Prompt instruction in Judge context (not sub-agent). Read-only scan → flag list → passed to Clash as additional input. No coordination overhead.

3. **Actionability:** Disposition requirement (accept/mitigate/watch/escalate) + trigger condition. Two-part overlap test: same disposition AND same primary subject → merge. When in doubt, keep separate with cross-reference.

4. **Anti-sycophancy:** Retain three-point structure. Correct rationale: calibration addresses prompt-similarity risk, not cross-contamination (lenses genuinely can't see each other). Make taxonomy a checklist in Judge output for auditability.

**Assessment: Spec implementable after 4 targeted additive changes. No architectural redesign.**

**One human decision needed:** Tier boundary soft cap number for Standard tier, and whether tier selection is user-driven or system-driven.

---

### Elder Council R2 (Historical Validator)

**Verdict: CONVERGED** (confidence: 0.91)

All 4 carry-forward items addressed with structural solutions. 5 historical vault findings checked — all map cleanly to resolved positions.

**Key observations:**
- Conflict taxonomy adds vocabulary without process overhead — low risk
- Interaction Scan must stay lightweight ("read-only, flag only, no synthesis") — medium-low risk
- Disposition requirement's merge tiebreaker ("when in doubt, keep separate") is conservative in the right direction — low risk
- Anti-sycophancy correction (prompt homogeneity, not cross-contamination) shows family self-corrected during debate — notable quality signal

**Human decisions deferred (tuning, not design):**
1. Standard tier soft cap — recommend 15, instrument, adjust after 3 runs
2. Tier selection — recommend system-driven with human override (factors are measurable)

---

# Stage 4: Edge Cases

## Round 1

### Child-Defend

**Position:** Spec handles boundaries through three patterns: inheritance (toolkit-level resume/JSON validation), graceful degradation (partial failures → conservative verdicts), mechanism-level specification (caps and intersection-only design). Adding explicit boundary handling for every degenerate case bloats the spec without changing behavior.

Key defenses:
- Empty/minimal specs → Light tier fires, self-scaling
- Agent failures → Clash works on what arrived, conservative verdict
- Vault/research unavailable → explicitly optional
- Empty agent output → zero findings is valid, meaningful output
- 10-finding cap + intersection-only Clash + deduplication = compression pipeline

---

### Child-Assert

**7 edge cases identified (5 HIGH, 2 MEDIUM):**

| # | Boundary | Failure | Conf |
|---|----------|---------|------|
| E1 | Zero intersecting findings → Clash agents hallucinate intersections | Silent | HIGH |
| E2 | Stale WU count from interrupted Stage 2 drives wrong tier | Silent | HIGH |
| E3 | Anonymization strips finding IDs → dedup conflates distinct issues | Silent | HIGH |
| E4 | Race: Refine eligibility evaluated before all Clash outputs committed | Silent | MEDIUM |
| E5 | Interaction Scan "read-only" contradicts "downstream agents consume output" | Silent | HIGH |
| E6 | **Dedup destroys compound signal before compound detection runs** | Silent | HIGH |
| E7 | Converge prompt references Clash on tiers where Clash didn't run | Silent | MEDIUM |

**Most dangerous:** E6 — unanimous multi-agent agreement (3/3 convergence) is the strongest severity signal, but deduplication collapses it to one finding before compound detection sees it.

**Most structurally broken:** E5 — "read-only flag that downstream agents consume" is architecturally incoherent without explicit handoff mechanism.
