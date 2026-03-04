# Specification: family-debate-and-rename

## Revision 1 — 2026-03-03

---

## 1. Overview

Two changes to the claude-bootstrap toolkit:

**Change A (Rename):** Rename `/simplify-this` → `/overcomplicated` across all files. Mechanical find-and-replace with content updates.

**Change B (Family Mode):** Add a new `--challenge=family` mode to `/blueprint` — a six-role generational debate architecture with Obsidian vault integration. Also wire `/overcomplicated` into the blueprint adversarial phase, and wire Anthropic's `/simplify` into post-implementation.

---

## 2. Change A: Rename `/simplify-this` → `/overcomplicated`

### 2.1 File Operations

| Action | File | Details |
|--------|------|---------|
| Rename | `commands/simplify-this.md` → `commands/overcomplicated.md` | File rename |
| Edit | `commands/overcomplicated.md` | Update `# Simplify This` → `# Overcomplicated`, internal self-references, output format headers |
| Edit | `commands/devils-advocate.md` | Line 144: `/simplify-this` → `/overcomplicated` |
| Edit | `commands/edge-cases.md` | Line 159: `/simplify-this` → `/overcomplicated` |
| Edit | `commands/review.md` | Lines 65, 229: `/simplify-this` → `/overcomplicated`, section header update |
| Edit | `commands/toolkit.md` | Line 43: update command name + description |
| Edit | `commands/README.md` | Lines 43, 319, 324: update table entry, section header, example |
| Edit | `README.md` | Line 43 (adversarial table), line 106 (pipeline diagram) |
| Edit | `GETTING_STARTED.md` | Line 439: update uninstall cleanup filename |

### 2.2 Content Changes in Renamed File

The file `commands/overcomplicated.md` needs these internal updates:

- **YAML frontmatter `description`:** Keep enforcement tier (REQUIRED after ANY architecture decision). No change needed to trigger language.
- **Title:** `# Simplify This` → `# Overcomplicated`
- **Opening paragraph:** Adjust to match new name voice
- **Output format headers:** `# Simplify This Review:` → `# Overcomplicated Review:`
- **Integration section (line 146):** `## Local Adversarial Findings (Simplify This)` → `## Local Adversarial Findings (Overcomplicated)`

### 2.3 Description Field

The renamed command's `description` field should read:

```
REQUIRED after ANY architecture decision or design. You MUST check for over-engineering — complexity is the enemy of reliability.
```

This is unchanged from current — the trigger language is already correct.

### 2.4 Bootstrap Manifest

`.claude/bootstrap-manifest.json` has a key `"commands/simplify-this.md"`. This needs updating to `"commands/overcomplicated.md"`.

---

## 3. Change B: Family Challenge Mode

### 3.1 Mode Registration

Add `family` to the challenge mode options in `commands/blueprint.md`:

```
/blueprint feature-auth                      # debate mode (DEFAULT)
/blueprint feature-auth --challenge=vanilla  # original single-agent
/blueprint feature-auth --challenge=debate   # sequential debate chain
/blueprint feature-auth --challenge=family   # generational debate (deep specs)
/blueprint feature-auth --challenge=team     # agent team (experimental)
```

Update the YAML frontmatter argument description:
```yaml
- name: challenge
  description: "Challenge mode: vanilla, debate (default), family, team"
```

### 3.2 Architecture Overview

The family mode implements a **generational review architecture** with three tiers:

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
│  analogies. Validates strengths against past    │
│  successes, weaknesses against past failures.   │
│  Issues convergence verdict.                    │
│                                                 │
│  CONVERGED → Stop                               │
│  CONTINUE  → Inject history, loop to Children   │
└─────────────────────────────────────────────────┘
```

### 3.3 Agent Specifications

#### 3.3.1 Child-Defend (subagent, sonnet)

**Persona:** An earnest advocate who genuinely believes the spec is sound. Not a sycophant — believes because they've found real reasons. Enthusiastic, specific, cites sections.

**Receives:** `spec.md` (+ `adversarial.md` from prior stages if regression)

**Prompt:**
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

#### 3.3.2 Child-Assert (subagent, sonnet)

**Persona:** A passionate challenger who believes the spec needs change. Not hostile — motivated by wanting the project to succeed. Points at specific gaps, not vague unease.

**Receives:** `spec.md` (same input as Child-Defend, independently)

**Prompt:**
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

#### 3.3.3 Mother — Strength Synthesizer (subagent, sonnet)

**Persona:** Sees merit in both children's positions, even when they contradict. Her gift is finding the hidden value in each argument. Warm but analytical. Never dismissive.

**Receives:** `spec.md` + Child-Defend output + Child-Assert output

**Prompt:**
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

#### 3.3.4 Father — Weakness Analyst & Guide (subagent, sonnet)

**Persona:** Loves the project, wants it to succeed. Finds weaknesses not to criticize but to strengthen. Offers direction, never implementation. Gentle in rebuke, firm in standards. If a position is untenable, says so clearly but kindly.

**Receives:** `spec.md` + Mother's synthesis

**Prompt:**
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

#### 3.3.5 Elder Council — Historical Validator (subagent, opus)

**Persona:** The wisdom of accumulated project experience. Speaks with quiet authority grounded in "we've seen this before." Not infallible — sometimes the past doesn't apply. Uses Opus model for deeper reasoning.

**Receives:** `spec.md` + Father's analysis + (prior round Elder output if looping)

**Tools required:** Obsidian MCP (vault query), Read, Grep, Glob

**Prompt:**
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
   - Log warning via Empirica `deadend_log`

### 3.4 Loop Control

#### Round Structure

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

#### Convergence Conditions

The Elder Council issues the verdict. Convergence is declared when ALL of:

1. No historical red flags remain unaddressed
2. Father's proposed changes are directionally sound (historically supported or genuinely novel)
3. No critical unresolved tensions between children's positions

#### Hard Limits

- **Maximum rounds: 3** (configurable via future setting, hardcoded for now)
- **Per-agent timeout: 3 minutes** (individual agent cutoff)
- **Round timeout: 10 minutes** (all 5 agents combined per round)
- **Total mode timeout: 25 minutes** (all rounds combined)

#### Timeout Behavior

- If a single agent exceeds 3 minutes: kill agent, log dead-end via Empirica, skip that agent's contribution, continue with remaining agents
- If round timeout exceeded: complete current agent, skip remaining agents in round, force Elder verdict with available data
- If total timeout exceeded: force CONVERGED with `confidence: 0.4` and note "timeout — forced convergence"
- On any timeout: fall back to vanilla mode is NOT applied (family mode either completes within limits or forces convergence — no mid-stream mode switch)

#### Incremental Output Persistence

Each agent's output is written to `debate-log.md` immediately upon completion (not batched at round end). This protects against mid-round context compaction:

1. Agent completes → append output to `debate-log.md` with agent label and round number
2. Update `family_progress.agents_completed` in `state.json`
3. On resume after compaction: read completed agents' outputs from `debate-log.md`, skip to `current_agent`

#### Asymmetric Child Output

If one child agent times out but the other completes:

- Mother receives the surviving child's output with a note: "The opposing perspective (defend/assert) was unavailable due to timeout."
- Mother should attempt synthesis by playing devil's advocate against the surviving position — generating the *likely* counterarguments the missing child would have raised.
- This is explicitly degraded quality. Father's confidence assessment should reflect the asymmetry.

#### Empty Carry-Forward Guard

If Elder Council issues CONTINUE but provides empty or null `carry_forward`:

- Treat as CONVERGED — a CONTINUE without specific context for the next round would cause children to repeat themselves.
- Set confidence to Elder's stated confidence (not forced low).
- Log via Empirica: "Elder CONTINUE overridden — empty carry_forward treated as CONVERGED."

#### Round Progress Tracking

`family_progress` is initialized fresh at the start of each stage (Stage 3 and Stage 4 each get their own 3-round budget). Prior stage's family progress is cleared.

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

### 3.5 How Family Mode Applies to Stage 3 (Challenge) and Stage 4 (Edge Cases)

#### Stage 3: Challenge — Family Mode

The children receive opposing mandates about the spec's **design decisions**:
- Child-Defend: Why the architecture and approach are sound
- Child-Assert: Why the architecture and approach need change

Mother synthesizes design strengths. Father finds design weaknesses. Elders validate against historical design decisions.

#### Stage 4: Edge Cases — Family Mode

The children receive opposing mandates about the spec's **boundary behavior**:
- Child-Defend: Why the boundaries and error handling are sufficient
- Child-Assert: Why the boundaries will break under stress

Mother synthesizes boundary coverage strengths. Father finds boundary gaps. Elders validate against historical edge case discoveries and past boundary failures.

The prompts shift focus but the structure is identical. The Father's "refined spec summary" at Stage 4 focuses on boundary additions rather than architectural changes.

#### Stage 4 Child Prompt Overrides

**Child-Defend (Stage 4):**
```
You are the Defender of this specification's boundary handling.
Argue that the error handling, input validation, state transitions,
and edge cases are SUFFICIENT as specified...
[same structure as 3.3.1 but boundary-focused]
```

**Child-Assert (Stage 4):**
```
You are the Challenger of this specification's boundary handling.
Find the inputs, states, and conditions that will BREAK this system...
[same structure as 3.3.2 but boundary-focused]
```

Mother, Father, and Elder prompts remain the same — they naturally adapt based on what the children present.

### 3.6 Output Artifacts

All family mode output goes to the same files as other challenge modes:

- `adversarial.md` — Curated findings (Mother's synthesis + Father's analysis + Elder's historical review, per round)
- `debate-log.md` — Full transcript of all agents, all rounds (debug artifact)
- `state.json` — Updated with `family_progress` tracking

The final curated output in `adversarial.md` uses this format per round:

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

### 3.7 Regression Triggers from Family Mode

Same rules as debate mode:
- Elder Council rates any finding as critical + unaddressed → suggest regression to Stage 2
- Father identifies architectural change needed → suggest regression to Stage 2
- All regression prompts follow existing blueprint regression flow

Additional family-specific trigger:
- If Elder Council issues CONTINUE verdict 3 times (max rounds exhausted), force convergence but set `confidence: 0.3` and suggest regression if any critical items remain unaddressed.

---

## 4. Wire `/overcomplicated` into Blueprint

### 4.1 Placement

Add `/overcomplicated` as a sub-step within Stage 3 (Challenge), executed AFTER the main challenge mode (debate/vanilla/family/team) completes.

```
Stage 3: Challenge
  ├── [Challenge mode: debate/vanilla/family/team]
  ├── /overcomplicated (complexity check on the spec)
  └── Stage 3 complete
```

### 4.2 Blueprint.md Changes

After the challenge mode sections, add:

```markdown
#### Post-Challenge: Complexity Check

After the challenge mode completes (regardless of mode), run `/overcomplicated`
on the spec. This checks whether the spec has become over-engineered through
the adversarial process (a common failure mode — addressing every challenge
can bloat a spec beyond what's necessary).

The `/overcomplicated` output is appended to `adversarial.md` under
`## Complexity Review`. If it identifies elements marked "Remove" or
"Simplify", these are presented to the user but do NOT auto-trigger regression.
The user decides whether to simplify.
```

---

## 5. Wire Anthropic's `/simplify` into Blueprint Completion

### 5.1 Placement

Add `/simplify` as a post-implementation suggestion at Stage 7 completion, alongside the existing implementation options.

### 5.2 Blueprint.md Changes

In the Completion section, add to post-implementation options:

```markdown
  Post-implementation:
    /simplify             — Review changed code for reuse, quality, efficiency
    /quality-gate         — Score against rubric before completing
```

`/simplify` should appear BEFORE `/quality-gate` since it may produce code changes that affect the quality score.

**Availability note:** `/simplify` is a Superpowers plugin skill. If unavailable (plugin not installed), skip silently — this is advisory, not required. The post-implementation options list should only show `/simplify` if the skill is detected.

---

## 6. Work Units

### WU-1: Rename file (Track A)
- Rename `commands/simplify-this.md` → `commands/overcomplicated.md`
- Update internal content
- **Depends on:** nothing
- **Blocks:** WU-2

### WU-2: Update cross-references (Track A)
- Update all 7 files that reference `/simplify-this`
- Update `.claude/bootstrap-manifest.json`
- **Depends on:** WU-1 (filename must exist)
- **Blocks:** nothing

### WU-3: Add family mode to blueprint.md (Track B)
- Add `--challenge=family` to mode selection
- Write full family mode specification section
- Add agent prompt specifications
- Add loop control, timeout, and convergence logic
- **Depends on:** nothing
- **Blocks:** WU-4, WU-5

### WU-4: Wire /overcomplicated into blueprint (Track B)
- Add post-challenge complexity check step
- **Depends on:** WU-1 (renamed file must exist), WU-3 (needs to know where in challenge flow)
- **Blocks:** nothing

### WU-5: Wire /simplify into blueprint completion (Track B)
- Add to post-implementation options
- **Depends on:** WU-3 (needs blueprint completion section context)
- **Blocks:** nothing

### WU-6: Update README and docs
- Update command counts if needed
- Update challenge mode references in README
- **Depends on:** WU-1, WU-3
- **Blocks:** nothing

---

## 7. Work Graph

```
WU-1 (rename) ──→ WU-2 (cross-refs) ──→ WU-6 (docs)
                                    ↗
WU-3 (family mode) ──→ WU-4 (wire /overcomplicated)
                  ╰──→ WU-5 (wire /simplify)

Parallelizable pairs:
  - WU-1 ∥ WU-3 (independent tracks)
  - WU-4 ∥ WU-5 (independent integrations, both depend on WU-3)
  - WU-2 ∥ WU-3 (after WU-1 completes)

Critical path: WU-3 → WU-4 (family mode is the long pole)
Graph width: 2 (two independent tracks)
```

---

## 8. Open Questions

1. **Elder Council: single agent or split Grandmother/Grandfather?** — Spec currently uses single Elder Council agent. User proposed split but we agreed to start unified, split later when vault depth justifies it. This is noted as a future enhancement.

2. **Family mode for Stage 5 (Review)?** — Currently family mode only applies to Stages 3 and 4 (same as debate mode). Could theoretically extend to Stage 5, but that stage already has its own multi-option system. Deferred.

3. **Persona strength in existing agents** — The session discussion identified strengthening existing review agent personas as a separate improvement. Not in scope for this blueprint but noted for future work.
