---
description: You MUST use this for ANY non-trivial implementation task. Skipping planning leads to confident mistakes that cost more to fix than to prevent.
arguments:
  - name: name
    description: Name for this blueprint (required for new, optional to resume)
    required: false
  - name: challenge
    description: "Challenge mode: vanilla, debate, family (default), team"
    required: false
  - name: parallel
    description: "Parallelization: sequential, parallel, auto (default)"
    required: false
---

## Cognitive Traps

Before skipping or simplifying this command, check yourself:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "This is too simple for a blueprint" | Simple tasks have the highest confident-mistake rate. The describe stage takes 2 minutes. The mistake it prevents takes 20. |
| "I'll just do it and fix issues later" | Fixing is always more expensive than preventing. You're trading 5 minutes of planning for 30 minutes of debugging. |
| "The user seems to want speed" | The user wants *correct results* quickly. A fast wrong answer wastes more time than a slightly slower right one. |
| "I already explored this in conversation" | Conversation exploration ≠ structured decomposition. The blueprint forces you to make implicit assumptions explicit. |

# Blueprint

Guided planning workflow that walks through all stages. Use this for full planning discipline, or when you want the toolkit to guide you through the right steps.

> **Note:** Storage directory is `.claude/plans/` (not `.claude/blueprints/`).
> This is intentional — the directory stores both blueprint artifacts and general
> planning state. See `docs/PLANNING-STORAGE.md` for details.

## Overview

```
Stage 1: Describe    → /describe-change (triage, path, execution_preference)
Stage 2: Specify     → /spec-change (spec + work units + work graph)
Stage 3: Challenge   → Family (default) / Vanilla / Debate / Agent team
Stage 4: Edge Cases  → Family (default) / Vanilla / Debate / Agent team
Stage 4.5: Pre-Mortem → Operational failure exercise
Stage 5: Review      → /gpt-review (external perspective) [optional]
Stage 6: Test        → /spec-to-tests (spec-blind tests)
Stage 7: Execute     → Implementation (with manifest handoff + work graph)
Stage 8: Debrief     → Completion ceremony (ship ref, spec delta, discoveries)

Cross-cutting:
  - Feedback loops (regression from any stage to any earlier stage, max 3)
  - HALT state with escape hatches (when regressions exhausted + low confidence)
  - Confidence scoring (per-stage, epistemic-tracking-backed, advisory + trigger gated)
  - Manifest (token-dense recovery, updated every stage, corruption recovery)
  - Work graph (parallelization, computed in Stage 2, checksum validated)
  - Spec diffs (revision tracking on regression)
  - Debate output schema (JSON validated, vanilla fallback on parse failure)
  - Pre-v2 migration (auto-detect and apply defaults)
```

## Process

### Pre-Stage: Before Starting

#### Research Brief Detection (Optional Enrichment)

Before showing pre-stage suggestions, check for a research brief:

1. Check `.claude/plans/[name]/research.md` for direct path match
2. If not found: search `.claude/plans/*/research.md` for briefs where `linked_blueprint` matches this blueprint name
3. If mismatch (brief exists at different path but `linked_blueprint` matches): prompt user to confirm

**If research brief found:**
```
Research brief detected: .claude/plans/[name]/research.md
  Coverage: [brainstorm ✓/✗] [prior-art ✓/✗] [requirements ✓/✗]
  Gate score: [X/5.0]  Mode: [quick/standard/deep]

  Investigative steps covered by research — skipping pre-stage suggestions.
  /design-check remains available if needed (implementation readiness).

Proceeding to Stage 1: Describe (solution scoping).
```

Re-check for research brief at the start of each stage (not just first invocation), so mid-session research is consumed on the next stage transition.

**If no research brief found:**
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

This is a soft nudge — never blocks progress. Displayed once per blueprint invocation.

### Vault Awareness (if vault available)

Before starting Stage 1, search the vault for prior knowledge relevant to this blueprint:

1. Source vault config:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null
   ```
2. If vault available, search for notes related to the blueprint topic:
   - Use Grep to search `$VAULT_PATH` for the blueprint name and key terms across findings, decisions, and patterns
   - Present any matches: "Vault has N notes that may be relevant to this work:"
   - List matches with titles and 1-line summaries
   - If a prior decision or pattern directly applies, highlight it
3. If vault unavailable, skip silently (fail-open)

This is advisory — it surfaces context, not gates progress.

### Starting or Resuming

**New blueprint:**
```
/blueprint feature-auth
/blueprint feature-auth --challenge=debate
/blueprint feature-auth --challenge=vanilla
/blueprint feature-auth --challenge=family
/blueprint feature-auth --challenge=team
```

Creates `.claude/plans/feature-auth/` and starts at Stage 1.

**Name collision handling:** If `.claude/plans/[name]/` already exists:
- If `execute.status === "complete"`: prompt "[1] Create '[name]-2', [2] View existing, [3] Archive and recreate"
- If in-progress: resume from current stage
- Never silently overwrite

**Resume existing:**
```
/blueprint feature-auth
```

If blueprint exists, read `manifest.json` for efficient context recovery (NOT full markdown).
**On resume, the challenge mode is ALWAYS read from `state.json` `challenge_mode` field, NOT from the command's YAML frontmatter default.** This ensures that a blueprint created with `--challenge=debate` before the default changed to family continues using debate mode.
Show current stage and resume.

**List all blueprints:**
```
/blueprints
```

### Bootstrap (First-Ever Blueprint)

If `.claude/plans/` directory doesn't exist, bootstrap:

1. Create `.claude/plans/` directory
2. Create blueprint subdirectory
3. Initialize state.json with defaults
4. Initialize epistemic session (auto-created by `epistemic-preflight.sh` hook)
5. Proceed to Stage 1

Each step is idempotent — check existence before creating.

### Challenge Mode Selection

The challenge mode is selected once at blueprint creation and **locked for the blueprint lifecycle**.
It applies to both Stage 3 (Challenge) and Stage 4 (Edge Cases).

```
/blueprint feature-auth                      # family mode (DEFAULT)
/blueprint feature-auth --challenge=vanilla  # original single-agent
/blueprint feature-auth --challenge=debate   # sequential debate chain
/blueprint feature-auth --challenge=family   # generational debate (deep specs)
/blueprint feature-auth --challenge=team     # agent team (experimental)
```

The mode is stored in `state.json` as `"challenge_mode"`. On regression, the same mode is reused.

### Pre-v2 Migration

When resuming a blueprint that lacks `blueprint_version` in state.json:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  MIGRATION │ [name] upgraded to Blueprint v2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Applied defaults:
    - Challenge mode: vanilla (original behavior)
    - Pre-mortem: skipped (pre-v2 plan)
    - Manifest: generated from existing artifacts
    - Epistemic tracking: not connected (optional for migrated plans)

  Your existing artifacts and progress are unchanged.
  The blueprint will continue from its current stage.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Apply defaults: `blueprint_version: 2`, `challenge_mode: "vanilla"`, `execution_preference: "auto"`,
`epistemic_session_id: null`, `manifest_stale: false`, `work_graph_stale: false`,
`premortem: { "status": "skipped", "skip_reason": "created before blueprint-v2" }`.

Generate manifest.json from existing artifacts. Set `blueprint_version: 2`.

### Stage Navigation

Present the current stage header:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage [N] of 8: [Stage Name]
  Mode: [vanilla/debate/team] │ Revision: [N] │ Confidence: [score]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stages:
  ✓ 1. Describe     [completed timestamp]
  ✓ 2. Specify      [completed timestamp]  (rev [N])
  → 3. Challenge    ← You are here
  ○ 4. Edge Cases
  ○ 4.5 Pre-Mortem
  ○ 5. Review       (optional)
  ○ 6. Test
  ○ 7. Execute
  ○ 8. Debrief

Commands:
  'next'     Advance to next stage (requires current stage complete)
  'back'     Return to previous stage
  'skip'     Skip current stage (requires reason)
  'status'   Show progress
  'exit'     Exit wizard (progress saved)
  'reset [stage]'  Jump to earlier stage (triggers regression)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Stage Execution

Each stage invokes its corresponding command or inline logic:

| Stage | Command | Can Skip? | Auto-skipped When |
|-------|---------|-----------|-------------------|
| 1. Describe | `/describe-change` | No | Never |
| 2. Specify | `/spec-change` | Yes | Light path |
| 3. Challenge | See Challenge Modes below | Yes | Light/Standard path |
| 4. Edge Cases | See Challenge Modes below | Yes | Light/Standard path |
| 4.5. Pre-Mortem | Inline (see below) | Recommended | Light/Standard path |
| 5. Review | `/gpt-review` | Yes | Always optional |
| 6. Test | `/spec-to-tests` | Yes | Light path |
| 7. Execute | Exit wizard | No | Never |
| 8. Debrief | Inline (see below) | No | Never |

### Solution-Clarity Gate (Between Stage 1 → Stage 2)

After Stage 1 (Describe) completes and before Stage 2 (Specify) begins, run a **solution-clarity** check on the description output. This front-loads ambiguity detection before it becomes baked into the spec.

> **Note:** This gate focuses on solution clarity — "is the desired outcome clear enough to specify?"
> Problem-space clarity is the concern of `/research` (which has its own problem-clarity gate).
> If a research brief was consumed in the pre-stage, the problem space has already been validated.
> This gate checks only whether the solution scope is well-defined.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AMBIGUITY CHECK │ Before proceeding to Specify
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Scoring the description across three dimensions:

  Goal Clarity       [?/5] — Is the desired outcome unambiguous?
                              Can two people read this and agree
                              on what "done" looks like?

  Constraint Clarity  [?/5] — Are boundaries explicit?
                              What's in scope vs out of scope?
                              What can't change?

  Success Criteria    [?/5] — Are acceptance criteria testable?
                              Could you write a test for "done"
                              without asking clarifying questions?

  Composite Score: [weighted average] / 5.0
    (Goal: 40%, Constraint: 30%, Success: 30%)

  Threshold: >= 3.5 to proceed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Gate Behavior

| Score | Action |
|-------|--------|
| >= 3.5 | Pass. Proceed to Specify. |
| 2.5 - 3.4 | Warn. Present specific ambiguities. Ask user to clarify OR override with reason. |
| < 2.5 | Block. "This description isn't ready for specification. Here's what's unclear: [list]." User must clarify or explicitly override. |

**Override mechanism:** User can always say "proceed anyway" — logged in `state.json` as `ambiguity_gate` object with scores, composite, result, override flag, and override_reason.

#### Scoring Prompt (Internal)

Claude scores itself using this internal prompt (not shown to user):

```
Review the describe stage output and score each dimension 1-5:

GOAL CLARITY (1-5):
  1 = Vague aspiration. Example: "Make auth better"
  2 = General direction but ambiguous outcome. Example: "Add token refresh"
  3 = Clear outcome, some interpretation needed. Example: "Add JWT refresh tokens so sessions don't expire during use"
  4 = Specific outcome, minimal ambiguity. Example: "Add JWT refresh token rotation with configurable expiry"
  5 = Unambiguous, two people would agree on "done". Example: "Add JWT refresh token rotation: 7-day expiry, sliding window, revocation on password change"

CONSTRAINT CLARITY (1-5):
  1 = No constraints mentioned. Example: (nothing about scope, compatibility, or limits)
  2 = Implied constraints only. Example: "Should work with existing auth" (what existing auth?)
  3 = Some explicit constraints, gaps remain. Example: "Must work with our Express middleware. No breaking API changes."
  4 = Clear boundaries, scope defined. Example: "In scope: token rotation. Out of scope: SSO, OAuth providers. Must maintain backwards compat with v2 API."
  5 = Explicit in/out scope, unchangeables named. Example: Full scope table with explicit "will not change" list.

SUCCESS CRITERIA (1-5):
  1 = No criteria. Example: "It should work"
  2 = Subjective criteria. Example: "Auth should feel seamless"
  3 = Some testable criteria, some subjective. Example: "Tokens refresh without user action; auth feels smooth"
  4 = Mostly testable criteria. Example: "Refresh token issued on login; auto-refreshes when access token < 5min from expiry; refresh token rotated on each use"
  5 = All criteria are testable assertions. Example: Each criterion maps to a specific test case with inputs and expected outputs.

For each dimension, cite the specific text from the describe output that supports your score.
If you can't find supporting text, that IS the score evidence (it's missing).
IMPORTANT: Compare the describe output to the calibration examples above. Your score should match the example level that most closely resembles the text.
```

#### Light Path Behavior

On Light path, run a **shortened gate**: score Goal Clarity only (the single most impactful dimension). If Goal Clarity < 3, warn. This catches "make it better" descriptions without the full 3-dimension overhead.

**Known gap:** Constraint Clarity and Success Criteria are intentionally not checked on Light path.

### Prior Art Gate (Between Stage 1 → Stage 2) — Conditional

After the Solution-Clarity Gate passes and before Stage 2 (Specify) begins, the prior-art gate runs **conditionally based on research brief coverage**.

**If research brief present with `coverage.prior_art: true`:**
- Prior art was done during research. Skip the gate.
- Record in state.json: `"prior_art_gate": { "status": "covered-by-research", "research_brief": ".claude/plans/[name]/research.md" }`

**If no research brief OR `coverage.prior_art: false`:**
- Run `/prior-art` inline with the problem description from describe.md
- Write output to `.claude/plans/[name]/prior-art.md`
- Gate behavior:
  - **Adopt** recommendation → prompt user to supersede blueprint or continue
  - **Adapt/Inform/Build** → proceed to Stage 2, prior-art report available as context
- Record in state.json: `"prior_art_gate": { "status": "complete", "recommendation": "[adopt/adapt/inform/build]", "override": false, "run_at": "YYYY-MM-DDTHH:MM:SSZ" }`

On Light path: skip prior-art gate entirely (Light path skips Stages 2-6, prior art is a pre-Stage-2 gate).
On Standard/Full path: conditional as described above.

If WebSearch is unavailable: log skip with reason, proceed to Stage 2.

**Backward compatibility:** If state.json has no `prior_art_gate` key AND the current stage is >= 2 (Specify), treat the gate as already passed: set `"prior_art_gate": { "status": "legacy-skipped", "reason": "pre-feature blueprint — stage already past gate" }` and proceed without prompting. Only enforce the gate on blueprints that have not yet reached Stage 2.

### Path-Based Stage Selection

After Stage 1 (Describe), the triage result determines the path:

**Light Path:** 1 → 7 (describe → execute)
- Stages 2-6 auto-skipped
- Quick preflight recommended but not required

**Standard Path:** 1 → 2 → 7 (describe → specify → execute)
- Stages 3-6 optional
- Preflight recommended

**Full Path:** 1 → 2 → 3 → 4 → 4.5 → 5 → 6 → 7 (all stages)
- Stage 5 (Review) always optional
- Stage 4.5 (Pre-Mortem) elevated — skip triggers regression warning before Stage 5
- Other stages recommended

---

## EPISTEMIC TRACKING ENFORCEMENT

When this workflow is active, you MUST track epistemic state at each stage transition.
This is not optional. The confidence data feeds regression decisions.
The blueprint-stage-gate hook will flag missing epistemic data.

**Before starting Stage 1:**
- The `epistemic-preflight.sh` SessionStart hook auto-creates a session in `~/.claude/.current-session`
- Run `/epistemic-preflight` for honest self-assessment
- Store session_id in state.json under `epistemic_session_id`
- Store session_id in manifest.json under `epistemic_session_id` (dual storage)
- Set `epistemic_preflight_complete: true` in state.json

**After completing each stage:**
- Append a finding summary to `.epistemic/insights.jsonl`
- Record confidence score (0.0-1.0) in state.json under `stages.[name].confidence`
- Include `confidence_note` explaining the score
- Update manifest.json

**On regression:**
- Log the mistake to `.epistemic/insights.jsonl` with type "mistake" if caused by error in judgment
- Log the dead-end to `.epistemic/insights.jsonl` with type "deadend" if an approach failed

**After Stage 7 complete (or workflow abandoned):**
- Run `/epistemic-postflight`

**Session recovery:** If session_id is missing on resume:
1. Check state.json first, then manifest.json
2. If both missing: read `~/.claude/.current-session` for the active session
3. Log discontinuity: `"epistemic_session_note": "Continuation session — original lost"`

---

## MANIFEST ENFORCEMENT

After every stage completion, update `manifest.json`. This is the token-dense recovery
format — see `docs/PLANNING-STORAGE.md` for the full schema.

**On resume:** Read manifest.json (NOT full markdown artifacts) for context recovery.
Only read full artifacts when the current stage's work requires them.

**On write failure:** Set `manifest_stale: true` in state.json, preserve `manifest.json.bak`,
block stage progression until resolved.

**On read failure (corruption):** Attempt regeneration from source artifacts
(describe.md + spec.md + adversarial.md + state.json). If regeneration fails, halt with error.

---

## Challenge Modes

### Vanilla Mode

Identical to the original behavior. A single agent runs `/devils-advocate` (Stage 3)
and `/edge-cases` (Stage 4) sequentially. One perspective per stage.

Output: Findings appended to `adversarial.md` as before.

### Debate Mode

A three-round sequential critique chain using subagents. Each round's agent sees all
prior rounds' output, creating escalating context.

**Timeout protection:** Each debate subagent has a 5-minute timeout. Each stage (3 rounds)
has a 15-minute total timeout. On timeout: log a dead-end to `.epistemic/insights.jsonl`, fall back to
vanilla mode for the remainder of that stage, preserve any completed rounds.

**Cascading timeout behavior:** The stage timeout (15 min) is the outer envelope. If Round 1
times out, remaining time for fallback = stage_timeout - elapsed. If remaining < 2 min,
skip stage entirely with `confidence: 0.3` and note "timeout, no adversarial review completed."

**Debate round progress tracking:** Store in state.json:
```json
{
  "debate_progress": {
    "rounds_completed": ["challenger"],
    "current_round": "defender"
  }
}
```
On resume, skip completed rounds and continue from `current_round`.

#### Stage 3 (Challenge) Debate

```
Round 1 — Challenger (subagent, sonnet)
  Sees: spec.md
  Prompt: "You are an adversarial reviewer. Find the weakest assumptions
  in this specification. What would a hostile user exploit? What breaks
  at scale? What breaks under network failure? What's underspecified?
  Produce a numbered list of findings with severity ratings."

Round 2 — Defender (subagent, sonnet)
  Sees: spec.md + Round 1 output
  Prompt: "You are a specification defender. Review these challenges.
  For each finding:
    - VALID: Confirm it's a real risk. Suggest mitigation.
    - OVERSTATED: Explain why the risk is lower than claimed.
    - FALSE: Explain why this isn't actually a problem.
  Then: What did the Challenger MISS? Add any new findings."

Round 3 — Judge (subagent, sonnet)
  Sees: spec.md + Round 1 + Round 2
  Prompt: "You are the final judge. Synthesize the debate into a
  verdict. For each finding, rate:
    - Severity: critical / high / medium / low
    - Convergence: both-agreed / disputed / newly-identified
    - Addressed: already in spec / needs spec update / needs new section
  Produce the final findings list, ordered by severity.

  OUTPUT FORMAT: You MUST produce your verdict as a JSON object with
  this structure:
  {
    \"findings\": [
      {
        \"id\": \"F1\",
        \"finding\": \"description\",
        \"severity\": \"critical|high|medium|low\",
        \"convergence\": \"both-agreed|disputed|newly-identified\",
        \"addressed\": \"already-in-spec|needs-spec-update|needs-new-section\"
      }
    ],
    \"verdict\": \"PASS|PASS_WITH_NOTES|REGRESS\",
    \"critical_count\": 0,
    \"regression_target\": \"specify\"
  }

  Verdict meanings:
    PASS = no critical findings, proceed
    PASS_WITH_NOTES = non-critical findings only, proceed normally, append to adversarial.md
    REGRESS = has critical findings that need spec changes"
```

#### Stage 4 (Edge Cases) Debate

```
Round 1 — Boundary Explorer (subagent, sonnet)
  Sees: spec.md + adversarial.md (from Stage 3)
  Prompt: "Map every boundary in this specification: input boundaries
  (empty, single, limit, over-limit, malformed), state boundaries
  (transitions, cold starts, restarts), concurrency boundaries
  (simultaneous, interrupted, stale), time boundaries (zones, skew,
  DST, leap). List each boundary with its expected behavior."

Round 2 — Stress Tester (subagent, sonnet)
  Sees: spec.md + adversarial.md + Round 1
  Prompt: "For each boundary identified, describe what happens at:
  the value just below, at, just above, and far beyond the boundary.
  Which of these are handled in the spec? Which are unspecified?
  Which would cause data loss, security issues, or silent corruption?"

Round 3 — Synthesizer (subagent, sonnet)
  Sees: spec.md + adversarial.md + Round 1 + Round 2
  Prompt: "Produce the final edge case report. For each edge case:
    - Impact: critical / high / medium / low
    - Likelihood: common / uncommon / rare / theoretical
    - Priority: impact x likelihood ranking
    - Addressed: yes (cite spec section) / no (needs spec update)
  Order by priority. Flag any edge case that implies an architectural
  change (potential regression trigger).

  OUTPUT FORMAT: You MUST produce your findings as a JSON object
  following the debate output schema (see PLANNING-STORAGE.md)."
```

#### Debate Output Processing

The Judge/Synthesizer output is processed as follows:

1. **Parse JSON:** Extract the structured findings from the output
2. **Schema validation:** Verify required fields (id, finding, severity, convergence, addressed)
3. **If valid:** Use structured data for regression trigger evaluation
4. **If invalid (parse failure):** Fall back to vanilla mode processing:
   - Extract numbered list items via pattern matching (`F[0-9]+`, `[0-9]+.`, `-`)
   - Assign all findings: severity=medium, convergence=newly-identified
   - If no list items found, wrap entire output as single finding
   - Log warning to `.epistemic/insights.jsonl` as dead-end
   - Flag all extracted findings for human review

The curated output goes to `adversarial.md` (canonical source of truth).
Raw debate transcript preserved in `debate-log.md` (debug artifact only).

### Family Mode (Default — Generational Debate)

A six-role generational debate architecture with three tiers. Designed for deep specification
review where the dialectical (thesis/antithesis/synthesis) approach produces better results
than adversarial (winner/loser) debate. Best for major blueprints on the Full path.

```
┌─────────────────────────────────────────────────┐
│  GENERATION 1: CHILDREN (parallel)              │
│                                                 │
│  Child-Defend          Child-Assert             │
│  "The spec works       "The spec needs          │
│   because..."           change because..."      │
└────────────────────┬────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────┐
│  GENERATION 2: PARENTS (serial)                 │
│                                                 │
│  Mother                Father                   │
│  "Both children        "But these               │
│   have merit..."        weaknesses remain..."   │
│                        → Refined spec            │
└────────────────────┬────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────┐
│  GENERATION 3: ELDERS (combined)                │
│                                                 │
│  Elder Council                                  │
│  Queries Obsidian vault for historical          │
│  analogies. Issues convergence verdict.         │
│                                                 │
│  CONVERGED → Stop                               │
│  CONTINUE  → Inject history, loop to Children   │
└─────────────────────────────────────────────────┘
```

#### Family Mode Agent Specifications

**Child-Defend** (subagent, sonnet):
A steelman advocate who finds the strongest possible case FOR the spec. Not a sycophant —
builds rigorous arguments from evidence. Receives `spec.md` independently.

```
You are the Defender of this specification. Your job is to steelman it —
find the strongest possible case FOR this plan.

For each major design decision in the spec:
  - What design choices are correct that a casual reader might question?
  - What constraints are handled that aren't obvious?
  - What alternatives were implicitly rejected, and why is this better?
  - What strengths would be LOST if this section were changed?

You are not a yes-man. If a section is genuinely weak, you may
acknowledge it — but even then, articulate the intent behind it and
why that intent matters, even if the execution needs work.

Produce a numbered list of defended positions, each with:
  - The decision being defended
  - The strongest argument FOR it
  - What would be lost without it
```

**Child-Assert** (subagent, sonnet):
A passionate challenger who believes the spec needs change. Not hostile — motivated by
wanting the project to succeed. Receives `spec.md` independently (same input, parallel).

```
You are the Challenger of this specification. You believe this plan
has real problems that need addressing before implementation.

For each concern you identify:
  - What SPECIFICALLY is wrong or missing?
  - What's the realistic failure scenario if this isn't addressed?
  - How confident are you this is a real risk vs theoretical?

Prioritize REAL risks over theoretical ones. A challenger who cries wolf
about everything is useless. Focus on the findings that would actually
cause pain.

Produce a numbered list of challenges, each with:
  - The specific concern
  - The failure scenario
  - Confidence: HIGH (seen this fail before) / MEDIUM (plausible) / LOW (theoretical)
```

**Mother — Strength Synthesizer** (subagent, sonnet):
Sees merit in both children's positions, even when they contradict. Her gift is finding the
hidden value in each argument. Receives `spec.md` + both children's outputs.

```
You are the Synthesizer. You have received two opposing perspectives
on this specification — one defending it, one challenging it.

You see value in BOTH positions. Your job is to extract what's WORTH
KEEPING from each perspective.

For each pair of opposing points:
  - What is the defender RIGHT about?
  - What is the challenger RIGHT about?
  - Is there a way BOTH can be true? (Often the defender identifies
    a real strength AND the challenger identifies a real gap in
    the same area.)

For points where only one child engaged:
  - Is the defender celebrating something that masks a weakness?
  - Is the challenger attacking something that's actually a strength?

Produce a synthesis that maps: defender-point → challenger-point →
what's genuinely strong → what genuinely needs work.

Do NOT pick winners. Extract the best from both.
```

**Father — Weakness Analyst & Guide** (subagent, sonnet):
Loves the project, wants it to succeed. Finds weaknesses not to criticize but to strengthen.
Offers direction, never implementation. Receives `spec.md` + Mother's synthesis.

```
You are the Guide. You receive a synthesis of strengths and genuine
concerns about this specification.

Your job is to find what BREAKS — not to attack, but to strengthen.

For each item the synthesis identified as "genuinely needs work":
  - Does this need a spec change, or is it acceptable risk?
  - If it needs a change: what DIRECTION should the change take?
    (Do NOT write the implementation. Point the way.)
  - If it's acceptable risk: why? What makes it tolerable?

For items the synthesis identified as "genuinely strong":
  - Do you agree? Or is this strength masking a subtle weakness?
  - Are there operational implications the synthesis didn't consider?

If any position from either child is truly untenable, say so clearly
but explain WHY it doesn't hold — not just that it's wrong.

Produce:
1. A refined spec summary — what should change and what should stay
2. For each proposed change: direction only (not implementation)
3. A confidence assessment: how close is this spec to ready?
4. Any unresolved tensions that need another round of discussion
```

**Elder Council — Historical Validator** (subagent, opus):
The wisdom of accumulated project experience. Speaks with quiet authority grounded in
"we've seen this before." Receives `spec.md` + Father's analysis. Queries Obsidian vault.

Tools required: Obsidian MCP (vault query), Read, Grep, Glob

```
You are the Elder Council. You bring the wisdom of past projects to
this specification review.

FIRST: Query the Obsidian vault for relevant history.

Search for (limit each query to 5 most relevant results):
  1. Past blueprints with similar scope or technology:
     - Use mcp__obsidian__search_notes with terms from the spec's
       key technologies, patterns, and domain
     - Check Engineering/Blueprints/ for prior work
  2. Past findings that relate to this spec's risk areas:
     - Check Engineering/Findings/ for relevant discoveries
  3. Past decisions that set precedent:
     - Search for decision records related to this domain

If no relevant vault results are found for any query:
  - Note: "No historical precedent found — evaluating on
    analytical merits only"
  - This is normal for novel work. Do NOT treat absence of
    history as a red flag.

If the Obsidian vault is unavailable (MCP error, vault not mounted):
  - Note: "Historical review limited — vault unavailable"
  - Compensate by drawing on general software engineering principles
    and common failure patterns for this type of system. Ask:
    "What patterns from software engineering generally apply here?"
    "What are the common failure modes for this kind of change?"
  - Do NOT block the review

WITH HISTORICAL CONTEXT (or without, if unavailable):

For each of Father's proposed changes:
  - Does history SUPPORT this direction? (Past success with similar approach)
  - Does history WARN against it? (Past failure with similar approach)
  - Is this genuinely novel? (No historical analogue found)

Weight recent findings (last 6 months) more heavily. Note the age of
any historical source cited.

For the spec's overall approach:
  - Have we attempted something structurally similar before?
  - What worked? What didn't?
  - What would we tell our past selves about this kind of project?

CONVERGENCE VERDICT:
  CONVERGED — The spec addresses historical risks, Father's changes
    are well-directed, and no historical red flags remain.
  CONTINUE — [specific unresolved tension] needs another round.
    Inject this historical context into the next cycle:
    [specific vault findings to carry forward]
    NOTE: If CONTINUE, carry_forward MUST contain specific context.
    Empty carry_forward invalidates CONTINUE — treat as CONVERGED.

You MUST justify your verdict with specific evidence (vault results
or analytical reasoning). "It feels ready" is not sufficient.

OUTPUT FORMAT:
{
  "historical_analogies": [
    {
      "source": "vault path or 'analytical'",
      "relevance": "description",
      "lesson": "what it teaches us here",
      "supports_or_warns": "supports|warns|neutral"
    }
  ],
  "father_review": [
    {
      "proposed_change": "description",
      "historical_support": "supported|warned|novel",
      "evidence": "source or reasoning"
    }
  ],
  "verdict": "CONVERGED|CONTINUE",
  "confidence": 0.0-1.0,
  "continue_reason": "null or specific tension",
  "carry_forward": "null or historical context for next round"
}
```

#### Elder Output Processing

The Elder Council's JSON output is processed with the same fallback chain as debate mode:

1. **Parse JSON:** Extract structured verdict
2. **Schema validation:** Verify required fields (verdict, confidence, historical_analogies)
3. **If valid:** Use structured data for convergence decision
4. **If invalid (parse failure):** Fall back:
   - Search for "CONVERGED" or "CONTINUE" keywords in raw output
   - If found: use keyword as verdict, set confidence to 0.5
   - If neither found: treat as CONVERGED with confidence 0.4 and flag for human review
   - Log warning to `.epistemic/insights.jsonl` as dead-end

#### Family Mode Loop Control

**Round structure:**
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

**Complexity-adaptive round limits:**

The maximum number of rounds scales with spec complexity, derived from the work graph:

| Signal | Condition | Max Rounds |
|--------|-----------|------------|
| Simple | ≤3 WUs AND no High-complexity WUs | 1 |
| Medium | 4-5 WUs OR 1+ High-complexity WU | 2 |
| Complex | ≥6 WUs | 3 |

The signal is computed from `work-graph.json` at the start of Stage 3/4.
Users can override with `--rounds=N` if needed.

**Progress checks (liveness probes):**

Family mode uses progress checks instead of hard timeouts for rounds and totals.
The design principle: don't cap how long the cooking takes — verify the cooking continues.

- **Per-agent liveness check:** 3 minutes. An individual agent that produces nothing for
  3 minutes is stuck, not thorough. On timeout: kill agent, log dead-end to
  `.epistemic/insights.jsonl`, skip that agent's contribution, continue with remaining agents.
- **Between agents:** After each agent completes (or times out), verify output was produced.
  Output received → progress confirmed, continue to next agent. No output (timeout) → skip + log.
- **Between rounds:** The Elder Council's convergence verdict (CONVERGED/CONTINUE) is itself
  a progress check. CONVERGED stops the loop. CONTINUE advances to the next round.
- **Round count limit:** Bounds total work by the complexity-adaptive table above, not wall time.
  On max rounds exhausted without convergence: force CONVERGED with `confidence: 0.3`.
- **No per-round or total hard timeouts.** A round that takes 15 minutes because the Elder
  Council did a thorough vault search is fine if it's producing output.

**Convergence conditions** (Elder Council must satisfy ALL):
1. No historical red flags remain unaddressed
2. Father's proposed changes are directionally sound (historically supported or genuinely novel)
3. No critical unresolved tensions between children's positions

**Asymmetric child output:** If one child agent times out but the other completes, Mother
receives the surviving child's output with a note: "The opposing perspective (defend/assert)
was unavailable due to timeout." Mother should attempt synthesis by playing devil's advocate
against the surviving position.

**Empty carry-forward guard:** If Elder Council issues CONTINUE but provides empty or null
`carry_forward`, treat as CONVERGED. A CONTINUE without specific context for the next round
would cause children to repeat themselves. Log to `.epistemic/insights.jsonl`.

#### Family Mode Output

Each agent's output is written to `debate-log.md` immediately upon completion (not batched
at round end). This protects against mid-round context compaction:
1. Agent completes → append output to `debate-log.md` with agent label and round number
2. Update `family_progress.agents_completed` in `state.json`
3. On resume after compaction: read completed agents' outputs from `debate-log.md`

Curated output in `adversarial.md` uses this format per round:

```markdown
## Family Round [N]

### Synthesis (Mother)
[Strength extraction from both children]

### Analysis (Father)
[Weakness findings + directional guidance]

### Historical Review (Elder Council)
[Vault findings + convergence verdict]

| Vault Source | Lesson | Relevance |
|---|---|---|
| [path] | [lesson] | supports/warns/neutral |

**Elder Verdict:** CONVERGED / CONTINUE
**Confidence:** [0.0-1.0]
**Carry Forward:** [context for next round, if continuing]
```

#### Family Mode Progress Tracking

`family_progress` is initialized fresh at the start of each stage (Stage 3 and Stage 4
each get their own 3-round budget).

Store in `state.json`:
```json
{
  "family_progress": {
    "stage": "challenge",
    "round": 1,
    "agents_completed": ["child_defend", "child_assert", "mother"],
    "current_agent": "father",
    "rounds_total": 1,
    "elder_verdicts": []
  }
}
```

On resume, skip completed agents and continue from `current_agent`.

#### Family Mode for Stage 3 vs Stage 4

Both stages use the same architecture but with shifted focus:

**Stage 3 (Challenge):** Children debate **design decisions**. Mother synthesizes design
strengths. Father finds design weaknesses. Elders validate against historical design decisions.

**Stage 4 (Edge Cases):** Children debate **boundary behavior**. Child-Defend argues
boundaries and error handling are sufficient. Child-Assert finds inputs, states, and
conditions that will break the system. Mother synthesizes boundary coverage strengths.
Father finds boundary gaps. Elders validate against historical edge case discoveries.

Mother, Father, and Elder prompts remain the same — they naturally adapt based on what
the children present.

#### Family Mode Regression Triggers

Same rules as debate mode:
- Elder Council rates any finding as critical + unaddressed → suggest regression to Stage 2
- Father identifies architectural change needed → suggest regression to Stage 2
- All regression prompts follow existing blueprint regression flow

Additional family-specific trigger:
- If Elder Council issues CONTINUE verdict 3 times (max rounds exhausted), force convergence
  but set `confidence: 0.3` and suggest regression if any critical items remain unaddressed.

### Team Mode (Opt-in, Experimental)

Requires `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`. If not set and user requests `--challenge=team`:

```
Agent team challenge mode requires the experimental agent teams flag.

To enable, add to your settings.json:
  "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" }

Falling back to debate mode (sequential challenge chain).
```

When available, spawns an agent team with three teammates:

```
Teammates:
  Red Team    — Attack vectors, security assumptions, trust boundaries
  Skeptic     — Complexity, YAGNI, hidden coupling, maintainability
  Pragmatist  — Operational reality, deployment risks, monitoring gaps
```

The teammates receive the spec and are instructed to:
1. Independently review and produce findings (Round 1)
2. Read each other's findings and respond — agree, disagree, or build on (Round 2)
3. Converge on a consensus findings list (Round 3)

The lead synthesizes the final output.

Output: Same format as debate mode — curated findings to `adversarial.md`, full transcript to `debate-log.md`.

### Post-Challenge: Complexity Check

After the challenge mode completes (regardless of mode), run `/overcomplicated` on the spec.
This checks whether the spec has become over-engineered through the adversarial process — a
common failure mode where addressing every challenge bloats the spec beyond what's necessary.

The `/overcomplicated` output is appended to `adversarial.md` under `## Complexity Review`.
If it identifies elements marked "Remove" or "Simplify", these are presented to the user but
do NOT auto-trigger regression. The user decides whether to simplify.

---

## Pre-Mortem (Stage 4.5)

### Scope

Pre-mortem focuses on **OPERATIONAL failures** — things that go wrong during deployment,
monitoring, rollback, and ongoing operations. This is explicitly distinct from Challenge
(Stage 3) and Edge Cases (Stage 4), which focus on **DESIGN failures**.

| Stage | Focus | Example Finding |
|-------|-------|-----------------|
| Challenge (3) | Design: "What's wrong with the architecture?" | "JWT secret rotation not handled" |
| Edge Cases (4) | Design: "What breaks at boundaries?" | "Empty token string passes validation" |
| Pre-Mortem (4.5) | Operational: "What goes wrong when deployed?" | "No monitoring for token refresh failure rate" |

### Process

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage 4.5: Pre-Mortem
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Premise: This plan was implemented and deployed two weeks ago.
  It failed. You're writing the post-mortem.

  Focus: OPERATIONAL failures only (deployment, monitoring,
  rollback, oncall, observability). Design failures were already
  caught in Stages 3-4.

  Questions:
  1. What was the most likely single cause of failure?
  2. What contributing factors made it worse?
  3. What early warning signs were missed during planning?
  4. What would the incident retrospective recommend changing?

  For each identified failure:
    COVERED  → Already addressed in spec or adversarial findings (cite)
    NEW      → Not previously identified (potential regression trigger)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Output

Written to `.claude/plans/[name]/premortem.md`. Any NEW findings also appended to
`adversarial.md` with the tag `[pre-mortem]`.

If any NEW finding is rated critical, a regression prompt fires (see Feedback Loops below).

### Overlap Detection

For each pre-mortem finding, check adversarial.md for same failure category + same
affected component:
- If match found → mark as COVERED
- If (COVERED count / total findings) > 0.8 → note `"premortem_overlap": "high"` in state.json
- On future blueprints with similar scope, note high overlap as a quality signal — prior rounds were thorough

### Skippability

Skippable on all paths with reason required. On Full path, skipping triggers a regression warning displayed before Stage 5 proceeds. On Standard path, skip is permitted without warning. Not shown on Light path.

### Skip Warning (Full Path Only)

When pre-mortem is skipped on the Full path, display this warning before Stage 5:

```
⚠️ Pre-mortem was skipped on Full path.
  Stage 4.5 surfaces operational failures that design review (Stages 3-4) doesn't catch.
  Reason logged: "[user's skip reason]"

  Proceed to Stage 5 anyway? (Y/n)
```

---

## Stage 5: External Review

### Overview

Stage 5 (Review) provides an external perspective on the specification and adversarial findings. It is always optional on all paths.

### Plugin Integration

Before presenting Stage 5 options, check for plugin enhancements:

1. **Read plugin registry:** Read `commands/plugin-enhancers.md`. If file not found, skip to standard options.
2. **Follow detection protocol:** Use Section 1 of plugin-enhancers.md to check installed plugins.
3. **Build dynamic options:** Construct the options list based on detected plugins.

### Stage 5 Options Presentation

Present options in this order:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage 5 of 8: External Review
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  External review options:

    [1] GPT Surgical Review (/gpt-review)
        Claude diagnoses → GPT implements fixes → Claude reviews PR

  [If pr-review-toolkit detected:]
    [2] Deep Dive — pr-review-toolkit agents (recommended)
        6 specialized lenses: silent failures, type design,
        test coverage, comments, simplification, conventions

  [If frontend detected:]
    [3] Multi-Model Consensus — frontend:reviewer
        Parallel assessment from multiple AI models

  [If security-pro detected:]
    [4] Security Audit — security-pro:security-auditor
        Deep vulnerability assessment, OWASP compliance, auth gaps

  [If performance-optimizer detected:]
    [5] Performance Audit — performance-optimizer:performance-engineer
        Bottleneck identification, caching, query optimization

  [If superpowers OR feature-dev detected:]
    [6] Code Quality Review — additional reviewers
        [superpowers: methodology-based] [feature-dev: convention-based]

    [N] Skip — local challenge stages were sufficient

>
```

**Dynamic numbering rules:**
- GPT review is always option [1]
- Plugin options are numbered sequentially after GPT review, in the order above
- Skip is always the last option (numbered N, where N = total options)
- Options only appear when their required plugin is detected
- Multiple options can be selected (comma-separated, e.g., "2,4")

**If no plugins detected:** Show only options [1] GPT review and [2] Skip.

### Deep Dive Option (pr-review-toolkit)

When user selects the Deep Dive option:

**Step 1: Fast-fail probe**
```
Probing pr-review-toolkit availability...
```

Dispatch `pr-review-toolkit:code-reviewer` with 10-second timeout.
- If probe succeeds: proceed to Step 2
- If probe fails:
  ```
  [PLUGIN] pr-review-toolkit probe failed; skipping all agents
  Note: pr-review-toolkit unavailable (probe failed). Falling back to GPT review.
  ```
  Automatically execute GPT review option instead.

**Step 2: Full agent dispatch**
```
Dispatching 6 specialized review agents...
```

Dispatch all 6 agents in parallel:
1. `pr-review-toolkit:silent-failure-hunter`
2. `pr-review-toolkit:type-design-analyzer`
3. `pr-review-toolkit:pr-test-analyzer`
4. `pr-review-toolkit:comment-analyzer`
5. `pr-review-toolkit:code-simplifier`
6. `pr-review-toolkit:code-reviewer`

Each agent receives:
- Context: Spec from `spec.md`
- Files: All implementation files from work units (if Stage 7 started) OR spec sections (if pre-implementation)
- Timeout: 5 minutes per agent

**Step 3: Collect results**

For each agent:
- Success: format per Section 5 of plugin-enhancers.md
- Failure: log and skip (see graceful degradation below)
- Timeout: kill agent, log, skip

**Step 4: Present findings**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Deep Dive Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Consolidated findings from all agents, formatted per Section 5]

These findings are advisory. They have been appended to
adversarial.md under "## Plugin Review Findings" with
[plugin-review] tags.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Append all findings to `.claude/plans/[name]/adversarial.md`:
```markdown
## Plugin Review Findings

[All plugin results with [plugin-review] tags]
```

**Step 5: Mark stage complete**

Set `stages.review.status = "complete"` in state.json with confidence 0.8 (plugin reviews are advisory but thorough).

### Multi-Model Option (frontend)

When user selects the Multi-Model option:

**Step 1: Dispatch**
```
Dispatching frontend:reviewer for multi-model assessment...
```

Dispatch `frontend:reviewer` with:
- Context: Spec from spec.md + adversarial findings
- Files: Implementation files (if available)
- Timeout: 5 minutes

**Step 2: Present findings**

Format per Section 5 of plugin-enhancers.md, append to adversarial.md with `[plugin-review]` tag.

**Step 3: Mark stage complete**

Set `stages.review.status = "complete"` with confidence 0.8.

### GPT Review Option (Existing Behavior)

When user selects GPT review (option [1]):

Execute `/gpt-review` as documented in that command. This is the existing cross-platform adversarial review.

### Skip Option

When user selects Skip:
```
You're about to skip Stage 5: External Review

This stage normally provides:
  - External perspective from different model families
  - Fresh eyes on assumptions made during planning
  - Specialized review lenses not available in earlier stages

Are you sure? Provide a reason for the skip:
> [user reason]

Skip recorded. Proceeding to Stage 6 (Test).
```

Set `stages.review.status = "skipped"` and `stages.review.skip_reason = "[user reason]"` in state.json.

### Graceful Degradation

Follow all rules from Section 4 of plugin-enhancers.md:

**Agent dispatch failure:**
1. Log: `[PLUGIN] pr-review-toolkit:<agent> dispatch failed: <error>`
2. User message: `Note: <agent> unavailable (dispatch failed), skipping.`
3. Continue with remaining agents

**Agent timeout (5 minutes):**
1. Log: `[PLUGIN] pr-review-toolkit:<agent> timeout: 5m exceeded`
2. User message: `Note: <agent> unavailable (timeout after 5min), skipping.`
3. Kill agent, continue with remaining agents

**Oversized output (>2000 tokens):**
1. Truncate to 2000 tokens
2. Append: `[truncated — full output available via direct plugin invocation]`

**Circuit breaker (3 consecutive failures):**
1. Log: `[PLUGIN] Circuit breaker: 3 consecutive failures from pr-review-toolkit; skipping remaining agents`
2. User message: `Plugin enhancements temporarily disabled due to repeated failures.`
3. Abort remaining agents for that plugin
4. Fallback: offer GPT review as alternative

### Results Handling

**Plugin findings are advisory:**
- Appended to `adversarial.md` with `[plugin-review]` tags
- Do NOT trigger regression logic
- Do NOT affect confidence scoring
- Do NOT block workflow progression
- User may act on them or ignore them

This is explicitly distinct from debate chain findings (Stage 3/4), which CAN trigger regressions.

### Logging

Use `[PLUGIN]` prefix for all plugin-related operations:
```
[PLUGIN] Detection: found pr-review-toolkit@claude-code-plugins
[PLUGIN] pr-review-toolkit:code-reviewer dispatched
[PLUGIN] pr-review-toolkit:code-reviewer completed: 1247 tokens
[PLUGIN] pr-review-toolkit:silent-failure-hunter timeout: 5m exceeded
```

If epistemic session is active:
- Log successful plugin insights to `.epistemic/insights.jsonl`
- Log failures to `.epistemic/insights.jsonl` as dead-ends

---

## Feedback Loops (Stage Regression)

### Regression Triggers

Two types: automatic (system-suggested) and manual (user-initiated).

**Automatic triggers** — the system prompts the user, who decides:

| Condition | Suggested Target | When |
|-----------|-----------------|------|
| Debate judge rates finding as critical + "needs spec update" | Stage 2 (Specify) | After Stage 3 |
| Edge case synthesizer flags "implies architectural change" | Stage 2 (Specify) | After Stage 4 |
| Pre-mortem identifies NEW critical failure mode | Stage 2 (Specify) | After Stage 4.5 |
| Confidence <0.5 AND a trigger event occurs | Previous stage | After any stage |
| 2+ agents in debate converge on same critical finding | Stage 2 (Specify) | After Stage 3 |

**Confidence-gated regression:** Confidence alone does NOT trigger regression. It requires
BOTH low confidence (<0.5) AND a specific trigger event (critical finding, schema validation
failure, etc.) to suggest regression.

**Manual triggers:**

```
back              ← Go to previous stage (exists today)
reset specify     ← Jump to Stage 2 with reason prompt
reset describe    ← Jump to Stage 1 (full restart)
reset [stage]     ← Jump to any earlier stage
```

### Regression Prompt

When an automatic trigger fires:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  REGRESSION SUGGESTED │ Stage [current] → Stage [target]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Trigger: [description of what caused the suggestion]

  Impact: [what part of the spec/plan is affected]

  Options:
    [1] Regress to [target stage] — rework affected sections
        (All later-stage findings are preserved and carried forward)
    [2] Note and continue — append finding to adversarial.md
    [3] Flag as blocking — halt workflow until manually resolved

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Option [3] behavior:** Set `status: "blocked_pending_resolution"` in state.json.
Store `blocking_finding: "F[id]"` in state.json. Append finding with `[BLOCKING]`
tag to adversarial.md. Workflow refuses to advance until user runs `/blueprint [name]`
and resolves. Resolution note appended to adversarial.md with timestamp.

### Regression Behavior

When a regression occurs:

1. **state.json updated** — `current_stage` set to target, target stage status set to
   `"in_progress"`, all stages between target+1 and current marked `"needs_revalidation"`.

2. **regression_log appended:**
```json
{
  "from_stage": "edge_cases",
  "to_stage": "specify",
  "trigger_type": "automatic",
  "trigger": "edge_case_architectural_impact",
  "reason": "JWT expiry mid-request requires new error handling strategy",
  "timestamp": "2026-02-07T15:00:00Z",
  "revision": 2
}
```

3. **Artifact preservation** — ALL existing artifacts are kept. The spec gets a revision
   header. Copy `spec.md` to `spec.md.revision-N.bak` before allowing re-entry to Stage 2.

4. **Preserved resolutions** — Ambiguities resolved in prior stages are listed in the
   regression context, preventing them from being re-introduced.

5. **spec.diff.md updated** — Revision log tracking all changes (see Spec Diff Tracking below).

6. **Work graph marked stale** — When regressing to Stage 2, set `"work_graph_stale": true`
   in state.json. Stage 2 completion MUST regenerate work-graph.json.

7. **Post-regression stages** — When re-running stages after regression, the agent is given
   the previous stage output plus the regression context. It updates, not restarts from scratch.

8. **Challenge mode preserved** — On regression, use the same `challenge_mode` from state.json.
   Do not re-prompt for mode selection.

### HALT State (Max Regression Recovery)

**Maximum regressions per blueprint: 3.**

If confidence is >=0.5 on all completed stages: proceed normally (regressions exhausted
but quality is acceptable). Skipped stages are excluded from threshold evaluation.

If confidence is <0.5 on any completed stage AND the regression limit is reached:
the blueprint enters **HALT**.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT HALTED │ [name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  This blueprint has exhausted its regression budget (3/3)
  but confidence remains below threshold on: [stage(s)]

  Regression history:
    [1] [from] → [to]: [reason]
    [2] [from] → [to]: [reason]
    [3] [from] → [to]: [reason]

  Options:
    [1] Override confidence threshold — proceed despite low confidence
        (Logged as override in state.json and overrides.json)
    [2] Simplify scope and restart — reduce scope, create new blueprint
        (Current blueprint archived as [name]-abandoned-[date])
    [3] Abandon blueprint — stop planning, decide manually
        (Artifacts preserved for reference)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Spec Diff Tracking

### When Created

`spec.diff.md` is created on the first regression and appended on subsequent ones.

### Format

```markdown
# Specification Revision History

## Revision 1 (initial)
- Created: [timestamp]
- Sections: [list of top-level sections]
- Work Units: [count]

## Revision 1 → Revision 2
- Trigger: [what caused the regression]
- Date: [timestamp]
- Sections added: [list]
- Sections modified: [list with change summaries]
- Sections removed: [list or None]
- Sections unchanged: [list]
- Adversarial findings addressed: [N/total]
- Work units affected: [list with changes]
```

### Maintenance

When a regression occurs:
1. Read current spec.md
2. After user modifies spec (re-running Stage 2), diff against previous version
3. Append diff summary to spec.diff.md
4. Increment `revision` in state.json and manifest.json
5. Update manifest's `spec_digest`

---

## During Any Stage

At any point during planning:

- **Non-obvious choice made?** → Run `/decision [topic]` to record rationale
- **Session getting long?** → Run `/checkpoint` to save context
- **Requirements unclear?** → Run `/requirements-discovery` to validate

These are invoked inline — they don't interrupt stage progression.

---

## Skip Handling

When user requests skip:

```
You're about to skip Stage [N]: [name]

This stage normally catches:
  - [what this stage finds]

Are you sure? Provide a reason for the skip:
> [user reason]

Skip recorded. Proceeding to Stage [N+1].
```

Skips are logged in `state.json` and visible in `/overrides`.

---

## Debrief (Stage 8 — Completion Ceremony)

Debrief is the final stage of every blueprint. It captures what shipped, what changed,
what was learned, and closes the blueprint with `completed: true`.

> **Enforcement tier:** Debrief uses `"skippable": false` in the stage schema and a
> regression-warning prompt at Stage 7 completion. This is tier 2.5 enforcement —
> stronger than prose, weaker than a shell hook. We do NOT claim debrief is "mandatory"
> (that implies hook enforcement). We claim it is "structurally expected."

### Prerequisites

- `stages.execute.status` MUST be `"complete"` before debrief can start
- If debrief is attempted on an un-executed blueprint: "Debrief requires Stage 7 (Execute)
  to be complete. Current status: [execute.status]"

### Session Recovery

On blueprint resume (`/blueprint [name]`), if `stages.execute.status === "complete"` and
(`stages.debrief` is absent OR `stages.debrief.status !== "complete"`), display the
transition prompt as if Stage 7 had just completed. This ensures session breaks between
execute and debrief are recoverable.

When writing Stage 7 completion to state.json, also write
`stages.debrief: { "status": "pending" }` to create a persistent breadcrumb.

### Context-Aware Mode

If the session has been through >5 blueprint stages, prefer manual input over
auto-detection for debrief steps 1-2 (ship reference, spec delta). Ask the user to
provide commit hashes and spec delta directly rather than attempting to auto-read and
synthesize from files that may have been compacted. Auto-detection is a convenience,
not a requirement — manual fallbacks are first-class.

### Debrief Flow

When Stage 7 (Execute) is marked complete, the blueprint transitions to Stage 8.
The transition prompt appears AFTER the implementation options block, with a clear separator:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Stage 8 of 8: Debrief
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Completing this blueprint. Capturing final state.

  1. SHIP REFERENCE
     Commit hash(es) that delivered this work:
     [Auto-detected from .claude/plans/[name]/commits.jsonl
      if available, otherwise prompt user]

  2. SPEC DELTA
     What changed from the original specification?
     [Read spec.diff.md if it exists (created on regression),
      otherwise summarize regression_log entries from state.json.
      If neither exists: "no tracked changes — spec stable
      through implementation."]

  3. DEFERRED ITEMS
     What was explicitly punted and why?
     > [user input — list items with reasons]

  4. DISCOVERIES
     What did this blueprint reveal that wasn't anticipated?
     > [user input — things learned during implementation]

  5. REFLECTION (what was learned)
     - What assumption from the spec turned out to be wrong?
     - What was harder/easier than expected?
     - What would you tell the next planner?
     - Which spec sections were most/least useful?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Debrief for Linked Blueprints (Meta-Aware)

When `state.json` has a `parent` field (this is a sub-blueprint), debrief adds two
additional steps after step 5:

```
  6. SIBLING IMPACT
     Do any sibling blueprints need to know about your discoveries?
     [List siblings from parent's meta_units map]
     > [user selects affected siblings + describes impact]

  7. META UPDATE
     Before attempting parent update, verify bidirectional consistency.
     If half-linked (child has parent ref but parent's meta_units
     doesn't list this child), repair the link first.

     Updating parent blueprint manifest...
     [Auto-update parent's meta_units with:
       - this blueprint's status → complete
       - ship_commit from step 1
       - discoveries from step 4
       - sibling impacts from step 6]

     If parent blueprint's state.json is unreachable or parent
     has completed: true, META UPDATE is skipped with warning:
       "Parent [name] is unreachable/completed — update recorded
        locally in debrief.md but parent was not modified."
```

### Debrief Output

Written to `.claude/plans/[name]/debrief.md`:

```markdown
# Debrief: [blueprint name]

## Ship Reference
- Commit(s): [hash list]
- Date: [completion date]

## Spec Delta
[Summary of what changed from original spec]
- Revisions: [count]
- Key changes: [list]

## Deferred Items
- [item]: [reason]

## Discoveries
- [discovery]

## Reflection
### Wrong Assumptions
- [list]
### Difficulty Calibration
- Harder: [list]
- Easier: [list]
### Advice for Next Planner
- [guidance]

## Sibling Impact (if linked)
- [sibling]: [impact description]
```

### Debrief Export

After writing `debrief.md`, execute this export sequence:

1. **Epistemic tracking (if session active):** For each finding in "Wrong Assumptions",
   "Discoveries", and "Spec Gaps", append to `.epistemic/insights.jsonl` with prefix
   "[Debrief]". Each discrete finding gets its own log entry.

2. **Vault (if vault available):** Export a summary finding to
   `Engineering/Findings/YYYY-MM-DD-debrief-[blueprint-name].md` using the finding template.
   ONE note per debrief (not per finding).

3. **If both unavailable:** Write findings to `debrief.md` only and log a warning.

### State Transitions

1. `stages.debrief.status` → `"complete"`
2. `stages.debrief.completed_at` → timestamp
3. `stages.debrief.ship_commits` → list of commit hashes
4. `stages.debrief.discoveries` → list of discovery strings
5. `completed` → `true` at state.json root
6. `completed_at` → timestamp at state.json root
7. If linked: update parent's `meta_units[this_blueprint].status` → `"complete"`

**Invariant:** `completed: true` is ONLY valid when BOTH `stages.execute.status === "complete"`
AND `stages.debrief.status === "complete"`. Any other write path is a schema violation.

### Skippability

Debrief is NOT skippable (`"skippable": false` in schema). On Light/Standard paths, the flow
is abbreviated (steps 1-2 auto-populated where possible, steps 3-5 brief). On Full path,
the full prompt is shown.

---

## Completion

When Stage 7 (Execute) is reached:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BLUEPRINT: [name] │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Planning complete! Summary:

  Path: [Light/Standard/Full]
  Mode: [vanilla/debate/team]
  Stages completed: [N]/8 (+ skipped: [list])
  Revisions: [N] (regressions: [N])
  Confidence: [min - max across stages]

  Artifacts:
  - .claude/plans/[name]/describe.md
  - .claude/plans/[name]/spec.md
  - .claude/plans/[name]/adversarial.md
  - .claude/plans/[name]/manifest.json
  - .claude/plans/[name]/work-graph.json
  [+ any additional artifacts]

Ready to implement. Artifacts saved for reference.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Vault Export (Automatic)

After presenting the completion summary, export blueprint to vault if available:

1. Source vault config:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
   ```

2. If vault is available (`VAULT_ENABLED=1` and path exists and writable):
   a. Ensure target directory: `mkdir -p "$VAULT_PATH/Engineering/Blueprints"`
   b. Read `manifest.json` for the completed blueprint
   c. Read `adversarial.md` for top findings (if exists)
   d. Determine project name: `basename $(git rev-parse --show-toplevel 2>/dev/null || echo "unknown")`
   e. Generate slug from blueprint name (include project): `YYYY-MM-DD-project-blueprint-name.md`
   f. Hydrate `blueprint-summary.md` template with `schema_version: 1` in frontmatter
   g. **Merge-write [F2]**: If file exists, read it, split at `<!-- user-content -->` sentinel, preserve content below sentinel, overwrite above
   h. Write to `$VAULT_PATH/Engineering/Blueprints/YYYY-MM-DD-project-blueprint-name.md`
   i. Report: `Vault: Blueprint summary exported to Engineering/Blueprints/`

3. If vault is enabled but not accessible: `"Vault write skipped: directory not accessible"`
4. If vault is not enabled: silently skip (no message)

```
  Pre-implementation:
    /design-check [name]    — Verify prerequisites are met (recommended)
    /preflight              — Safety check for risky operations
    /freeze [dir]           — Lock directories you don't want touched during implementation

  TDD enforcement: [N] of [M] work units annotated tdd:true
    (TDD applied per-WU automatically — not a path choice)

  Implementation options:
    [1] Sequential — work units executed one at a time
    [2] Parallel dispatch → /delegate --plan .claude/plans/[name]/spec.md --review
        [parallelization recommendation based on work graph + execution_preference]

  Post-implementation:
    /quality-sweep [name]   — Structured review sweep with all reviewer agents (recommended)
    /outside-review         — Cross-model adversarial assessment
    /simplify               — Review changed code for reuse, quality, efficiency (if available)
    /quality-gate           — Score against rubric before completing

  Retrospective (user-initiated):
    /log-success            — Something work unusually well? Capture the pattern
    /log-error              — Something go wrong? Interview yourself on what YOU did wrong
    /retro                  — Retrospective across recent sessions (commits, errors, successes)
    /evolve                 — Synthesize recurring patterns into workflow improvements
    /audit                  — Review what hooks blocked during implementation

  Also available (user-initiated):
    [If git-workflow plugin detected:]
      Working on a feature branch? /feature and /finish manage Git Flow lifecycle.
    [If ralph-wiggum plugin detected:]
      Long implementation? /ralph-loop adds verification checkpoints during execution.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Parallelization recommendation** (based on work graph analysis + execution_preference):

| Width | Critical Path | Preference | Suggestion |
|-------|--------------|------------|------------|
| Any | Any | `speed` | `strong` — always suggest `/delegate` |
| Any | Any | `simplicity` | `none` — always suggest sequential |
| 1 | Any | `auto` | `none` — sequential |
| 2 | <=3 | `auto` | `moderate` — suggest `/delegate` |
| 3+ | Any | `auto` | `strong` — recommend `/delegate --review` |
| Any | >5 | `auto` | `strong` — recommend `/delegate --review` |

The execution_preference is advisory — user always has final choice.

---

## State Persistence

On any action, update `.claude/plans/[name]/state.json`.
See `docs/PLANNING-STORAGE.md` for the full v2 schema.

---

## Output Artifacts

All artifacts saved to `.claude/plans/[name]/`:
- `state.json` — Progress tracking + v2 metadata
- `manifest.json` — Token-dense recovery format
- `describe.md` — Triage output
- `spec.md` — Full specification
- `adversarial.md` — Challenge + edge case findings (canonical source of truth)
- `premortem.md` — Pre-mortem analysis (operational focus)
- `debate-log.md` — Raw debate transcript (debug, debate/team mode only)
- `work-graph.json` — Parallelization dependency graph
- `spec.diff.md` — Revision history (created on first regression)
- `preflight.md` — Pre-flight checklist
- `tests.md` — Generated test specs
- `debrief.md` — Completion ceremony output (Stage 8)
- `commits.jsonl` — Commit log (if SAIL_BLUEPRINT_ACTIVE was set during execution)

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Debate agent timeout (>5 min) | Agent returns no result | Fall back to vanilla mode for remainder of stage. Preserve completed rounds. |
| Manifest corruption on resume | manifest.json unparseable | Regenerate from source artifacts (describe.md + spec.md + adversarial.md + state.json). |
| Regression loop exhaustion (3/3) | state.json regression_count = 3, confidence <0.5 | HALT state with escape hatches: override, simplify scope, or abandon. |
| Elder Council vault unavailable | Obsidian MCP error or vault not mounted | Compensate with analytical reasoning. Note "Historical review limited." |
| Work graph stale after regression | work_graph_stale = true in state.json | Stage 2 re-completion regenerates work-graph.json. Block execution until resolved. |
| Context compaction mid-family-debate | Agent output lost to compression | debate-log.md preserves each agent's output immediately on completion. Resume from disk. |
| Session break between Stage 7→8 | Execute complete, debrief pending, session ends | `stages.debrief: { "status": "pending" }` breadcrumb written at Stage 7 completion. Resume surfaces transition prompt. |
| Parent unreachable during debrief META UPDATE | Parent state.json deleted/archived/completed | Warning displayed, debrief completes locally. Parent not modified. Manual reconciliation needed. |
| Half-linked state at debrief time | Child has parent ref, parent's meta_units missing child | Debrief step 7 detects and repairs before attempting update. |
| Context exhaustion confabulates debrief data | Session >5 stages, auto-detection unreliable | Context-aware mode: prefer manual input when session is heavy. |

## Known Limitations

- **Markdown-only enforcement** — Blueprint stages are guided by prose, not shell hooks. "Required" stages can still be skipped by a determined user. The regression warning is the highest enforcement tier available.
- **Context pressure on long blueprints** — Full-path blueprints with family mode can consume significant context. Blueprint.md itself is 1600+ lines; Claude may need multiple reads to find edit points.
- **Vault awareness depends on vault availability** — If the Obsidian vault is not configured or the path is invalid, vault-related features silently degrade. This is intentional fail-open behavior.
- **Cognitive trap staleness** — Trap rows are contextual snapshots. They may become less relevant as the toolkit evolves. Review periodically.

## Integration

- **Wraps:** All planning commands
- **Tracked in:** `.claude/plans/[name]/`
- **Listed by:** `/blueprints`
- **Status checked by:** `/status`
- **Recovery format:** `manifest.json` (read at all recovery points)
- **Work decomposition:** `work-graph.json` (consumed by `/delegate`)
- **Enforcement:** `hooks/blueprint-stage-gate.sh` (checks epistemic data)
