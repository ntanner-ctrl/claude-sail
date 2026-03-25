# Family Debate Log: research-pipeline

## Round 1

### Child-Defend (Round 1)

**10 defended positions:**

1. **Separation of investigation from planning** — Enforces boundary between discovered knowledge and invented solutions. Cost of mid-implementation discoveries is high and asymmetric.

2. **Coverage manifest in YAML frontmatter** — Machine-readable booleans enable deterministic skip decisions. Extends existing YAML frontmatter convention.

3. **Optional-enrichment as named pattern** — Prevents inconsistent future seam implementations. The naming communicates the invariant (always optional, never blocking).

4. **Fail-open guarantee** — Prevents pattern from becoming a footgun. Users won't cargo-cult research just to silence warnings.

5. **Parameterized ambiguity gate** — Correctly splits "do I understand the problem?" from "do I know what I'm building?" Same mechanics, right questions at right moments.

6. **Mode system (quick/standard/deep)** — Varies which sub-steps run, not quality per step. Prevents "quick" from meaning "worse."

7. **Progressive vault capture** — Targets session-interruption failure mode. Findings written immediately are more accurate than reconstructed during synthesis.

8. **Soft deprecation of /clarify** — Actively teaches replacement pattern rather than silent removal. Handles orphaned wizard state.

9. **Dual-output research brief** — Project-local for machine consumption, vault for human/cross-project learning. Orient stage only pays off if briefs are in vault.

10. **Human touchpoints after each sub-step** — Prevents "doing more than needed." Options [2]-[4] give course-correction, depth control, and pause.

**Acknowledged weakness:** Deep mode's "extended investigation" lacks stopping conditions.

---

### Mother — Strength Synthesizer (Round 1)

**Composite Map:**

| Spec Element | Genuinely Strong | Genuinely Needs Work |
|---|---|---|
| Investigation/planning separation | Correct architectural boundary | Gap at low end: nothing fills /clarify's lightweight role explicitly |
| Coverage manifest (booleans) | Right for routing decisions | Needs note: quality signal comes from gate_score + mode, not booleans |
| Optional-enrichment pattern | Right as named convention | Enforcement is social, not structural — should be stated honestly |
| Fail-open guarantee | Correct on consumer side | MUST language on /research production side needs qualifying condition |
| Parameterized gate | Opens pattern for future seams | WU5 is documentation work, not behavioral change — label accordingly |
| Mode system | Correct depth-scaling mechanism | Quick mode heavier than /clarify; individual commands need stronger placement |
| Progressive vault capture | Session-interruption resilience | Needs significance filter; brief should be primary vault artifact |
| Soft deprecation | Right mechanics, handles orphaned state | Redirect needs decision criterion (brainstorm vs research) |
| Dual-output brief | Right design | Vault absence degrades Orient to within-project-only; tier explicitly |
| Human touchpoints | Correct within-session control | Deep mode needs staleness threshold on resume |
| Linkage mechanism | Coverage manifest deterministic given correct path | Name divergence is real gap; recommend `linked_blueprint` frontmatter field |

**Top 2 issues requiring resolution:**
1. MUST/optional contradiction on enforcement tier
2. Name-linkage fragility undermining coverage manifest determinism

---

### Father — Weakness Analyst & Guide (Round 1)

**8 proposed changes (4 required, 4 acceptable risk with notes):**

| # | Item | Verdict | Direction |
|---|------|---------|-----------|
| 1 | Enforcement tier contradiction | **Change required** | Drop to Utility tier. MUST is inconsistent with optional-enrichment. Soft nudge becomes sole prompt. |
| 2 | Name mismatch linkage | **Change required** | Add `linked_blueprint` to research brief frontmatter. Explicit link, not path inference. |
| 3 | Vault noise from progressive capture | Acceptable risk | Tier findings: working artifacts to `Engineering/Research/Working/`, brief to `Engineering/Research/` |
| 4 | WU5 is documentation overhead | **Change required** | Collapse WU5 into WU4. Gate concept moves to docs, no standalone behavioral change. |
| 5 | Deep-mode staleness | Acceptable risk | Add 48h resume warning. Small addition, closes real gap. |
| 6 | No lightweight replacement | **Change required** | Update blueprint pre-stage + clarify redirect to surface brainstorm/design-check as lightweight path. |
| 7 | Coverage boolean quality | Acceptable risk | Display `gate_score` alongside coverage in blueprint enrichment. Clarification, not structural. |
| 8 | Redirect decision criterion | Change required | Add 3-case decision table to clarify deprecation message. |

**Additional observations:**
- Remove `design_check: false` from coverage block (dead field creates confusion)
- Add mode selection decision criterion for users who don't specify mode
- Vault-absent user experience should be explicitly tiered in docs

**Confidence: 7/10** — strong foundation, needs targeted revision on items 1+2 before WU1 begins.

**3 unresolved tensions for Elder Council:**
1. Is the soft nudge (sole remaining enforcement) strong enough for behavior change?
2. Are the problem-clarity rubric questions different enough from solution-clarity to justify the split?
3. Vault dependency creates two-tier experience not acknowledged in the spec.

---

### Elder Council — Historical Validator (Round 1)

**8 vault analogies found. All 8 Father items historically validated.**

**Verdict: CONVERGED** (confidence: 0.78)

Key historical evidence:
| Vault Source | Lesson | Relevance |
|---|---|---|
| enforcement-tier-honesty | MUST in markdown is credibility erosion when no hook enforces it | Supports Item 1 (tier drop) |
| meta-blueprint-coordination blueprint | Tier 2.5 precedent (behavioral + schema signal) is established | Refines Item 1: tier 2.5, not pure Utility |
| workflow-orphan-analysis | /clarify solved orphan problem; /research must surface lightweight alternatives | Supports Item 6 (lightweight path) |
| source-of-truth-drift pattern | Every copy of authoritative data is a future drift bug | Supports Item 2 (linked_blueprint field) |
| spec-deployment-gap | Spec can describe artifacts that test.sh never verifies | Warns: WU9 must verify artifact paths |
| premortem-catches-process-failures | Pre-mortem catches orthogonal failure class to design review | Warns: run pre-mortem before WU1 |
| family-debate-catches-critical-bugs | Enforcement overclaiming is a recurring failure class | Supports Item 1 |
| workflow-portfolio-analysis | The research gap is evidenced by 3 real March 2026 sprint examples | Supports overall direction |

**Critical refinement:** Father's Item 1 targets Utility tier. Elder recommends tier 2.5 instead (precedent from meta-blueprint-coordination). Tier 2.5 = behavioral guidance + schema signal + soft nudge, without MUST language.

**All 3 tensions resolved:**
1. Soft nudge + tier 2.5 is strong enough (MUST erodes credibility, nudge is honest)
2. Rubric split justified (lifecycle gap is observed pain, not speculation)
3. Vault-absent tiering is a docs task, not a design reopening

---

## Stage 4: Edge Cases — Round 1

### Edge-Defend (Round 1)

Defended boundaries across 5 categories. Key arguments:
- **Input**: required field constraint gates empty topic; mode falls back to standard
- **State**: wizard state + progressive capture protects against interruption; coverage → routing only
- **Concurrency**: timestamp-based session IDs prevent collision; same-topic overwrite tolerable (vault preserves prior)
- **Time**: date field in frontmatter gives consumers staleness info; 48h threshold is implementation detail
- **Integration**: vault-config.sh 2>/dev/null pattern handles all vault-absent cases; fail-open established

Acknowledged gaps: same-topic overwrite, staleness threshold, state corruption verbosity — all defended as tolerable.

### Edge-Assert (Round 1)

**28 boundaries mapped, 10 HIGH-severity unhandled:**

Top 8 by risk:
1. B-S-2: Multiple active sessions → wrong session resumed silently
2. B-I-2: Special chars in topic (/, &, :) → vault path failure, YAML corruption
3. B-IN-2: research.md overwrite on re-run → silent data loss
4. B-W-4: Vault write failure in progressive capture → misleading findings count
5. B-W-5: Gate passes despite thin coverage → quality assurance gap
6. B-W-1: /research mid-blueprint → new brief invisible to running blueprint
7. B-T-3: Deep-mode staleness (F5 not merged into spec body)
8. B-IN-4: Blueprint renamed after research (F2 not merged into spec body)

### Edge-Mother — Synthesis (Round 1)

3 MUST FIX, 4 SHOULD FIX, 1 ACCEPTABLE:
| Boundary | Verdict | Fix |
|---|---|---|
| B-I-2: Special chars in topic | MUST FIX | Topic sanitization in §1.7; quoted in YAML |
| B-IN-2: research.md overwrite | MUST FIX | Confirm-before-overwrite prompt |
| B-IN-4: linked_blueprint (F2 unmerged) | MUST FIX | Add to §2.2 frontmatter |
| B-S-2: Multiple active sessions | SHOULD FIX | List all by topic before resume |
| B-W-4: Vault write failure count | SHOULD FIX | Increment only on confirmed write |
| B-W-1: Mid-blueprint research | SHOULD FIX | Blueprint re-reads brief on resume |
| B-T-3: Staleness (F5 unmerged) | SHOULD FIX | 48h resume warning |
| B-W-5: Thin coverage gate | ACCEPTABLE | gate_score + mode are the quality signal |

Key finding: 2 of 3 MUST FIX are unmerged Family findings (F2, F5). Only B-I-2 is genuinely new.

### Edge-Father — Guide (Round 1)

All items validated. No regression to Stage 2 — 5 targeted section amendments. Confidence: 0.83-0.85.

### Edge-Elder — Historical Validator (Round 1)

**Verdict: CONVERGED** (confidence: 0.86)

Vault analogies: notion-html-publisher E1+E7 (slug sanitization + silent overwrite), vault-data-pipeline F2 (overwrite destroys annotations), wizard-state-management (positive state assertion for resume). All 3 MUST FIX historically validated.

---

### Child-Assert (Round 1)

**7 challenges identified:**

1. **Enforcement tier contradiction** [HIGH] — MUST language vs optional-enrichment philosophy. Risks compliance fatigue or cry-wolf degradation of MUST tier.

2. **Name mismatch breaks linkage** [HIGH] — Research topics and blueprint names will differ. Manual prompt is easy to forget. Handoff degrades to convention.

3. **Progressive vault capture creates noise** [MEDIUM] — 10-20 granular notes per session. No significance filter. Vault search quality degrades over time.

4. **Parameterized gate is cosmetic** [HIGH as scope risk] — Solution-clarity rubric is unchanged. WU5 is overhead with no functional gain.

5. **Deep-mode staleness** [MEDIUM] — No defined threshold. Multi-week research resumes with stale Orient findings.

6. **No lightweight pre-planning replacement** [MEDIUM] — /research is heavier than /clarify was. Users may skip pre-planning entirely.

7. **Coverage booleans lack quality signal** [MEDIUM] — `prior_art: true` after a 2-minute scan skips the same gate as after thorough research.
