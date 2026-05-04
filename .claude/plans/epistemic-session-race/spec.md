# Change Specification: epistemic-session-race (Revision 2)

> **Revision history**: rev1 → rev2 due to Stage 3 critique REWORK verdict on 2026-05-04. Rev1 preserved at `spec.md.revision-1.bak`. See `regression_log` in state.json for trigger details, and `adversarial.md` for the 20 findings carried forward.

## Summary

Replace the single-file `~/.claude/.current-session` marker with per-claude-PID markers under `~/.claude/.current-session/` (directory), keyed by the **Claude main process PID resolved via process-tree traversal** (handling the empirically-confirmed `hook → sh → claude` hierarchy AND the `bash-tool → claude` hierarchy with one helper). Marker contents store Claude Code's own `session_id` from SessionStart stdin JSON as the canonical identity. All 13+ readers (3 hooks + 6 command bash blocks + transitively-affected hooks) source `scripts/epistemic-marker.sh` for resolution. Eliminates 3 confirmed clobber incidents.

## What Changes

### Files/Components Touched

| File | Nature of Change |
|------|------------------|
| `scripts/epistemic-marker.sh` | **NEW** — shared helper: `epistemic_claude_main_pid`, `epistemic_marker_path`, `epistemic_get_session_id`, `epistemic_session_active`, `epistemic_sweep_orphans`, `epistemic_write_marker` |
| `hooks/epistemic-preflight.sh` | Modify — read stdin JSON for session_id, source helper, write per-claude-PID marker, run orphan sweep before write, handle migration of legacy single-file marker, handle `source: "resume"`, defensive default for unrecognized source values, **remove uuidgen fallback** |
| `hooks/epistemic-postflight.sh` | Modify — source helper, read marker via `epistemic_get_session_id`, fall back to stdin session_id (verified empirically present), scope `rm -f` to own claude-PID marker only |
| `hooks/_audit-log.sh` | Modify — source helper, replace inline marker grep with `epistemic_get_session_id` |
| `commands/epistemic-preflight.md` | Modify — bash block: helper-based read; **rewrite the create-fallback path** to write into per-claude-PID directory (no uuidgen) |
| `commands/epistemic-postflight.md` | Modify — bash block: helper-based read; **scoped delete** uses helper's marker path (not bare `rm -f` on directory root) |
| `commands/end.md` | Modify — bash block: helper-based read; **rewrite line-284 grep** (`session-[^ ]*` doesn't match UUIDs); use `epistemic_get_session_id` directly |
| `commands/start.md` | Modify — bash block: replace `cat ~/.claude/.current-session` with `epistemic_get_session_id`; replace prose existence check with `epistemic_session_active` |
| `commands/collect-insights.md` | Modify — replace `[ -f ... ]` with `epistemic_session_active`; helper-based read |
| `commands/vault-curate.md` | Modify — replace `[ -f ... ]` with `epistemic_session_active`; helper-based read |
| `commands/checkpoint.md` | Modify — prose reference: describe new per-claude-PID directory scheme |
| `commands/log-success.md` | Modify — prose reference |
| `commands/log-error.md` | Modify — prose reference |
| `commands/evolve.md` | Modify — prose reference |
| `commands/blueprint.md` | Modify — prose reference (lines 400, 421) |
| `commands/README.md` | Modify — prose reference (line 607) |
| `docs/PLANNING-STORAGE.md` | Modify — describe marker location change (was missed in rev1; CF-17) |
| `scripts/epistemic-smoke-test.sh` | Modify — assert per-claude-PID marker layout (directory + per-PID file); update PID-existence assertions |
| `evals/evals.json` | Modify — add 4 fixtures: parallel-isolation, resume-pairing, orphan-sweep, migration-non-destructive |
| `scripts/behavioral-smoke.sh` | Modify (likely) — helpers for parallel-session simulation (subshell with controlled hierarchy) |
| `test.sh` | Modify — extend Category 1 (syntax) and Category 2 (shellcheck) to cover `scripts/epistemic-marker.sh`; add Category 5 (no `set -e`) check for the new file |
| `install.sh` | Verify only — tarball auto-extract should pick up new helper |

### External Dependencies

- [x] None — pure shell + jq.

### Database/State Changes

- **Marker location**: `~/.claude/.current-session` (file) → `~/.claude/.current-session/` (directory). One file per active Claude main process keyed by claude PID. Discovery via process-tree traversal.
- **Marker contents**: K=V format with one new field. Schema: `SESSION_ID=<from stdin>`, `PROJECT=<dir>`, `STARTED=<ISO timestamp>`, `CLAUDE_PID=<for self-validation>`. Removing the K=V `uuidgen`-derived fallback path entirely.
- **`epistemic.json` schema**: unchanged.
- **Migration**: on first new-scheme write, if `~/.claude/.current-session` exists as a non-directory, atomically rename it to `~/.claude/.current-session.legacy-${TS}` and create the directory. **Race-safe**: `mv` can fail with ENOENT under concurrent migration — treated as "peer migrated first, proceed." `mkdir -p` is idempotent. Both error paths exit fail-open.

## Preservation Contract (What Must NOT Change)

- **Single-session behavior**: preflight → postflight pairing identical to today.
- **Fail-open semantics**: hooks exit 0 on any error path; helper file uses explicit `set +e`.
- **Hook timeout budget**: SessionStart hook completes under 2 seconds (current ~1.5s for calibration). Process-tree traversal adds ~3-5 syscalls per call; sweep is O(active session files), bounded.
- **Public-facing UX**: SessionStart calibration block layout and `/end` postflight prompt unchanged.
- **`epistemic.json` schema**: writes preserve `sessions`, `paired`, `deltas` structure.
- **`SAIL_DISABLED_HOOKS` toggle**: continues to disable both hooks atomically.
- **Subagent behavior**: out of scope. If subagent Bash invocations have a different process tree (e.g., spawned by Task tool with intermediate processes), helper traversal still finds claude — but subagent epistemic tracking is not a goal of this blueprint.

## Success Criteria

> **Verification vocabulary** (per `feedback_verification_word_precision.md`): `TESTED` = automated assertion in eval; `VERIFIED` = manual measurement or inspection; `OBSERVED` = behavioral confirmation in real session. Vocabulary is now applied carefully — see CF-16 fix.

| AC | Criterion | Mechanism |
|----|-----------|-----------|
| AC1 | Concurrent isolation | **TESTED** — eval simulates two parallel preflight invocations with different claude PIDs (subshell + crafted PPID propagation), each writes own marker; verify each can submit postflight without affecting the other's epistemic.json entry. |
| AC2 | Postflight under correct ID | **TESTED** — eval: session A submits preflight (session_id=X), simulated session B starts (different claude PID), session A's postflight reads its OWN marker file → SESSION_ID=X → epistemic.json entry for X paired correctly. |
| AC3 | Resume preserves identity | **VERIFIED** (manual) — run `claude --print "ping"` then `claude --resume <uuid> --print "ping"`, inspect epistemic.json: only one entry under that session_id, paired correctly. Per-claude-PID markers created and cleaned up across both runs. (TESTED simulation in eval is a proxy; manual is authoritative.) |
| AC4 | All consumers use helper | **TESTED** — `bash test.sh` adds checks: `grep -rl 'epistemic_get_session_id\|epistemic_marker_path\|epistemic_session_active' hooks/ commands/ scripts/ \| wc -l` returns at least 9 (3 hooks + 6 command files). Second check: `grep -rln '\\.current-session\b' hooks/ commands/ scripts/ \| grep -v '\\.bak\|legacy\|migration\|README\|\\.md$'` should match only the helper file (which legitimately defines the path). |
| AC5 | Orphan cleanup works | **TESTED** — eval: write marker for fake PID 99999 (no `/proc/99999`), run sweep helper, verify marker removed. Additional check: write marker for a real PID whose `/proc/<pid>/comm` is NOT "claude" (e.g., this shell), verify sweep removes it (PID-reuse defense). |
| AC6 | Migration is non-destructive | **TESTED** — eval: pre-create legacy single-file `~/.claude/.current-session` with known content, run new SessionStart hook simulation, verify file was renamed to `.legacy-<TS>` and content preserved; new directory exists; new marker writes succeed. |
| AC7 | Existing test suite passes | **TESTED** — `bash test.sh` exits 0. |
| AC8 | Smoke test passes | **TESTED** — `bash scripts/epistemic-smoke-test.sh` exits 0 against new layout. |
| AC9 | Hook conventions preserved | **TESTED** — test.sh Category 5 (no `set -e`, no `eval`, `set +e` present) extended to include `scripts/epistemic-marker.sh`. |
| AC10 | SessionStart timing | **VERIFIED** (manual, Stage 7) — time the SessionStart hook end-to-end with traversal + sweep on Nick's WSL2 instance. Must complete under 2.0s. Hardware variance precludes a CI threshold. |
| AC11 | No SessionEnd silent regression | **TESTED** — eval: SessionEnd stdin lookup verified to provide session_id (per probe v2). Postflight with marker missing falls back to stdin successfully; postflight with both missing logs warning to stderr but exits 0. |

## Failure Modes

| What Could Fail | Detection | Recovery Action |
|-----------------|-----------|-----------------|
| Stdin JSON missing/malformed at SessionStart | `jq` parse fails — no session_id available | **Hook continues fail-open with stderr warning. NO marker written.** Per-PPID resolution will return empty session_id at next consumer call → postflight skips with "no marker / no session_id" warning. **No uuidgen fallback** (CF-7). User sees stderr but session continues. |
| Process-tree traversal cannot find `comm=claude` | Loop exhausts max 15 hops without match | Helper returns empty PID. Caller treats as "no active session." Fail-open with stderr warning. |
| `/proc` filesystem unavailable (non-Linux: macOS, BSD) | `[ -d /proc ]` check returns false | Sweep skips orphan check (markers accumulate harmlessly until manual cleanup). Process-tree traversal cannot work — falls back to `$PPID` directly. **Caveat (NEW-3)**: in hook context this means PPID=`sh` (intermediate shell), which re-exposes the original cross-session clobber bug on non-Linux platforms. **Mitigation**: WU2 should emit a one-time stderr warning at SessionStart on non-Linux: `"[epistemic] /proc unavailable; per-PID isolation degraded — concurrent claude sessions on this platform may cross-contaminate epistemic.json. macOS/BSD support is a separate blueprint."` |
| Marker directory creation fails | `mkdir -p` exits non-zero | Hook continues fail-open with stderr warning; epistemic tracking degrades. |
| Helper file missing (`scripts/epistemic-marker.sh` not installed) | `source` returns non-zero | Hooks: stderr warning + skip; commands: stderr warning + treat as no-session. **No per-file inline fallbacks** — single mechanism (CF-10 fix). |
| `claude --resume` reuses session_id with new PID | Expected behavior | Marker filename differs (new claude PID), marker contents (SESSION_ID) match. epistemic.json operations key on SESSION_ID, not PID — pairing preserved automatically. |
| Multiple SessionStart fires for same claude process (`source: startup` then `source: resume` or `clear`) | Sequential, not simultaneous | WU2 source-branching: `startup` creates marker; `resume` unconditionally creates a new marker (the prior session's marker was deleted by its SessionEnd postflight cleanup, so there is nothing to reuse); `clear` and any unrecognized source treated as startup with stderr warning. **Constraint** (NEW-2 fix): if `source: "resume"` or `"clear"` AND a preflight has already been submitted to `epistemic.json` for this `session_id` (check `paired: false, preflight: <non-null>`), WU2 must NOT trigger an automatic preflight re-submission — it would overwrite the original. Failure Modes section no longer claims "impossible." |
| Sweep removes a live marker (race) | Sweep checks BOTH `[ -d /proc/$PID ]` AND `[ "$(cat /proc/$PID/comm)" = "claude" ]` | Two-condition check substantially reduces (but does not fully eliminate per E8) the PID-reuse race window: an orphan marker for a PID now belonging to a non-claude process is correctly identified and removed. A live claude marker passes both checks. Residual TOCTOU between the two `/proc` reads is theoretical and acceptable. |
| Concurrent legacy-file migration race | `mv` returns ENOENT (peer renamed first) | Treated as success: `mkdir -p` creates directory regardless. (CF-14 fix) |
| PPID=1 hierarchy (Docker init) | Helper traversal walks past PPID=1 boundary | Traversal max-depth (15 hops) terminates loop; if no `comm=claude` found, returns empty (handled per row above). PPID=1 case (CF-8) becomes moot under traversal — no special-casing needed. |
| Bash subshell PPID differs across platform | Stage 6 spec-blind test runs `[ "$(cat /proc/$PPID/comm)" = "claude" ] || [ "$(cat /proc/$$/.../up-to-claude)" = "claude" ]` and reports | WSL2 + Linux known-good. macOS verification: out of scope (separate blueprint). |

## Rollback Plan

Reverting the change requires more than `git revert` because the directory persists on disk:

1. **Revert hooks + helper + commands**: `git revert <commit-sha>` for the rev2 commit chain. Single revert.
2. **MANDATORY cleanup of marker directory** (CF-9 fix — rev1 said "no action needed", which was incorrect):
   ```bash
   # Required for reverted hook to write to file path
   rm -rf ~/.claude/.current-session/
   # If a recent legacy backup exists, restore it (optional):
   ls -t ~/.claude/.current-session.legacy-* 2>/dev/null | head -1 | \
     xargs -I {} mv {} ~/.claude/.current-session
   ```
3. **`epistemic.json`** unchanged by this work — no rollback needed.
4. **Notification**: none (single-user tool).

Rollback test: after revert + cleanup, `bash test.sh` passes against rev1 state in <1 min.

## Dependencies (Preconditions)

- [x] Q1 resolved correctly (rev2): probe v2 confirmed both hierarchies and process-tree traversal viability
- [x] Q2 resolved (rev2): SessionEnd stdin contains session_id and reason field, structure documented in probe-v2 log
- [x] Q3 (compaction `source` value) deferred to defensive handling — defensive default branch in WU2
- [x] Existing per-PPID convention found at `session-end-cleanup.sh:18`
- [x] Defensive snapshot of original session preflight intact (Stage 1 hold)

## Open Questions

> **Spec-discovery items rather than blockers.** None gate Stage 4 entry.

- **OQ-rev2-1 — Subagent compatibility**: Do subagent Bash invocations have a process tree where claude is reachable? Probably yes (Task tool spawns are children of claude main), but unverified. **Decision**: out of scope. Document in debrief.
- **OQ-rev2-2 — Eval simulation fidelity**: How accurately can we simulate a parallel session in `evals/evals.json` without launching a second `claude` process? Approach: bash subshell with controlled environment (clear PPID, set CLAUDE_MAIN_PID via env, run helper directly). Worked example to be drafted in Stage 7 / WU8. **Confidence**: 0.7 — the helper-level simulation is sound; the hook-level simulation is necessarily a proxy.
- **OQ-rev2-3 — Sweep placement traceability** (CF-20 partial): rev2 implements sweep at SessionStart per WU2 description and Failure Modes table; describe.md's tentative "likely SessionEnd" is implicitly overridden but not explicitly noted. **Disposition**: trivial — record in debrief; no spec change needed.

## Senior Review Simulation

- **They'd ask**: *"Why not just use the session_id directly and skip the PPID layer?"* Answer: Bash turn invocations don't see session_id in their environment (verified by both probes). The PPID layer is the discovery scaffolding that lets a Bash turn find its session_id without prior knowledge.
- **They'd ask**: *"What if the user runs `claude` inside `claude` (e.g., via `&` background invocation)?"* The traversal finds the **innermost** `comm=claude` (the immediate ancestor). Each nested invocation has its own marker. Probably correct, but documented as untested.
- **Non-obvious risk**: The helper does process-tree traversal on every call. Sourced 13+ places, each potentially calling `epistemic_get_session_id` once per command turn. On a 10-turn session, that's ~50 traversals — fast but not free. Mitigation: helper caches result in `EPISTEMIC_CLAUDE_MAIN_PID` env var on first call.
- **Standard approach**: pidfd / process tracking via cgroup. Considered, rejected — adds complexity for no benefit at our scale, and not portable across older kernels.
- **What bites first-timers**: forgetting that hook stdin is consumed once. The helper's documentation header MUST state: `# Hook stdin: read by epistemic-preflight.sh ONLY. Other hook consumers MUST read session_id from the marker file via epistemic_get_session_id.`

## Edge Case Implementation Constraints (post-Stage-4 patches)

The following constraints must be honored in WU1/WU2 implementation. They are not new WUs — they are inline corrections from Stage 4 (Edge Cases) review.

| ID | Patch | WU | Severity |
|----|-------|----|----------|
| E1 | **Process-tree traversal MUST parse `/proc/$PID/status` PPid line, NOT `/proc/$PID/stat` field 4.** Comm names can contain spaces/parens (kernel threads); space-delimited field parsing is fragile and can return wrong PPid silently. Status format: `key: value` per line, robust regardless of comm content. | WU1 | high |
| E2 | **`epistemic_write_marker` MUST create tmpfile on the SAME filesystem as the target.** Use `mktemp -p "$(dirname "$marker_path")"` not `mktemp` (which defaults to /tmp, may be different mount → `mv` fails with EXDEV). | WU1 | high |
| E3 | **On `source: "resume"` or `"clear"` re-write of an existing live marker, preserve the original `STARTED` field.** Read the existing marker's STARTED before writing; if present and parseable, reuse it. Otherwise write current time. (Without this, every `/compact` rewrites STARTED to compaction time, losing session-start time.) | WU2 | medium |
| E5 | **All path construction in helper MUST double-quote `$HOME` and the returned marker path.** Single users with spaces in `$HOME` (less rare on macOS) hit "ambiguous redirect" otherwise. | WU1 | medium |
| E6 | **Validate `session_id` matches UUID pattern before writing marker.** Pattern: `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`. If validation fails, log to stderr and exit fail-open (no marker written). Defends against future Claude Code format changes and stray newline/`=` injection. | WU1 | medium |
| E8 | **Failure Modes wording correction**: change "two-condition check eliminates the PID-reuse race" to "substantially reduces (does not eliminate) the PID-reuse race window." TOCTOU between two `/proc` reads remains theoretically possible; documentation accuracy. | (FM table) | low |
| E9 | **Traversal loop MUST terminate on `next_pid <= 1`.** Guards against PPid=0 from kernel threads (unreachable in practice but cheap defense; max 15 hops still applies as upper bound). | WU1 | low |

E4 was a documentation accuracy issue (caching is per-invocation, not session-level) — noted but no spec change needed; the Senior Review Simulation paragraph about caching is now slightly inaccurate but harmless. E7, E10, E11, E12 were verified safe (already addressed or out of scope).

## Work Units

| WU | Description | Files | Dependencies | Complexity | TDD |
|----|-------------|-------|--------------|------------|-----|
| WU1 | Create shared helper. Functions: `epistemic_claude_main_pid` (process-tree traversal with caching), `epistemic_marker_path`, `epistemic_get_session_id`, `epistemic_session_active` (existence check that works on directory layout), `epistemic_sweep_orphans` (two-condition check: `/proc/$PID` exists AND `comm=claude`), `epistemic_write_marker` (atomic write via tmpfile + mv). Explicit `set +e`. Doc-block on stdin-once contract. | `scripts/epistemic-marker.sh` (NEW) | — | High | true |
| WU2 | Refactor `epistemic-preflight.sh`: read stdin JSON for session_id, source helper, run sweep, write per-claude-PID marker, handle migration (with race ENOENT), source-branching (`startup`/`resume`/`clear`/default→stderr-warning-treat-as-startup). **No uuidgen fallback** (per CF-7). | `hooks/epistemic-preflight.sh` | WU1 | High | true |
| WU3 | Refactor `epistemic-postflight.sh`: source helper, read marker via `epistemic_get_session_id`, fall back to stdin session_id (now verified to be present per probe v2), scope `rm -f` to own claude-PID marker only. | `hooks/epistemic-postflight.sh` | WU1 | Medium | true |
| WU4 | Refactor `_audit-log.sh`: source helper, replace inline marker grep with `epistemic_get_session_id`. | `hooks/_audit-log.sh` | WU1 | Low | true |
| WU5a | `commands/epistemic-preflight.md`: bash block now uses helper for read; **rewrite create-fallback** to write per-claude-PID marker (CF-4 M1). | `commands/epistemic-preflight.md` | WU1 | Medium | false |
| WU5b | `commands/epistemic-postflight.md`: bash block uses helper for read; rewrite Step 6 cleanup from bare `rm -f` to helper-scoped delete (CF-4 M4). | `commands/epistemic-postflight.md` | WU1 | Low | false |
| WU5c | `commands/end.md`: bash block uses helper for read; **rewrite line-284 grep** (`session-[^ ]*` doesn't match UUIDs) to use `epistemic_get_session_id` directly (CF-4 M2). | `commands/end.md` | WU1 | Low | false |
| WU5d | `commands/start.md`, `commands/collect-insights.md`, `commands/vault-curate.md`: replace `[ -f ... ]` existence checks with `epistemic_session_active`; helper-based read for content (CF-4 M3). | 3 command files | WU1 | Low | false |
| WU6 | Update prose references in 6 docs: `commands/{checkpoint,log-success,log-error,evolve,blueprint,README}.md` AND `docs/PLANNING-STORAGE.md` (CF-17). | 7 files | — | Trivial | false |
| WU7 | Update `scripts/epistemic-smoke-test.sh` for per-claude-PID layout. | `scripts/epistemic-smoke-test.sh` | WU2, WU3 | Low | false |
| WU8 | Add parallel-isolation eval fixture (AC1, AC2). Subshell-with-PPID-propagation simulation. | `evals/evals.json`, `scripts/behavioral-smoke.sh` (helpers if needed) | WU2, WU3 | High | false |
| WU9 | Add resume-pairing eval fixture (AC3 simulation proxy; manual is authoritative). | `evals/evals.json` | WU2, WU3 | Medium | false |
| WU10 | Add orphan-sweep eval fixture (AC5 — both fake-PID and PID-reuse defense). | `evals/evals.json` | WU2 | Low | false |
| WU11 | Add migration eval fixture (AC6) including ENOENT race path. | `evals/evals.json` | WU2 | Medium | false |
| WU12 | Extend `test.sh`: Category 1 syntax for `scripts/epistemic-marker.sh`; Category 2 shellcheck; Category 5 no-set-e check. Verify install dry run lands the new helper (CF-15). **PM-Fix-1**: extend `install.sh` to run a post-install verification of helper sourceability and print explicit success line. **PM-Fix-4**: add AC11.5 "after install, smoke test outputs SESSION_ID for current session." | `test.sh`, `install.sh` | WU1 | Low | false |
| WU5d-extended | (additive) `commands/start.md` and `commands/status.md` (if exists): show marker file path + age (e.g., "Marker: ~/.claude/.current-session/12345 (age 2m)"). One-line addition per file. **PM-Fix-3**. | `commands/start.md`, `commands/status.md` | WU1, WU5d | Trivial | false |

**Critical path (rev2):** WU1 → WU2 → WU8. Width unchanged.

**Diff vs rev1**: WU1 expanded (added `epistemic_claude_main_pid`, `epistemic_session_active`, `epistemic_write_marker`). WU2 expanded (source-branching, no uuidgen). WU5 split into 5a-5d for per-file fix enumeration. WU6 added `docs/PLANNING-STORAGE.md`. WU12 expanded (test.sh Category 1+2+5, not just Category 7).

---

Specification rev2 complete. Next: regenerate work-graph.json (work_graph_stale=true) and re-enter Stage 3 critique against rev2.
