---
description: You MUST use this for ANY non-trivial implementation task. Skipping planning leads to confident mistakes that cost more to fix than to prevent.
arguments:
  - name: name
    description: Name for this blueprint (required for new, optional to resume)
    required: false
  - name: challenge
    description: "Challenge mode: vanilla, debate (default), family, team"
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
Stage 3: Challenge   → Debate chain (default) / Vanilla / Family / Agent team
Stage 4: Edge Cases  → Debate chain (default) / Vanilla / Family / Agent team
Stage 4.5: Pre-Mortem → Operational failure exercise
Stage 5: Review      → /gpt-review (external perspective) [optional]
Stage 6: Test        → /spec-to-tests (spec-blind tests)
Stage 7: Execute     → Implementation (with manifest handoff + work graph)

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

If the problem is complex or requirements are unclear, suggest pre-stage commands:

```
Before planning, consider:
  /brainstorm [topic]            — If the problem has multiple viable approaches
  /requirements-discovery [topic] — If requirements are unclear or complex
  /design-check [topic]          — If implementation boundaries are fuzzy

These are optional. Proceed to /blueprint when you have a clear enough picture.
```

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
/blueprint feature-auth                      # debate mode (DEFAULT)
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
  BLUEPRINT: [name] │ Stage [N] of 7: [Stage Name]
  Mode: [vanilla/debate/team] │ Revision: [N] │ Confidence: [score]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stages:
  ✓ 1. Describe     [completed timestamp]
  ✓ 2. Specify      [completed timestamp]  (rev [N])
  → 3. Challenge    ← You are here
  ○ 4. Edge Cases
  ○ 4.5 Pre-Mortem  (optional)
  ○ 5. Review       (optional)
  ○ 6. Test
  ○ 7. Execute

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
| 4.5. Pre-Mortem | Inline (see below) | Yes | Light/Standard path |
| 5. Review | `/gpt-review` | Yes | Always optional |
| 6. Test | `/spec-to-tests` | Yes | Light path |
| 7. Execute | Exit wizard | No | Never |

### Ambiguity Gate (Between Stage 1 → Stage 2)

After Stage 1 (Describe) completes and before Stage 2 (Specify) begins, run a clarity check on the description output. This front-loads ambiguity detection before it becomes baked into the spec.

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

### Prior Art Gate (Between Stage 1 → Stage 2)

After the Ambiguity Gate passes and before Stage 2 (Specify) begins, run a prior art search.
This is ENFORCED — cannot proceed to Stage 2 without completing it.

1. Run `/prior-art` with the problem description from describe.md
2. Write output to `.claude/plans/[name]/prior-art.md`
3. Gate behavior:
   - **Adopt** recommendation → prompt user to supersede blueprint or continue
   - **Adapt/Inform/Build** → proceed to Stage 2, prior-art report available as context
4. Record in state.json: `"prior_art_gate": { "status": "complete", "recommendation": "[adopt/adapt/inform/build]", "override": false, "run_at": "YYYY-MM-DDTHH:MM:SSZ" }`

On Light path: skip prior-art gate entirely (Light path skips Stages 2-6, prior art is a pre-Stage-2 gate).
On Standard/Full path: enforced.

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
- Stage 4.5 (Pre-Mortem) recommended, skippable
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

### Debate Mode (Default)

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

### Family Mode (Generational Debate)

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
An earnest advocate who genuinely believes the spec is sound. Not a sycophant — believes
because they've found real reasons. Receives `spec.md` independently.

```
You are the Defender of this specification. You genuinely believe this
plan is sound, and your job is to articulate WHY.

For each major design decision in the spec:
  - Why is this the RIGHT choice? What alternatives were implicitly
    rejected, and why is this better?
  - What strengths would be LOST if this section were changed?
  - What subtle benefits does this approach have that a critic might miss?

You are not a yes-man. If a section is genuinely weak, you may
acknowledge it — but even then, find the kernel of good intent behind
it and articulate why that intent matters.

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
  - Proceed with analysis based on spec content only
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

**Hard limits:**
- Maximum rounds: 3 (hardcoded)
- Per-agent timeout: 3 minutes (individual agent cutoff)
- Round timeout: 10 minutes (all 5 agents combined per round)
- Total mode timeout: 25 minutes (all rounds combined)

**Timeout behavior:**
- If a single agent exceeds 3 minutes: kill agent, log dead-end to `.epistemic/insights.jsonl`, skip that
  agent's contribution, continue with remaining agents
- If round timeout exceeded: complete current agent, skip remaining agents in round,
  force Elder verdict with available data
- If total timeout exceeded: force CONVERGED with `confidence: 0.4` and note
  "timeout — forced convergence"
- On any timeout: fall back to vanilla mode is NOT applied (family mode either completes
  within limits or forces convergence — no mid-stream mode switch)

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
- On future blueprints with similar scope, suggest skipping pre-mortem

### Skippability

Skippable (with reason logged) on all paths. Recommended on Full path, suggested on
Standard path, not shown on Light path.

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
  BLUEPRINT: [name] │ Stage 5 of 7: External Review
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

## Post-Implementation Reflection (Stage 7 Completion)

When Stage 7 (Execute) is about to be marked complete, fire this reflection step inline. This is NOT a separate stage — it's part of Stage 7 completion.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  POST-IMPLEMENTATION REFLECTION │ [blueprint name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Implementation is complete. Before closing this blueprint,
  capture what was learned.

  WONDER — What surprised you?
  1. What assumption from the spec turned out to be wrong?
  2. What was harder than expected? What was easier?
  3. What would you add to the spec if starting over?
  4. Did any adversarial finding turn out to be more (or less)
     important than rated?

  REFLECT — What should change for next time?
  1. Which spec sections were most useful during implementation?
  2. Which were ignored or irrelevant?
  3. What's one thing the blueprint process missed?
  4. If a similar feature were planned tomorrow, what would you
     tell the planner?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Reflection Output

Written to `.claude/plans/[name]/reflect.md` with this structure:

```markdown
# Post-Implementation Reflection

## Wonder (Surprises)

### Assumptions Proven Wrong
- [list]

### Difficulty Calibration
- Harder than expected: [list]
- Easier than expected: [list]

### Spec Gaps (would add if starting over)
- [list]

### Adversarial Finding Recalibration
- [finding] (rated [severity]) was actually [higher/lower] because [reason]

## Reflect (Process Improvements)

### Most Useful Spec Sections
- [list]

### Least Useful Spec Sections
- [list]

### Blueprint Process Gap
- [description]

### Advice for Next Planner
- [guidance]
```

### Reflection Export (Mandatory)

After writing `reflect.md`, execute this export sequence (NOT optional):

1. **Epistemic tracking (mandatory if session active):** For each finding in "Assumptions Proven Wrong" and "Spec Gaps", append to `.epistemic/insights.jsonl` with prefix "[Reflection]". Each discrete finding gets its own log entry.

2. **Vault (mandatory if vault available):** Export a summary finding to `Engineering/Findings/YYYY-MM-DD-reflect-[blueprint-name].md` using the finding template. ONE note per reflection (not per finding).

3. **If both unavailable:** Write findings to `reflect.md` only and log a warning.

### Skippability

The reflection is prompted but skippable. When skipped: `"reflection": { "status": "skipped", "reason": "[user reason]" }` in state.json.

On Light/Standard paths, it's suggested but brief. On Full path, the full prompt is shown.

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
  Stages completed: [N]/7 (+ skipped: [list])
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

  Implementation options:
    [1] Standard implementation (sequential)
    [2] TDD-enforced → /tdd --plan-context [name]
    [3] Parallel dispatch → /delegate --plan .claude/plans/[name]/spec.md --review
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

## Integration

- **Wraps:** All planning commands
- **Tracked in:** `.claude/plans/[name]/`
- **Listed by:** `/blueprints`
- **Status checked by:** `/status`
- **Recovery format:** `manifest.json` (read at all recovery points)
- **Work decomposition:** `work-graph.json` (consumed by `/delegate`)
- **Enforcement:** `hooks/blueprint-stage-gate.sh` (checks epistemic data)
