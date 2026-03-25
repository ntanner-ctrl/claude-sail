---
description: Use when investigating a problem space before planning. Unvalidated assumptions entering a blueprint cause expensive mid-implementation discoveries.
arguments:
  - name: topic
    description: What you're investigating (problem area, technology, or question)
    required: true
  - name: mode
    description: "Investigation depth: quick, standard, deep (default: standard)"
    required: false
---

## Cognitive Traps

Before skipping or simplifying this command, check yourself:

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "I already know enough to start planning" | You know what you THINK you know. Research surfaces the assumptions you're treating as facts. The blueprint ambiguity gate catches solution clarity — it cannot catch problem-space blindness. |
| "This will slow me down" | An hour of research prevents a day of mid-blueprint rework. The most expensive line in a spec is the one based on an untested assumption. |
| "Quick mode is enough" | Quick mode is for focused questions in known domains. If you're unsure which mode to pick, you need at least standard. |
| "I'll just do a quick grep and wing it" | Scattered grep sessions produce scattered understanding. Research structures the investigation so findings compound instead of evaporate. |

# Research

Structured investigation workflow that formalizes the ad-hoc research phase before blueprinting. Transforms scattered grep sessions, memory files, and vault notes into a progressive pipeline: freeform findings to synthesis brief.

> **Note:** Research is optional enrichment for blueprint, not a prerequisite.
> A blueprint can proceed without a research brief — the ambiguity gate will
> catch missing clarity. Research makes the blueprint better, not possible.

## Overview

```
Stage 1: Orient       → What do we already know? (vault search + prior research)
Stage 2: Investigate   → Active research (mode-dependent sub-steps)
Stage 3: Synthesize    → Produce research brief
Stage 4: Gate          → Problem-clarity ambiguity check

Cross-cutting:
  - Progressive vault capture (findings saved as they emerge)
  - Multi-session state tracking (deep mode)
  - Coverage manifest (tracks which sub-steps were run)
  - Human touchpoints after each sub-step
```

## Modes

| Mode | When | What It Does |
|------|------|-------------|
| `quick` | Focused question, known domain | Prior-art search + vault check → brief |
| `standard` | New problem area, moderate complexity | Brainstorm + prior-art + requirements-discovery → brief |
| `deep` | Unfamiliar domain, high stakes, multi-session | All standard steps + extended investigation + multi-session state |

Mode determines which sub-steps run, not the quality of each step.

## Process

### Mode Selection (when mode not specified)

If the user did not specify a mode at invocation, prompt:

```
Which best describes your situation?
  [1] Quick  — Focused question, known domain (5-10 min)
  [2] Standard — New problem area, moderate complexity (15-30 min)
  [3] Deep  — Unfamiliar domain, high stakes, may span sessions (30+ min)
```

Do NOT default silently. The mode choice determines which sub-steps run and whether multi-session state is tracked.

### Topic Sanitization

At argument ingestion, normalize the topic for filesystem use:

- **Slug:** lowercase, spaces to hyphens, strip characters outside `[a-z0-9-_]`. Used in ALL file paths.
- **Display name:** original topic string, preserved in YAML frontmatter as a quoted string (handles colons, ampersands safely).
- Both are stored in state.json: `"topic": "auth: redesign"`, `"topic_slug": "auth-redesign"`.

### State Initialization

Before beginning any research, initialize wizard state:

```
1. Ensure .claude/wizards/ exists (mkdir -p)
2. Check for active research sessions: glob .claude/wizards/research-*/state.json
   - Exclude _archive/ paths (active glob matches at top level only)
3. Handle existing sessions (see Multi-Session Support below)
4. If no active sessions: create new session
5. Create .claude/wizards/research-YYYYMMDD-HHMMSS/state.json
6. Initialize with:
   {
     "wizard": "research",
     "version": 1,
     "session_id": "research-<YYYYMMDD-HHMMSS>",
     "status": "active",
     "topic": "[display name]",
     "topic_slug": "[sanitized slug]",
     "mode": "[quick/standard/deep]",
     "current_stage": "orient",
     "stages": {
       "orient": { "status": "pending" },
       "investigate": {
         "status": "pending",
         "substeps": {
           "prior_art": { "status": "pending" },
           "brainstorm": { "status": "pending" },
           "requirements": { "status": "pending" },
           "extended_investigation": { "status": "pending" },
           "cross_project_vault": { "status": "pending" }
         }
       },
       "synthesize": { "status": "pending" },
       "gate": { "status": "pending" }
     },
     "coverage": {
       "prior_art": false,
       "brainstorm": false,
       "requirements": false,
       "extended_investigation": false
     },
     "findings_count": 0,
     "brief_path": null,
     "linked_blueprint": null
   }
7. Display initial stage progression header
```

### Multi-Session Support

On invocation, check for existing active research sessions:

**Multiple active sessions found:**
```
Active research sessions:
  [1] heartbeat-v2-constraints (standard, 2h ago, Stage 2: Investigate)
  [2] openvas-docker-limits (deep, 3d ago, Stage 1: Orient)
  [3] Start new research
```

List ALL active sessions by topic and session age before prompting.

**Single active session found:**
Display topic, mode, progress, and session age. Prompt to resume or start new.

**Staleness warning (session age exceeds 48 hours):**
```
This research session is [N] days old. Orient findings may be stale.
  [1] Resume from [current stage/substep]
  [2] Re-run Orient before continuing (refreshes vault search)
  [3] Abandon and start fresh
```

Display this prominently — stale research is worse than no research because it creates false confidence.

**No active sessions:** Create new session and proceed.

### Stage Navigation

Present the current stage header at each transition:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RESEARCH: [topic] │ Stage [N] of 4: [Stage Name]
  Mode: [quick/standard/deep] │ Findings: [N]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stages:
  ✓ 1. Orient        [completed]
  → 2. Investigate   ← You are here
  ○ 3. Synthesize
  ○ 4. Gate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Stage markers: `✓` complete, `→` active, `○` pending.

---

### Stage 1: Orient

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

1. Source vault config:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null
   ```
2. If vault available: search findings, decisions, patterns for topic terms
   - Use Grep to search `$VAULT_PATH` for the topic slug and key terms
   - Search across `Engineering/Findings/`, `Engineering/Decisions/`, `Engineering/Patterns/`
   - Present matches with titles and 1-line summaries
3. Search memory files for project context (`.claude/` memory files)
4. Search `.claude/plans/*/research.md` for prior research briefs in this project
5. If vault unavailable: skip with note, proceed to Stage 2

This is advisory — it surfaces context, not gates progress.

**State update:** Mark stage `orient` complete. Record `vault_hits` count. Set `current_stage` to `investigate`. Display updated stage progression header.

---

### Stage 2: Investigate

Active research, with sub-steps determined by mode:

| Sub-step | Quick | Standard | Deep | Command Used |
|----------|-------|----------|------|-------------|
| Prior art search | Yes | Yes | Yes | `/prior-art` |
| Problem analysis (brainstorm) | — | Yes | Yes | `/brainstorm` |
| Requirements discovery | — | Yes | Yes | `/requirements-discovery` |
| Extended investigation | — | — | Yes | Freeform (code reading, web search, experimentation) |
| Cross-project vault search | — | — | Yes | Vault MCP deep search |

**Sub-step invocation:** Each sub-step invokes its corresponding command with the research topic as context. The command runs normally — research does not modify how brainstorm/prior-art/requirements work. It orchestrates WHEN they run and captures their output.

**Sub-step outputs** are saved as working artifacts at `.claude/wizards/research-<id>/[substep].md`. These are intermediate — the research brief (Stage 3) is the durable artifact.

#### Progressive Vault Capture

After each sub-step completes, significant findings are saved to the vault as individual notes tagged with the research topic. This happens during investigation, not deferred to synthesis.

**Significance filter:** Only capture to vault if the finding is:
- Non-obvious (not something a quick search would reveal)
- Project-specific (not generic knowledge)
- Decision-relevant (would change a future decision)

The synthesis brief (Stage 3) is the primary durable artifact. Individual findings hit the vault only when they carry information the brief will not fully contain — dead ends that saved investigation time, edge cases worth preserving independently, surprising constraints.

**Vault write mechanics:**
1. Ensure `Engineering/Research/` and `Engineering/Findings/` directories exist before first write (mkdir-p equivalent via vault MCP)
2. Write finding to vault:
   ```
   Finding captured → vault: Engineering/Findings/YYYY-MM-DD-[topic-slug]-[finding-slug].md
   Tagged: research, [topic-slug], [sub-step-name]
   ```
3. `findings_count` in state.json increments ONLY after confirmed vault write
4. If vault write fails (MCP error, path issue, vault unavailable mid-session): log a warning and continue — the finding remains in the working artifact at `.claude/wizards/research-<id>/[substep].md` but is NOT counted as a vault finding

#### Human Touchpoints

After each sub-step completes, present findings and ask:

```
Sub-step complete: [name]
Key findings: [summary]

  [1] Continue to next sub-step
  [2] Investigate this finding deeper (adds to extended investigation)
  [3] I have enough — skip to synthesis
  [4] Pause research (save state, resume later)
```

Option [2] adds the selected finding to the extended investigation queue. Even in quick/standard mode, this allows the user to selectively go deeper on a specific thread without switching to deep mode.

Option [3] skips remaining sub-steps and advances to Stage 3. All completed sub-step coverage booleans are preserved — only unattempted steps show `false`.

Option [4] saves current state and exits. Available in all modes but primarily useful in deep mode for multi-session work. On resume, research picks up from the next pending sub-step.

**State update:** After each sub-step, mark it complete in `stages.investigate.substeps`. Update `coverage` booleans. If all mode-applicable sub-steps complete, mark `investigate` stage complete and set `current_stage` to `synthesize`. Display updated stage progression header.

---

### Stage 3: Synthesize

Transform individual findings into a structured research brief. This is the handoff artifact.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RESEARCH: [topic] │ Stage 3: Synthesize
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Synthesizing [N] findings into research brief...

  The brief will be written to:
    .claude/plans/[name]/research.md  (project-local)
    Vault: Engineering/Research/YYYY-MM-DD-[topic-slug].md (durable)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Blueprint Linkage

Before writing the brief, determine where it goes:

```
What will this research feed into?
  [1] An existing blueprint: [list detected blueprints from .claude/plans/*/state.json]
  [2] A new blueprint (enter name)
  [3] Standalone research (no blueprint link)
```

The answer determines:
- **Option 1/2:** Brief stored at `.claude/plans/[blueprint-name]/research.md`, `linked_blueprint` set in YAML frontmatter
- **Option 3:** Brief stored at `.claude/research/[topic-slug]/research.md`, `linked_blueprint: null`

#### Conflict Check

Before writing research.md, check if the file already exists at the target path:

```
A research brief already exists for [name] (dated [frontmatter.date]).
  [1] Overwrite with new research
  [2] Save as [name]-v2
  [3] View existing brief before deciding
```

The vault copy uses date-stamped paths (`YYYY-MM-DD-[topic-slug].md`) which naturally avoid collision across different days. Same-day re-runs to the same vault path ALSO prompt before overwriting.

#### Research Brief Format

The synthesis produces a research brief with this structure:

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

Sections that correspond to skipped sub-steps are omitted from the brief (not left as empty placeholders). The `coverage` YAML block tells downstream consumers which sections to expect.

The synthesis is Claude's work, informed by all findings. The user reviews and approves before the brief is written to disk.

**State update:** Mark `synthesize` complete. Record `brief_path` in state.json. Set `current_stage` to `gate`. Display updated stage progression header.

---

### Stage 4: Problem-Clarity Gate

The research-side ambiguity check. Three dimensions, each scored 1-5:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RESEARCH: [topic] │ Stage 4: Problem-Clarity Gate
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Problem-Clarity Rubric

| Dimension | Weight | Question | Anchors |
|-----------|--------|----------|---------|
| Problem Understanding | 40% | Is the problem space well-mapped? Could you explain it to a colleague? | 1=vague notion, 5=can draw the problem map with all actors and constraints |
| Constraint Discovery | 30% | Are the technical/resource/compatibility constraints identified? | 1=no constraints explored, 5=constraint space fully mapped with evidence |
| Solution Direction | 30% | Is there a clear enough direction for planning (not a solution, a direction)? | 1=no idea where to start, 5=confident direction with alternatives considered |

```
  Problem Understanding  [?/5] — Can you explain the problem space to a colleague?
  Constraint Discovery   [?/5] — Are technical/resource/compatibility constraints identified?
  Solution Direction     [?/5] — Is there a clear enough direction for planning?

  Composite Score: [weighted average] / 5.0
    (Problem Understanding: 40%, Constraint Discovery: 30%, Solution Direction: 30%)
```

#### Gate Behavior

- **Pass (>= 3.5):** Research complete, brief ready for consumption.
  ```
  Gate PASSED ([score]/5.0). Research brief is ready.
  ```

- **Warn (2.5-3.4):** Gaps identified, user decides.
  ```
  Gate WARNING ([score]/5.0). These areas remain unclear:
    - [specific gap 1]
    - [specific gap 2]

    [1] Accept gaps and complete research
    [2] Return to Investigate to address gaps
  ```

- **Block (< 2.5):** Problem space insufficiently understood.
  ```
  Gate BLOCKED ([score]/5.0). The problem space isn't well enough
  understood to hand off. Here's what's missing:
    - [specific missing area 1]
    - [specific missing area 2]

    [1] Return to Investigate (recommended)
    [2] Override and complete anyway (gaps will propagate to blueprint)
  ```

On pass (or user override), research is marked complete. The brief is the completion signal.

**State update:** Record `gate_score` in state.json. Update brief YAML frontmatter with final `gate_score`. Mark `gate` complete. Set `status` to `"complete"`. Display completion banner.

---

### Completion

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RESEARCH: [topic] │ Complete
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Mode: [quick/standard/deep]
  Findings captured: [N]
  Sub-steps completed: [list]

  Research brief written to:
    .claude/plans/[name]/research.md
    Vault: Engineering/Research/YYYY-MM-DD-[topic-slug].md

  Coverage: [brainstorm ✓] [prior-art ✓] [requirements ✓]
            [extended ✗]

  Next steps:
    /blueprint [name]  — Plan implementation (brief auto-consumed)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If a linked blueprint exists but is not yet started:
```
  Research brief is ready. Run /blueprint [name] to begin
  planning — the brief will be consumed automatically.
```

If standalone (no linked blueprint):
```
  Standalone research complete. Link to a blueprint later with:
    /blueprint [name]  — will auto-detect the brief by topic match
```

---

## Storage

| Artifact | Location | Purpose |
|----------|----------|---------|
| Wizard state | `.claude/wizards/research-<id>/state.json` | Progress tracking |
| Sub-step outputs | `.claude/wizards/research-<id>/[substep].md` | Working artifacts (not exported) |
| Individual findings | Vault: `Engineering/Findings/YYYY-MM-DD-[topic-slug]-*.md` | Durable knowledge (significance-filtered) |
| Research brief | `.claude/plans/[blueprint-name]/research.md` OR `.claude/research/[topic-slug]/research.md` | Handoff artifact |
| Vault brief copy | Vault: `Engineering/Research/YYYY-MM-DD-[topic-slug].md` | Durable copy |

**Vault directory creation:** Before first vault write, ensure target directories exist (`Engineering/Research/`, `Engineering/Findings/`). Use vault MCP mkdir-p equivalent. If directory creation fails, degrade to local-only storage with a warning.

---

## Coverage Manifest

The `coverage` block in the research brief YAML frontmatter is the key innovation. It tells downstream consumers WHICH sub-steps were run, enabling evidence-based skipping:

```yaml
coverage:
  prior_art: true      # /prior-art was run during research
  brainstorm: true     # /brainstorm was run during research
  requirements: true   # /requirements-discovery was run during research
  extended_investigation: false  # deep-mode extended work
```

Consumers read this YAML frontmatter to make **routing** decisions (skip or run a gate). For **quality** signal, consumers read `gate_score` (0-5 composite from problem-clarity gate) and `mode` (depth of investigation). Coverage booleans answer "was this done?" — gate_score and mode answer "how thoroughly?"

---

## Vault Awareness

Before starting Stage 1, source vault configuration:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

If vault available (`VAULT_ENABLED=1`):
- Orient stage searches vault for prior knowledge
- Progressive capture writes findings to vault during investigation
- Synthesis stage writes durable brief copy to vault
- All vault operations are fail-open — vault failure degrades gracefully

If vault unavailable:
- Orient stage searches only memory files and prior research briefs
- Progressive capture stores findings in local working artifacts only
- Synthesis stage writes brief to project-local path only
- No warnings displayed (vault is optional enrichment)

---

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| Sub-step command fails (/brainstorm, /prior-art, etc.) | Command produces no output or errors | Log failure, skip sub-step, mark coverage as false, continue to next sub-step |
| Vault write fails mid-session | MCP error or vault path issue | Warning displayed, finding retained in local working artifact, findings_count NOT incremented |
| Vault unavailable at session start | vault-config.sh returns VAULT_ENABLED=0 | Skip vault features silently, proceed with local-only storage |
| State file corrupted on resume | state.json unparseable | Abandon corrupt session, prompt to start fresh |
| Session stale (>48h) | Timestamp comparison against session_id | Prominent staleness warning with option to refresh Orient |
| Multiple active sessions for same topic | Glob finds overlapping topic slugs | List all, let user choose which to resume or abandon |
| Brief target path conflict | research.md already exists at target | Prompt: overwrite, version, or view existing |
| Gate score too low | Composite < 2.5 | Block with specific gaps, user can override or return to Investigate |
| Extended investigation produces no findings | Deep mode freeform returns empty | Note in coverage, proceed to synthesis with available findings |
| Context exhaustion during deep mode | Long multi-session investigation | Sub-step outputs are persisted to disk — resume reconstructs from files, not memory |

## Known Limitations

- **Research does not replace domain expertise** — it structures investigation, but the quality of findings depends on Claude's knowledge of the domain. Novel or niche domains may produce shallow findings.
- **Vault capture is significance-filtered** — the filter is LLM judgment. Some findings that seem insignificant during research may prove critical during implementation. The working artifacts (substep .md files) retain everything; only vault capture is filtered.
- **Progressive capture is append-only** — findings captured to vault during investigation cannot be retracted if later sub-steps contradict them. The synthesis brief is the authoritative artifact; individual vault findings are supplementary.
- **Mode selection is one-way** — upgrading from quick to standard mid-research is not supported. Start a new research session if deeper investigation is needed.
- **Cross-project vault search (deep mode) depends on vault organization** — if prior projects did not capture findings to vault, deep mode's cross-project search returns nothing. This is a bootstrapping limitation.
- **Coverage manifest is boolean, not quality-scored** — `prior_art: true` means the step ran, not that it was thorough. Consumers should check `gate_score` and `mode` for quality signal.

## Integration

- **Produces:** Research brief (`.claude/plans/[name]/research.md`) with coverage manifest
- **Consumed by:** `/blueprint` via optional-enrichment pattern (see `docs/OPTIONAL-ENRICHMENT.md`)
- **Sub-commands invoked:** `/prior-art`, `/brainstorm`, `/requirements-discovery`
- **State tracked in:** `.claude/wizards/research-<id>/`
- **Vault directories:** `Engineering/Research/`, `Engineering/Findings/`
- **Supersedes:** `/clarify` (deprecated — use `/research` for investigation, `/design-check` for implementation readiness)
