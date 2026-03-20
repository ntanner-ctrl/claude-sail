---
description: Use when you want to review session turn usage or set a context awareness target for the current project.
arguments:
  - name: threshold
    description: Subcommand — set an awareness target turn count (e.g. "threshold 100")
    required: false
  - name: N
    description: Turn count for the awareness target (used with "threshold" subcommand)
    required: false
---

# Budget

Session turn awareness tool. Reads `.claude/budget.jsonl` to summarize historical session usage and optionally sets a per-session awareness target in `.claude/budget-config.json`. Advisory only — this is not enforcement.

## Why This Exists

Long sessions accumulate context cost and tend to degrade in quality as the context window fills. Having a rough sense of session turn counts helps you decide when to checkpoint and start fresh. This command makes that usage visible.

**Important caveat:** Turn count is a heuristic. Subagent-heavy sessions (e.g., using `/delegate` or multi-agent workflows) can record 10–50× more turns than a simple back-and-forth session of the same perceived length. Use counts as approximate signals, not precise measurements. All displays use `~N` format to reflect this.

## Usage

- `/budget` — display session usage summary
- `/budget threshold N` — set an awareness target of ~N turns per session

## Process

### Display Mode (no arguments)

#### Step 1: Read Budget Data

```bash
cat .claude/budget.jsonl 2>/dev/null
```

If the file does not exist or is empty, display:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BUDGET SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  No budget data recorded yet.

  Usage data is written to .claude/budget.jsonl when
  sessions are tracked. Start a session to begin.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Stop here.

#### Step 2: Parse Sessions

Each line in `budget.jsonl` is a JSON object with these fields:

```json
{
  "session_id": "string",
  "timestamp": "ISO-8601Z",
  "turns": 42,
  "notes": "optional string"
}
```

Parse all valid lines. Skip malformed lines silently (log count of skipped lines if any).

Compute:
- **Total sessions recorded**
- **Total turns** across all sessions
- **Average turns per session** — round to nearest 10 for display (e.g., 47 → `~50`, 83 → `~80`)
- **Most recent session** — highest `timestamp` value
- **Trend** — compare most recent 3 sessions vs prior 3 sessions average. If fewer than 4 sessions, skip trend.
  - Trend up (>20% increase): "Sessions getting longer"
  - Trend down (>20% decrease): "Sessions getting shorter"
  - Stable: "Usage stable"

#### Step 3: Read Awareness Target (if set)

```bash
cat .claude/budget-config.json 2>/dev/null
```

If present, extract `budget_threshold`. If absent, threshold is unset.

#### Step 4: Display Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  BUDGET SUMMARY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Sessions recorded:  [N]
  Total turns:        ~[rounded total]
  Avg per session:    ~[rounded avg]
  Last session:       [YYYY-MM-DD] (~[turns] turns)

  Trend:              [Sessions getting longer / shorter / Usage stable / (not enough data)]

  Awareness target:   [~N turns per session / not set]

  [If threshold is set AND last session exceeds threshold:]
  Note: Last session (~[N] turns) exceeded your awareness
  target (~[threshold] turns). Consider /checkpoint sooner.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Turn count is a heuristic (~10-50x off for subagent-
  heavy sessions). Use as a rough signal, not a hard cap.

  /budget threshold N    set an awareness target
  /checkpoint            save context and start fresh

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

### Threshold Mode (`/budget threshold N`)

#### Step 1: Validate N

N must be a positive integer. If N is missing, zero, or non-numeric:

```
Usage: /budget threshold N
  N must be a positive integer (e.g. /budget threshold 100)
```

Stop.

#### Step 2: Write Config

```bash
mkdir -p .claude
```

Read `.claude/budget-config.json` if it exists (preserve other fields). Set or update the `budget_threshold` field:

```json
{
  "budget_threshold": N,
  "updated": "YYYY-MM-DDTHH:MM:SSZ"
}
```

Write back to `.claude/budget-config.json`. All timestamps use UTC with Z suffix.

#### Step 3: Add CLAUDE.md Awareness Section (first time only)

Check whether `.claude/CLAUDE.md` exists and already contains a `Budget Awareness` section. If NOT present, append:

```markdown

## Budget Awareness

Session turn awareness target: ~[N] turns (set via /budget threshold).
Check /budget at session start if concerned about context cost.
Turn counts are approximate — subagent-heavy sessions can be 10-50x higher.
```

If the file does not exist, skip this step (do not create CLAUDE.md for just this).

If a `Budget Awareness` section already exists, update only the threshold number in the existing line — do not rewrite the section.

#### Step 4: Confirm

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AWARENESS TARGET SET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Target:   ~[N] turns per session
  Config:   .claude/budget-config.json
  CLAUDE.md: [updated / skipped — no .claude/CLAUDE.md found]

  This is an advisory target, not a hard limit.
  You won't be blocked — just made aware.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Data Format Reference

`.claude/budget.jsonl` — one JSON object per line:

```json
{"session_id": "session-2026-01-15-1430", "timestamp": "2026-01-15T14:30:00Z", "turns": 62, "notes": "blueprint stage 3-5"}
```

`.claude/budget-config.json`:

```json
{"budget_threshold": 100, "updated": "2026-01-15T14:35:00Z"}
```

Both files live in `.claude/` alongside other project-local Claude artifacts.

## Notes

- Advisory only — nothing is blocked or stopped when a threshold is exceeded
- `budget.jsonl` is written by the session-tracking infrastructure (e.g., hooks or `/end`), not by this command
- The `budget_threshold` in `budget-config.json` is read by Claude at session start via CLAUDE.md guidance — behavioral, not deterministic
- Threshold is a per-project setting — different projects can have different targets
- Run `/checkpoint` when approaching your awareness target to preserve context before starting a fresh session
