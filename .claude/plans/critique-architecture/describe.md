# Describe: critique-architecture

## Change Summary

Replace the "family mode" challenge architecture in `/blueprint` with a new "critique mode" based on the Orient→Diverge→Clash→(Refine)→Converge pipeline. This is a structural redesign of how blueprint's adversarial stages (Stage 3: Challenge, Stage 4: Edge Cases) work, grounded in academic literature on multi-agent debate systems and empirical data from 8+ family mode blueprints.

### What changes:
1. **New challenge mode (`critique`)** — Four-phase critique pipeline replacing the five-role family structure
2. **Orient phase** — Front-loads historical context (vault, research briefs) before any perspective runs
3. **Diverge phase** — Three orthogonal analytical lenses (Correctness/Completeness/Coherence) replace thesis/antithesis Children
4. **Clash phase** — Sparse cross-examination where perspectives engage with each other's findings (anonymized)
5. **Refine gate** — Bounded single refinement cycle on contested items (replaces unbounded family rounds)
6. **Converge phase** — Opus-model synthesis with confidence scoring and structured verdict
7. **Family mode deprecation** — `--challenge=family` maps to critique with deprecation notice
8. **New state tracking** — `critique_progress` replaces `family_progress` in state.json

### What doesn't change:
- Vanilla and debate modes remain unchanged
- Pre-mortem (Stage 4.5) stays as a separate stage
- Output format (adversarial.md + debate-log.md) preserved
- Blueprint stage structure (Stages 1-8) preserved
- state.json v2 schema extended, not replaced

## Discrete Steps

### Track A: Architecture (blueprint.md modifications)
1. Add Orient phase specification with agent prompt and vault integration
2. Add Diverge phase with three perspective agent prompts (Correctness/Completeness/Coherence)
3. Add Clash phase with sparse interaction logic and anonymization
4. Add Refine gate logic (confidence threshold, contested finding detection)
5. Add Converge phase with opus agent prompt and verdict schema
6. Add critique mode tier selection (Light/Standard/Full)
7. Add critique mode progress tracking schema (`critique_progress`)
8. Wire critique as default challenge mode (replacing family)
9. Add `--challenge=critique` to mode selection section
10. Add family→critique deprecation mapping

### Track B: Documentation
11. Rewrite `docs/BLUEPRINT-MODES.md` — add critique section, update comparison table, revise FAQ
12. Update `README.md` — challenge mode descriptions, agent counts
13. Update `commands/README.md` — if challenge mode references exist

### Track C: Testing
14. Update `test.sh` — adjust any checks that reference family mode specifically
15. Update `evals/evals.json` — if behavioral evals reference family mode

### Track D: Migration
16. Add backward-compatible handling for `challenge_mode: "family"` in existing state.json files
17. Add deprecation notice when `--challenge=family` is explicitly passed

## Risk Assessment

- **Blueprint modification risk**: Changing the primary planning workflow's default challenge mode. Mitigated by: critique is additive (new mode), family maps to critique for backward compat, vanilla and debate untouched.
- **Prompt engineering risk**: New agent prompts (Orient, Diverge×3, Clash×3, Converge) need to produce well-structured output for downstream processing. Mitigated by: uniform output schema, JSON fallback parsing, existing debate output processing logic.
- **State schema risk**: New `critique_progress` field could conflict with existing `family_progress`. Mitigated by: separate field name, family_progress preserved for legacy blueprints.
- **Token cost regression**: If critique mode accidentally costs MORE than family mode. Mitigated by: explicit agent count caps (5/8/10 per tier), empirical comparison target.

## Triage

- **Steps:** 17
- **Risk flags:** Blueprint modification, prompt engineering, state schema
- **Execution preference:** Auto
- **Recommended path:** Full
- **Date:** 2026-03-27
