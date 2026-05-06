---
id: bash-missing-fail-fast
language: bash
severity: high
status: active
detection_regex: '[A-Z][A-Z_]*=\$\(grep [^|]*\| cut'
fixture_good: |
  SESSION_ID="${SESSION_ID:-}"
  [ -z "$SESSION_ID" ] && { echo "ERROR: missing SESSION_ID" >&2; exit 1; }
fixture_bad: |
  SESSION_ID=$(grep "^SESSION_ID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
  jq ".sessions += [{id: \"$SESSION_ID\"}]" "$EPISTEMIC" > "$TMP"
first_seen: 2026-04-30
last_seen: 2026-05-06T13:45:08Z
total_hits: 17
recent_hits: 17
recent_window_days: 60
locations_remedied: 0
related_hookify: []
references:
  - "[[2026-04-30-jq-tmp-mv-data-loss]]"
---

# Missing Fail-Fast on Config-File Variable Extraction

## What It Looks Like

Extracting a critical variable from a config file via `grep | cut` (or similar
fragile parsing) without immediately validating the extracted value is non-empty.

```bash
# UNSAFE — silent failure if line missing, file unreadable, or grep mismatched
SESSION_ID=$(grep "^SESSION_ID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
# ... downstream code uses $SESSION_ID with no -z guard
```

## Why It's Dangerous

`grep | cut` returns success (exit 0) even on no match — the pipeline exits with
the status of the last command, and `cut` succeeds on empty input. The variable
silently becomes empty. Downstream consumers (`jq` filters, file paths, queries)
then operate on `""` and produce surprising results.

The 2026-04-30 epistemic data-loss incident compounded this with the
`bash-unsafe-atomic-write` pattern: `SESSION_ID` was empty, `jq` produced empty
output, the unsafe `> "$TMP" && mv` clobbered the real file. Either pattern
alone might have been caught; the compound was silent.

## How to Fix

Validate the extracted value immediately, OR use a more robust extraction
approach (jq for JSON, source-with-default for shell config).

```bash
# SAFE — explicit fail-fast
SESSION_ID=$(grep "^SESSION_ID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
[ -z "$SESSION_ID" ] && { echo "ERROR: SESSION_ID empty" >&2; exit 1; }

# OR: SAFE — use bash default expansion if extraction is best-effort
SESSION_ID="${SESSION_ID:-default-session}"

# OR: SAFE — use jq for JSON config (impossible to silently empty-result)
SESSION_ID=$(jq -re '.session_id' "$CONFIG") || exit 1
```

## Coarseness Note

This regex catches the `VAR=$(grep ... | cut)` shape regardless of whether a
guard follows. Manual review distinguishes guarded vs unguarded uses. False
positives expected; the catalog flags the smell, the human decides the fix.

## Examples

### Bad
```bash
SESSION_ID=$(grep "^SESSION_ID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
PROJECT=$(grep "^PROJECT=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
# ... no -z checks before $SESSION_ID and $PROJECT are used downstream
```

### Good
```bash
SESSION_ID=$(grep "^SESSION_ID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2)
[ -z "$SESSION_ID" ] && { echo "ERROR: SESSION_ID required" >&2; exit 1; }
```

## Source

- First seen: 2026-04-30 — `/epistemic-postflight` proceeded with empty SESSION_ID, compounding into data loss
- Sister-site remediation commit: `318e09f`
