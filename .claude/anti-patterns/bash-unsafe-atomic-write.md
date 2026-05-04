---
id: bash-unsafe-atomic-write
language: bash
severity: high
status: active
detection_regex: '> *"?\$[A-Z_]+"? *&& *mv'
fixture_good: |
  jq '.' input.json > "$TMP"
  jq -e . "$TMP" >/dev/null && mv "$TMP" "$FILE"
fixture_bad: |
  jq '.' input.json > "$TMP" && mv "$TMP" "$FILE"
first_seen: 2026-04-30
last_seen: 2026-05-04T16:22:15Z
total_hits: 6
recent_hits: 6
recent_window_days: 60
locations_remedied: 0
related_hookify: []
references:
  - "[[2026-04-30-jq-tmp-mv-data-loss]]"
---

# Unsafe Atomic Write via `jq ... > $TMP && mv`

## What It Looks Like

Writing JSON via `jq` to a temp file, then moving the temp into place — but
without validating the temp file is non-empty / valid JSON between the two
operations.

```bash
# UNSAFE — common idiom, dangerous failure mode
jq '.sessions += [...]' "$FILE" > "$TMP" && mv "$TMP" "$FILE"
```

## Why It's Dangerous

`jq` exits 0 even when its input is empty or its output is empty. The `&& mv`
chain only checks that the redirect succeeded — not that the content is sane.
Compound failure modes (empty SESSION_ID, missing input, malformed filter) all
produce empty output, which then atomically replaces the original file. Data loss
is silent and often only visible session-later.

This is exactly how a 91KB `epistemic.json` was wiped on 2026-04-30 — the
SESSION_ID was empty, jq operated on nothing, and the empty result clobbered the
real file. Multiple sister sites in `epistemic-compute.sh` and
`epistemic-feedback.sh` use the same pattern.

## How to Fix

Use `epistemic_safe_swap` from `scripts/epistemic-safe-write.sh`, or inline the
validate-before-swap pattern:

```bash
# SAFE — validate the temp content before swapping it in
jq '.sessions += [...]' "$FILE" > "$TMP"
jq -e . "$TMP" >/dev/null || { rm "$TMP"; exit 1; }
[ -s "$TMP" ] || { rm "$TMP"; exit 1; }
mv "$TMP" "$FILE"
```

The cost is one extra `jq -e` call (microseconds). The benefit is preventing
silent data loss on the most-used persistence path in the toolkit.

## Examples

### Bad
```bash
jq ".sessions += [{\"id\":\"$SESSION_ID\"}]" "$EPISTEMIC" > "$TMP" && mv "$TMP" "$EPISTEMIC"
```

### Good
```bash
jq ".sessions += [{\"id\":\"$SESSION_ID\"}]" "$EPISTEMIC" > "$TMP"
jq -e . "$TMP" >/dev/null && [ -s "$TMP" ] && mv "$TMP" "$EPISTEMIC" || rm -f "$TMP"
```

## Source

- First seen: 2026-04-30 incident — `/epistemic-postflight` wiped 91KB of session history
- Sister-site remediation commit: `318e09f` (epistemic-postflight + 4 sister sites hardened)
- Related helper: `scripts/epistemic-safe-write.sh` (`epistemic_safe_swap`)
