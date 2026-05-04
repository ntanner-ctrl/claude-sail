---
description: Use when ending a session. Runs epistemic postflight assessment and exports session artifacts to Obsidian vault before exit.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# End Session

Graceful session closure that preserves epistemic data and exports session artifacts to the Obsidian vault. Runs postflight self-assessment and vault export while you're still in the loop, then tells the user to `/exit`.

## Why This Exists

Without explicit closure, sessions become epistemically orphaned — the SessionEnd hook fires but no learning delta is captured. This command ensures the postflight self-assessment happens while you can still reflect on what you learned.

## Process

### Step 1: Check for Active Epistemic Session

```bash
# Read active session from native epistemic tracking marker (per-claude-PID layout)
source ~/.claude/scripts/epistemic-marker.sh 2>/dev/null
if epistemic_session_active; then
    epistemic_get_session_id
else
    echo "NO_SESSION"
fi
```

Extract `SESSION_ID` (via `epistemic_get_session_id`) and `PROJECT` (via
`epistemic_get_marker_field PROJECT`) from the per-claude-PID marker. If no
active session is found, skip to Step 4 (just show the exit message).

### Step 1.5: Reconcile Orphaned Insights

Reconcile insights that exist on disk but not in vault, or vice versa. This closes the gap between the write-through cache and the vault.

1. **Read insights.jsonl**: Read `.epistemic/insights.jsonl` from the project root. If the file doesn't exist or is empty, skip this step.

2. **Read vault findings**: List files in `$VAULT_PATH/Engineering/Findings/` that match this project (check `project:` frontmatter). Source vault config first:
   ```bash
   source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_PATH=$VAULT_PATH"
   ```
   If vault is not accessible, skip vault-side reconciliation but still report disk-only insights.

3. **Match entries**: For each insights.jsonl entry, check if a corresponding vault note exists by matching:
   - Finding text similarity (the `finding` field in insights.jsonl vs the note body)
   - Timestamp proximity (same calendar day)

4. **Reconcile disk → vault**: For insights.jsonl entries with NO matching vault note:
   - Create a vault note using the finding template (`~/.claude/commands/templates/vault-notes/finding.md`)
   - Populate epistemic fields: `epistemic_confidence: 0.5` (default — not yet assessed), `epistemic_assessed: today`, `epistemic_session: SESSION_ID`, `epistemic_status: active`
   - Use vault_sanitize_slug for the filename

5. **Reconcile vault → disk**: For vault finding notes (created this session via `/vault-save`) with NO matching insights.jsonl entry:
   - Append a finding entry to `.epistemic/insights.jsonl` with the finding text (prefix with "[Insight] " if from vault finding notes)

6. **Report**:
   ```
   Reconciled N orphaned insights (M→vault, K→disk)
   ```
   If nothing to reconcile, report: "No orphaned insights found."

**Fail-soft**: If any reconciliation step fails, log the error and continue. Never block session closure.

### Step 2: Run Postflight Assessment

**Invoke `/epistemic-postflight`** to capture postflight vectors and compute calibration deltas. This is the primary mechanism for pairing sessions — it computes the delta between your preflight and current state.

Rate each of the 13 vectors (0.0-1.0) based on where you are NOW:

| Vector | What to assess |
|--------|---------------|
| `engagement` | How deeply did you engage with the task? |
| `know` | How much do you now know about the domain? |
| `do` | How much practical ability did you gain? |
| `context` | How well do you understand the project context? |
| `clarity` | How clear is your understanding? |
| `coherence` | How well does everything fit together? |
| `signal` | How strong was the signal-to-noise ratio? |
| `density` | How information-dense was the work? |
| `state` | How well do you know the current state of things? |
| `change` | How much changed from your initial understanding? |
| `completion` | How complete is the work? |
| `impact` | How impactful was the session? |
| `uncertainty` | How much uncertainty remains? |

**Be honest.** The value of postflight is in the delta between preflight and postflight. Inflated scores corrupt the calibration data.

### Step 2.75: Confidence Writeback

After postflight vectors are submitted, write epistemic confidence data back to vault findings. This closes the loop between epistemic self-assessment and persistent knowledge.

1. **Gather session findings**: Collect all findings logged this session from `.epistemic/insights.jsonl` (filtered by session-start timestamp, same as Step 2.5.3).

2. **Update new findings**: For each finding that was exported to vault THIS session (created in Step 1.5 or Step 2.5.4):
   - Read the vault note
   - Update frontmatter with:
     ```yaml
     epistemic_confidence: <confidence from postflight — use the `know` vector as proxy>
     epistemic_assessed: <today's date YYYY-MM-DD>
     epistemic_session: <SESSION_ID>
     epistemic_status: active
     ```
   - Write the updated note back using the Edit tool

3. **Update confirmed findings**: For existing vault findings (pre-session) that were referenced or used successfully this session:
   - Update frontmatter: `epistemic_status: confirmed`, `epistemic_assessed: <today>`
   - This indicates the finding was re-validated in practice

4. **Update contradicted findings**: For existing vault findings that were found to be wrong or outdated this session:
   - Update frontmatter: `epistemic_status: contradicted`, `epistemic_assessed: <today>`
   - Add a note in the Implications section: `> Contradicted in session [[SESSION_LINK]] — [brief reason]`

5. **Report**:
   ```
   Confidence writeback: N findings updated (M active, K confirmed, J contradicted)
   ```

**Fail-soft**: If vault is inaccessible or frontmatter parsing fails, skip writeback with note and continue.

### Step 2.5: Vault Export

Export session artifacts to the Obsidian vault. This step is Claude-executed (using Read/Write/Bash tools), not a shell script.

#### 2.5.1: Source Vault Config

Use the Bash tool to source vault-config.sh and extract config values:

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH" && echo "VAULT_EXPORT_MARKER=$VAULT_EXPORT_MARKER"
```

This evaluates the `$(id -u)` and `$(date +%Y%m%d)` subshells at runtime. Do NOT read vault-config.sh as text.

If `VAULT_ENABLED=0` or vault path is empty/missing/unwritable, skip with note: "Vault export skipped (vault disabled or not accessible)." and continue to Step 3.

#### 2.5.2: Ensure Vault Structure

```bash
mkdir -p "$VAULT_PATH/Engineering/Decisions" "$VAULT_PATH/Engineering/Findings" "$VAULT_PATH/Engineering/Blueprints" "$VAULT_PATH/Engineering/Patterns" "$VAULT_PATH/Sessions" "$VAULT_PATH/Ideas"
```

#### 2.5.3: Collect Session Artifacts

Scope artifacts to "this session" using the session-start timestamp:

1. Read session-start timestamp: `cat /tmp/.claude-session-start-$(id -u)` (ISO-8601).
   **Fallback:** If absent or empty, use `$(date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)`. Log: "Session-start timestamp missing — scoping artifacts to last 24 hours."
2. Read session ID via `epistemic_get_session_id` (from per-claude-PID marker under `~/.claude/.current-session/`). Fallback: `session-YYYY-MM-DD-HHMM`.
3. **Decision records:** Read `.claude/decisions/*.md` files. Each has `date:` frontmatter in ISO-8601. Include where `date:` >= session-start timestamp.
4. **Disk findings:** Read `.epistemic/insights.jsonl`. Each line has `timestamp` field in ISO-8601. Include where `timestamp` >= session-start timestamp.
5. Check for active blueprint progress (`.claude/plans/*/state.json` with `updated` after session start).
6. Check `Ideas/` in vault for notes with `date:` matching today (these are `/vault-save` captures).

#### 2.5.4: Create Vault Notes

For each artifact, create a vault note using templates from `~/.claude/commands/templates/vault-notes/`. Read the template, replace all `{{key}}` placeholders with corresponding values. For conditional directives like `{{#if key}}...{{/if}}`, include the block only if the key has a value — otherwise omit the entire line. If a placeholder has no value, use sensible defaults (category: "insight", severity: "info"). **All filenames via vault_sanitize_slug()** (Bash: `echo "TITLE" | tr -cd '[:alnum:] ._-' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | head -c 80`):

- Decisions → `Engineering/Decisions/YYYY-MM-DD-slug.md`
- Findings → `Engineering/Findings/YYYY-MM-DD-slug.md`
- Blueprint updates → `Engineering/Blueprints/YYYY-MM-DD-blueprint-name.md` (overwrite/snapshot semantics)
- Session summary → `Sessions/YYYY-MM-DD-HHMM-project-summary.md`

**Wiki-link rules:** Links ONLY between notes created in this export batch. Session summary links to decisions/findings. Decisions/findings link back to session. No speculative links.

**Session summary content:**
- Summary: 2-3 sentence overview (Claude-generated from conversation)
- Work Completed: Derived from artifact evidence (decisions, findings, blueprints, vault-saves) — NOT git diff
- Decisions Made: Wiki-links to decision notes in this batch
- Findings: Wiki-links to finding notes in this batch
- Blueprint Progress: Current stage/status if active
- Open Questions: Anything flagged unresolved

#### 2.5.5: Write Export Marker

```bash
touch "$VAULT_EXPORT_MARKER"
```

This tells the SessionEnd safety-net hook that export already happened.

#### 2.5.6: Detect Stale Findings

After export, scan vault findings for staleness. A finding is stale if its `epistemic_assessed` date is more than 30 days old.

1. **Scan vault findings**: Read all files in `$VAULT_PATH/Engineering/Findings/` that have `project:` matching the current project.

2. **Check freshness**: For each finding with an `epistemic_assessed` frontmatter field:
   - Parse the date (YYYY-MM-DD format)
   - If >30 days old, mark as stale

3. **Update stale findings**: For each stale finding:
   - Update frontmatter: `epistemic_status: stale`
   - Do NOT change `epistemic_assessed` (preserve the last-assessed date for audit trail)

4. **Report stale findings** in the session summary:
   ```
   Stale findings (>30 days since last verification):
     - [[finding-name-1]] (last assessed: YYYY-MM-DD)
     - [[finding-name-2]] (last assessed: YYYY-MM-DD)
   ```
   If no stale findings, omit this section.

**Fail-soft**: If vault scanning fails, skip with note and continue to summary.

#### 2.5.7: Present Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VAULT EXPORT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Exported to vault:
    [list of files written]

  Total: N notes (N new, N updated)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 2.6: Export Epistemic Delta to Vault

Pair preflight and postflight vectors and export the learning delta.

1. **Read vectors from epistemic.json**: Read `~/.claude/epistemic.json`. Find the session matching the current session_id. If file missing or session not found, skip with note: `"Epistemic delta skipped: session data not found"`.

2. **Extract preflight and postflight**: From the matching session entry, read `.preflight` and `.postflight` objects. If either is null, skip delta computation.

3. **Resolve paths**: Explicitly display the data path:
   `"Reading epistemic data from: ~/.claude/epistemic.json"`

4. **Calculate delta**: For each of the 13 vectors, compute `postflight - preflight`. Categorize:
   - Delta > +0.2: "Significant learning gain"
   - Delta > +0.1: "Moderate gain"
   - Delta -0.1 to +0.1: "Stable"
   - Delta < -0.1: "Confidence decreased" (not a bad thing — recalibration)

   Handle non-numeric values: if a vector value is null, NaN, or non-numeric, display "n/a" in the delta column and skip that vector in categorization.

5. **Create vault note**: If vault is available AND both preflight and postflight data exist, hydrate `~/.claude/commands/templates/vault-notes/epistemic-delta.md` template:
   - `date`: today (YYYY-MM-DD)
   - `project`: current project name (git repo basename)
   - `session_id`: from `epistemic_get_session_id` (per-claude-PID marker)
   - `vector_rows`: table rows for all 13 vectors (one row per vector: dimension | pre | post | delta | assessment)
   - `key_movements`: top 3 biggest deltas (positive or negative) with brief explanation
   - `session_link`: link to session summary note if created in Step 2.5
   - `blueprint_link`: link to active blueprint note if applicable

   Write to `$VAULT_PATH/Sessions/YYYY-MM-DD-epistemic-delta-project.md`

   Use the merge-write pattern [F2] if file already exists. Ensure `mkdir -p` for the target directory [S-2].

6. **Guard**: Only create if vault is available AND both preflight and postflight data exist. If either is missing, log reason and continue (fail-soft).

### Step 2.7: Mark JSONL Entries as Exported

After successful vault writes (Steps 1.5, 2.5, 2.6), mark consumed JSONL entries as exported to prevent duplication on future runs:

1. For each `insights.jsonl` entry exported to vault this session: add `"exported": true`
2. For each `preflight.jsonl` entry consumed in Step 2.6: add `"exported": true`
3. For each `postflight.jsonl` entry consumed in Step 2.6: add `"exported": true`

Implementation: For each file, read all lines, update matching entries (by timestamp match), write back. Use a temporary file to avoid partial writes.

**Fail-soft**: If marking fails, log warning and continue. Never block session closure for export bookkeeping.

### Step 3: Collect Remaining Insights

**Note:** For mid-session insight capture, use `/collect-insights` directly. This step runs the same sweep automatically at session close.

This is your last chance to capture session knowledge. Do NOT skip this step.

1. **Scan conversation for unlogged `★ Insight` blocks**: Search your own output in this session for any `★ Insight` blocks. For each one, check if a corresponding `finding_log` call followed it (look for a finding_log tool call within ~2 messages after the insight).

2. **For each unlogged insight**: Append to `.epistemic/insights.jsonl` with a JSON line: `{"timestamp": "ISO-8601", "type": "finding", "input": {"finding": "[Insight] the insight text"}}`. This is the safety net for the behavioral gap where insights get generated as text but never recorded.

3. **Final reflection**: Beyond `★ Insight` blocks, did you learn something significant that wasn't captured anywhere? If so, log it now.

4. **Report**:
   ```
   Insight sweep: N ★ Insight blocks found, M already logged, K newly captured
   ```

**Why this matters**: Soft instructions to "log insights as you go" have a ~50% compliance rate in practice. This step catches the other 50% before the session closes and the knowledge is lost.

### Step 3.5: Log Budget Entry

Append a heuristic budget record to `.claude/budget.jsonl` in the project root. This is approximate — treat all values as estimates.

```bash
# Read session info via helper (per-claude-PID marker; CF-4 M2 — old grep
# 'session-[^ ]*' did not match the UUID format Claude Code emits).
source ~/.claude/scripts/epistemic-marker.sh 2>/dev/null
SESSION_ID=$(epistemic_get_session_id 2>/dev/null || echo "unknown")
PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
STARTED=$(cat /tmp/.claude-session-start-$(id -u) 2>/dev/null || echo "unknown")
ENDED=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

Compute `duration_min` from start to end (integer minutes; 0 if start unknown). Estimate `estimated_turns` as the approximate number of user messages in this session (count your own responses as a proxy — heuristic only).

Append one JSON line to `.claude/budget.jsonl`:

```json
{"session_id":"SESSION_ID","project":"PROJECT","started":"ISO-UTC","ended":"ISO-UTC","duration_min":N,"estimated_turns":N,"notes":"heuristic — all values approximate"}
```

**Fail-soft**: If the file cannot be written (missing directory, permissions), skip silently. Never block session closure for budget logging.

### Step 3.7: Anti-Pattern Sweep (opt-in by directory presence)

If the project has opted into the anti-pattern catalog (`.claude/anti-patterns/` exists),
run a session-scoped sweep with a 5-second hard cutoff. Emits a stale-sweep nudge when the
heartbeat is missing or >7 days old (silent observability is broken observability).
Fail-open: any failure is logged to stderr and ignored.

```bash
if [ -d .claude/anti-patterns ]; then
    HEARTBEAT=".claude/anti-patterns/.last-sweep.json"

    # Stale-sweep nudge — surface when bookkeeping has decayed
    if [ ! -f "$HEARTBEAT" ]; then
        echo "[anti-pattern catalog] no successful sweep recorded — first run pending." >&2
    else
        last_ts=$(jq -r '.timestamp' "$HEARTBEAT" 2>/dev/null)
        if [ -n "$last_ts" ]; then
            # GNU date first, BSD `date -j` fallback (macOS)
            last_epoch=$(date -d "$last_ts" +%s 2>/dev/null \
                || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_ts" +%s 2>/dev/null)
            if [ -n "$last_epoch" ]; then
                now_epoch=$(date -u +%s)
                age_days=$(( (now_epoch - last_epoch) / 86400 ))
                if [ "$age_days" -gt 7 ]; then
                    echo "[anti-pattern catalog] last successful sweep: ${age_days}d ago. Investigate sweep health." >&2
                fi
            fi
        fi
    fi

    # Run the sweep (5s timeout; non-blocking on /end)
    SWEEP_SCRIPT="$(git rev-parse --show-toplevel 2>/dev/null)/scripts/anti-pattern-sweep.sh"
    [ -f "$SWEEP_SCRIPT" ] || SWEEP_SCRIPT="${HOME}/.claude/scripts/anti-pattern-sweep.sh"
    if [ -f "$SWEEP_SCRIPT" ]; then
        timeout 5 bash "$SWEEP_SCRIPT" --session 2>&1 | tail -10 || true
    fi
fi
```

**Fail-soft**: missing jq, slow vault, regex bit-rot — sweep logs WARN and exits 0. The
`/end` flow continues regardless. The session-mode 5s cutoff is the outer envelope; the
sweep itself uses validate-before-swap on counter rewrites so partial work is safe.

### Step 4: Confirm and Prompt Exit

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SESSION CLOSED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Epistemic:    [session_id or "no active session"]
  Postflight:   [completed / skipped]
  Reconciled:   [N orphaned insights (M→vault, K→disk) / skipped]
  Confidence:   [N findings updated / skipped]
  Insights:     [N ★ blocks found, M already logged, K swept / skipped]
  Findings:     [N logged this session (total)]
  Delta:        [13 vectors paired / skipped (reason)]
  Exported:     [N JSONL entries marked / skipped]
  Vault:        [N notes exported / skipped (reason)]
  Stale:        [N findings need re-verification / none]
  Budget:       [logged to .claude/budget.jsonl / skipped]
  Anti-patterns: [N events from session sweep / skipped (no catalog)]

  Type /exit to end the conversation.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Integration

Also available (user-initiated):
- If `documentation-generator` plugin is installed, docs changed this session? Run `/update-docs` before closing.
- Anything go notably well or poorly this session? `/log-success` and `/log-error` capture the patterns before context is lost. Best done before `/end` while the conversation is still fresh.
- Multiple sessions completed? `/retro` synthesizes patterns across sessions.
- Accumulated 5+ error/success logs? `/evolve` can propose workflow improvements.
- Want to review what hooks blocked this session? `/audit` shows the trail.

## Notes

- This command does NOT automatically exit — the user must type `/exit` after
- If no epistemic session is active, the command still works (just shows the exit prompt)
- The SessionEnd hook (`epistemic-postflight.sh`) acts as a safety net — reminds about unpaired sessions
- The SessionEnd hook (`session-end-vault.sh`) acts as a safety net for vault export when `/end` wasn't used
- Vault export uses templates from `~/.claude/commands/templates/vault-notes/`
- Pair with `/checkpoint` if you also want to save decision context for future sessions
