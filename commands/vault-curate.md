---
description: Use when you need to review, triage, and maintain the Obsidian vault. Covers all content types (findings, blueprints, ideas, sessions, decisions, patterns) for staleness, contradictions, and synthesis. Modifies vault notes — always previews changes before applying.
---

# Vault Curate

Interactive, multi-stage knowledge triage workflow for the Obsidian vault. Covers all 6 content types with type-specific health signals. Integrates Empirica calibration data when available. Self-tuning frequency recommendations.

Subsumes `/review-findings`, which is now a deprecated alias for `/vault-curate --quick --section findings`.

## Command Signature

```
/vault-curate                                    # Full 6-stage interactive workflow
/vault-curate --quick                            # Quick pass: Inventory + Triage (findings only) + Report
/vault-curate --section findings|blueprints|ideas|sessions|decisions|patterns
                                                 # Deep dive on one vault area
/vault-curate --project NAME                     # Filter to one project
/vault-curate --skip-health                      # Skip Stage 2 (Health Check)
/vault-curate --skip-synthesis                   # Skip Stage 4 (Synthesis)
```

Flags are composable: `--quick --project claude-sail` works.

## Vault Content Types

6 content types, each with type-specific health signals.

**Type authority**: The note's **directory** is authoritative for type classification, NOT the `type` frontmatter field. A file in `Engineering/Findings/` is always a Finding regardless of its `type` field. If the frontmatter `type` contradicts the directory, log a warning during triage but use the directory-based type for all processing.

| Type | Directory | Health Signals |
|------|-----------|----------------|
| Finding | `Engineering/Findings/` | `empirica_status`, `empirica_confidence`, `empirica_assessed` age |
| Blueprint | `Engineering/Blueprints/` | Linked plan still exists? Execute stage reached? Age vs. project activity |
| Idea | `Ideas/` | Age without action (>30 days = cold), linked to any blueprint? |
| Session | `Sessions/` | Has findings? Has open questions? Links to other notes? |
| Decision | `Engineering/Decisions/` | Referenced by later work? Superseded by newer decisions? |
| Pattern | `Engineering/Patterns/` | Still seen in codebase? Referenced by findings? |

---

## Stage 1: Inventory

**Always runs. Not skippable.**

### 1.1 Source vault config and anchor date

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
TODAY=$(date +%Y-%m-%d)
echo "TODAY=$TODAY"
```

If vault unavailable, stop: `"Vault not available. /vault-curate requires an accessible Obsidian vault."`

Use `$TODAY` as the reference date for ALL age calculations throughout the session.

### 1.2 Check vault write access (early detection)

```bash
touch "$VAULT_PATH/.vault-curate-writetest" 2>/dev/null && rm "$VAULT_PATH/.vault-curate-writetest" && echo "WRITABLE" || echo "READ_ONLY"
```

If read-only, warn immediately:
```
Warning: Vault is read-only. Running in review-only mode — Stages 1-4 will work normally but Stage 5 (Prune) will be skipped.
```

### 1.3 Check for existing triage checkpoint

```bash
if [ -f "$VAULT_PATH/.vault-curate-checkpoint.jsonl" ]; then
  AGE=$(( ($(date +%s) - $(stat -c %Y "$VAULT_PATH/.vault-curate-checkpoint.jsonl")) / 3600 ))
  LINES=$(wc -l < "$VAULT_PATH/.vault-curate-checkpoint.jsonl")
  echo "CHECKPOINT_EXISTS age_hours=$AGE verdicts=$LINES"
elif [ -f "${GIT_ROOT:-.}/.claude/.vault-curate-checkpoint.jsonl" ]; then
  AGE=$(( ($(date +%s) - $(stat -c %Y "${GIT_ROOT:-.}/.claude/.vault-curate-checkpoint.jsonl")) / 3600 ))
  LINES=$(wc -l < "${GIT_ROOT:-.}/.claude/.vault-curate-checkpoint.jsonl")
  echo "CHECKPOINT_EXISTS age_hours=$AGE verdicts=$LINES location=project"
else
  echo "NO_CHECKPOINT"
fi
```

**If checkpoint exists and < 24 hours old**, offer:
```
Found checkpoint from [N] hours ago with [N] verdicts.
  [1] Resume — skip already-triaged notes, continue from where you left off
  [2] Start fresh — discard checkpoint and begin new curation
```

**If checkpoint exists and >= 24 hours old**, warn:
```
Found stale checkpoint from [N] hours ago with [N] verdicts.
This checkpoint is too old to resume reliably.
  [1] Discard and start fresh
  [2] Resume anyway (verdicts may not match current vault state)
```

### 1.4 Bulk scan vault directories using bash (scale-safe)

Instead of reading each file individually, use a single bash command to extract frontmatter from all notes:

```bash
for dir in "$VAULT_PATH/Engineering/Findings" "$VAULT_PATH/Engineering/Blueprints" "$VAULT_PATH/Engineering/Decisions" "$VAULT_PATH/Engineering/Patterns" "$VAULT_PATH/Ideas" "$VAULT_PATH/Sessions"; do
  for f in "$dir"/*.md 2>/dev/null; do
    [ -f "$f" ] || continue
    echo "=== FILE: $f ==="
    awk '/^---$/{if(c++) exit} c{print}' "$f" 2>/dev/null || echo "PARSE_ERROR"
  done
done
```

**Malformed or missing YAML handling**: If a note's frontmatter fails to parse (missing closing `---`, syntax errors, awk outputs `PARSE_ERROR`) OR produces empty output (no `---` delimiters at all), treat the note as **Unassessed** with type inferred from its directory. Do not attempt to infer field values. Log: `"Skipping malformed/missing frontmatter: [filename]"`

### 1.5 Filter archived notes

Exclude any note whose frontmatter contains `archived: true` from all subsequent processing. Count them separately: `Archived (excluded): N notes`

### 1.6 Check for active Empirica session

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$GIT_ROOT" ]; then
  cat "$GIT_ROOT/.empirica/active_session" 2>/dev/null || echo "NO_SESSION"
else
  echo "NO_SESSION"
fi
```

If session available, query `mcp__empirica__get_calibration_report` for calibration data.

### 1.7 Apply filters

**`--project` filter**: Match notes where the `project` frontmatter field, after lowercasing, exactly equals the lowercased flag value. Notes with no `project` field are excluded when `--project` is specified. If zero notes match:
```
No notes found for project "[NAME]". Available projects: [list from scan]
```
and exit.

**`--section` filter**: Restrict processing to only the specified content type's directory. Applies to all stages. If zero notes match:
```
No [type] notes found in vault. Available sections with content: [list non-empty types]
```
and exit.

### 1.8 Compute distributions

- **Age distribution** using `$TODAY` as reference: buckets 0-7 days, 8-30 days, 31-90 days, 90+ days
- **Project distribution**: notes by project name

### 1.9 Scale warning (if total active notes > 100)

```
Warning: Large vault (N notes). Full curation may take 60-90 minutes.
Consider: --section [type] or --quick for a shorter session.
```

### Inventory Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT INVENTORY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Total notes: N
  Empirica session: [session_id or "none — proceeding without calibration"]

  By type:
    Findings:    N
    Blueprints:  N
    Ideas:       N
    Sessions:    N
    Decisions:   N
    Patterns:    N

  By project:
    claude-sail:  N
    project-scout:     N
    [other]:           N

  By age:
    Fresh (0-7d):      N
    Recent (8-30d):    N
    Aging (31-90d):    N
    Old (90+d):        N

  Calibration: [adjustment note or "no Empirica data"]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Stage 2: Health Check

**Skippable with `--skip-health`. Skipped in `--quick` mode.**

When `--section` is set, only assess health for the specified content type.

### Health Criteria by Type

**Findings:**
| Status | Criteria |
|--------|----------|
| Contradicted | `empirica_status: contradicted` |
| Stale | `empirica_status: stale` OR `empirica_assessed` > 30 days ago |
| Low confidence | `empirica_confidence` < 0.6 |
| Partially assessed | Has SOME but not ALL `empirica_*` fields. Treat as Unassessed for health scoring (neutral) but flag in triage as "incomplete assessment — needs full review." |
| Unassessed | No `empirica_*` fields at all |
| Healthy | `empirica_status: confirmed` AND confidence >= 0.7 AND assessed < 30 days |

**Blueprints:**
| Status | Criteria |
|--------|----------|
| Orphaned | References a plan directory that does not exist. If path can't be resolved, classify as Unknown. |
| Incomplete | Execute stage not reached |
| Stale | > 60 days old AND no recent session references it |
| Healthy | Execute complete, linked plan exists or age < 60 days |

**Ideas:**
| Status | Criteria |
|--------|----------|
| Cold | > 30 days old with no linked blueprint or session |
| Acted on | Has a linked blueprint or referenced in a session |
| Fresh | < 30 days old |

**Sessions:**
| Status | Criteria |
|--------|----------|
| Sparse | No findings, no open questions, no links |
| Rich | Has findings AND links to other notes |
| Isolated | No backlinks from other notes |

**Decisions:**
| Status | Criteria |
|--------|----------|
| Superseded | Claude identifies a newer decision on the same topic (semantic similarity of titles, overlapping tags, same `component` field). MUST state reasoning: "This decision appears superseded because [newer decision] also addresses [topic] and is dated [N] days later." |
| Unreferenced | No other notes link to this decision |
| Active | Referenced by findings or blueprints within last 90 days |

**Patterns:**
| Status | Criteria |
|--------|----------|
| Unused | No findings or sessions reference this pattern |
| Active | Referenced by recent work |

### Vault Health Score

Compute overall health (0-100) using weighted categories:

```
healthy_weight    = 1.0   (confirmed, active, fresh, rich, acted_on)
neutral_weight    = 0.5   (unassessed, incomplete, unreferenced, isolated)
unhealthy_weight  = 0.0   (contradicted, stale, orphaned, cold, superseded, sparse, unused)

if total_count == 0:
    score = "N/A"  # no active notes to assess
else:
    weighted_sum = (healthy_count * 1.0) + (neutral_count * 0.5) + (unhealthy_count * 0.0)
    score = round(100 * weighted_sum / total_count)
```

When `total_count == 0`, display `"Health score: N/A (no active notes)"` and skip frequency recommendation in Stage 6.

### Health Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT HEALTH CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Overall health: NN/100

  Needs attention:
    Findings:
      Contradicted: N   Stale: N   Low confidence: N   Unassessed: N

    Blueprints:
      Orphaned: N   Stale: N   Incomplete: N

    Ideas:
      Cold (>30d, no action): N

    Sessions:
      Sparse: N   Isolated: N

    Decisions:
      Superseded: N   Unreferenced: N

    Patterns:
      Unused: N

  Healthy notes: N/N total (X%)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Stage 3: Triage

**Always runs (core stage). In `--quick` mode, only processes findings.**

### Grouping Strategy

Group notes needing attention:
1. **By project** (primary) — review all notes for one project together
2. **By type** (secondary within project) — findings first, then blueprints, ideas, etc.
3. **By severity** (tertiary) — contradicted/orphaned first, then stale, then unassessed

### Interactive Flow

For each group, present the group header:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Reviewing: [project] / [type] (N notes)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

For each note:

1. **Show the note**: title, date, project, current status, 2-3 line summary
2. **Show context**:
   - Findings: search codebase for related code, check recent git history
   - Blueprints: check if linked plan directory exists, check execute status
   - Ideas: check if any blueprint or session references it
   - Decisions: check if newer decisions exist for same topic
   - Sessions: check finding count, link count
   - Patterns: check codebase for usage
3. **Assess**: Propose updated status with reasoning
4. **Offer verdict** (type-appropriate):

**Findings verdicts:**
```
  [1] Confirm — mark as confirmed, update confidence
  [2] Update — edit content, then confirm
  [3] Contradict — mark as contradicted, add note
  [4] Stale — needs deeper investigation later
  [5] Skip — leave as-is (adds last_reviewed date)
  [6] Archive — flag as archived (remains in place)
```

**Blueprints verdicts:**
```
  [1] Current — blueprint is still relevant
  [2] Completed — work was done, mark as complete
  [3] Abandoned — mark as abandoned with reason
  [4] Skip — leave as-is
  [5] Archive — flag as archived
```

**Ideas verdicts:**
```
  [1] Still relevant — keep, update if needed
  [2] Acted on — link to blueprint/finding that implements it
  [3] Superseded — another approach was taken
  [4] Skip — leave as-is
  [5] Archive — flag as archived
```

**Sessions verdicts:**
```
  [1] Enriched — add missing links or findings references
  [2] Complete — no action needed
  [3] Skip — leave as-is
  [4] Archive — flag as archived (old, sparse sessions)
```

**Decisions verdicts:**
```
  [1] Still active — decision is current
  [2] Superseded — link to newer decision
  [3] Skip — leave as-is
  [4] Archive — flag as archived
```

**Patterns verdicts:**
```
  [1] Active — still in use
  [2] Evolved — update to reflect current practice
  [3] Skip — leave as-is
  [4] Archive — flag as archived
```

**Note on Skip**: Even when skipping, add `last_reviewed: YYYY-MM-DD` to frontmatter so future runs can distinguish "never triaged" from "deliberately skipped." This applies to ALL content types.

### Batch Operations

After presenting each group, offer:
```
Group summary: N notes reviewed
  Batch options:
    [B1] Confirm all remaining in this group
    [B2] Skip all remaining in this group
    [B3] Continue one-by-one
```

### Triage Checkpoint (Persistence)

Persist verdicts incrementally to prevent loss on session interruption. After each verdict:

```bash
CHECKPOINT_DIR="$VAULT_PATH"
[ -w "$VAULT_PATH" ] || CHECKPOINT_DIR="${GIT_ROOT:-.}/.claude"
SAFE_PATH=$(echo '[note_path]' | sed 's/\\/\\\\/g; s/"/\\"/g')
echo "{\"path\":\"$SAFE_PATH\",\"verdict\":\"[verdict]\",\"confidence\":[value],\"timestamp\":\"[ISO-8601]\"}" >> "$CHECKPOINT_DIR/.vault-curate-checkpoint.jsonl"
```

When Stage 5 (Prune) completes successfully, delete the checkpoint file.

### Conversation Mode

Unlike checklist-based review, triage encourages discussion:

- After showing context, pause for user input before proposing a verdict
- If user says "tell me more" — expand with full note content, deeper codebase search, related notes
- If user says "what else is related?" — search vault for notes with overlapping tags, project, or keywords
- If user proposes a different interpretation — adapt the verdict

**Verdict closure protocol**: After any open-ended discussion, re-present the numbered verdict options. A note's triage is only complete when the user selects a numbered option (or says "skip"). Conversational statements like "yeah, archive it" MUST be confirmed: "Understood — selecting [6] Archive. Correct?"

---

## Stage 4: Synthesis

**Skippable with `--skip-synthesis`. Skipped in `--quick` mode.**

Analyze the **full vault state** — not just notes acted on in this session. Skipped notes retain their prior status and are included based on existing frontmatter.

**Partial triage caveat**: If >50% of notes were skipped or batch-skipped in Stage 3, prepend output with: `"Note: Synthesis is based on partial triage (N% of notes were skipped). Gap detection may reflect triage coverage rather than actual knowledge gaps."`

### Analysis Types

1. **Cluster detection**: Group confirmed findings by overlapping tags, keywords, project. Identify clusters of 3+ findings sharing a theme.
2. **Cross-project patterns**: Findings from different projects describing the same underlying pattern.
3. **Contradiction detection**: Findings that contradict each other.
4. **Gap detection**: Areas with suspiciously few findings. "You have 15 findings about hooks but zero about agent design — is that intentional or a blind spot?"
5. **Trend analysis**: If multiple curations have occurred, compare decay rates and accumulation patterns.

### Synthesis Trellis

For each observation, present within a structured frame:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SYNTHESIS OBSERVATION [N of M]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Type: [Cluster | Cross-Project | Contradiction | Gap | Trend]

  Observation: [2-3 sentence description]

  Evidence:
    - [[finding-1]] (project-a)
    - [[finding-2]] (project-b)
    - [N more related notes]

  Proposed action:
    [1] Create meta-finding — capture this as a new finding note
    [2] Merge findings — combine N findings into one consolidated note
    [3] Note and continue — interesting but no action needed
    [4] Dismiss — not actually a meaningful pattern
    [5] Promote to pattern — extract the reusable principle into Engineering/Patterns/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Meta-Finding Creation

When user selects "Create meta-finding", create a new finding note directly (NOT via `/vault-save`):

- **Location**: `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-[slug].md`
- **Frontmatter**:
  ```yaml
  type: finding
  date: YYYY-MM-DD
  project: [primary project, or "cross-project" if multi-project]
  category: synthesis
  tags: [synthesis, source project tags]
  empirica_confidence: 0.7
  empirica_status: active
  synthesis_source: true
  synthesized_from:
    - "[[source-finding-1]]"
    - "[[source-finding-2]]"
  ```
- **Content**: observation text + evidence links as wiki-links

### Merge Findings

**Merge NEVER deletes source notes.** Source notes are archived in place.

#### Merge Process

1. **Present merge preview**:
   ```
   Merging N findings into one consolidated note:
     Sources:
       - [[finding-1]]: "Title 1" (project-a, confidence: 0.8)
       - [[finding-2]]: "Title 2" (project-a, confidence: 0.7)

     Proposed merged title: "[synthesized title]"
     Proceed? [Y/n]
   ```
   If **n**, cancel and return to the synthesis observation frame, re-presenting the four action options.

2. **Create the merged note** at `$VAULT_PATH/Engineering/Findings/YYYY-MM-DD-[slug].md`:
   ```yaml
   type: finding
   date: YYYY-MM-DD
   project: [primary project, or "cross-project"]
   category: synthesis
   tags: [union of all source tags, plus "merged"]
   empirica_confidence: [average of source confidences]
   empirica_status: active
   synthesis_source: true
   merged_from:
     - "[[source-finding-1]]"
     - "[[source-finding-2]]"
   ```
   Content: consolidated text incorporating key points from all sources, with wiki-links back to each source.

3. **Archive each source note** (do NOT delete). Add to each source's frontmatter:
   ```yaml
   archived: true
   archived_date: YYYY-MM-DD
   archived_reason: "Merged into [[merged-note-title]]"
   merged_into: "[[merged-note-title]]"
   ```

4. **Confirm**: `"Merged N findings -> [[merged-note-title]]. Source notes archived (not deleted)."`

### Promote to Pattern

When user selects "Promote to pattern", extract the reusable principle from a finding cluster into `Engineering/Patterns/`:

#### Promotion Process

1. **Present pattern extraction preview**:
   ```
   Promoting cluster to pattern:
     Source findings:
       - [[finding-1]]: "Title 1" (project-a)
       - [[finding-2]]: "Title 2" (project-b)

     Proposed pattern title: "[extracted principle]"
     Applicability: "[when this pattern applies]"
     Proceed? [Y/n]
   ```
   If **n**, cancel and return to the synthesis observation frame, re-presenting the five action options.

2. **Create the pattern note** using the template (`~/.claude/commands/templates/vault-notes/pattern.md`) at `$VAULT_PATH/Engineering/Patterns/YYYY-MM-DD-[slug].md`:
   ```yaml
   type: pattern
   date: YYYY-MM-DD
   project: [primary project, or "cross-project"]
   tags: [pattern, source project tags]
   extracted_from:
     - "[[source-finding-1]]"
     - "[[source-finding-2]]"
   applicability: "[when to use this pattern]"
   ```
   Content: the reusable principle, when to use it, example, source findings list, and trade-offs.

3. **Update source findings** to link to the new pattern. Add to each source finding's frontmatter:
   ```yaml
   pattern_link: "[[pattern-name]]"
   ```

4. **Confirm**: `"Pattern created: [[pattern-name]]. N source findings linked."`

---

## Stage 5: Prune

**Always runs. Applies decisions from Stages 3-4.**

### Dry-Run Preview

Before applying changes, present a summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PRUNE PREVIEW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Changes to apply:

    Update frontmatter:     N notes
    Edit content:           N notes
    Archive (flag):         N notes
    Create meta-findings:   N notes

  [1] Apply all
  [2] Review changes one-by-one
  [3] Cancel (no changes applied)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Apply Changes

For each note with a verdict:

1. **Confirmed/Active/Current** — Update frontmatter:
   ```yaml
   empirica_assessed: YYYY-MM-DD
   empirica_status: confirmed
   empirica_confidence: [updated value]
   empirica_session: [current session ID]
   ```

2. **Updated/Enriched/Evolved** — Edit note content as discussed, then update frontmatter.

3. **Contradicted** — Update frontmatter:
   ```yaml
   empirica_status: contradicted
   empirica_confidence: [low value]
   empirica_assessed: YYYY-MM-DD
   ```
   Add to Implications section:
   ```markdown
   > Contradicted during vault curation on YYYY-MM-DD — [brief reason]
   ```

4. **Archived** — Add frontmatter flag:
   ```yaml
   archived: true
   archived_date: YYYY-MM-DD
   archived_reason: [reason from verdict]
   ```
   Note remains in its original location. Future inventory scans exclude `archived: true`.

5. **Acted on (ideas)** — Update:
   ```yaml
   acted_on: true
   acted_on_date: YYYY-MM-DD
   acted_on_link: "[[linked-blueprint-or-finding]]"
   ```

6. **Superseded (decisions)** — Update:
   ```yaml
   superseded: true
   superseded_by: "[[newer-decision]]"
   superseded_date: YYYY-MM-DD
   ```

7. **Log to Empirica** (if session active): `mcp__empirica__finding_log` for each updated note. For archived notes, prefix finding with "[Archived] " (NOT `deadend_log` — archiving is curation, not a dead end).

### Interruption Recovery

If session interrupts during Stage 5:
- Notes already updated are in a better state than before (each update is independent)
- Notes not yet updated remain unchanged — NOT corrupted
- Checkpoint file still exists for next run to resume
- No rollback mechanism because partial application is not harmful

### Post-Prune Cleanup

When Stage 5 completes successfully, delete the checkpoint file:
```bash
rm -f "$VAULT_PATH/.vault-curate-checkpoint.jsonl" "$CHECKPOINT_DIR/.vault-curate-checkpoint.jsonl" 2>/dev/null
```

---

## Stage 6: Report

**Always runs. Not skippable.**

### Frequency Recommendation

Calculate based on observed decay rate. Skip entirely if `total_count == 0`:

```
if total_count == 0:
    skip frequency recommendation; display "N/A (no active notes)"

decay_rate = (stale_count + contradicted_count) / total_count

# Use MEDIAN of empirica_assessed dates (not most recent) to avoid single-note bias
assessed_notes = notes where empirica_assessed exists
fraction_never_assessed = 1 - (len(assessed_notes) / total_count)

if assessed_notes:
    median_assessed_date = median(assessed_notes.empirica_assessed)
    days_since_median_curation = TODAY - median_assessed_date
else:
    days_since_median_curation = 999  # never curated

if decay_rate > 0.3:       recommend = "1-2 weeks"
elif decay_rate > 0.15:    recommend = "2-4 weeks"
elif decay_rate > 0.05:    recommend = "monthly"
else:                      recommend = "quarterly"

# Adjust for vault growth rate
# notes_created_since_last_curation = count of notes whose `date` field
# is after median_assessed_date (or all notes if no assessed dates)
notes_created_since_last_curation = count(notes where date > median_assessed_date)

if notes_created_since_last_curation > 20:
    bump one tier sooner (quarterly->monthly, monthly->2-4wk, 2-4wk->1-2wk)

# Adjust for high fraction never assessed
if fraction_never_assessed > 0.5:
    bump one tier sooner (same mapping)
```

### Report Output

**Health comparison**: Only show "Before/After" when Stage 2 ran. When Stage 2 was skipped, omit the health comparison section.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CURATION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Session summary:
    Notes reviewed:     N
    Confirmed:          N
    Updated:            N
    Contradicted:       N
    Archived:           N
    Merged:             N (source notes archived)
    Skipped:            N
    Meta-findings:      N (new synthesis notes)

  [If Stage 2 ran:]
  Vault health:
    Before: NN/100
    After:  NN/100 (+NN)

  [If Stage 4 ran:]
  Synthesis:
    Clusters found:     N
    Cross-project:      N
    Contradictions:     N
    Gaps identified:    N

  Next curation:
    Recommended in ~N weeks (based on N% decay rate)
    Suggested date: YYYY-MM-DD
    [If fraction_never_assessed > 0.3:]
    Note: N% of vault has never been assessed — consider a focused
    --section pass to build baseline coverage.

  Time spent: ~N minutes

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Write Cadence Marker

After report is generated, write the curation date for the bootstrap hook to check:

```bash
echo "$(date +%Y-%m-%d)" > "$VAULT_PATH/.vault-last-curated"
```

### Log to Empirica

If session active, call `mcp__empirica__finding_log` with:
- finding: "[Vault curation] Vault curation complete: N notes reviewed, health NN->NN, next curation ~YYYY-MM-DD"

---

## Quick Mode (`--quick`)

When `--quick` is passed:

1. **Inventory** runs (always)
2. **Health Check** skipped
3. **Triage** runs but ONLY for findings (same scope as original `/review-findings`)
4. **Synthesis** skipped
5. **Prune** runs (applies triage decisions)
6. **Report** runs (abbreviated — no health comparison, no synthesis section)

---

## Fail-Soft Behavior

- **No vault**: Stop immediately with helpful error
- **No Empirica session**: Proceed without calibration data. Skip calibration-dependent features. Note in inventory: "No Empirica session — proceeding without calibration data"
- **Vault on unreachable path**: Stop with error (e.g., NTFS path not mounted in WSL)
- **Read-only vault**: Detected at Stage 1. Allow Stages 1-4 in review-only mode. Skip Stage 5 entirely: "Vault is read-only — changes were not applied. Verdicts are saved in the checkpoint file for when write access is restored."
- **Individual note read failure**: Skip note, log warning, continue with remaining notes
- **Empirica call failure mid-session**: Log warning, continue without Empirica for remainder
