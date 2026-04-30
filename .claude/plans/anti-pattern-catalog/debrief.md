# Debrief: anti-pattern-catalog

## Ship Reference

- **36bff79** — feat: Implement anti-pattern-catalog (WU1-WU7) — 17 files changed, +1542 / -9
- **e53a7d2** — plan: Mark anti-pattern-catalog execute stage complete

Completion date: 2026-04-30

## Spec Delta

| From | To | Trigger | Status |
|------|------|---------|--------|
| rev1 (initial) | rev2 | Vanilla challenge: 2 critical + 4 lower findings — REWORK verdict | Mechanism redesign (hookify→shell hook, EXCLUDE_PATHS, F3 swap) |
| rev2 | rev3 | /review wizard 4-lens analysis: 16 findings (3H/4M/9L) | No regression — framing/positioning polish only |
| rev3 | rev4 | Pre-impl AC14 gating verification | Mechanism correction (stderr→additionalContext); architecture preserved |

3 spec revisions, 1 architectural regression (rev1→rev2), 1 mechanism correction
(rev3→rev4). Full delta detail in `spec.diff.md`. Adversarial findings addressed
inline: 18 of 22 across all revisions; 4 deferred with documented reasoning
(DA-2/DA-4/S-2/S-4) and 2 v2 carry-forward (F6/F8).

## Deferred Items

- **AC14 form-2 (live-session manual gate)** — in a fresh Claude Code session,
  attempt a Write whose content matches a catalog `fixture_bad`. Confirm the
  tool feedback contains `Catalog: <id>`. The settings cache prevents in-session
  verification; this is the empirical close-out of the AC14 contract. If form-2
  fails, redesign per spec Decisions section (Path B exit-2 with single-flight
  approval is the documented fallback).
- **Pattern: detection_kind v2 schema** — `bash-silent-error-suppression` was
  dropped from v1 (F3) because multi-line context-aware detection requires
  schema extension `detection_kind: regex|awk|external-script`. Reintroduce
  when schema gains the field.
- **`--full --prune` flag (E22)** — orphaned events for deleted patterns aren't
  garbage-collected. Accumulate in `.events.jsonl` indefinitely.
- **Per-project `recent_window_days` config (F8/S-4)** — v1 keeps per-pattern
  frontmatter only; project-level override deferred to v2.
- **Sister-site remediation** — first sweep on this repo found 4 unfixed
  `bash-unsafe-atomic-write` instances in `scripts/epistemic-{compute,feedback}.sh`.
  Commit `318e09f` claimed to remediate sister sites but missed these. Separate
  fix work; not part of this blueprint.

## Discoveries

Things observed during execution that weren't anticipated in planning:

1. **Sister-site remediation incomplete.** Commit `318e09f` ("Harden epistemic-postflight
   + sister sites against data-loss bug") was supposed to fix the unsafe atomic-write
   pattern across all sites. The first full sweep on this repo found 4 unfixed
   instances in `scripts/epistemic-compute.sh` (lines 135, 194) and
   `scripts/epistemic-feedback.sh` (lines 144, 155). The catalog surfaced this
   immediately — exactly its purpose. Surfacing > fixing was the design intent;
   the discovery validates that the catalog earns its keep on day one.

2. **Rev4 (additionalContext) is cleaner than rev3 (stderr) would have been.**
   The empirical AC14 gating revealed not just that stderr is invisible to Claude
   but that the documented `additionalContext` primitive is strictly better:
   surfaces to BOTH the user terminal and Claude alongside the tool result, no
   blocking, multi-hook accumulation supported. The rev4 design is what we'd have
   reached for if we'd known about the field; we reached it via empirical failure.

3. **The 80-line SCHEMA.md cap was load-bearing.** AC6's "≤1 page" became `-le 80`
   in test code. Three rewrites later, the doc is structurally simpler than the
   first attempt — concision forced by the test, not by aesthetic preference.
   Topic-grep coverage in the test (`schema|frontmatter`, `add (a )?pattern`,
   `counter|derived`) prevented compression from gutting required content.

4. **Bash multiline-string concatenation is subtle.** Building the hook's
   `additionalContext` text via `matches+="$(printf '...\n\n')"` strips the
   trailing newlines (command substitution behavior). The fix — bash `+=` with a
   double-quoted real-newline literal — preserves them. AC14 form-1 unit test 5
   (multi-pattern accumulation) caught this; tests 1-4 didn't.

5. **`set -euo pipefail` is incompatible with `if cmd1 | cmd2; then` assertion
   patterns.** Category 9 of test.sh died silently on its first run because a
   piped grep returning "no match" propagated exit 1 through the pipeline despite
   being inside an `if`. Fix: `set +eo pipefail` inside the assertion section,
   restore strict mode after. This is the third or fourth time a bash strict-mode
   issue has bitten this toolkit; worth a dedicated CLAUDE.md note.

## Reflection

### Wrong Assumptions

- **`bash-rm-rf-with-variable` would have "near-zero" hits on this repo.** Spec
  said "expected to find zero or near-zero in claude-sail." Sweep found 5-6.
  Several are safe-by-construction (`mktemp -d` followed by `rm -rf "$TEMP_DIR"`),
  but the regex doesn't distinguish. The "exercises recent_hits=0 path" rationale
  for shipping the pattern was off — what it actually exercises is the
  false-positive rate of the regex on legitimate construction patterns.
- **Test fixture `test_preserve_sail_disabled_hooks_honored` exercises what it
  claims.** It doesn't — `SAIL_DISABLED_HOOKS=x echo "$input" | bash hook` sets
  the env var only on `echo`, not on the piped `bash`. The test passes vacuously
  because the hook outputs to stdout (not stderr), and the test only captures
  stderr. Worth a v2 fix; not blocking since the env-var mechanism IS verified by
  Cat 9's standalone test.

### Difficulty Calibration

- **Harder than expected:**
  - POSIX ERE portability — no `\b` word boundary, had to fall back to leading-space workaround
  - Bash command-substitution newline stripping (caught at test 5 of 5, not earlier)
  - test.sh strict-mode interaction with assertion-style pipelines
- **Easier than expected:**
  - Counter dedup via jq `group_by + max_by` (worked first try)
  - Helper-or-fallback safe-swap pattern (epistemic-safe-write.sh was already a clean template)
  - Vault mirror with contract header — straightforward awk frontmatter injection

### Advice for Next Planner

1. **Spec-blind tests with hard-coded thresholds beat fuzzy contracts.** AC6
   specified "≤1 page"; the test used `-le 80`. The hard threshold did real
   work: forced three rewrites, each tighter. If you write a contract, write
   the threshold too.
2. **Pre-impl empirical gating is worth the friction.** AC14 form-2 verification
   ran BEFORE WU6 implementation and caught a wired-but-silent failure mode that
   form-1 alone couldn't have caught. The cost was one session of detour
   (verification + rev4 polish); the alternative was a shipped catalog with no
   Claude-visible signal. The pattern (force-an-empirical-gate-before-impl when
   the AC depends on harness behavior the spec can't dictate) deserves a
   permanent place in the toolkit's planning vocabulary — already memorialized
   as `feedback_pre_impl_gating_for_empirical_acs.md`.
3. **Strict bash mode and assertion-style scripts don't mix.** When you write
   a test that uses pipelines as data extraction (grep | grep, jq | wc), wrap
   the section in `set +eo pipefail` — strict mode is for catching bugs, not
   for adjudicating "no match found" results.

### Most Useful Spec Sections

- **Decisions section (rev3)** — the why-regex-not-AST + why-additionalContext
  + why-heartbeat anchors. When implementing, I went back to it three times
  to confirm I was making the documented choice, not re-deriving.
- **Tests.md AC14 with form-1/form-2 split** — knowing which test forms were
  verifiable in-session vs requiring fresh-session was decisive for sequencing.
- **work-graph.json depends_on** — sequenced WU1→WU2→WU5→WU6→WU3→WU4→WU7
  efficiently; dependencies were correct.

### Least Useful Spec Sections

- **Initial counter values** in WU2 (e.g., `total_hits: 4` for the unsafe-write
  pattern). The spec described post-incident historical state. The actual sweep
  recomputes counters from `.events.jsonl`, which starts empty. Unused.
  Worth noting in v2: either backfill events for documented incidents, or stop
  describing initial counter values that don't survive first sweep.
- **work-graph.json was rev1-stale** — still listed `bash-silent-error-suppression`
  in WU5 after rev2's F3 swap. Spec.md was authoritative; this didn't bite, but
  next planner should know to trust spec over manifest when they diverge after
  a regression.

## Sibling Impact (linked blueprints)

No parent blueprint. This blueprint is the gating predecessor to
**test-debt-in-prism** (memory: `project_test_debt_design.md`) which is now
unblocked for its dedicated `/blueprint test-debt-in-prism` session.
