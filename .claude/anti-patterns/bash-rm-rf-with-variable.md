---
id: bash-rm-rf-with-variable
language: bash
severity: critical
status: active
detection_regex: ' rm +-r[fr]?[fr]? +"?\$\{?[A-Z_a-z]+'
fixture_good: |
  [ -n "$TEMP_DIR" ] && [ "$TEMP_DIR" != "/" ] && rm -rf -- "$TEMP_DIR"
fixture_bad: |
  cleanup() { rm -rf "$TEMP_HOME"; }
  trap cleanup EXIT
first_seen: 2026-04-30
last_seen: 2026-05-04T16:22:15Z
total_hits: 20
recent_hits: 20
recent_window_days: 60
locations_remedied: 0
related_hookify: []
references: []
---

# `rm -rf` With Unguarded Variable Expansion

## What It Looks Like

Recursive force-delete using a shell variable that isn't checked for emptiness
or root-equivalent values, and without the `--` end-of-options separator.

```bash
# UNSAFE — if $VAR is unset, empty, or "/", catastrophic
rm -rf "$VAR"
rm -rf $VAR/
rm -rf "${VAR}"
```

## Why It's Dangerous

If the variable is unset (typo, scoping bug, sourcing-order issue), the command
becomes `rm -rf` with no argument (which usually fails harmlessly) OR — worse —
`rm -rf /trailing/path` if there's a path suffix, which deletes from root.
Even when "obviously" set, dynamic edge cases bite: whitespace, glob expansion,
substitution at the wrong boundary.

The shape is well-known across many incidents in the wild. Not every match here
is dangerous — `rm -rf "$TEMP_DIR"` immediately after `TEMP_DIR=$(mktemp -d)` is
usually safe by construction. The catalog flags the smell; the human reviews.

## How to Fix

Three layered guards make this safe:

```bash
# SAFE — three guards
[ -n "$VAR" ] && [ "$VAR" != "/" ] && rm -rf -- "$VAR"
```

1. `[ -n "$VAR" ]` — non-empty (catches unset/empty)
2. `[ "$VAR" != "/" ]` — not root (catches catastrophic mistake)
3. `rm -rf --` — `--` ends option parsing (defends against `$VAR` starting with `-`)

For mktemp-derived dirs, a tighter guard is also acceptable:

```bash
TEMP_DIR=$(mktemp -d) || exit 1
trap '[ -n "$TEMP_DIR" ] && rm -rf -- "$TEMP_DIR"' EXIT
```

## Coarseness Note

This pattern is included as a v1 entry that may have **zero or near-zero recent
hits** in this codebase — exercising the recent_hits=0 path of the sweep
honestly. A pattern can sit in the catalog without recent activity; the system
should report this rather than fabricate hits.

## Examples

### Bad
```bash
rm -rf "$BUILD_DIR"
rm -rf $TMP_DIR
```

### Good
```bash
[ -n "$BUILD_DIR" ] && [ "$BUILD_DIR" != "/" ] && rm -rf -- "$BUILD_DIR"
```

## Source

- Documented anti-pattern across many incidents in the wild (no claude-sail-specific incident)
- Included to test the recency=0 codepath: catalog correctness when a pattern has no recent activity
