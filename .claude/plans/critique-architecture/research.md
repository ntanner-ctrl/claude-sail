---
topic: "Optimal Multi-Agent Critique Architecture"
topic_slug: multi-agent-critique-architecture
date: 2026-03-27
mode: deep
linked_blueprint: critique-architecture
coverage:
  prior_art: true
  brainstorm: true
  requirements: true
  extended_investigation: true
gate_score: 4.7
vault_findings: 0
---

# Research Brief: Optimal Multi-Agent Critique Architecture

## Problem Statement

The current "family mode" in blueprint's challenge stages uses a familial metaphor (Children → Mother → Father → Elder Council) that obscures the real mechanism driving its effectiveness: sequential produce→consume→produce-better cycles. The metaphor led to structural design decisions that don't serve the machine's purpose:

1. **Information loss**: Father sees only Mother's synthesis, not raw Children output
2. **No rebuttal**: Children argue independently, never engage each other's points
3. **Vault-blind Round 1**: Historical context arrives via Elders at the END
4. **No feasibility check**: All layers assess design merit, none checks buildability

Family mode works empirically (12+ blueprints, 6 critical bugs caught that single-perspective review missed, 0.90 confidence). The goal is to preserve what works while fixing what's broken, guided by academic literature on multi-agent critique systems.

## Key Findings

### Prior Art

**Academic literature (7 papers, 2024-2026) reveals:**

- **DMAD (ICLR 2025)**: Diversity of *reasoning method* matters more than diversity of *persona*. Three fundamentally different analytical approaches outperform N identical agents with different roles. Validates our Correctness/Completeness/Coherence lens design.

- **CortexDebate (ACL 2025)**: Sparse agent interaction outperforms dense all-to-all debate. Not every agent needs to see every other agent's output. Reduces input by 70.8% while raising accuracy. Validates sparse Clash design.

- **"Talk Isn't Always Cheap" (2025)**: Performance systematically degrades with additional debate rounds. Sycophancy and conformity pressure are the dominant failure modes. Explicit accuracy instructions don't help — mitigations must be structural (anonymization, diverse methods, devil's advocate injection).

- **Confidence Calibration (2024)**: Post-deliberation confidence scoring improves calibration over pre-deliberation. 6 agents is a good balance. Two-stage architecture (specialized generation → general deliberation) is validated.

- **Multi-Model Code Review (Zylos, 2026)**: Single-pass catches <50% of bugs. 60-70% of total value comes from rounds 1-3. Exponential decay after. Clean round (zero confirmed bugs) is the stopping criterion.

**Recommendation:** Build, not adopt. No existing framework matches our specific requirements (markdown-only, Claude Code subagent model, vault integration, blueprint stage integration). But the architectural patterns are well-validated and should be followed.

### Problem Analysis

The produce→consume→produce-better cycle is the core engine across three of claude-sail's most powerful features (family mode, research pipeline, prism). Stripping the family metaphor reveals four distinct operations:

1. **Orient** — Comprehend + ground with external context (vault, research briefs)
2. **Diverge** — Multiple independent perspectives using orthogonal analytical lenses
3. **Clash** — Perspectives engage with each other's findings (cross-examination)
4. **Converge** — Synthesize into prioritized, confidence-rated findings with verdict

This maps to the literature's validated patterns: DMAD's diverse reasoning → CortexDebate's sparse interaction → post-deliberation calibration → human-decidable output.

**Key revision from prior art:** Pure single-pass catches <50%. Allow exactly 1 bounded refinement cycle on contested items (mid-range confidence 0.4-0.6 + substantive rebuttal). Not unbounded looping. This matches both the literature's convergence curves and the empirical data from family mode runs (Stage 4 always converges in 1 round, Stage 3 in max 2).

### Requirements

**Hard constraints:**
- Drop-in replacement for family mode (same output format, same state tracking)
- Coexist with vanilla and debate modes
- Vault-optional, fail-open
- Token budget ≤ family mode (≤10 agents per stage for Full mode)
- Liveness probes, not hard timeouts (validated finding)
- No new dependencies (pure bash/markdown)

**Integration:**
- Input: spec.md + optional research.md + describe.md + vault context + stage context
- Output: adversarial.md (curated) + debate-log.md (raw) + state.json update
- Downstream consumers: Pre-mortem, Test generation, Execute, Regression flow

**Migration:** `--challenge=family` maps to new mode with deprecation notice. Name: `critique`.

## Open Questions

1. **Should Orient be a full agent or a hybrid (structured query + brief summarization)?** Lean: hybrid (cheaper, Orient brief ≤500 words).

2. **Should Diverge perspectives be hardcoded (Correctness/Completeness/Coherence) or adaptive based on Orient findings?** Lean: hardcoded for v1. Domain-specific lenses belong in pre-mortem or prism.

3. **Should Clash inputs be anonymized (strip perspective labels)?** Lean: yes, based on anonymization research reducing sycophancy. Low cost, structural mitigation.

4. **What's the right default tier?** Standard (8 agents) matches empirical data from family mode's typical runs. Light (5) for simple/token-constrained. Full (10) for high-risk.

5. **How does the Converge agent handle conflicting Clash rebuttals?** The Converge agent adjudicates — it reads both the original finding and the rebuttal and decides which holds. This is where opus model heterogeneity adds value.

## Constraints Discovered

1. **Claude Code subagent model**: Agents are stateless. Each gets a fresh context with only what you pass. No shared memory. All context accumulation must be explicit in the dispatch prompt.

2. **Conformity pressure is structural, not fixable by prompting**: The literature is clear — telling agents to "be accurate" doesn't reduce sycophancy. Mitigations must be architectural: anonymization, diverse methods, sparse interaction, bounded rounds.

3. **Pre-mortem separation is load-bearing**: Cross-project evidence confirms adversarial challenge and pre-mortem find orthogonal failure classes. The new critique mode replaces Stages 3+4, NOT Stage 4.5.

4. **Compound failure detection must be preserved**: The crown jewel finding. New architecture preserves it via two mechanisms: Clash (connecting findings across perspectives) and Converge (opus reads everything, explicitly looks for compound interactions).

5. **Research brief interaction**: Orient should supplement, not duplicate, existing research briefs. Check for research.md first, use as primary context if present.

## Recommendation

**Replace family mode with `critique` mode** as the default challenge architecture. Four phases: Orient → Diverge → Clash → (conditional Refine) → Converge. Three tiers matching complexity-adaptive principles.

The design is well-grounded in:
- Academic literature (DMAD, CortexDebate, failure modes research)
- Empirical data from 8+ family mode blueprints across 2 projects
- Existing claude-sail patterns (prism's serial accumulation, research pipeline's progressive structure)

The key innovations over family mode:
1. Historical context at the START (Orient), not the end (Elders)
2. Orthogonal analytical lenses instead of positional argumentation
3. Sparse cross-examination instead of filtered-through-one-lens synthesis
4. Uniform output schema enabling structured comparison
5. Bounded refinement instead of unbounded looping
6. Model heterogeneity (opus for Converge)
7. Anonymized Clash inputs (structural sycophancy resistance)

**NOT a solution design** — the blueprint will specify the full implementation. This brief provides the grounding for that specification.

## Linked Findings

Working artifacts (not exported to vault — the brief is the durable artifact):
- `.claude/wizards/research-20260327-225039/orient.md`
- `.claude/wizards/research-20260327-225039/prior-art.md`
- `.claude/wizards/research-20260327-225039/brainstorm.md`
- `.claude/wizards/research-20260327-225039/requirements.md`
- `.claude/wizards/research-20260327-225039/extended-investigation.md`
- `.claude/wizards/research-20260327-225039/cross-project-vault.md`
