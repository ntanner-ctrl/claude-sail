# Specification: research-pipeline

## Overview

Split the investigation concern from the planning concern in claude-sail's workflow portfolio. Creates a new `/research` command, restructures blueprint's early stages, establishes the optional-enrichment pattern for inter-workflow communication, and deprecates `/clarify`.

---

## 1. The `/research` Command

### 1.1 Purpose

A structured investigation workflow that formalizes the ad-hoc research phase before blueprinting. Transforms scattered grep sessions, memory files, and vault notes into a progressive pipeline: freeform findings → synthesis brief.

### 1.2 Enforcement Tier

**Tier 2.5** (behavioral + schema signal): `Use when investigating a problem space before planning. Unvalidated assumptions entering a blueprint cause expensive mid-implementation discoveries.`

NOT Process-Critical (MUST) — research is optional enrichment for blueprint, not a prerequisite. Tier 2.5 means: suggestion language in the description, `skippable: false` in wizard state schema, soft nudge in blueprint pre-stage when brief is absent. Per vault precedent (enforcement-tier-honesty finding, meta-blueprint-coordination tier 2.5 pattern).

### 1.3 Arguments

```yaml
arguments:
  - name: topic
    description: What you're investigating (problem area, technology, or question)
    required: true
  - name: mode
    description: "Investigation depth: quick, standard, deep (default: standard)"
    required: false
```

### 1.4 Modes

| Mode | When | What It Does |
|------|------|-------------|
| `quick` | Focused question, known domain | Prior-art search + vault check → brief |
| `standard` | New problem area, moderate complexity | Brainstorm + prior-art + requirements-discovery → brief |
| `deep` | Unfamiliar domain, high stakes, multi-session | All standard steps + extended investigation + multi-session state |

Mode determines which sub-steps run, not the quality of each step.

**Mode selection criterion** (when mode not specified at invocation):
```
Which best describes your situation?
  [1] Quick  — Focused question, known domain (5-10 min)
  [2] Standard — New problem area, moderate complexity (15-30 min)
  [3] Deep  — Unfamiliar domain, high stakes, may span sessions (30+ min)
```

### 1.5 Stages

```
Stage 1: Orient       → What do we already know? (vault search + prior research)
Stage 2: Investigate   → Active research (mode-dependent sub-steps)
Stage 3: Synthesize    → Produce research brief
Stage 4: Gate          → Problem-clarity ambiguity check

Cross-cutting:
  - Progressive vault capture (findings saved as they emerge)
  - Multi-session state tracking (deep mode)
  - Coverage manifest (tracks which sub-steps were run)
```

#### Stage 1: Orient

Search for existing knowledge before doing new work. Prevents re-discovering what's already known.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RESEARCH: [topic] │ Stage 1: Orient
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Searching for existing knowledge...

  Vault:
    [N] findings related to [topic]
    [N] decisions related to [topic]
    [N] patterns related to [topic]

  Memory:
    [N] project memories mentioning [topic]

  Prior research briefs:
    [list any existing research.md files in .claude/plans/*/]

  Starting point: [summary of what's already known]
  Open questions: [what remains unclear]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Vault search mechanics:**
1. Source vault config: `source ~/.claude/hooks/vault-config.sh 2>/dev/null`
2. If vault available: search findings, decisions, patterns for topic terms
3. Search memory files for project context
4. Search `.claude/plans/*/research.md` for prior research briefs in this project
5. If vault unavailable: skip with note, proceed to Stage 2

#### Stage 2: Investigate

Active research, with sub-steps determined by mode:

| Sub-step | Quick | Standard | Deep | Command Used |
|----------|-------|----------|------|-------------|
| Prior art search | ✓ | ✓ | ✓ | `/prior-art` |
| Problem analysis (brainstorm) | — | ✓ | ✓ | `/brainstorm` |
| Requirements discovery | — | ✓ | ✓ | `/requirements-discovery` |
| Extended investigation | — | — | ✓ | Freeform (code reading, web search, experimentation) |
| Cross-project vault search | — | — | ✓ | Vault MCP deep search |

**Sub-step invocation:** Each sub-step invokes its corresponding command with the research topic as context. The command runs normally — research doesn't modify how brainstorm/prior-art/requirements work, it orchestrates when they run and captures their output.

**Progressive capture:** After each sub-step completes, significant findings are saved to the vault as individual notes tagged with the research topic. This happens during investigation, not deferred to synthesis.

**Significance filter:** Only capture to vault if the finding is non-obvious, project-specific, or would change a future decision. The synthesis brief (Stage 3) is the primary durable artifact; individual findings should only hit the vault when they carry information the brief won't fully contain (e.g., a dead end that saved investigation time, an edge case worth preserving independently).

**Vault write confirmation:** `findings_count` in state.json increments only after confirmed vault write. If vault write fails (MCP error, path issue, vault unavailable mid-session), log a warning and continue — the finding remains in the working artifact at `.claude/wizards/research-<id>/[substep].md` but is not counted as a vault finding. Ensure `Engineering/Research/` directory exists before first write (mkdir-p equivalent via vault MCP).

```
Finding captured → vault: Engineering/Findings/YYYY-MM-DD-[topic-slug]-[finding-slug].md
Tagged: research, [topic-slug], [sub-step-name]
```

**Human touchpoints:** After each sub-step, present findings and ask:
```
Sub-step complete: [name]
Key findings: [summary]

  [1] Continue to next sub-step
  [2] Investigate this finding deeper (adds to extended investigation)
  [3] I have enough — skip to synthesis
  [4] Pause research (save state, resume later)
```

Option [4] is available in all modes but primarily useful in deep mode for multi-session work.

#### Stage 3: Synthesize

Transform individual findings into a structured research brief. This is the handoff artifact.

**Conflict check before writing:** Before writing research.md, check if the file already exists at the target path. If it does:
```
A research brief already exists for [name] (dated [frontmatter.date]).
  [1] Overwrite with new research
  [2] Save as [name]-v2
  [3] View existing brief before deciding
```
The vault copy uses date-stamped paths (`YYYY-MM-DD-[topic-slug].md`) which naturally avoid collision across different days. Same-day re-runs to the same vault path should also prompt before overwriting.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RESEARCH: [topic] │ Stage 3: Synthesize
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Synthesizing [N] findings into research brief...

  The brief will be written to:
    .claude/plans/[topic]/research.md  (project-local)
    Vault: Engineering/Research/YYYY-MM-DD-[topic].md (durable)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The synthesis is Claude's work, informed by all findings. The user reviews and approves.

#### Stage 4: Problem-Clarity Gate

The research-side ambiguity check. Uses the parameterized gate (see §4) with the **problem-clarity rubric**.

Gate behavior:
- Pass (≥3.5): Research complete, brief ready for consumption
- Warn (2.5-3.4): "These areas remain unclear: [list]. Continue investigating or accept gaps?"
- Block (<2.5): "The problem space isn't well enough understood to hand off. Here's what's missing: [list]."

On pass, research is marked complete. The brief is the completion signal.

### 1.6 State Management

Research uses the same wizard state pattern as other claude-sail wizards (`.claude/wizards/research-<YYYYMMDD-HHMMSS>/state.json`).

```json
{
  "wizard": "research",
  "version": 1,
  "session_id": "research-<YYYYMMDD-HHMMSS>",
  "status": "active",
  "topic": "heartbeat-v2-constraints",
  "mode": "standard",
  "current_stage": "investigate",
  "stages": {
    "orient": { "status": "complete", "vault_hits": 3 },
    "investigate": {
      "status": "in_progress",
      "substeps": {
        "prior_art": { "status": "complete", "recommendation": "build" },
        "brainstorm": { "status": "in_progress" },
        "requirements": { "status": "pending" }
      }
    },
    "synthesize": { "status": "pending" },
    "gate": { "status": "pending" }
  },
  "coverage": {
    "prior_art": true,
    "brainstorm": true,
    "requirements": true,
    "extended_investigation": false
  },
  "findings_count": 0,
  "brief_path": null
}
```

**Multi-session support (deep mode):** State persists across sessions. On resume:
1. Check for active research sessions: glob `.claude/wizards/research-*/state.json`
   - Exclude `_archive/` paths (active glob matches at top level only)
2. If **multiple** active sessions found: list ALL by topic and session age before prompting
   ```
   Active research sessions:
     [1] heartbeat-v2-constraints (standard, 2h ago, Stage 2: Investigate)
     [2] openvas-docker-limits (deep, 3d ago, Stage 1: Orient)
     [3] Start new research
   ```
3. If **single** session found: display topic, mode, progress, session age
4. **Staleness warning:** If session age exceeds 48 hours, display prominently:
   ```
   ⚠ This research session is [N] days old. Orient findings may be stale.
     [1] Resume from [current stage/substep]
     [2] Re-run Orient before continuing (refreshes vault search)
     [3] Abandon and start fresh
   ```
5. If no active sessions: create new session

### 1.7 Storage

**Topic sanitization:** The topic string is normalized for filesystem use at argument ingestion:
- **Slug:** lowercase, spaces → hyphens, strip characters outside `[a-z0-9-_]`. Used in all file paths.
- **Display name:** original topic string, preserved in YAML frontmatter as a quoted string (handles colons, ampersands safely).
- Both are stored in state.json: `"topic": "auth: redesign"`, `"topic_slug": "auth-redesign"`.

| Artifact | Location | Purpose |
|----------|----------|---------|
| Wizard state | `.claude/wizards/research-<id>/state.json` | Progress tracking |
| Individual findings | Vault: `Engineering/Findings/YYYY-MM-DD-[topic-slug]-*.md` | Durable knowledge (significance-filtered) |
| Research brief | `.claude/plans/[blueprint-name]/research.md` AND Vault: `Engineering/Research/YYYY-MM-DD-[topic-slug].md` | Handoff artifact + durable copy |
| Sub-step outputs | `.claude/wizards/research-<id>/[substep].md` | Working artifacts (not exported) |

**Vault directory creation:** Before first vault write, ensure target directories exist (`Engineering/Research/`, `Engineering/Findings/`). Use vault MCP mkdir-p equivalent. If directory creation fails, degrade to local-only storage.

**Brief storage path:** The research brief lands in `.claude/plans/[name]/research.md` where `[name]` is the blueprint name. If no blueprint exists yet, research prompts: "What will this research feed into? (blueprint name or 'standalone')" — the answer is stored as `linked_blueprint` in the brief's YAML frontmatter. Standalone research briefs go to `.claude/research/[topic-slug]/research.md` with `linked_blueprint: null`.

### 1.8 Completion

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RESEARCH: [topic] │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Mode: [quick/standard/deep]
  Findings captured: [N]
  Sub-steps completed: [list]

  Research brief written to:
    .claude/plans/[name]/research.md
    Vault: Engineering/Research/YYYY-MM-DD-[topic].md

  Coverage: [brainstorm ✓] [prior-art ✓] [requirements ✓]
            [design-check ✗] [extended ✗]

  Next steps:
    /blueprint [name]  — Plan implementation (brief auto-consumed)

  Soft nudge (if blueprint exists but isn't started):
    "Research brief is ready. Run /blueprint [name] to begin
     planning — the brief will be consumed automatically."

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 2. Research Brief Artifact Format

### 2.1 Purpose

The research brief is the handoff artifact between `/research` and `/blueprint` (and potentially future consumers). It must be structured enough that consumers can determine what was covered without reading the full content.

### 2.2 Format

```markdown
---
topic: "[research topic — display name, quoted for YAML safety]"
topic_slug: [sanitized slug used in file paths]
date: YYYY-MM-DD
mode: quick|standard|deep
linked_blueprint: [blueprint name this feeds into, or null for standalone]
coverage:
  prior_art: true|false
  brainstorm: true|false
  requirements: true|false
  extended_investigation: true|false
gate_score: [composite score from problem-clarity gate]
vault_findings: [count of confirmed vault writes]
---

# Research Brief: [topic]

## Problem Statement
[What is the problem? Why does it matter? What are the stakes?]

## Key Findings

### Prior Art
[Summary of existing solutions, libraries, tools surveyed]
[Recommendation: build/adopt/adapt/inform]

### Problem Analysis
[Root causes, constraints, dependencies discovered]
[What's harder than expected? What's easier?]

### Requirements
[Stakeholder needs, success criteria, hard/soft constraints]
[MVP scope vs stretch goals]

## Open Questions
[What remains unclear? What needs more investigation?]
[What assumptions are we making that haven't been validated?]

## Constraints Discovered
[Technical limitations, resource constraints, compatibility requirements]
[Things that narrow the solution space]

## Recommendation
[High-level direction: what approach should planning take?]
[NOT a solution design — a direction indicator]

## Linked Findings
[List of vault finding paths captured during research]
```

### 2.3 Coverage Manifest (YAML Frontmatter)

The `coverage` block is the key innovation. It tells downstream consumers *which sub-steps were run*, enabling evidence-based skipping:

```yaml
coverage:
  prior_art: true      # /prior-art was run during research
  brainstorm: true     # /brainstorm was run during research
  requirements: true   # /requirements-discovery was run during research
  extended_investigation: false  # deep-mode extended work
```

Consumers read this YAML frontmatter to make **routing** decisions (skip or run a gate). For **quality** signal, consumers read `gate_score` (0-5 composite from problem-clarity gate) and `mode` (depth of investigation). Coverage booleans answer "was this done?" — gate_score and mode answer "how thoroughly?"

---

## 3. Optional-Enrichment Pattern

### 3.1 Purpose

A reusable design convention for inter-workflow communication. Workflow B can consume Workflow A's output for richer context, but works fine without it.

### 3.2 Pattern Definition

```
OPTIONAL ENRICHMENT
═══════════════════

Precondition: Workflow A produces an artifact with known path and format
Postcondition: Workflow B checks for artifact, enriches if present, proceeds if absent

Detection:
  1. Check for artifact at expected path
  2. If present: validate format (YAML frontmatter parseable, required fields present)
  3. If valid: consume artifact, adjust behavior based on coverage
  4. If absent OR invalid: proceed with default behavior + soft nudge

Soft nudge (when artifact absent):
  "[workflow A] wasn't run for this topic. Consider running it first
   for richer context. Proceeding with standard behavior."

Soft nudge rules:
  - Display once per workflow invocation (not per stage)
  - Never block progress
  - Never repeat if user has seen it this session
  - Phrased as suggestion, not warning

Fail-open guarantee:
  - Missing artifact = proceed normally (NEVER block)
  - Corrupt artifact = log warning, proceed normally (NEVER block)
  - Partial artifact = consume what's valid, ignore what's not
```

### 3.3 First Instance: Research → Blueprint

```
Artifact: .claude/plans/[name]/research.md
Detection: glob .claude/plans/[name]/research.md
Validation: YAML frontmatter has 'coverage' block with expected keys
Enrichment: blueprint reads brief, adjusts pre-stage and describe behavior
Fallback: blueprint runs as-is with standard pre-stage suggestions
```

### 3.4 Convention for Future Seams

Any workflow can adopt this pattern by documenting:
1. **Producer**: which workflow creates the artifact
2. **Artifact path**: where the artifact lives (convention-based, predictable)
3. **Artifact format**: YAML frontmatter with structured metadata + markdown body
4. **Consumer**: which workflow reads the artifact
5. **Enrichment behavior**: what changes when artifact is present
6. **Fallback behavior**: what happens when artifact is absent (must be fully functional)

---

## 4. Parameterized Ambiguity Gate

### 4.1 Purpose

A base ambiguity-checking mechanism that can be instantiated with different rubrics. Same scoring infrastructure, different criteria.

### 4.2 Base Gate Structure

```
Three dimensions, each scored 1-5:
  Dimension A  [?/5] — [rubric-specific question]
  Dimension B  [?/5] — [rubric-specific question]
  Dimension C  [?/5] — [rubric-specific question]

  Composite Score: [weighted average] / 5.0
    (A: 40%, B: 30%, C: 30%)

  Threshold: >= 3.5 to proceed
```

Gate behavior is identical across rubrics:
- ≥ 3.5: Pass
- 2.5–3.4: Warn with specific gaps, user can override
- < 2.5: Block with required clarification or explicit override

### 4.3 Problem-Clarity Rubric (Research Gate)

Used at the end of `/research` Stage 4.

| Dimension | Question | Anchors |
|-----------|----------|---------|
| Problem Understanding | Is the problem space well-mapped? Could you explain it to a colleague? | 1=vague notion, 5=can draw the problem map with all actors and constraints |
| Constraint Discovery | Are the technical/resource/compatibility constraints identified? | 1=no constraints explored, 5=constraint space fully mapped with evidence |
| Solution Direction | Is there a clear enough direction for planning (not a solution, a direction)? | 1=no idea where to start, 5=confident direction with alternatives considered |

Weight: Problem Understanding 40%, Constraint Discovery 30%, Solution Direction 30%.

### 4.4 Solution-Clarity Rubric (Blueprint Gate)

Used between blueprint's describe and specify stages (replaces current ambiguity gate).

| Dimension | Question | Anchors |
|-----------|----------|---------|
| Goal Clarity | Is the desired outcome unambiguous? Can two people agree on "done"? | (unchanged from current gate) |
| Constraint Clarity | Are boundaries explicit? What's in scope vs out of scope? | (unchanged from current gate) |
| Success Criteria | Are acceptance criteria testable? Could you write a test for "done"? | (unchanged from current gate) |

Weight: Goal 40%, Constraint 30%, Success 30% (unchanged).

### 4.5 Implementation Note

The gate is NOT a shared function or library (claude-sail has no runtime code). It's a documented pattern: each command that uses an ambiguity gate includes the base structure + its specific rubric inline. The "composability" is conceptual, not code-level. If a future command needs an ambiguity gate, it copies the base structure and defines its own rubric dimensions.

---

## 5. Blueprint Restructure

### 5.1 Changes to Pre-Stage

**Current behavior:**
```
Before planning, consider:
  /clarify [topic]               — Guided pre-planning
  /brainstorm [topic]            — If multiple viable approaches
  /requirements-discovery [topic] — If requirements unclear
  /design-check [topic]          — If boundaries fuzzy
```

**New behavior (research brief present):**
```
Research brief detected: .claude/plans/[name]/research.md
  Coverage: [brainstorm ✓] [prior-art ✓] [requirements ✓]
  Gate score: [X/5.0]  Mode: [quick/standard/deep]

  Investigative steps covered by research — skipping pre-stage suggestions.
  /design-check remains available if needed (implementation readiness).

Proceeding to Stage 1: Describe (solution scoping).
```

Blueprint re-reads the research brief at the start of each stage (not just first invocation), so mid-session research is consumed on the next stage transition.

**New behavior (no research brief):**
```
Before planning, consider:

  Complex or unfamiliar problem?
    /research [topic]              — Structured investigation (recommended)

  Quick question, low stakes?
    /brainstorm [topic]            — Problem analysis (5-10 min)
    /requirements-discovery [topic] — Requirements check

  Implementation boundaries fuzzy?
    /design-check [topic]          — Architecture & interface readiness

  Prior art will be checked during planning (standard/full path).
```

Note: `/clarify` removed from suggestions (deprecated). The lightweight path (brainstorm/design-check) is surfaced explicitly alongside /research so users choose the right tool for their situation's complexity.

### 5.2 Changes to Describe Stage

**Current:** Describe handles both problem understanding AND solution scoping in a single pass.

**New:** Describe is refocused on **solution scoping only**.

When research brief is present:
1. Read research brief
2. Display: "Research brief loaded. Problem space: [summary]. Constraints: [summary]."
3. Proceed directly to solution scoping questions:
   - "What are you building?" (solution, not problem)
   - "What are the steps?" (decomposition)
   - "Risk scan" (unchanged)
   - "Path determination" (unchanged)

When research brief is absent:
1. Describe works as today (problem + solution in one pass)
2. Soft nudge displayed once at start (see §3.2)
3. No other behavioral changes — full backward compatibility

### 5.3 Changes to Ambiguity Gate

Replace current gate with solution-clarity rubric (§4.4). The questions are identical to today's gate — the change is conceptual (it's now explicitly about solution clarity, not conflated with problem clarity).

On Light path: unchanged (Goal Clarity only).

### 5.4 Changes to Prior-Art Gate

**Remove from blueprint entirely.** Prior art is now an investigation activity owned by `/research`.

When research brief is present with `coverage.prior_art: true`:
- Prior art was done during research. Skip the gate.
- Record in state.json: `"prior_art_gate": { "status": "covered-by-research", "research_brief": ".claude/plans/[name]/research.md" }`

When research brief is absent OR `coverage.prior_art: false`:
- Run `/prior-art` inline (as blueprint does today)
- This preserves the current behavior for users who skip research
- Record in state.json: `"prior_art_gate": { "status": "complete", ... }` (as today)

### 5.5 Conditional Stage Inclusion Logic

The blueprint reads the research brief's YAML frontmatter `coverage` block to make skip decisions.

**Detection logic:** Blueprint checks for the research brief using the `linked_blueprint` field, not just path inference:
1. Check `.claude/plans/[blueprint-name]/research.md` — direct path match
2. If not found: search `.claude/plans/*/research.md` for briefs where `linked_blueprint` matches this blueprint name
3. If mismatch found (brief exists at different path but `linked_blueprint` matches): prompt user to confirm
4. If no brief found: proceed without enrichment + soft nudge

```
research_brief = detect_research_brief("[blueprint-name]")  # uses linked_blueprint field

if research_brief exists AND research_brief.coverage:
  if coverage.brainstorm:   skip brainstorm suggestion in pre-stage
  if coverage.prior_art:    skip prior-art gate between describe→specify
  if coverage.requirements: skip requirements-discovery suggestion in pre-stage
  # design-check is always available (not research's concern)
  # coverage fields are independent — partial coverage is fine

else:
  # No research brief — full pre-stage as today (minus /clarify, plus /research suggestion)
```

This is per-field conditional, not all-or-nothing. A quick-mode research that only did prior-art will skip only the prior-art gate; brainstorm and requirements suggestions remain.

---

## 6. `/clarify` Deprecation

### 6.1 Deprecation Strategy

Soft deprecation: command still exists but shows a redirect message.

### 6.2 New `/clarify` Content

```yaml
description: "DEPRECATED: Use /research for investigation or /design-check for implementation readiness."
```

Body:
```
# Clarify (Deprecated)

This command has been superseded by:

  /research [topic]     — For investigating problem spaces
                          (brainstorm + prior-art + requirements)

  /design-check [topic] — For checking implementation readiness
                          (architecture, interfaces, error strategy)

Not sure which you need? Use this guide:

  ┌─────────────────────────────────────────────┐
  │ Problem space unclear?   → /research        │
  │   (brainstorm + prior-art + requirements)   │
  │                                             │
  │ Quick question, low stakes?  → /brainstorm  │
  │   (lightweight, 5-10 min)                   │
  │                                             │
  │ Solution unclear?        → /blueprint       │
  │   (ambiguity gate catches this)             │
  │                                             │
  │ Ready to build?          → /design-check    │
  │   (architecture, interfaces, error strategy)│
  └─────────────────────────────────────────────┘

Run /research, /brainstorm, or /design-check instead.
```

### 6.3 Wizard State Cleanup

`/clarify` currently has wizard state management (`.claude/wizards/clarify-*/`). On invocation of the deprecated `/clarify`:
1. Check for active clarify wizard sessions
2. If found: "You have an active /clarify session. Complete it, or abandon it and use /research instead."
3. If not found: display deprecation message above

No auto-migration of clarify state to research state — they're different workflows with different shapes.

---

## 7. Documentation & Tests

### 7.1 Files to Create
- `commands/research.md` — The new `/research` command
- `docs/OPTIONAL-ENRICHMENT.md` — Pattern documentation (Diataxis: explanation)

### 7.2 Files to Modify
- `commands/blueprint.md` — Pre-stage, describe, ambiguity gate, prior-art gate changes
- `commands/clarify.md` — Deprecation content
- `commands/README.md` — Add /research, mark /clarify deprecated
- `README.md` — Update command count, add research to lifecycle map
- `test.sh` — Update command count, add deprecation check
- `docs/PLANNING-STORAGE.md` — Add research.md artifact to storage schema

### 7.3 Test Changes
- Command count: +1 (research) net new, /clarify stays (deprecated, not removed) → CMD_EXPECTED 64→65
- Enforcement lint: /research description must NOT use MUST language (tier 2.5)
- Deprecation lint: /clarify description must start with "DEPRECATED:"
- Frontmatter validation: research.md artifact format (YAML coverage block with linked_blueprint)
- Behavioral evals: 4 new fixtures (enrichment present, enrichment absent, clarify deprecation, research completion)
- Edge case checks: sanitization reference, overwrite reference, multi-session reference, staleness reference

---

## Work Units (WU5 collapsed into WU4 per F4)

| WU | Name | Files | Complexity | TDD | Depends On |
|----|------|-------|-----------|-----|------------|
| WU1 | Create `/research` command | `commands/research.md` | High | No (markdown) | — |
| WU2 | Define research brief artifact format | (documented in spec, validated by tests) | Low | No | WU1 |
| WU3 | Document optional-enrichment pattern | `docs/OPTIONAL-ENRICHMENT.md` | Low | No | — |
| WU4 | Restructure blueprint pre-stage + describe + ambiguity gate | `commands/blueprint.md` | High | No (markdown) | WU2 |
| WU6 | Remove/conditionalize prior-art gate in blueprint | `commands/blueprint.md` | Medium | No (markdown) | WU4 |
| WU7 | Deprecate `/clarify` | `commands/clarify.md` | Low | No | WU1 |
| WU8 | Update docs + READMEs | `commands/README.md`, `README.md`, `docs/PLANNING-STORAGE.md` | Low | No | WU1, WU4, WU7 |
| WU9 | Update tests + behavioral evals | `test.sh`, `evals/evals.json` | Medium | Yes | WU1, WU4, WU7, WU8 |

## Work Graph

```
WU1 (research command) ──→ WU2 (brief format) ──→ WU4 (blueprint pre-stage + gate) ──→ WU6 (prior-art gate)
WU3 (enrichment pattern) ──────────────────────────────────────────────────────────→ (independent)
WU1 ──→ WU7 (deprecate clarify)
WU1 + WU4 + WU7 ──→ WU8 (docs)
WU1 + WU4 + WU7 + WU8 ──→ WU9 (tests + evals)
```

**Parallelization analysis:**
- **Width: 2** — WU1 and WU3 can run in parallel (independent)
- **Critical path:** WU1 → WU2 → WU4 → WU6 → WU8 → WU9 (6 steps)
- WU7 depends only on WU1, can run in parallel with WU2→WU4

**Execution preference:** `auto` → moderate parallelization suggestion.

---

## Acceptance Criteria

1. `/research heartbeat-v2` produces a research brief at `.claude/plans/heartbeat-v2/research.md` with YAML coverage manifest
2. `/blueprint heartbeat-v2` detects the research brief and skips covered pre-stage suggestions
3. `/blueprint new-feature` (no research brief) works exactly as today plus soft nudge
4. `/blueprint` ambiguity gate uses solution-clarity rubric (same questions, explicitly scoped)
5. `/blueprint` prior-art gate is skipped when `coverage.prior_art: true` in research brief
6. `/blueprint` prior-art gate runs inline when no research brief present (backward compatible)
7. `/clarify` shows deprecation message directing to `/research` and `/design-check`
8. `bash test.sh` passes with updated command counts and deprecation check
9. Research brief YAML frontmatter is parseable and coverage fields are boolean
10. Optional-enrichment pattern documented in `docs/OPTIONAL-ENRICHMENT.md`
11. Vault findings captured during research stage are tagged with research topic
