# Generated Tests: epistemic-session-race (rev2)

> **Spec-blind constraint applied**: tests are derived from spec.md's Success Criteria (AC1–AC11), Preservation Contract, and Failure Modes table. They describe observable behavior, not implementation structure. Where spec calls out specific function names (e.g. `epistemic_get_session_id`), I treat those as part of the *contract* (consumers must use them), not as implementation details — because the spec's AC4 explicitly tests for that exact contract via grep.

---

## Source Specification

### Success Criteria Used
| Criterion | Test Coverage |
|-----------|--------------|
| AC1 — Concurrent isolation | T-AC1-parallel-markers, T-AC1-no-clobber |
| AC2 — Postflight under correct ID | T-AC2-postflight-attribution |
| AC3 — Resume preserves identity | T-AC3-resume-pairing (manual + eval proxy) |
| AC4 — All consumers use helper | T-AC4-helper-adoption-grep, T-AC4-no-direct-marker-reads |
| AC5 — Orphan cleanup works | T-AC5-fake-pid-orphan, T-AC5-pid-reuse-defense |
| AC6 — Migration is non-destructive | T-AC6-legacy-rename, T-AC6-migration-ENOENT |
| AC7 — Existing test suite passes | T-AC7-test-sh-green |
| AC8 — Smoke test passes | T-AC8-epistemic-smoke-green |
| AC9 — Hook conventions preserved | T-AC9-set-e-absent |
| AC10 — SessionStart timing | T-AC10-timing-budget (manual) |
| AC11 — No SessionEnd silent regression | T-AC11-stdin-fallback, T-AC11-both-missing |

### Preservation Contract Used
| Invariant | Test Coverage |
|-----------|--------------|
| Single-session pairing identical | T-PC1-single-session-pairing |
| Fail-open semantics | T-PC2-fail-open-on-error |
| Hook timeout under 2s | T-PC3-timing-budget (overlaps AC10) |
| UX layout unchanged | T-PC4-calibration-block-shape |
| epistemic.json schema unchanged | T-PC5-json-schema-stable |
| SAIL_DISABLED_HOOKS toggle | T-PC6-disable-toggle |

### Failure Modes Used
| Failure | Test Coverage |
|---------|--------------|
| Stdin JSON missing/malformed | T-FM1-malformed-stdin |
| Process-tree traversal exhaust | T-FM2-traversal-exhaust |
| /proc unavailable | T-FM3-no-proc-warning (manual on macOS; behavioral assertion only) |
| Marker dir creation fails | T-FM4-mkdir-fail |
| Helper file missing | T-FM5-helper-missing |
| Resume preserves session_id | T-FM6-resume-marker-newpid (overlaps AC3) |
| Sequential SessionStart for same claude PID | T-FM7-source-branching, T-FM7-no-double-preflight |
| Sweep removes live marker | T-FM8-sweep-respects-comm-check (overlaps AC5) |
| Concurrent legacy migration | T-FM9-migration-race (overlaps AC6) |
| PPID=1 docker init | T-FM10-traversal-terminates-at-1 |

---

## Generated Tests

### Behavior Tests

#### T-AC1-parallel-markers: Two parallel preflight invocations write distinct markers
- **Setup:** Two subshells, each simulating a distinct claude main PID (e.g., env `CLAUDE_MAIN_PID_OVERRIDE=10001` and `=10002`). Marker directory `~/.claude/.current-session/` empty at start.
- **Action:** Each subshell invokes the preflight hook via stdin with a distinct UUID session_id.
- **Assert:**
  - `~/.claude/.current-session/10001` exists, contains `SESSION_ID=<UUID-A>`
  - `~/.claude/.current-session/10002` exists, contains `SESSION_ID=<UUID-B>`
  - Neither file overwrote the other; mtime confirms both writes succeeded.
  - Reading marker A returns A's session_id; reading marker B returns B's.

#### T-AC1-no-clobber: Postflight reads its own marker when a peer marker exists
- **Setup:** Marker A (PID=10001, session_id=X) and Marker B (PID=10002, session_id=Y) both present. Subshell with simulated claude PID = 10001 runs postflight.
- **Action:** Postflight hook fires.
- **Assert:** epistemic.json gets a paired entry under session_id=X, not Y. Marker B is untouched.

#### T-AC2-postflight-attribution: Postflight pairs against correct session_id
- **Setup:** Preflight A submitted with session_id=X (entry exists in epistemic.json with `paired: false`). Simulated peer session B's preflight clobbers nothing (different PID-keyed marker).
- **Action:** Session A's postflight fires (claude PID resolves to A's).
- **Assert:** epistemic.json entry for session_id=X transitions to `paired: true` with both preflight and postflight vectors. No entry under session_id=Y is created or modified.

#### T-AC3-resume-pairing (proxy + manual)
- **Eval proxy:** Two sequential simulated invocations: first claude PID=20001 with session_id=Z, postflight fires, marker cleaned. Second invocation with claude PID=20002 (different PID, "resumed") with session_id=Z. Both runs attribute to one entry under session_id=Z.
- **Manual authoritative:** Real `claude --print "ping"` then `claude --resume <uuid> --print "ping"`. Inspect epistemic.json — exactly one entry under session_id, paired correctly.
- **Assert:** Marker filenames differ across the two invocations (per-PID), but session_id inside both points to the same epistemic.json entry, which ends paired.

#### T-AC4-helper-adoption-grep: All consumers source the helper or use its functions
- **Setup:** None (static check).
- **Action:** Grep against `hooks/`, `commands/`, `scripts/` for helper function names.
- **Assert:** At least 9 files reference `epistemic_get_session_id`, `epistemic_marker_path`, or `epistemic_session_active` (3 hooks + 6 command files per spec).

#### T-AC4-no-direct-marker-reads: No file reads `.current-session` directly
- **Setup:** None (static check).
- **Action:** Grep `\.current-session\b` in `hooks/` `commands/` `scripts/`, exclude `.bak`, `legacy`, `migration`, `README`, `*.md`.
- **Assert:** Match set is exactly `scripts/epistemic-marker.sh` (legitimate definition site).

#### T-AC5-fake-pid-orphan: Sweep removes marker for nonexistent PID
- **Setup:** Write marker file at path keyed to PID 99999 (no such process). Confirm `/proc/99999` does not exist.
- **Action:** Invoke sweep helper.
- **Assert:** Marker file is removed. Other markers untouched.

#### T-AC5-pid-reuse-defense: Sweep removes marker whose PID points at non-claude process
- **Setup:** Write marker file at path keyed to current shell's `$$` (definitely exists in /proc, but `comm` is `bash` not `claude`).
- **Action:** Invoke sweep helper.
- **Assert:** Marker removed (two-condition check fires: PID exists but comm != claude).

#### T-AC6-legacy-rename: Single-file legacy marker is preserved during migration
- **Setup:** Pre-create `~/.claude/.current-session` as a file (legacy layout) containing known content `SESSION_ID=legacy-test-uuid`.
- **Action:** Trigger preflight hook simulation.
- **Assert:**
  - `~/.claude/.current-session.legacy-<TS>` exists, content matches what was originally in the legacy file.
  - `~/.claude/.current-session/` exists as a directory.
  - New per-PID marker write succeeds inside the directory.

#### T-AC6-migration-ENOENT: Concurrent migration race is treated as success
- **Setup:** Use a fixture that intercepts the `mv` and forces ENOENT (peer migrated first scenario).
- **Action:** Trigger migration code path.
- **Assert:** Hook exits 0. Directory is created (mkdir -p idempotent). No marker write fails downstream.

#### T-AC7-test-sh-green: Existing test suite passes
- **Action:** `bash test.sh`
- **Assert:** Exit 0. All 8 categories pass. Specifically verify Category 7 (install dry-run) shows `scripts/epistemic-marker.sh` landing in the temp `$HOME`.

#### T-AC8-epistemic-smoke-green: Smoke test passes against new layout
- **Action:** `bash scripts/epistemic-smoke-test.sh`
- **Assert:** Exit 0. Asserts directory layout, marker presence, marker contents.

#### T-AC9-set-e-absent: New helper file follows hook conventions
- **Action:** test.sh Category 5 extended grep.
- **Assert:** `scripts/epistemic-marker.sh` does not contain `set -e`, does not use `eval`, and contains an explicit `set +e`.

#### T-AC10-timing-budget (manual)
- **Setup:** Real claude session on Nick's WSL2 box.
- **Action:** Time SessionStart hook end-to-end with `time`.
- **Assert:** Total real time < 2.0s. (Caveat: hardware-dependent; not a CI gate.)

#### T-AC11-stdin-fallback: Postflight reads session_id from stdin when marker missing
- **Setup:** Delete the per-PID marker before postflight fires. Stdin JSON contains valid session_id.
- **Action:** Trigger postflight.
- **Assert:** epistemic.json entry for that session_id transitions to paired correctly. Stderr may show a notice about marker fallback. Hook exits 0.

#### T-AC11-both-missing: Postflight with no marker AND no stdin session_id
- **Setup:** Delete marker. Provide empty/malformed stdin.
- **Action:** Trigger postflight.
- **Assert:** Hook exits 0 (fail-open). Stderr shows warning. epistemic.json is not corrupted (no partial entry written).

---

### Contract Tests (Preservation)

#### T-PC1-single-session-pairing: Single-session preflight→postflight identical to pre-change behavior
- **Pre-state:** Empty epistemic.json sessions array, empty marker dir.
- **Action:** Run preflight, then postflight (single claude PID throughout).
- **Assert:** Exactly one session entry with `paired: true`, both preflight and postflight vectors present, structure matches schema as it existed pre-change.

#### T-PC2-fail-open-on-error: Hooks exit 0 on any error path
- **Setup:** Force errors at multiple points: missing helper file, malformed stdin, /proc unavailable simulation, mkdir failure (read-only `$HOME` simulation).
- **Action:** Each failure scenario invokes the hook.
- **Assert:** Each invocation returns exit 0. User-facing output goes to stderr only.

#### T-PC3-timing-budget: SessionStart < 2s with traversal + sweep
- (Same as T-AC10 — single test serves both contract and AC.)

#### T-PC4-calibration-block-shape: SessionStart UI output unchanged
- **Pre-state:** Capture the calibration text block emitted by `epistemic-preflight.sh` on a paired-history session pre-change.
- **Action:** Run new preflight on same session ID.
- **Assert:** Block shape, headers, vector list, and final preflight prompt are byte-for-byte identical (other than any `Migration:` notice on first run, which is one-time).

#### T-PC5-json-schema-stable: epistemic.json schema unchanged
- **Action:** Diff the keys-of-keys between old and new entries.
- **Assert:** Both entries contain the same top-level keys (`sessions[].id`, `project`, `timestamp`, `preflight`, `postflight`, `deltas`, `task_summary`, `paired`). No new keys added at the schema level — additions like `claude_pid` go into the marker file, not into epistemic.json.

#### T-PC6-disable-toggle: SAIL_DISABLED_HOOKS still disables both hooks
- **Setup:** Export `SAIL_DISABLED_HOOKS=epistemic-preflight,epistemic-postflight`.
- **Action:** Run preflight and postflight invocations.
- **Assert:** Neither writes a marker. Neither modifies epistemic.json. Both exit 0 silently.

---

### Failure Mode Tests

#### T-FM1-malformed-stdin: No marker written on bad stdin, no uuidgen fallback
- **Setup:** Hook receives stdin that is not valid JSON, or JSON without `session_id` field.
- **Action:** Preflight fires.
- **Assert:**
  - No marker file is created.
  - Stderr shows a warning.
  - Hook exits 0.
  - **CRITICAL**: marker filename does NOT contain a uuidgen-style ID — the absence of stdin session_id must NOT cause synthesis of a fake one.

#### T-FM2-traversal-exhaust: Helper returns empty PID after 15 hops
- **Setup:** Construct a /proc fixture (or run in a controlled env) where the PPID chain never hits a `comm=claude` ancestor.
- **Action:** Invoke `epistemic_claude_main_pid`.
- **Assert:** Returns empty / exit non-zero. Caller treats as no-session. No marker is read or written. No infinite loop (loop terminated within 15 hops).

#### T-FM3-no-proc-warning: One-time stderr warning when /proc is unavailable
- **Setup:** Simulate via runtime guard. (Real test on macOS would be authoritative, but out of scope per spec.)
- **Action:** Preflight fires with `[ -d /proc ]` returning false.
- **Assert:** Stderr contains the documented warning string about non-Linux degradation. Hook exits 0. PPID fallback is used (acknowledged as degraded).

#### T-FM4-mkdir-fail: Hook exits 0 if marker dir cannot be created
- **Setup:** Read-only `$HOME` simulation (or pre-existing non-directory file at `.current-session/`).
- **Action:** Preflight fires.
- **Assert:** Stderr warning. Exit 0. epistemic.json not modified.

#### T-FM5-helper-missing: Hooks degrade with stderr warning when helper file is absent
- **Setup:** Move/rename `scripts/epistemic-marker.sh` temporarily.
- **Action:** Each consumer (3 hooks + 6 commands) runs.
- **Assert:** Each emits a stderr warning, treats state as no-session, exits 0. **No inline fallback that re-implements marker reading** (single-mechanism guarantee from CF-10).

#### T-FM6-resume-marker-newpid: Resume creates new marker keyed by new claude PID, same session_id inside
- (Same as T-AC3 — overlap.)

#### T-FM7-source-branching: SessionStart `source` value drives hook behavior
- **Setup:** Three preflight invocations with stdin field `source` = `"startup"`, `"resume"`, `"clear"`, plus one with an unrecognized value (e.g., `"unknown_value_xyz"`).
- **Action:** Each fires sequentially against the same claude PID.
- **Assert:**
  - `startup`: marker created normally.
  - `resume`: new marker created (prior cleaned by SessionEnd).
  - `clear`: new marker created.
  - `unknown_value_xyz`: stderr warning emitted, treated as startup (defensive default branch from CF-5).

#### T-FM7-no-double-preflight: Resume/clear does NOT auto-resubmit preflight if epistemic.json already has one
- **Setup:** epistemic.json has entry for session_id=X with `paired: false, preflight: <vectors>`.
- **Action:** Hook fires with `source=resume` and same session_id.
- **Assert:** epistemic.json entry for X is unchanged (preflight vectors not overwritten). Marker is created/refreshed normally. (NEW-2 constraint.)

#### T-FM7-resume-preserves-STARTED: Resume reuses original marker's STARTED field
- **Setup:** Marker exists with `STARTED=2026-05-04T14:00:00Z`. Hook fires with `source=resume`.
- **Action:** Marker rewritten.
- **Assert:** New marker's `STARTED` field is preserved (not the current rewrite time). E3 constraint.

#### T-FM8-sweep-respects-comm-check
- (Same as T-AC5-pid-reuse-defense — overlap.)

#### T-FM9-migration-race
- (Same as T-AC6-migration-ENOENT — overlap.)

#### T-FM10-traversal-terminates-at-1: Loop bounded for Docker init scenarios
- **Setup:** Construct chain where PPID=1 occurs (real or simulated).
- **Action:** Helper traversal.
- **Assert:** Loop terminates (either via `next_pid <= 1` guard from E9 or 15-hop ceiling). No infinite loop. Returns empty if no claude found.

---

### Edge Case Constraint Tests (from Stage 4 patches)

#### T-E1-status-not-stat: Traversal parses /proc/$PID/status PPid line, not /proc/$PID/stat field 4
- **Setup:** Construct a process whose `comm` contains spaces or parentheses.
- **Action:** Helper traversal.
- **Assert:** Correct PPID returned. (If implementation read `stat` field 4 with naive whitespace split, this would break — test catches it.)

#### T-E2-same-fs-tmpfile: Atomic write tmpfile is on same filesystem as marker
- **Setup:** None (static check on helper, or: trace `mv` calls during a write).
- **Action:** Inspect helper logic OR observe a write under strace.
- **Assert:** `mktemp -p "$(dirname "$marker_path")"` pattern is used (or equivalent that guarantees same-fs). No `mv` call ever returns EXDEV.

#### T-E5-quoted-paths: Path construction tolerates spaces in $HOME
- **Setup:** `HOME=/tmp/test home with spaces` runtime override.
- **Action:** Helper invocation.
- **Assert:** No "ambiguous redirect" error. Marker writes succeed.

#### T-E6-uuid-validation: session_id is validated as UUID before write
- **Setup:** Stdin JSON with `session_id=not-a-uuid` or with embedded newlines/equals signs.
- **Action:** Preflight fires.
- **Assert:** No marker written. Stderr warning. Hook exits 0. (Defends against future format changes and injection.)

---

## Anti-Tautology Review

| Test | Trivial Pass? | Behavior Focus? | Refactor-Safe? | Spec-Derived? |
|------|---------------|-----------------|----------------|---------------|
| T-AC1-parallel-markers | No (requires both files distinct) | ✓ observable file state | ✓ any impl that writes per-PID passes | ✓ AC1 |
| T-AC1-no-clobber | No | ✓ file-level | ✓ | ✓ AC1 |
| T-AC2-postflight-attribution | No (epistemic.json content asserted) | ✓ end-state of pairing | ✓ | ✓ AC2 |
| T-AC3-resume-pairing | Manual is authoritative; eval is proxy | ✓ pairing outcome | ✓ | ✓ AC3 |
| T-AC4-helper-adoption-grep | Could pass with stub helper | ✓ adoption is the goal | ✓ if function names stable | ✓ AC4 |
| T-AC4-no-direct-marker-reads | No (static check is exhaustive) | ✓ structural invariant | ✓ | ✓ AC4 |
| T-AC5-fake-pid-orphan | No | ✓ filesystem effect | ✓ | ✓ AC5 |
| T-AC5-pid-reuse-defense | No | ✓ | ✓ | ✓ AC5 + FM table |
| T-AC6-legacy-rename | No (asserts file content + new dir) | ✓ | ✓ | ✓ AC6 |
| T-AC6-migration-ENOENT | No (forces error path) | ✓ behavioral on rare path | ✓ | ✓ FM table |
| T-AC7-test-sh-green | Could pass if other categories never ran — but all 8 must pass | ✓ end-to-end | ✓ | ✓ AC7 |
| T-AC8-epistemic-smoke-green | No | ✓ | ✓ | ✓ AC8 |
| T-AC9-set-e-absent | No (grep is precise) | ✓ convention | ✓ | ✓ AC9 |
| T-AC10-timing-budget | Manual; informational | ✓ timing | depends on hardware — that's why manual | ✓ AC10 |
| T-AC11-stdin-fallback | No (deletes marker) | ✓ | ✓ | ✓ AC11 |
| T-AC11-both-missing | No | ✓ fail-open | ✓ | ✓ AC11 + FM table |
| T-PC1-single-session-pairing | No | ✓ end-state | ✓ | ✓ Preservation |
| T-PC2-fail-open-on-error | No (multiple error paths) | ✓ | ✓ | ✓ Preservation |
| T-PC4-calibration-block-shape | Could pass if prompt is hard-coded — that's fine, it should be | ✓ UX invariant | ✓ | ✓ Preservation |
| T-PC5-json-schema-stable | No | ✓ schema-level | ✓ | ✓ Preservation |
| T-PC6-disable-toggle | No | ✓ | ✓ | ✓ Preservation |
| T-FM1-malformed-stdin | No (asserts NO marker) | ✓ | ✓ | ✓ FM table + CF-7 |
| T-FM2-traversal-exhaust | No | ✓ | ✓ | ✓ FM table |
| T-FM3-no-proc-warning | Indirect — runtime simulation | ✓ | ✓ | ✓ FM table NEW-3 |
| T-FM4-mkdir-fail | No | ✓ | ✓ | ✓ FM table |
| T-FM5-helper-missing | No | ✓ | ✓ | ✓ FM table + CF-10 |
| T-FM7-source-branching | No (4 distinct sources, 4 distinct outcomes) | ✓ | ✓ | ✓ FM table + CF-5 |
| T-FM7-no-double-preflight | No | ✓ | ✓ | ✓ FM table NEW-2 |
| T-FM7-resume-preserves-STARTED | No | ✓ | ✓ | ✓ E3 |
| T-FM10-traversal-terminates-at-1 | No | ✓ | ✓ | ✓ FM table + E9 |
| T-E1-status-not-stat | No (requires comm with spaces) | ✓ | ✓ | ✓ E1 |
| T-E2-same-fs-tmpfile | Static check OK if observable | ✓ | ✓ | ✓ E2 |
| T-E5-quoted-paths | No | ✓ | ✓ | ✓ E5 |
| T-E6-uuid-validation | No (rejects bad input) | ✓ | ✓ | ✓ E6 |

**Red flag scan:**
- No test mocks the entire stack (each is filesystem- or grep-rooted in observable state).
- No test asserts internal function calls (we don't check whether `epistemic_claude_main_pid` was *called* — only that traversal *result* matches expectation).
- T-AC4 grep tests are tautology-leaning: they check that helper function names appear in consumers. This is intentional — AC4 explicitly says "all consumers use helper" as an architectural invariant. Without this, the per-PID isolation could be bypassed by a stale consumer reading the directory directly.
- T-PC4 (UX shape) is byte-for-byte and would break on legitimate UX changes. That's accepted: the spec promises shape preservation.

---

## Test Mapping to Eval Fixtures

The evals.json fixtures specified in WU8–WU11 cover the TESTED criteria:

| WU | Eval Fixture | Tests Implemented |
|----|--------------|-------------------|
| WU8 | parallel-isolation | T-AC1-parallel-markers, T-AC1-no-clobber, T-AC2-postflight-attribution |
| WU9 | resume-pairing (proxy) | T-AC3-resume-pairing eval portion |
| WU10 | orphan-sweep | T-AC5-fake-pid-orphan, T-AC5-pid-reuse-defense |
| WU11 | migration | T-AC6-legacy-rename, T-AC6-migration-ENOENT |

Static checks (T-AC4, T-AC9) live in `test.sh` extensions per WU12.

Manual checks (T-AC3 authoritative, T-AC10) belong in the debrief verification log.

---

## Implementation Notes

These tests:
1. **Will fail initially** — `scripts/epistemic-marker.sh` doesn't exist yet, hooks still write single-file markers.
2. **Should pass without test modification** when WU1–WU12 ship correctly.
3. **If a test needs changing during impl** — that's the signal to revisit spec, not the test. Most likely: a Failure Mode wording inaccuracy (precedent: E8 was a similar correction).

**Dogfood note**: T-PC1 must be re-verified after this session via `/end` — that's the live check that the new pairing logic works on a real session. If `/end` fails to pair this session correctly, we have a bug regardless of what evals say.
