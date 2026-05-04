# Debrief: epistemic-session-race

> Stage 8 of 8 — completion ceremony for the rev2 blueprint that fixed
> the `~/.claude/.current-session` clobber when parallel claude sessions
> share a global marker. 3 confirmed incidents on 2026-05-01, including
> incident #3 which happened **during the planning of this fix**.

## Ship Reference

- **Branch**: main
- **Commit(s)**: pending — implementation in working tree, not yet committed
- **Files changed**:
  - **NEW** `scripts/epistemic-marker.sh` (helper, 6 functions + 2 internal)
  - **Modified** `hooks/{epistemic-preflight,epistemic-postflight,_audit-log}.sh` (3 hooks)
  - **Modified** `commands/{epistemic-preflight,epistemic-postflight,end,start,collect-insights,vault-curate}.md` (6 bash blocks)
  - **Modified** `commands/{checkpoint,log-success,log-error,evolve,blueprint,README}.md` + `docs/PLANNING-STORAGE.md` (7 prose updates)
  - **Modified** `scripts/epistemic-smoke-test.sh` (extended for new layout + 11 phases)
  - **Modified** `test.sh` (Category 1+2+5 extended, new Category 8.5, AC4 grep checks)
  - **Modified** `install.sh` (helper added to install path, both local + remote branches)
- **Deployed**: `bash install.sh` ran during this session — toolkit live in `~/.claude/`

## Spec Delta

This blueprint went through **one regression** (rev1 → rev2) due to the Stage 3 critique
returning REWORK with 4 critical findings — the most severe being CF-1 (the load-bearing
PPID claim was wrong). The rev2 spec re-grounded on probe v2 evidence and shipped.

| Aspect | rev1 → rev2 |
|--------|-------------|
| Marker discovery | `$PPID` direct → process-tree traversal helper (max 15 hops) |
| Identity source | new uuidgen → SessionStart stdin JSON `session_id` (no fallback) |
| Source-branching | absent → startup/resume/clear/default(warn) |
| WU count | 12 → 15 (+3, +1 split into 4) |
| `STARTED` field | overwritten on resume → preserved (E3) |
| UUID validation | absent → regex-validated before write (E6) |
| Tmpfile location | `mktemp` → `mktemp -p $marker_dir` (E2 EXDEV defense) |
| `/proc` parse | `stat` field 4 → `status` PPid line (E1 — robust to comm with spaces) |

Full revision diff in `spec.diff.md`-equivalent regression_log; rev1 preserved at `spec.md.revision-1.bak`.

### Implementation deltas from rev2 spec

1. **WU8-11 (evals)** were specified as `evals/evals.json` fixtures. Runtime discovery: the
   evals framework is regex-on-text, not behavioral simulation. Implemented as Phase 9-11
   of `scripts/epistemic-smoke-test.sh` with subshell + `EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE`.
   Wired into `test.sh` as Category 8.5. Coverage equivalent or stronger than fixture-based.

2. **Added `EPISTEMIC_SKIP_SWEEP=1` test-only env var** to the helper. Default off.
   Reason: parallel-isolation tests use fake PIDs that the production sweep would correctly
   remove. Production behavior unchanged.

3. **AC10 (timing budget)** is deferred to manual verification on the live session via
   `time` against `/end` invocation. Not measured during this implementation session.

## Deferred Items

- **OQ-rev2-1 — Subagent compatibility**: Untested. Probably works (Task tool spawns are
  children of claude main), but unverified. Document in patterns or open as a small
  follow-up if subagent epistemic tracking surfaces as a need. **Why deferred**: out of
  scope per blueprint; subagent epistemic tracking is not a stated goal.

- **AC10 timing**: SessionStart hook end-to-end timing on Nick's WSL2 box. Need to
  measure with traversal + sweep. **Expected**: well under 2.0s (sweep is O(active markers)
  which is tiny; traversal is 2-3 syscalls). **How to verify**: `time bash hooks/epistemic-preflight.sh < stdin.json`
  on a real claude session.

- **PM-Fix-2 (epistemic.json health probe)**: deferred to a separate blueprint per
  premortem decision. Operates on epistemic.json integrity, not marker scoping.

- **macOS / non-Linux support**: out of scope. The `/proc` warning fires correctly per FM3,
  but the fundamental problem (no /proc) remains. Separate blueprint if claude-sail ever
  ships beyond Linux/WSL.

## Discoveries

### 1. The `/proc/$PID/status` parsing route is meaningfully safer than `stat`

Started as an E1 finding from edge-cases stage; confirmed during implementation. Comm names
with spaces or parens (kernel threads, certain user processes) break field-4 parsing of
`/proc/$PID/stat`. The `status` file is `key:\tvalue` per line — `awk -F'\t' '$1=="PPid:"'`
is robust. This is now the canonical pattern for any toolkit code that walks `/proc`.

### 2. Test-time clobber: simulating preflight against live PID overwrites your own marker

When I ran `echo '{"session_id":"test"}' | bash hooks/epistemic-preflight.sh` to validate
WU2, my live session's marker (PID 2889563, real session_id) got overwritten with the test
ID. Recovered manually using the helper. **Lesson**: end-to-end hook smoke tests MUST set
`EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=<fake>` to scope writes away from the live PID. Added
to `epistemic-smoke-test.sh` as the convention. Worth promoting to a CLAUDE.md rule.

### 3. The sweep is correct; test fidelity has to bend, not the production behavior

The two-condition sweep (`/proc/$PID` exists AND `comm=claude`) correctly removes any
marker for a fake PID. But fake PIDs are exactly what test fixtures use. Trying to make
the sweep "test-friendly" would weaken its PID-reuse defense. The right move: a test-only
`EPISTEMIC_SKIP_SWEEP` env var. Production stays strict.

### 4. Anti-pattern hooks fire on shape, not intent

Two PreToolUse hook flags during implementation:
- `bash-rm-rf-with-variable` on `cleanup() { rm -rf "$TEMP_HOME"; }` (preserved verbatim
  from the original smoke-test) — fixed with the three-guard pattern (`-n` && `!= "/"` && `--`).
- `bash-missing-fail-fast` on `VAR=$(grep ... | cut)` — fixed with explicit `-z` guards
  on each, but the hook **kept firing** on subsequent edits because the regex matches the
  shape regardless of guards. Catalog notes this is expected: "false positives expected;
  the catalog flags the smell, the human decides."

The catalog is doing its job. The right reaction was to add the guard once and proceed.

### 5. Manifest staleness wasn't caught by `manifest_stale=false`

state.json's `current_stage` was "test" while manifest.json said "challenge" — 38 minutes
of drift. The `manifest_stale` flag is only flipped on regression in the current code; it
should also flip on stage transitions. Surfacing as a follow-up paper cut for the blueprint
workflow itself.

## Reflection

### Wrong Assumptions

- **Rev1 PPID claim** (already documented): "claude is the direct PPID" — true for Bash-tool
  context, false for hook context. Rev2 process-tree traversal handles both. This blueprint
  proves the value of multi-context probes; one-context probes lock you into wrong
  abstractions.

- **Eval fixture suitability for behavioral tests**: I assumed `evals/evals.json` could host
  the parallel-isolation tests. Runtime check during WU8 showed it's text-regex only. Not a
  big deal — the smoke test was already a behavioral harness — but worth noting that the
  spec assumed expressiveness the framework doesn't have.

### Difficulty Calibration

- **Easier than expected**: WU5a-d (command bash blocks) — the helper functions are clean
  enough that consumers became 1-3 line replacements. Shipped in ~10 minutes total.
- **Harder than expected**: Phase 9 parallel-isolation in the smoke test. The sweep
  removed fake-PID markers (correctly!), making the test fail in a way that initially
  looked like the helper was wrong. Took two iterations to recognize that test fidelity
  needed an opt-out.

### Advice for Next Planner

- **For empirical-gate blueprints**: keep the probe artifacts in the blueprint directory
  AND attach them to the empirical_findings keys in state.json. When rev1's PPID claim was
  retracted, having `probe-v2-process-tree-and-sessionend.log` adjacent saved 10+ minutes
  of "wait what was the actual hierarchy."
- **For blueprints that touch their own runtime**: dogfood at every stage. Incident #3
  happened DURING planning of the fix. The recovery snapshot at
  `preflight-snapshot-original-2026-05-01T17-11-37Z.json` is itself a testimonial: yes,
  the bug is real, and yes, the fix is needed.
- **For shell helpers consumed by 13+ files**: lead with the helper (WU1) and validate it
  in isolation BEFORE refactoring consumers. Saved a lot of "is the helper wrong or is
  this consumer wrong?" debugging.

### Which spec sections were most/least useful

- **Most useful**: the Failure Modes table. Every implementation decision had a row to
  cross-check. The Edge Case Constraints table (E1-E9) was second most useful — those
  were the patches that prevented real bugs.
- **Least useful**: the Senior Review Simulation. Good shape, but the questions it raised
  were already covered in Failure Modes / Edge Cases. Could be condensed for next time.

## Live verification (this session)

This session's `/end` invocation IS the end-to-end test. The hooks are now installed
(`bash install.sh` ran), my live marker is at `~/.claude/.current-session/2889563`
containing `session_id=593d965a-9883-4c3b-8027-f2a7287e91cf`. When `/end` runs:

1. `/end` command's bash block uses `epistemic_get_session_id` → reads my marker
2. `/epistemic-postflight` writes postflight vectors against my session_id
3. SessionEnd hook (new code) cleans up `~/.claude/.current-session/2889563` only

If `/end` pairs my session correctly in `epistemic.json` (`paired: true` for
`593d965a-...`), the blueprint has shipped its primary acceptance criterion in production.

## State Transitions

- `stages.test.status` → `complete` (rev2)
- `stages.execute.status` → `complete`
- `stages.debrief.status` → `complete`
- `completed` → `true` (after this debrief is committed)
