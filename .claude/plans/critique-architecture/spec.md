# Specification: critique-architecture

## Overview

Replace family mode with `critique` mode as the default challenge architecture in `/blueprint`. Four phases: Orient → Diverge → Clash → (Refine) → Converge. Three tiers: Light (5 agents), Standard (8 agents, default), Full (10 agents max).

### Design Principles (from research)

1. **Diversity of analytical lens > diversity of persona** (DMAD, ICLR 2025)
2. **Sparse interaction > dense all-to-all** (CortexDebate, ACL 2025)
3. **Conformity mitigations must be structural, not prompt-based** (failure modes literature)
4. **Bounded refinement > unbounded looping** (exponential decay in multi-round value)
5. **Historical context at the START, not the end** (Orient before Diverge)
6. **Model heterogeneity where reasoning is most complex** (opus for Converge)

---

## Architecture

```
Input: spec.md + (optional) research.md + describe.md + stage_context

┌─────────────────────────────────────────────────────┐
│  Phase 1: ORIENT (1 agent, sonnet)                  │
│  Vault search + research brief + constraint summary │
│  Output: context brief (≤500 words)                 │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Phase 2: DIVERGE (3 agents, parallel, sonnet)      │
│  Correctness / Completeness / Coherence             │
│  Each receives: input + Orient brief + stage context│
│  Each produces: structured findings                 │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Phase 3: CLASH (3 agents, parallel, sonnet)        │
│  Sparse: each responds to intersecting findings     │
│  from other two perspectives (anonymized inputs)    │
│  Produces: rebuttals, reinforcements, gaps          │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Phase 3.5: REFINE (conditional, 0-2 agents)        │
│  IF contested findings at mid-range confidence:     │
│    Re-examine ONLY contested items                  │
│  ELSE: skip                                         │
└───────────────────────┬─────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────┐
│  Phase 4: CONVERGE (1 agent, opus)                  │
│  Reads ALL prior output                             │
│  Produces: prioritized findings + verdict           │
│  Verdict: READY / REWORK / REDIRECT                 │
└─────────────────────────────────────────────────────┘
```

### Tier Selection

| Tier | Phases | Agent Calls | When to Use |
|------|--------|-------------|-------------|
| Light | Orient → Diverge → Converge | 5 per stage | Simple specs (≤3 WUs, no high-complexity) |
| **Standard** (default) | Orient → Diverge → Clash → Converge | 8 per stage | Most work |
| Full | Orient → Diverge → Clash → Refine → Converge | ≤10 per stage | High-risk, complex specs (≥6 WUs) |

Tier is auto-selected from work graph complexity (same signal as family mode's round limits):

| Signal | Condition | Tier |
|--------|-----------|------|
| Simple | ≤3 WUs AND no High-complexity WUs | Light |
| Medium | 4-5 WUs OR 1+ High-complexity WU | Standard |
| Complex | ≥6 WUs | Full |

User can override with `--tier=light|standard|full`.

---

## Phase Specifications

### Phase 1: Orient (1 agent, sonnet)

**Purpose:** Comprehend the input and bring external context so every downstream perspective is grounded.

**Input:**
- `spec.md` (always)
- `research.md` (if exists — use as primary context, supplement with vault)
- `describe.md` (always)
- Stage context: "CHALLENGE" or "EDGE_CASES"

**Process:**
1. If `research.md` exists: extract key findings, constraints, prior art as primary context
2. If vault available: search for related findings, decisions, patterns (limit: 5 most relevant per query)
3. If neither: extract constraints from spec.md + describe.md only
4. Summarize into context brief (≤500 words)

**Agent prompt:**
```
You are the Orient agent. Your job is to COMPREHEND this specification
and GROUND it with relevant context. You do NOT critique — you understand.

INPUT DOCUMENTS:
[spec.md content]
[research.md content if available]
[describe.md content]

STAGE CONTEXT: [CHALLENGE: evaluate design decisions | EDGE_CASES: evaluate boundary behavior]

YOUR TASK:
1. RESTATE the spec's intent in 2-3 sentences (what is it trying to do?)
2. MAP the constraints (what limits apply? what can't change?)
3. IDENTIFY the scope boundaries (what this explicitly doesn't cover)
4. SURFACE relevant historical context:
   [If research brief available: extract key findings and constraints]
   [If vault available: search for related findings and decisions]
   [If neither: note "no external context available — grounding from spec only"]
5. FLAG any assumptions the spec makes that aren't validated

OUTPUT FORMAT:
## Context Brief

### Intent
[2-3 sentence restatement]

### Constraints
- [constraint 1]
- [constraint 2]
...

### Scope Boundaries
- In: [what's covered]
- Out: [what's not covered]

### Historical Context
[Relevant findings, decisions, patterns — or "none available"]

### Unvalidated Assumptions
- [assumption 1]: [why it matters]
...

CRITICAL: Keep total output under 500 words. Downstream agents
receive this verbatim — brevity preserves their reasoning capacity.
```

**Output:** Context brief written to `debate-log.md` as `## Orient Phase`.

**Vault search mechanics:**
```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```
If vault available: search Engineering/Findings/, Engineering/Decisions/, Engineering/Patterns/ for terms from the spec's key technologies and domain. Limit to 5 most relevant results per query. If vault unavailable: skip silently (fail-open).

---

### Phase 2: Diverge (3 agents, parallel, sonnet)

**Purpose:** Three orthogonal analytical perspectives examine the spec independently.

**Input (each agent receives):** spec.md + Orient context brief + stage context header

**Stage context header:**
- CHALLENGE: "You are evaluating DESIGN DECISIONS. Focus on whether the design approach is [correct/complete/coherent]."
- EDGE_CASES: "You are evaluating BOUNDARY BEHAVIOR. Focus on whether boundary handling is [correct/complete/coherent]."

#### Correctness Perspective

```
You analyze this specification for CORRECTNESS — are the claims
and assumptions true?

CONTEXT BRIEF:
[Orient output]

STAGE: [CHALLENGE or EDGE_CASES]

SPECIFICATION:
[spec.md content]

For each section of the spec, ask:
  - Are the stated constraints actually constraints?
  - Are the claimed behaviors achievable with the described approach?
  - Are there implicit assumptions that aren't validated?
  - Is anything stated as fact that is actually uncertain?
  - [CHALLENGE]: Is this design approach sound?
  - [EDGE_CASES]: Are the boundary claims true?

For each finding, produce EXACTLY this format:

FINDING-C[N]:
  Summary: [one-line summary]
  Section: [which spec section]
  Claim: [what the spec asserts]
  Assessment: TRUE | FALSE | UNCERTAIN
  Evidence: [why you believe this]
  Severity: critical | high | medium | low
  Confidence: [0.0-1.0]
  False-known: [yes|no] — yes if the spec is CONFIDENTLY WRONG

Prioritize findings by severity. Limit to your top 10 findings.
Do NOT pad with low-confidence theoretical concerns.
```

#### Completeness Perspective

```
You analyze this specification for COMPLETENESS — what's missing
that should be there?

CONTEXT BRIEF:
[Orient output]

STAGE: [CHALLENGE or EDGE_CASES]

SPECIFICATION:
[spec.md content]

For each section of the spec, ask:
  - What inputs, states, or conditions are not addressed?
  - What error paths are not handled?
  - What dependencies are not documented?
  - [CHALLENGE]: What design decisions are implied but not stated?
  - [EDGE_CASES]: What happens at boundaries (empty, max, concurrent, timeout)?

For each finding, produce EXACTLY this format:

FINDING-M[N]:
  Summary: [one-line summary]
  Section: [where this should be addressed]
  Gap: [what's missing]
  Impact: [what fails if this isn't addressed]
  Severity: critical | high | medium | low
  Confidence: [0.0-1.0]
  False-known: [yes|no] — yes if the spec claims "this is covered" but it isn't

Prioritize findings by severity. Limit to your top 10 findings.
```

#### Coherence Perspective

```
You analyze this specification for COHERENCE — do the parts work
together?

CONTEXT BRIEF:
[Orient output]

STAGE: [CHALLENGE or EDGE_CASES]

SPECIFICATION:
[spec.md content]

For the spec as a whole, ask:
  - Do any sections contradict each other?
  - Are there circular dependencies between components?
  - Does the execution order match the dependency order?
  - Are naming conventions and terminology consistent?
  - [CHALLENGE]: Do the stated requirements match the proposed solution?
  - [EDGE_CASES]: Do boundary handlers conflict with each other?

For each finding, produce EXACTLY this format:

FINDING-H[N]:
  Summary: [one-line summary]
  Sections: [which sections are in tension]
  Contradiction: [what conflicts]
  Resolution: [which section should yield, or how to reconcile]
  Severity: critical | high | medium | low
  Confidence: [0.0-1.0]
  False-known: [yes|no] — yes if the spec claims internal consistency that doesn't exist

Prioritize findings by severity. Limit to your top 10 findings.
```

**Output:** Each agent's output written to `debate-log.md` immediately upon completion (progressive capture).

---

### Phase 3: Clash (3 agents, parallel, sonnet)

**Purpose:** Cross-examination. Each perspective engages with findings from the other two that intersect its domain.

**Input preparation (ANONYMIZED):**

Before dispatching Clash agents, the orchestrator:
1. Collects all findings from Diverge
2. Strips perspective labels (FINDING-C3 → FINDING-03, FINDING-M7 → FINDING-07, etc.)
3. Groups findings by spec section
4. For each Clash agent: provides ONLY findings that share a section reference with that agent's own Diverge findings (sparse interaction)

If a Diverge perspective produced zero findings, its corresponding Clash agent is skipped.

**Clash agent prompt (same for all three, with different finding sets):**

```
You are a cross-examiner. You have produced findings about this
specification. Now you see findings from other perspectives that
touch the SAME sections of the spec.

YOUR FINDINGS:
[This agent's Diverge findings, with original labels]

OTHER FINDINGS (touching your sections):
[Anonymized findings from other perspectives]

For each other finding that intersects your work:

REBUTTAL (if you disagree):
  Finding: [ID]
  Your position: [why this finding is wrong or overstated]
  Evidence: [specific evidence from the spec]
  Rebuttal confidence: [0.0-1.0]

REINFORCEMENT (if you independently found the same issue):
  Finding: [ID]
  Your finding: [your corresponding finding ID]
  Agreement: [what you both see]
  Combined confidence: [boosted confidence]

GAP (something neither you nor they mentioned):
  Gap: [what was missed]
  Section: [where it belongs]
  Severity: critical | high | medium | low
  Confidence: 0.50 (default for newly identified gaps)

IMPORTANT: Only respond to findings that genuinely intersect your
analysis. Do NOT comment on findings outside your domain.
Silence on a finding = no opinion (not agreement).
```

**Output:** Written to `debate-log.md` as `## Clash Phase`.

---

### Phase 3.5: Refine (conditional, 0-2 agents, sonnet)

**Purpose:** Targeted re-examination of contested findings. ONLY runs on Full tier.

**Trigger logic:**

After Clash completes, the orchestrator:
1. Identifies findings that received substantive rebuttals (rebuttal confidence > 0.3)
2. Computes post-Clash confidence for each finding:
   - Reinforced by 1 perspective: original + 0.15 (cap 0.95)
   - Reinforced by 2 perspectives: original + 0.25 (cap 0.95)
   - Rebutted (strong, conf > 0.6): original - 0.20 (floor 0.10)
   - Rebutted (weak, conf ≤ 0.6): no change
   - No engagement: no change
   - New gap from Clash: starts at 0.50
3. Selects findings where post-Clash confidence is 0.4-0.6 AND a substantive rebuttal exists
4. If count > 0: select top 3 by severity, dispatch refine agents

**Refine agent prompt:**

```
A finding about this specification is CONTESTED. Two perspectives
disagree. Your job is to provide ADDITIONAL EVIDENCE to resolve
the dispute.

CONTESTED FINDING:
[Original finding with full context]

REBUTTAL:
[The rebuttal with its evidence]

SPECIFICATION SECTION:
[The relevant spec section]

Provide additional evidence for ONE side. Do not hedge.
Either the finding stands or the rebuttal holds. Which?

VERDICT:
  Finding: [stands | overturned]
  Evidence: [what clinches it]
  Revised confidence: [0.0-1.0]
```

**Maximum agents:** 2 per stage (one contest involves 2 perspectives). Only the perspectives involved in the specific contest are re-dispatched.

**If no contested findings at mid-range confidence:** Refine is skipped entirely.

---

### Phase 4: Converge (1 agent, opus)

**Purpose:** Synthesize all prior output into prioritized findings and a verdict.

**Input:** ALL prior output (Orient brief, all Diverge findings, all Clash results, Refine results if any).

**Agent prompt:**

```
You are the Converge agent. You synthesize the entire critique
pipeline into a final verdict.

ORIENT BRIEF:
[Orient output]

DIVERGE FINDINGS:
[All findings from all three perspectives, with original labels restored]

CLASH RESULTS:
[All rebuttals, reinforcements, and gaps]

REFINE RESULTS (if any):
[Contested finding verdicts]

YOUR TASK:

1. DEDUPLICATE: Merge findings that describe the same issue from different angles.

2. PRIORITIZE: For each unique finding, compute final confidence:
   - Base: original Diverge confidence
   - Reinforced by 1 perspective: +0.15
   - Reinforced by 2 perspectives: +0.25
   - Rebutted (strong): -0.20
   - Rebutted (weak): no change
   - Refine verdict (if available): use Refine's revised confidence
   - Cap at 0.95, floor at 0.10

3. DETECT COMPOUND FAILURES: Look for findings from DIFFERENT
   perspectives that affect the SAME component. Two individually
   minor findings that combine into something dangerous should be
   flagged as a compound finding with elevated severity.

4. FLAG FALSE KNOWNS: Any finding where the spec is CONFIDENTLY WRONG
   (false-known: yes) gets special attention. These are the most
   dangerous because the author doesn't know they're wrong.

5. PRODUCE VERDICT:

OUTPUT FORMAT (JSON):
{
  "findings": [
    {
      "id": "CF-[N]",
      "summary": "one-line",
      "source_findings": ["C3", "M7"],
      "severity": "critical|high|medium|low",
      "confidence": 0.0-1.0,
      "false_known": true|false,
      "compound": true|false,
      "section": "spec section",
      "direction": "what to do (not how)",
      "addressed": "already-in-spec|needs-update|needs-new-section"
    }
  ],
  "verdict": "READY|REWORK|REDIRECT",
  "verdict_rationale": "why this verdict",
  "critical_count": 0,
  "false_known_count": 0,
  "compound_count": 0,
  "unresolved_tensions": [
    "description of tension that needs HUMAN decision"
  ],
  "regression_target": "specify|null"
}

VERDICT MEANINGS:
  READY    — No critical findings. Proceed to next stage.
  REWORK   — Critical findings in specific sections. Spec needs targeted revision.
             regression_target = "specify"
  REDIRECT — Fundamental approach is flawed. Rethink required.
             regression_target = "specify" (or "describe" if scope is wrong)

IMPORTANT: If findings disagree and you cannot resolve the tension,
list it in unresolved_tensions. These get flagged for HUMAN decision.
Do NOT paper over genuine uncertainty with a confident verdict.
```

**Output processing:**
1. Parse JSON (same fallback chain as debate mode — pattern match if JSON fails)
2. Write curated findings to `adversarial.md`
3. Write verdict to state.json
4. If REWORK/REDIRECT: trigger regression prompt

---

## Output Format

### adversarial.md (Curated)

```markdown
# Critique Analysis: [stage name]

## Orient Context
[Brief summary of grounding context]

## Findings

### Critical
| ID | Finding | Confidence | False Known | Compound | Direction |
|----|---------|-----------|-------------|----------|-----------|
| CF-1 | ... | 0.85 | No | Yes | ... |

### High
[same table format]

### Medium
[same table format]

### Low
[same table format]

## Verdict: [READY/REWORK/REDIRECT]
[Rationale]

## Unresolved Tensions
- [tension requiring human decision]

## Complexity Review
[/overcomplicated output, appended post-challenge as before]
```

### debate-log.md (Raw Transcript)

```markdown
# Critique Transcript: [stage name]

## Orient Phase
[Full Orient agent output]

## Diverge Phase
### Correctness
[Full output]
### Completeness
[Full output]
### Coherence
[Full output]

## Clash Phase
### Correctness Cross-Examination
[Full output]
### Completeness Cross-Examination
[Full output]
### Coherence Cross-Examination
[Full output]

## Refine Phase (if triggered)
[Full output per contested finding]

## Converge Phase
[Full JSON output]
```

---

## State Tracking

### critique_progress in state.json

```json
{
  "critique_progress": {
    "stage": "challenge",
    "tier": "standard",
    "phase": "clash",
    "agents_completed": ["orient", "diverge_correctness", "diverge_completeness", "diverge_coherence"],
    "current_agent": "clash_correctness",
    "findings_count": 12,
    "contested_count": 0,
    "refine_triggered": false,
    "verdict": null,
    "confidence": null
  }
}
```

On resume: skip completed agents, continue from `current_agent`. Read completed agents' output from `debate-log.md`.

### Family mode backward compatibility

When resuming a blueprint with `challenge_mode: "family"`:
- If challenge stages are NOT yet started: silently use critique architecture
- If challenge stages are IN PROGRESS with `family_progress`: continue with family architecture (don't switch mid-challenge)
- Record: `"family_migrated": true` in state.json

When `--challenge=family` is explicitly passed:
```
Note: --challenge=family has been renamed to --challenge=critique.
Using critique mode (Orient→Diverge→Clash→Converge architecture).
See docs/BLUEPRINT-MODES.md for details on the new architecture.
```

---

## Work Units

### WU-1: Orient Phase Implementation
**File:** `commands/blueprint.md`
**Complexity:** Medium
**TDD:** false
**Description:** Add Orient phase agent specification, vault integration logic, research brief detection, and context brief output format. Include the ≤500 word constraint and fail-open vault behavior.
**Dependencies:** None
**Acceptance Criteria:**
- AC-1: Orient agent prompt specified with all 5 output sections
- AC-2: Research brief detection: if research.md exists, use as primary context
- AC-3: Vault search mechanics documented with fail-open behavior
- AC-4: Context brief capped at 500 words with truncation logic
- AC-5: Output written to debate-log.md immediately

### WU-2: Diverge Phase Implementation
**File:** `commands/blueprint.md`
**Complexity:** High
**TDD:** false
**Description:** Add three Diverge perspective agent specifications (Correctness, Completeness, Coherence), stage context headers for Challenge vs Edge Cases, and uniform output schema.
**Dependencies:** WU-1
**Acceptance Criteria:**
- AC-6: Three agent prompts with distinct analytical lenses
- AC-7: Stage context header switches between CHALLENGE and EDGE_CASES
- AC-8: Uniform finding format across all three (ID, summary, section, observation, severity, confidence, false-known)
- AC-9: Finding ID prefixes: C (correctness), M (completeness), H (coherence)
- AC-10: Each agent limited to top 10 findings

### WU-3: Clash Phase Implementation
**File:** `commands/blueprint.md`
**Complexity:** High
**TDD:** false
**Description:** Add Clash phase with sparse interaction logic, anonymization preprocessing, and cross-examination prompt. Define rebuttal/reinforcement/gap output format.
**Dependencies:** WU-2
**Acceptance Criteria:**
- AC-11: Anonymization: strip perspective labels before passing to Clash agents
- AC-12: Sparse interaction: each Clash agent only sees findings touching its sections
- AC-13: Three output types defined: rebuttal, reinforcement, gap
- AC-14: Skip Clash agent if corresponding Diverge perspective produced zero findings
- AC-15: Clash skipped entirely on Light tier

### WU-4: Refine Gate Implementation
**File:** `commands/blueprint.md`
**Complexity:** Medium
**TDD:** false
**Description:** Add Refine gate logic: confidence update rules, contested finding detection, targeted re-dispatch prompt. Define trigger threshold (0.4-0.6 confidence + substantive rebuttal).
**Dependencies:** WU-3
**Acceptance Criteria:**
- AC-16: Confidence update table documented (reinforcement boost, rebuttal reduction)
- AC-17: Trigger: mid-range confidence (0.4-0.6) AND substantive rebuttal (conf > 0.3)
- AC-18: Maximum 2 agents, top 3 findings by severity
- AC-19: Refine only runs on Full tier
- AC-20: If no contested findings at mid-range: skip entirely

### WU-5: Converge Phase Implementation
**File:** `commands/blueprint.md`
**Complexity:** High
**TDD:** false
**Description:** Add Converge agent specification (opus model), deduplication logic, compound failure detection, false-known flagging, verdict schema, and JSON output processing with fallback chain.
**Dependencies:** WU-4
**Acceptance Criteria:**
- AC-21: Converge uses opus model (model heterogeneity)
- AC-22: JSON output schema with all required fields
- AC-23: Fallback chain on JSON parse failure (same as debate mode)
- AC-24: Compound failure detection explicitly in prompt
- AC-25: Verdict: READY/REWORK/REDIRECT with regression target
- AC-26: Unresolved tensions flagged for human decision

### WU-6: Tier Selection and Mode Wiring
**File:** `commands/blueprint.md`
**Complexity:** Medium
**TDD:** false
**Description:** Add tier auto-selection from work graph, `--tier` override, `--challenge=critique` mode selection, critique as default mode replacing family, and progress tracking schema.
**Dependencies:** WU-5
**Acceptance Criteria:**
- AC-27: Tier auto-selected from work graph complexity (same signal as family rounds)
- AC-28: `--tier=light|standard|full` override documented
- AC-29: `--challenge=critique` added to mode selection
- AC-30: critique is new default (replacing family)
- AC-31: `critique_progress` state tracking schema defined

### WU-7: Family Mode Deprecation and Migration
**File:** `commands/blueprint.md`
**Complexity:** Low
**TDD:** false
**Description:** Add `--challenge=family` → critique mapping with deprecation notice. Handle existing blueprints with `challenge_mode: "family"` in state.json.
**Dependencies:** WU-6
**Acceptance Criteria:**
- AC-32: `--challenge=family` maps to critique mode internally
- AC-33: Deprecation notice displayed when family explicitly requested
- AC-34: Existing in-progress family blueprints continue with family architecture
- AC-35: Not-yet-started family blueprints silently use critique

### WU-8: Output Format and adversarial.md
**File:** `commands/blueprint.md`
**Complexity:** Low
**TDD:** false
**Description:** Define adversarial.md output format for critique mode (findings tables by severity, verdict section, unresolved tensions). Define debate-log.md structure with phase headers.
**Dependencies:** WU-5
**Acceptance Criteria:**
- AC-36: adversarial.md format with severity-grouped tables
- AC-37: debate-log.md with phase-labeled sections
- AC-38: Progressive capture: each agent writes immediately on completion

### WU-9: Documentation Updates
**Files:** `docs/BLUEPRINT-MODES.md`, `README.md`, `commands/README.md`
**Complexity:** Low
**TDD:** false
**Description:** Rewrite BLUEPRINT-MODES.md to add critique section and update comparison table. Update README.md challenge mode descriptions and agent counts.
**Dependencies:** WU-6
**Acceptance Criteria:**
- AC-39: BLUEPRINT-MODES.md has critique mode section with full architecture description
- AC-40: Comparison table updated (5 modes: vanilla, debate, critique, family-deprecated, team)
- AC-41: FAQ updated with critique-specific entries
- AC-42: README.md agent counts and mode descriptions updated

### WU-10: Test Updates
**Files:** `test.sh`, `evals/evals.json`
**Complexity:** Low
**TDD:** false
**Description:** Update test.sh checks that reference family mode. Update evals if behavioral fixtures reference family mode.
**Dependencies:** WU-9
**Acceptance Criteria:**
- AC-43: test.sh passes with critique as default mode
- AC-44: No hardcoded "family" references in test assertions (unless testing deprecation path)
- AC-45: Eval fixtures updated if they reference family mode

---

## Work Graph

```json
{
  "units": {
    "WU-1": { "depends_on": [], "complexity": "medium", "batch": 1 },
    "WU-2": { "depends_on": ["WU-1"], "complexity": "high", "batch": 2 },
    "WU-3": { "depends_on": ["WU-2"], "complexity": "high", "batch": 3 },
    "WU-4": { "depends_on": ["WU-3"], "complexity": "medium", "batch": 4 },
    "WU-5": { "depends_on": ["WU-4"], "complexity": "high", "batch": 5 },
    "WU-6": { "depends_on": ["WU-5"], "complexity": "medium", "batch": 6 },
    "WU-7": { "depends_on": ["WU-6"], "complexity": "low", "batch": 6 },
    "WU-8": { "depends_on": ["WU-5"], "complexity": "low", "batch": 6 },
    "WU-9": { "depends_on": ["WU-6"], "complexity": "low", "batch": 7 },
    "WU-10": { "depends_on": ["WU-9"], "complexity": "low", "batch": 7 }
  },
  "critical_path": ["WU-1", "WU-2", "WU-3", "WU-4", "WU-5", "WU-6", "WU-9", "WU-10"],
  "max_parallelism": 3,
  "batches": [
    { "batch": 1, "units": ["WU-1"] },
    { "batch": 2, "units": ["WU-2"] },
    { "batch": 3, "units": ["WU-3"] },
    { "batch": 4, "units": ["WU-4"] },
    { "batch": 5, "units": ["WU-5"] },
    { "batch": 6, "units": ["WU-6", "WU-7", "WU-8"] },
    { "batch": 7, "units": ["WU-9", "WU-10"] }
  ]
}
```

**Parallelization note:** Batch 6 has width 3 (WU-6, WU-7, WU-8 can run in parallel after WU-5). Batch 7 has width 2 (WU-9, WU-10 can run in parallel after batch 6). Critical path is 8 units long.

---

## Open Questions

1. **OQ-1: Refine confidence thresholds** — 0.4-0.6 mid-range is proposed but not empirically validated. May need adjustment after first real-world use.
2. **OQ-2: Orient context brief length** — 500 words may be too tight for complex specs with rich vault history. Monitor and adjust.
3. **OQ-3: Anonymization effectiveness** — Does stripping perspective labels actually reduce sycophancy in practice? Literature says yes, but our context (same-model agents) may differ.
