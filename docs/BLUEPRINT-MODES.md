# Blueprint Challenge Modes

How the `/blueprint` command challenges your plans — five modes for different needs.

---

## The Five Modes

The blueprint workflow includes adversarial stages (Challenge and Edge Cases) that
stress-test your specification before implementation. These stages can operate in
five modes, selected once at blueprint creation.

### Vanilla Mode

The original behavior. A single agent reviews the spec from one perspective per stage.

- **Stage 3 (Challenge):** Runs `/devils-advocate` — assumption-based challenge
- **Stage 4 (Edge Cases):** Runs `/edge-cases` — boundary condition mapping

**When to use:** Quick reviews, smaller changes, when token budget is tight.

**Cost:** ~1 subagent call per stage (2 total for Stages 3+4).

### Debate Mode

A three-round sequential critique chain. Each round's agent sees all prior output,
creating escalating depth.

**Stage 3 (Challenge):**
1. **Challenger** — Attacks assumptions, finds the weakest points
2. **Defender** — Responds: validates, refutes, or downgrades each finding. Adds missed items.
3. **Judge** — Synthesizes into a final verdict with severity, convergence, and action ratings

**Stage 4 (Edge Cases):**
1. **Boundary Explorer** — Maps every boundary: input, state, concurrency, time, scale
2. **Stress Tester** — Tests each boundary: just below, at, just above, far beyond
3. **Synthesizer** — Prioritizes by impact x likelihood, flags architectural implications

**When to use:** Good for token-constrained reviews or when historical vault context isn't needed.

**Cost:** ~3 subagent calls per stage (6 total for Stages 3+4). Uses sonnet model.

### Critique Mode (Default — Phased Analysis Pipeline)

A four-phase analytical pipeline grounded in multi-agent debate research. Uses three
analytical lenses (Correctness / Completeness / Coherence) with sparse cross-examination,
bounded refinement, and model heterogeneity.

**Pipeline:**
```
Orient (1, sonnet) → Diverge (3, parallel, sonnet) → Interaction Scan
  → Clash (3, parallel, sonnet) → Refine (0-2, conditional) → Converge (1, opus)
```

**Key design principles:**
- Diversity of analytical lens over diversity of persona
- Sparse interaction (each agent only responds to intersecting findings)
- Anonymized Clash inputs (structural conformity mitigation)
- Three-point anti-sycophancy intervention (pre-Diverge calibration, pre-Clash convergence
  flag, post-Clash coverage check)
- Bounded refinement (one conditional cycle on contested items, not unbounded looping)
- Model heterogeneity (opus for synthesis where reasoning depth matters most)

**Tier selection (auto from work graph):**

| Tier | Phases | Agent Calls | When |
|------|--------|-------------|------|
| Light | Orient → Diverge → Converge | 5 per stage | ≤3 WUs, no High-complexity |
| **Standard** | Orient → Diverge → Scan → Clash → Converge | 8 per stage | 4-5 WUs or 1+ High |
| Full | All phases including Refine | ≤10 per stage | ≥6 WUs |

Risk-pattern override: auth, security, data migration, external API, or schema changes
force minimum Standard tier regardless of WU count.

**When to use:** Most work. Provides structured multi-perspective analysis with compound
failure detection, historical context (via Orient), and actionable verdicts. The tier
system scales cost to complexity — Light tier is comparable to debate for simple specs.

**Cost:** 5-10 agents per stage depending on tier (10-20 total for Stages 3+4).

**Output:** `adversarial.md` leads with verdict summary table (not buried at end).
`debate-log.md` has per-entry schema (lens + round + position + confidence + outcome).
Converge produces structured JSON with disposition requirements per finding.

### Family Mode (Deprecated — Generational Debate)

> **Deprecated:** `--challenge=family` now maps to critique mode. Existing in-progress
> family blueprints continue with the family architecture until completion.

A multi-round generational critique structure with five specialized agents. Each round
builds on the previous, with an Elder Council that queries historical vault data to
determine when the analysis has converged.

**Round structure (per stage):**
```
Round N:
  ├── Child-Defend (parallel) ──┐
  ├── Child-Assert  (parallel) ──┤
  │                              ▼
  ├── Mother (serial: receives both children)
  ├── Father (serial: receives mother's synthesis)
  │                              ▼
  └── Elder Council (serial: receives father + queries vault)
       │
       ├── CONVERGED → Stop, emit final analysis
       └── CONTINUE  → Round N+1
            Children receive: refined spec + elder's carry_forward context
```

**Why deprecated:** Critique mode preserves family mode's strengths (compound failure
detection, historical context, multi-perspective analysis) while fixing structural gaps:
front-loaded Orient phase instead of end-loaded Elder Council, sparse cross-examination
instead of sequential produce-consume chains, and bounded refinement instead of
unbounded looping. See the research brief for empirical comparison.

**Cost:** ~5 agents per round, up to 3 rounds per stage (max ~30 agent calls for Stages 3+4).

### Team Mode (Experimental)

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. Falls back to debate if not enabled.

Spawns three concurrent agents with distinct perspectives:
- **Red Team** — Security, trust boundaries, attack vectors
- **Skeptic** — Complexity, YAGNI, hidden coupling, maintainability
- **Pragmatist** — Operational reality, deployment risks, monitoring gaps

Agents independently review, then read each other's findings and respond, then converge
on a consensus list.

**When to use:** Large, security-sensitive, or high-risk changes where concurrent diverse
perspectives justify the cost. Experimental — behavior may evolve.

**Cost:** 3 concurrent agents per stage (6 total).

---

## Comparison

| Aspect | Vanilla | Debate | Critique | Family (deprecated) | Team |
|--------|---------|--------|----------|---------------------|------|
| Perspectives | 1 | 3 (sequential) | 3 lenses (phased) | 5 (generational) | 3 (concurrent) |
| Token cost | Low (~2 calls) | Medium (~6 calls) | Medium-High (~10-20 calls) | High (~10-30 calls) | High (~6 agents) |
| Depth | Surface | Deep (escalating) | Deep (structured analysis) | Deepest (historical + generational) | Broad (diverse) |
| Speed | Fast | Moderate | Moderate (tier-dependent) | Slow (multi-round) | Depends on coordination |
| Best for | Quick reviews | Token-constrained | Most work (default) | In-progress legacy plans | High-risk, security |
| Requires | Nothing | Nothing | Nothing (vault optional) | Obsidian vault (recommended) | Experimental flag |
| Relative cost | 1x | 3x | 5-10x (tier-adaptive) | 5-15x (round-adaptive) | 3x |

---

## Output Format

All modes produce the same output structure:

- **`adversarial.md`** — Canonical source of truth. Curated findings with severity ratings.
  Critique mode leads with a verdict summary table for readability.
- **`debate-log.md`** — Raw transcript. Critique mode uses per-entry schema
  (lens + round + position + confidence + outcome) for downstream parseability.

The Judge in debate mode, Converge agent in critique mode, Elder Council in family mode,
and lead agent in team mode produce structured JSON output that feeds automatic regression
triggers. See `docs/PLANNING-STORAGE.md` for the schema.

---

## Mode Selection

```bash
/blueprint feature-auth                       # critique mode (default)
/blueprint feature-auth --challenge=critique  # phased analysis pipeline
/blueprint feature-auth --challenge=vanilla   # single-agent
/blueprint feature-auth --challenge=debate    # sequential debate chain
/blueprint feature-auth --challenge=family    # DEPRECATED — maps to critique
/blueprint feature-auth --challenge=team      # experimental teams
```

The mode is set once at creation and locked for the blueprint's lifecycle.
On regression, the same mode is reused — no re-prompting.

---

## Backward Compatibility

- Pre-v2 plans default to `critique` mode on migration (previously defaulted to vanilla)
- `--challenge=family` maps to critique mode with a deprecation notice
- In-progress family blueprints (with `family_progress` in state.json) continue with
  family architecture until completion
- Vanilla and debate modes are unchanged

---

## FAQ

**Q: Why is critique the default instead of family?**
A: Critique mode was designed as a direct improvement over family mode, based on academic
research (DMAD, CortexDebate) and empirical data from 8+ family mode blueprints. It fixes
four structural gaps: information loss in sequential produce-consume chains, no cross-examination
between perspectives, vault-blind Round 1 (now Orient is first), and unbounded looping
(now bounded Refine). The tier system scales cost to complexity — Light tier is comparable
to debate for simple specs.

**Q: Critique mode seems more expensive than debate. Is it?**
A: Tier-adaptive: Light tier (5 agents) is comparable to debate (6 agents). Standard tier
(8 agents) costs more but provides structured cross-examination. Full tier (≤10 agents) is
for complex/high-risk specs where the depth is justified. Use `--challenge=debate` if you
need to minimize token usage.

**Q: Can I still use family mode?**
A: Existing in-progress family blueprints continue with the family architecture. New blueprints
cannot select family mode — `--challenge=family` maps to critique. The family architecture
remains in `blueprint.md` for backward compatibility but is not actively maintained.

**Q: Can I switch modes mid-blueprint?**
A: No. The mode is locked at creation to ensure consistent adversarial depth across
the blueprint's lifecycle. Create a new blueprint if you need a different mode.

**Q: What happens if a Clash agent times out or fails?**
A: Critique mode uses progressive capture — each agent writes to debate-log.md immediately
on completion. Failed agents are skipped; Converge synthesizes over available evidence.
Turn-level checkpointing in state.json enables resume after session interruption.

**Q: Does critique mode require an Obsidian vault?**
A: No. The Orient phase searches the vault for historical context if available but operates
in fail-open mode — no vault means grounding from spec and research brief only.

**Q: What's the Interaction Scan?**
A: A lightweight prompt-instruction step (not a full agent) that runs between Diverge and
Clash. It scans the full findings matrix for compound interaction failures — cases where
two individually-safe findings combine into something dangerous. This preserves the compound
failure detection capability that was family mode's signature strength.

**Q: Why is team mode experimental?**
A: It requires Claude Code's experimental agent teams feature, which is still evolving.
The behavior and quality of concurrent agent coordination may change as the feature matures.
