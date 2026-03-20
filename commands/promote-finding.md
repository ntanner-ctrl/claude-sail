---
description: Use when a finding has been observed multiple times and is ready to become a CLAUDE.md rule. Manages the full promotion lifecycle with capacity checking.
arguments:
  - name: finding
    description: Finding text, vault path, or omit to list candidates
    required: false
---

# Promote Finding

Manages the lifecycle of findings from isolated observation to codified CLAUDE.md rule, with mandatory capacity checking and paired pruning to prevent unbounded growth.

## Maturation Tiers

```
Tier 1: ISOLATED     — Single observation, one session
                        Source: `.epistemic/insights.jsonl`, vault notes

Tier 2: CONFIRMED    — Observed 2+ times across sessions
                        Source: Cross-referencing vault findings by similarity

Tier 3: CONVICTION   — 3+ confirmations, consistent pattern
                        Source: User acknowledgment or automatic detection

Tier 4: PROMOTED     — Codified into CLAUDE.md as a project rule
                        Source: /promote-finding command
```

## Command Signature

```
/promote-finding                          # List recent Tier 3 (conviction) candidates
/promote-finding [finding text]           # Search vault for matching findings
/promote-finding [vault-path]             # Read specific finding from vault
```

---

## Step 1: Identify the Finding

### If argument is a vault path

Read the finding directly:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

Use `mcp__obsidian__get_note` to read the note at the given path. Extract the finding text from the note content.

### If argument is text

Search vault for matching findings:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

Use `mcp__obsidian__search_notes` or `mcp__obsidian__intelligent_search` with the provided text. Present matches ranked by relevance:

```
Found N matching findings:
  [1] "Finding text..." — 2026-02-15, project-a, confidence: 0.8
  [2] "Finding text..." — 2026-02-28, project-b, confidence: 0.7
  [3] "Finding text..." — 2026-03-01, project-a, confidence: 0.9

Select a finding to promote [1-N]:
```

### If no argument

List recent Tier 3 (conviction) candidates. Search vault for findings that appear 3+ times:

1. Read all findings from `Engineering/Findings/` directory
2. Group by semantic similarity (overlapping tags, similar titles, matching content themes)
3. Filter to clusters with 3+ members
4. Exclude any already marked as `tier: promoted`
5. Present candidates:

```
Conviction-level findings (3+ observations):

  [1] "Hook fail-open pattern is critical for reliability"
      Observations: 4 across 3 sessions
      Projects: claude-sail, project-scout

  [2] "CLAUDE.md description field must be trigger-only"
      Observations: 3 across 2 sessions
      Projects: claude-sail

  [0] Cancel

Select a finding to promote [1-N]:
```

If no conviction-level findings exist:

```
No findings at conviction level (3+ observations).

Closest candidates (2 observations):
  [1] "Finding text..." — 2 observations across 2 sessions

Promote with reduced evidence? Or wait for more observations.
  [1] Promote anyway (will require extra user confirmation)
  [0] Cancel
```

---

## Step 2: Verify Maturation

### Evidence gathering

Search vault for ALL notes related to the selected finding:
- Search by key phrases from the finding text
- Search by matching tags
- Search by related project names
- Check `.epistemic/insights.jsonl` for additional findings

### Independence assessment

For each observation found, assess independence:

| Marker | Criteria |
|--------|----------|
| INDEPENDENT | Different session AND different context (different blueprint, different task) |
| CORRELATED | Same session as another observation, OR arose as a reflection/derivative of another observation |
| DUPLICATE | Same finding logged to multiple systems (e.g., vault note + insights.jsonl = 1 observation) |

**Correlation detection rules:**
- A `reflect.md` entry that references a finding from the same session = CORRELATED
- An `insights.jsonl` entry and a vault note with identical text from the same session = DUPLICATE (count as 1)
- A finding in session X that explicitly references a finding from session Y = CORRELATED with Y
- Findings from different sessions about different tasks = INDEPENDENT even if the finding text is similar

### Present evidence trail

```
Evidence trail for "[finding summary]":

  [1] 2026-02-15 — Session abc123 — Blueprint: auth-feature    [INDEPENDENT]
      Source: Engineering/Findings/2026-02-15-hook-fail-open.md

  [2] 2026-02-28 — Session def456 — Blueprint: api-refactor    [INDEPENDENT]
      Source: .epistemic/insights.jsonl

  [3] 2026-03-01 — Session def456 — Reflection from [2]        [CORRELATED with #2]
      Source: Engineering/Findings/2026-03-01-hook-pattern-reflection.md

  Independent observations: 2 of 3 (minimum 2 required for Conviction)
```

### Threshold check

- **2+ INDEPENDENT observations**: Proceed to Step 3.
- **Fewer than 2 INDEPENDENT observations**: Warn before proceeding.

```
Warning: Only N independent observation(s) found. The minimum for Conviction
is 2 independent observations from different sessions and contexts.

Promote anyway? This finding may not yet be mature enough for codification.
  [1] Promote anyway — I have additional evidence not captured in the vault
  [2] Cancel — wait for more observations
```

### User acknowledgment (REQUIRED)

Present the evidence trail and WAIT for explicit user confirmation before proceeding. The user MUST confirm the evidence is valid.

```
Review the evidence trail above. Is this evidence sufficient to promote?
  [Y] Yes, proceed with promotion
  [N] No, cancel
```

Do NOT generate the CLAUDE.md rule draft until the user confirms.

---

## Step 3: Capacity Check

Read the target project's CLAUDE.md file and count lines:

```bash
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
wc -l "$GIT_ROOT/.claude/CLAUDE.md" 2>/dev/null || wc -l "$GIT_ROOT/CLAUDE.md" 2>/dev/null || echo "NO_CLAUDE_MD"
```

### Capacity rules

| CLAUDE.md Size | Behavior |
|---------------|----------|
| < 150 lines | Promote freely. No capacity concerns. |
| 150-200 lines | Warn: "CLAUDE.md is at [N] lines. Getting full. Consider pruning on next promotion." Proceed with promotion. |
| > 200 lines | REQUIRE paired retirement before promotion. "CLAUDE.md is at [N] lines. Before promoting, you MUST identify a stale entry to retire." |
| > 300 lines | BLOCK promotion entirely. "CLAUDE.md is at [N] lines — too large. Run /vault-curate to triage before promoting." Stop here. |

### When paired retirement is required (> 200 lines)

Present retirement candidates. A CLAUDE.md entry is a candidate for retirement if:

1. **Stale**: Added > 90 days ago AND no recent vault notes or disk findings reference the rule text (fuzzy search, last 60 days)
2. **Conflicting**: Contradicts the finding being promoted or a newer confirmed finding
3. **Overly specific**: Applies to a narrow situation that no longer exists (deprecated feature, resolved bug, completed migration)

```
CLAUDE.md capacity: [N] lines (> 200 — paired retirement required)

Retirement candidates:
  [1] Line 45: "Always use v2 API for auth endpoints"
      Added: ~90+ days ago | Last referenced: none found | Reason: Stale
  [2] Line 78: "Run migration script before deploying to staging"
      Added: ~120 days ago | Last referenced: none found | Reason: Overly specific (migration complete)
  [3] Line 112: "Prefer callbacks over promises in legacy module"
      Added: ~60 days ago | Last referenced: 45 days ago | Reason: Conflicts with newer finding

  [0] None — I'll manually identify an entry to retire

Select entry to retire [1-N, or 0]:
```

### Staleness detection

A CLAUDE.md entry is "stale" if:
- It was added > 90 days ago AND
- No recent vault notes reference the rule text (fuzzy search, last 60 days) AND
- No recent `.epistemic/insights.jsonl` entries reference the rule text (fuzzy search, last 60 days)

Staleness is advisory — the user decides what to retire.

---

## Step 4: Draft the Rule

Convert the finding into a CLAUDE.md-appropriate rule:

1. **Identify the target section** in CLAUDE.md where the rule belongs (match by topic, create new section only if no existing section fits)
2. **Draft the rule text**: concise, actionable, imperative mood
3. **Show the draft** for user approval

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PROMOTION DRAFT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Finding: "[original finding text]"

  Proposed CLAUDE.md rule:
    Section: [target section name]
    Text: "[drafted rule text]"

  [If retirement required:]
  Entry to retire:
    Line [N]: "[retiring entry text]"

  [1] Approve — apply promotion (and retirement if applicable)
  [2] Edit rule text — suggest changes before applying
  [3] Change target section
  [4] Cancel

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Rule drafting guidelines

- Use imperative mood: "Use X when Y" not "X should be used when Y"
- Be specific enough to be actionable, general enough to apply across sessions
- Include the "why" if not obvious from context
- Match the style and voice of existing CLAUDE.md entries
- Do NOT include temporal references ("as of March 2026") — rules are meant to be durable

---

## Step 5: Paired Operation

If capacity check required paired retirement (> 200 lines):

```
Applying paired operation:
  PROMOTE: "[new rule text]" → Section: [section]
  RETIRE:  "[old rule text]" → Line [N]

Both changes will be applied together. Approve?
  [Y] Apply both
  [N] Cancel both
```

The user MUST approve both the promotion and retirement together. Neither is applied without the other when paired retirement is required.

---

## Step 6: Apply

### Add the new rule to CLAUDE.md

Use the Edit tool to insert the new rule in the target section of CLAUDE.md.

### Remove the retired entry (if applicable)

Use the Edit tool to remove the retired entry from CLAUDE.md.

### Log the promotion in vault

Create a promotion decision note at `$VAULT_PATH/Engineering/Decisions/YYYY-MM-DD-promoted-[slug].md` using the promotion template (`~/.claude/commands/templates/vault-notes/promotion.md`):

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

Use `mcp__obsidian__create_note` with the promotion template filled in.

### Update the source finding's tier

For each source finding in the vault, update its frontmatter:

```yaml
tier: promoted
promoted_date: YYYY-MM-DD
promoted_to: "CLAUDE.md"
promoted_rule: "[rule text summary]"
```

### Log to epistemic tracking (if session active)

Append to `.epistemic/insights.jsonl`:
```json
{"timestamp": "ISO-8601", "type": "finding", "input": {"finding": "[Promotion] Finding promoted to CLAUDE.md: [rule text summary]. Evidence: N independent observations across N sessions."}}
```

### Confirmation

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PROMOTION COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Rule added to CLAUDE.md:
    Section: [section]
    Text: "[rule text]"

  [If retirement:]
  Rule retired from CLAUDE.md:
    Text: "[retired text]"

  Vault record:
    Engineering/Decisions/YYYY-MM-DD-promoted-[slug].md

  Source findings updated: N notes marked as tier: promoted

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Degradation Paths

| Available Systems | Behavior |
|-------------------|----------|
| Vault + disk insights | Full workflow — vault for evidence trail, `.epistemic/insights.jsonl` for session correlation |
| Vault only | Full workflow — evidence trail from vault notes only. Skip disk insight logging at end. |
| Disk insights only | Reduced workflow — search `.epistemic/insights.jsonl` for evidence. No vault promotion record. Apply CLAUDE.md change only. |
| Neither available | Minimal workflow — user provides evidence verbally. Warn: "Limited evidence trail — promotion based on user attestation only." Apply CLAUDE.md change. No vault record. |

---

## Fail-Soft Behavior

- **No CLAUDE.md found**: Stop with error. "No CLAUDE.md found in project root or .claude/ directory."
- **Vault unreachable**: Degrade to disk-insights-only or user-attestation mode (see degradation paths).
- **Epistemic session unavailable**: Proceed without epistemic tracking. Skip disk logging.
- **CLAUDE.md write fails**: Show the drafted rule text and ask user to apply manually.
- **Vault write fails**: Show the promotion record and ask user to create the note manually.
