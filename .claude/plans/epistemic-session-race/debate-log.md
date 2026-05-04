## Orient Phase

### Intent

Replace the single-file `~/.claude/.current-session` global state with a per-PPID directory scheme (`~/.claude/.current-session/<pid>`), using Claude Code's own `session_id` (sourced from SessionStart stdin JSON) as the stored value, and routing all 13+ consumers through a shared `scripts/epistemic-marker.sh` helper — eliminating cross-session clobber that has caused 3 confirmed data-corruption incidents on 2026-05-01. The design relies on `$PPID` (the Claude main process PID) as the discovery key, with orphan sweep at SessionStart via `/proc` PID-existence check.

### Constraints

- Fail-open: hooks must exit 0 on any error path; helper file must not use `set -e`
- SessionStart timing budget: sweep must keep total hook time under 2.0s (current: 1.5s for calibration load)
- No new dependencies: pure bash + jq (both already required)
- `epistemic.json` schema: no new top-level fields; writes preserve `sessions`, `paired`, `deltas` structure
- Stdin is consumed once: only `epistemic-preflight.sh` may read stdin; downstream consumers must use the marker file
- Backward-compat single-session path: preflight → postflight pairing must be invisible to the dominant single-session case

### Scope Boundaries

- In: `epistemic-preflight.sh`, `epistemic-postflight.sh`, `_audit-log.sh`, 6 command bash blocks, 6 prose-reference commands, `scripts/epistemic-marker.sh` (new), smoke test update, 4 behavioral evals, legacy-file migration
- Out: subagent PPID compatibility (out-of-scope by explicit spec decision), `epistemic.json` schema changes, backward-compat shim for old marker path, macOS/BSD verification

### Historical Context

**Finding 1 (2026-05-01-current-session-marker-single-file-race.md):** Original architectural diagnosis. Identified that `epistemic-preflight.sh:48-53` unconditionally overwrites on every SessionStart. Noted "non-blocking severity" at the time; parallel-session usage was rare. Correctly predicted the fix shape: `epistemic-preflight.sh`, `epistemic-postflight.sh`, `_audit-log.sh`.

**Finding 2 (2026-05-01-current-session-marker-race-confirmed-incident.md):** Empirical confirmation during `test-debt-in-prism` session. The corrupted `slims-device-updater` postflight overwrote the correct slot; recovery required a `recovery-` prefixed session ID. Key lesson: corruption is silent — only caught by noticing unexpected `task_summary` content. Recovery procedure documented.

**Decision (2026-03-19-build-native-epistemic-tracking.md):** Establishes why native tracking exists at all — to replace the failed Empirica MCP with direct DB writes and hook-triggered fail-open semantics. This decision constrains the fix: the tracking system is intentionally simple by design; the fix must stay in that lane.

**Pattern (silent-failure-as-operational-risk.md):** From an unrelated project (S4 Scout) but directly applicable: corruption under the old scheme produced no error — calibration deltas were silently wrong. The fix's `uuidgen` fallback and inline fallback in consumers could fall into the same trap if failures are swallowed without any diagnostic signal.

No additional vault context beyond the known findings and the two adjacent files above.

### Unvalidated Assumptions

- **Sweep-on-SessionStart is safe for the concurrent-session case**: The spec places orphan sweep BEFORE writing the own marker. But if two sessions start near-simultaneously, session A's sweep could remove session B's freshly-written-but-not-yet-confirmed marker (if B's PID happened to match an orphan check timing window). The spec asserts "each writes own PPID-keyed file; no contention" — but this is only true if the `mkdir -p` + write is atomic with respect to another session's sweep. A sweep that checks `/proc/<pid>` and removes a file for a PID that IS still alive (B just wrote it) would require a race between sweep and B's write, not between two sweeps. This is extremely tight, but not proven safe under adversarial timing.

- **`$PPID` reliably equals the Claude main process PID across all invocation paths**: Confirmed on WSL2 + bash for the interactive case. NOT tested for `claude --print` (non-interactive), `claude --resume`, hook re-fire after compaction, or multi-hop subshell paths. The spec notes the probe confirmed `claude --print` cleanup works, but the PPID identity check in that path is not explicitly documented.

- **`source: "resume"` in stdin JSON reliably signals a session continuation**: Spec uses this to re-create the marker without changing `session_id`. If Claude Code changes the resume signal (or a version delivers `source: "clear"` after compaction instead), the spec's resume handling would silently create a NEW marker for an existing session, potentially orphaning the original preflight.

- **No external consumers of `~/.claude/.current-session`**: Spec asserts this; the out-of-scope note says "no external consumers." But user-authored scripts, other plugins, or the Obsidian vault-notes hooks could read this path. The assertion is unverified beyond the claude-sail codebase itself.

- **`evals.json` behavioral eval can accurately simulate parallel preflight isolation**: OQ4 notes the eval cannot actually launch two `claude` processes. The simulation approach (bash -c subshells with controlled PPID) tests the helper functions but not the actual hook-level stdin-consumption behavior. The AC it covers (AC1, AC2) may therefore verify shell logic without verifying the end-to-end hook firing sequence.

### Known Risks

- **Sweep window could remove a live marker for a concurrently-starting session** (category: technical): if sweep checks `/proc/<pid>` just before another session's `mkdir -p` + write completes, and the PID is momentarily unresolvable, the new session's marker is wiped before postflight can read it. Extremely narrow window, but the spec does not address it.
- **Silent fallback degrades without observable signal to the user** (category: operational): the `uuidgen` fallback on stdin-parse failure and the inline consumer fallback both exit 0 with a stderr warning. In a single-user, single-window environment, these warnings are swallowed — the operator has no dashboard to notice the degradation. Per the vault pattern, "no error" is not a guarantee of correct behavior.

## Diverge Phase

### Coherence

```
FINDING-H1:
  Summary: OQ1 (sweep ownership) listed as an open question but already decided in spec body
  Sections: Open Questions (OQ1) vs Files/Components Touched, WU2, Failure Modes
  Contradiction: OQ1 states "Decision can flip based on Stage 3 (challenge) findings" — marking it as
    genuinely open. But three other sections commit it to SessionStart: Files/Components Touched says
    epistemic-preflight.sh "sweep stale PIDs on entry"; WU2 says "run orphan sweep before write";
    Failure Modes describes "Sweep on next SessionStart removes orphan." The spec has already decided
    and implemented OQ1 in its body while declaring it open in the OQ section. A reader following OQ1
    as a decision point would be misled — any challenge finding that recommends SessionEnd would
    surface a decision already baked into 3 WU-level commitments.
  Resolution: OQ1 section should yield. Close OQ1 as "decided: SessionStart" and record the rationale
    (synchronous gate, sweep-before-write ordering). Remove the "Decision can flip" hedge.
  Severity: critical
  Confidence: 0.97
  False-known: yes — spec claims OQ1 is open while its body has already resolved it
  Adjacent-risks: A Stage 3 challenger could spend effort arguing for SessionEnd placement, unaware
    it's already locked in WU2 scope.
```

```
FINDING-H2:
  Summary: Q2 resolution sidesteps the original question; postflight PPID match unvalidated
  Sections: Dependencies (Q2 resolved) vs describe.md Q2 definition
  Contradiction: describe.md Q2 asks "Verify postflight's process ancestry matches preflight's" — an
    empirical identity question about whether postflight's $PPID equals preflight's $PPID. The spec
    resolves Q2 as "postflight gets session_id via marker (helper) OR stdin (fallback)" — which is a
    workaround, not an answer. If postflight's $PPID differs from preflight's (different hook
    subprocess spawned by Claude at SessionEnd), the marker lookup by $PPID fails silently and stdin
    fallback activates. The scoped `rm -f` then deletes the marker at the wrong PPID path, potentially
    leaving the preflight's marker as a permanent orphan. The empirical findings confirm claude --print
    SessionEnd cleanup works, but do not explicitly confirm $PPID identity across hook firings.
  Resolution: Q2 resolution should be expanded. Either: (a) add empirical evidence that postflight
    $PPID == preflight $PPID (a probe log showing both hooks' $PPID values), or (b) redesign the
    scoped rm -f to use the session_id from stdin/marker to locate the marker file (content-addressed
    delete), making PPID identity irrelevant.
  Severity: high
  Confidence: 0.88
  False-known: yes — spec claims Q2 is resolved but the empirical question in describe.md is unanswered
  Adjacent-risks: If PPID differs across hook firings, the postflight rm -f deletes nothing and
    orphan markers accumulate — the sweep at next SessionStart would catch them, but the pairing
    logic might read a stale marker.
```

```
FINDING-H3:
  Summary: AC4 claims "13 readers" but Work Units scope accounts for only 9 files
  Sections: Success Criteria (AC4) vs Work Units (WU2-WU5) file list
  Contradiction: AC4 states "All 13 readers resolve via helper" and specifies a grep returning
    >= "number of touched files." The Work Units that introduce helper calls are: WU2
    (epistemic-preflight.sh), WU3 (epistemic-postflight.sh), WU4 (_audit-log.sh), WU5 (6 command
    .md files) = 9 files. The 6 _audit-log.sh consumers (secret-scanner, anti-pattern-write-check,
    tdd-guardian, freeze-guard, protect-claude-md, dangerous-commands) are NOT listed in any WU as
    files to modify — they read session_id through _audit-log.sh, not directly from the helper.
    Adding scripts/epistemic-smoke-test.sh (WU7) and scripts/behavioral-smoke.sh (WU8) reaches 11.
    No combination of in-scope files reaches 13. The "13+" phrasing in the Orient Phase suggests
    the number was estimated, not counted.
  Resolution: AC4 should yield. Replace "13 readers" with the actual count from the WU file list
    (9 files directly modified to call the helper). If the 6 audit-log consumers are meant to be
    counted because they transitively use the helper through audit-log, state that explicitly and
    verify the grep command captures it.
  Severity: high
  Confidence: 0.91
  False-known: yes — AC4 asserts a specific number that is not grounded in the WU scope
  Adjacent-risks: The AC4 grep would trivially pass (9 files is < 13) yet the criterion would
    report failure, causing a false negative at acceptance testing.
```

```
FINDING-H4:
  Summary: AC4 grep command is technically invalid — grep -c on directories without -r flag errors
  Sections: Success Criteria (AC4) — self-contained
  Contradiction: AC4 specifies `grep -c "epistemic_get_session_id\|epistemic_marker_path" hooks/
    commands/ scripts/` — but grep -c on a directory argument without -r (recursive) outputs an
    error "Is a directory" and exits non-zero on most shells, not a line count. The second grep
    (`grep -c "/.current-session\b"`) has the same flaw. As written, neither command is executable
    as a valid static check. The correct command would use grep -rl ... | wc -l (file count) or
    grep -rn ... | wc -l (occurrence count).
  Resolution: AC4 should yield. Replace both grep commands with valid shell one-liners. Example for
    file count: `grep -rl "epistemic_get_session_id\|epistemic_marker_path" hooks/ commands/ scripts/
    | wc -l`. Specify whether the threshold is file count or occurrence count.
  Severity: medium
  Confidence: 0.95
  False-known: no — the spec does not claim the command works, it's just underspecified
  Adjacent-risks: An implementer running AC4 as written discovers it errors and either fixes it
    on the fly (inconsistency with spec) or marks it failing.
```

```
FINDING-H5:
  Summary: WU9 depends only on WU2 but AC3 requires postflight pairing — WU3 is a missing dependency
  Sections: Work Units (WU9 depends_on) vs Success Criteria (AC3)
  Contradiction: AC3 says "postflight pairs correctly with original preflight" — AC3 explicitly
    involves postflight behavior. WU9 ("Add behavioral eval fixture: resume preserves session_id")
    lists depends_on: [WU2] only. But to verify AC3's pairing claim, the postflight hook (WU3) must
    also be complete — the eval cannot test pairing without a functioning postflight. In batch 2,
    WU9 runs after batch 1 which includes WU3, so execution order happens to be correct. But the
    declared dependency is wrong: WU9 should declare WU3 as a dependency, matching WU8 which lists
    both WU2 and WU3.
  Resolution: WU9 depends_on should yield. Add WU3 to WU9's dependency list: depends_on: [WU2, WU3].
    This doesn't change batch ordering (both are already in batch 1), but makes the dependency
    semantics correct for work-graph validation.
  Severity: medium
  Confidence: 0.90
  False-known: no — execution order is incidentally correct, the dependency declaration is wrong
  Adjacent-risks: If a future executor runs WU9 after WU2 but before WU3 (e.g., parallelizing
    batch 1 differently), the eval would exercise an incomplete postflight.
```

```
FINDING-H6:
  Summary: Failure Mode FM4 requires inline fallbacks in all hook/command files but WU5 doesn't specify them
  Sections: Failure Modes (FM4) vs Work Units (WU5)
  Contradiction: FM4 states "Each hook/command has inline fallback that does the same lookup; warns
    to stderr but continues." This is a requirement for all 9 files that source the helper (3 hooks
    + 6 command bash blocks). WU5's description only says "Refactor command bash blocks to source
    helper and use epistemic_get_session_id" — no mention of implementing an inline fallback in each
    of the 6 command files. WU2 and WU3 descriptions similarly don't mention inline fallbacks. The
    Failure Modes section creates a requirement that no Work Unit captures.
  Resolution: WU2, WU3, and WU5 should yield — each should add "implement inline fallback if source
    fails" to their description. Alternatively, WU1 (the helper itself) could implement a no-op
    graceful degradation path that is sourced as a single unit, eliminating the need for per-file
    inline fallbacks — then FM4 should be updated to describe this alternative.
  Severity: high
  Confidence: 0.92
  False-known: no — FM4 states a requirement, WU5 simply doesn't implement it
  Adjacent-risks: Missing inline fallbacks mean that on systems where epistemic-marker.sh is not
    installed (e.g., after a partial install), command bash blocks fail silently rather than
    degrading gracefully as FM4 promises.
```

```
FINDING-H7:
  Summary: Scope drift — describe.md places orphan cleanup at SessionEnd; spec places it at SessionStart
  Sections: describe.md In Scope vs spec.md Files/Components Touched, WU2
  Contradiction: describe.md In Scope says "Orphan cleanup of stale markers (likely SessionEnd or
    session-end-cleanup.sh)." The spec instead places sweep in epistemic-preflight.sh (SessionStart)
    via WU2, and does not modify session-end-cleanup.sh at all. The spec body acknowledges this was
    a tentative choice (OQ1), but never explicitly closes the gap with describe.md. OQ1's "Tentative
    answer: SessionStart" implicitly overrides describe.md's "likely SessionEnd" — but only implicitly.
  Resolution: OQ1 section (and describe.md if amended) should explicitly record this decision as a
    deliberate override of the describe-stage assumption: "Orphan cleanup moved from tentative
    SessionEnd placement to SessionStart — rationale: sweep-before-write ordering is required for
    correct isolation." This is a low-stakes correction but closes a traceability gap.
  Severity: medium
  Confidence: 0.85
  False-known: no — both documents state tentative/likely, not certain
  Adjacent-risks: None material; execution is correct. Traceability gap only.
```

```
FINDING-H8:
  Summary: AC9 references "Stage 6 spec-blind tests" but Stage 6 in the pipeline is the review stage
  Sections: Success Criteria (AC9) vs state.json stage sequence
  Contradiction: The blueprint stage sequence is: describe(1), specify(2), challenge(3),
    edge_cases(4), premortem(5), review(6), test(7), execute(8), debrief(9). AC9 says "Stage 6
    spec-blind tests check that hooks still use set +e." But Stage 6 = review, not test. The test
    stage is Stage 7. This is also internally inconsistent with AC10 which says "Manual verification
    (Stage 7)" — Stage 7 = test, which is where behavioral tests run. If spec-blind tests belong
    in Stage 7, AC9 should say Stage 7. If spec-blind tests are meant to run in the review stage
    (Stage 6), that is unusual and should be explicitly justified.
  Resolution: AC9 should yield. Either: (a) change "Stage 6" to "Stage 7" to match where test
    activities occur, consistent with AC10's Stage 7 reference; or (b) clarify that the set +e
    check is covered by the existing test.sh Category 5 (already runs in test.sh) and remove the
    stage reference entirely as redundant.
  Severity: low
  Confidence: 0.82
  False-known: no — this is ambiguous, not a false claim of consistency
  Adjacent-risks: A test executor running Stage 6 (review) would be confused about whether
    spec-blind hook tests are part of their mandate.
```

```
FINDING-H9:
  Summary: AC4 second grep requires exclusion logic that is unspecified
  Sections: Success Criteria (AC4) — self-contained
  Contradiction: AC4's second check says `grep -c "/.current-session\b"` (excluding directory
    references and migration code) returns 0. But the exclusion is stated as a parenthetical, not
    as a grep flag or pipeline stage. Migration code in epistemic-preflight.sh (WU2) will
    legitimately reference `~/.claude/.current-session` to detect the legacy file and rename it.
    Any naive grep of the codebase will hit this reference and fail the zero-count assertion.
    The spec does not provide the grep flags, exclusion pattern, or pipeline to implement the
    exclusion — leaving it to the implementer to guess.
  Resolution: AC4 should yield. Provide a concrete grep command that implements the exclusion,
    e.g.: `grep -rn "/.current-session\b" hooks/ commands/ scripts/ | grep -v "legacy\|migration\|
    \.legacy\|directory" | wc -l` should equal 0. Or better: document the specific file+line
    exceptions rather than a regex exclusion.
  Severity: medium
  Confidence: 0.88
  False-known: no — the spec acknowledges the exclusion exists, just doesn't specify it
  Adjacent-risks: An implementer who misses the exclusion will see false positives and either
    (a) incorrectly remove migration code or (b) mark AC4 as failing when it should pass.
```

```
FINDING-H10:
  Summary: describe.md success criterion counts "7 hooks" but its own list totals 9
  Sections: describe.md Success Criteria — self-contained
  Contradiction: describe.md success criteria says "All 7 hooks that read the marker (preflight,
    postflight, audit-log + 6 audit-log consumers) resolve to the correct per-session ID." But
    1 (preflight) + 1 (postflight) + 1 (audit-log) + 6 (consumers) = 9, not 7. The parenthetical
    enumeration contradicts the "7" count in the same sentence. (This is in describe.md, not the
    spec, so its impact is limited to traceability — spec.md independently lists "13+" readers.)
  Resolution: describe.md should yield. Correct "7 hooks" to "9 hooks" or recount by removing
    audit-log consumers (since they read via audit-log, not directly). Either way, the number
    should match the enumeration that follows it.
  Severity: low
  Confidence: 0.95
  False-known: yes — sentence claims internal consistency between "7" and the parenthetical list
    that enumerates 9
  Adjacent-risks: None material to implementation. Describe.md is superseded by spec.md for
    execution purposes.
```

### Completeness

```
FINDING-M1:
  Summary: epistemic-preflight.md command has an in-place fallback that creates a SINGLE-FILE marker — this silently breaks after the directory migration
  Section: Work Units (WU5), Files/Components Touched
  Gap: The /epistemic-preflight command's "Step 1: Read Session Context" includes a fallback bash
    block that creates a session marker if none exists:
      printf "SESSION_ID=%s\nPROJECT=%s\nSTARTED=%s\n" "$SESSION_ID" "$PROJECT" "$NOW" > ~/.claude/.current-session
    After the migration, ~/.claude/.current-session is a DIRECTORY. Writing a file to a directory
    path fails with "Is a directory" — but 2>/dev/null is absent here. The fallback also generates
    a uuidgen-style SESSION_ID (not Claude Code's UUID), producing a key that won't match any
    existing marker under the per-PPID scheme. WU5 says "bash block reads marker via helper" but
    does not specify that the fallback CREATE path must be rewritten to write into the per-PPID
    directory using the helper's epistemic_marker_path function.
  Impact: Any session that triggers the "no marker exists" fallback in /epistemic-preflight will
    silently fail to create a marker, and subsequent /epistemic-postflight will report
    "SESSION_ID is empty — refusing to write postflight" — epistemic pairing silently breaks for
    those sessions.
  Severity: critical
  Confidence: 0.93
  False-known: no — WU5 mentions "reads marker via helper" but the create-fallback path is distinct
    from the read path and is not addressed
  Adjacent-risks: The same create-fallback exists in epistemic-preflight.sh (WU2 scope) — if the
    hook's stdin parse fails AND uuidgen fallback fires, the marker write path must also use the
    per-PPID directory scheme. WU2 likely covers this, but the command-level fallback is not WU2.
```

```
FINDING-M2:
  Summary: end.md budget-logging bash block uses a grep pattern that silently returns empty for UUIDv4 session IDs
  Section: Work Units (WU5), Files/Components Touched
  Gap: end.md line 284 reads:
      SESSION_ID=$(cat ~/.claude/.current-session 2>/dev/null | grep -o 'session-[^ ]*' | head -1 || echo "unknown")
    After the fix, two things break independently:
    (1) cat on a directory path outputs nothing (error is suppressed by 2>/dev/null), so the pipe
        gets empty input regardless of file existence.
    (2) The grep pattern 'session-[^ ]*' matches only the OLD timestamp-based session ID format
        (session-YYYYMMDD-HHMMSS-PID). Claude Code's UUID-format session IDs (e.g.
        "16293da5-cb8a-4ecf-b260-49679e10e1a9") will NEVER match this pattern. Even if the cat
        were fixed to use the helper, the grep would return empty, setting SESSION_ID="unknown".
    WU5 lists end.md as "bash block reads marker via helper" but this specific grep-based
    extraction pattern in the budget section is a separate bash block that needs an independent fix.
  Impact: budget.jsonl entries will always record session_id="unknown" after the migration, making
    budget data useless for cross-session correlation. This is fail-soft (data quality, not
    session continuity) but it is a permanent silent degradation, not a transient one.
  Severity: high
  Confidence: 0.97
  False-known: no — the grep pattern incompatibility with UUIDs is independently verifiable;
    the spec does not claim this is handled
  Adjacent-risks: Other places in end.md that derive session_id (lines 20, 141, 235) use different
    extraction patterns; not all may be updated consistently by WU5.
```

```
FINDING-M3:
  Summary: WU5 scope is silent on how collect-insights.md and vault-curate.md should detect an active session after .current-session becomes a directory
  Section: Work Units (WU5), Failure Modes
  Gap: collect-insights.md (line 28) and vault-curate.md (line 123) both test:
      if [ -f "$HOME/.claude/.current-session" ]; then
    After migration, ~/.claude/.current-session is a DIRECTORY. The -f test (regular file) returns
    false for a directory. These bash blocks will therefore always report "NO_SESSION" even when a
    session is active, silently skipping session-linked writes. WU5 says "source helper and use
    epistemic_get_session_id" — the helper call would find the session correctly, but the -f gate
    before it prevents reaching the helper. The spec does not define what the correct existence
    check should be post-migration: -d (directory exists), -e (anything exists), or calling
    epistemic_get_session_id and checking for non-empty output.
  Impact: collect-insights session-ID attribution will always be absent. Vault curate's epistemic
    calibration integration block (Stage 1.6) will always be skipped. Silent regressions in two
    commands' core behavior.
  Severity: high
  Confidence: 0.96
  False-known: no — the -f breakage is a direct consequence of the migration; the spec doesn't
    address what the guard test becomes
  Adjacent-risks: start.md line 32 also has a prose condition "if .current-session exists" followed
    by a cat bash block — after migration, the cat silently returns empty, so /start will incorrectly
    report "no active session" even when one is running.
```

```
FINDING-M4:
  Summary: epistemic-postflight.md Step 6 cleanup does rm -f on the directory path — this is a no-op after migration, leaking the per-PPID marker indefinitely
  Section: Work Units (WU5), Preservation Contract
  Gap: epistemic-postflight.md Step 6 contains:
      rm -f ~/.claude/.current-session 2>/dev/null
    After migration, ~/.claude/.current-session is a directory. rm -f on a directory without -r
    silently fails (error suppressed). The per-PPID marker file inside the directory
    (~/.claude/.current-session/$PPID) is NOT deleted. The spec's WU5 description says "bash block
    reads marker via helper, scoped delete" — but the MECHANISM for "scoped delete" in the command
    is not specified. The spec correctly addresses scoped delete in the HOOK (WU3: "scope `rm -f` to
    own PPID marker only"), but the command bash block has the same problem and the spec's description
    for WU5 is too vague to catch it.
  Impact: After /epistemic-postflight runs, the per-PPID marker is not cleaned up. The next
    SessionStart's orphan sweep will eventually remove it, but only if /proc/$PPID no longer exists
    at that point. If the same user starts a new session with the same PPID (PID reuse), the sweep
    won't clean it (the process exists), and the stale marker with old session_id persists as a
    ghost that the postflight hook picks up instead of the correct new marker.
  Severity: high
  Confidence: 0.94
  False-known: no — WU5 says "scoped delete" without specifying that it must use the per-PPID path;
    a naive implementer replacing rm -f on the directory would still break cleanup
  Adjacent-risks: The scoped-delete PPID lookup in command bash blocks requires knowing $PPID at
    command execution time. If the Bash tool's $PPID differs from the hook's $PPID (see FINDING-M5),
    the scoped delete deletes the wrong file.
```

```
FINDING-M5:
  Summary: The probe confirms hook $PPID comm = "sh" (intermediate), not "claude" — the PPID consistency between hook writes and Bash tool reads is asserted but not proven
  Section: Dependencies (Preconditions), empirical_findings, Failure Modes
  Gap: The probe-sessionstart-stdin.log shows: PID=3180050, PPID=3180048, PPID comm: "sh". This
    means in the hook's execution context, $PPID = the sh intermediate PID, not the claude main
    process PID. The empirical_findings state "Bash tool $PPID = claude main process PID" — meaning
    in Bash tool context, $PPID = claude main. If hook $PPID = sh and Bash tool $PPID = claude,
    these are different values, and the marker written by the hook (keyed by sh PID) is not
    findable by the Bash tool command (looking up claude PID). The spec's core assumption is that
    $PPID is consistent across all invocation paths within a session, but the probe data leaves an
    unresolved gap: is the "sh" parent the SAME process that is also the parent of Bash tool
    invocations in the same session? This depends on whether Claude Code reuses the same sh process
    across all tool invocations (consistent) or spawns fresh sh processes (inconsistent).
  Impact: If PPID is inconsistent across hook and Bash tool paths, all command bash blocks that
    call epistemic_get_session_id will fail to find the marker written by the hook, returning empty
    session_id and silently skipping all epistemic writes. This would be undetectable without
    explicit logging — a silent regression in the dominant use case (single interactive session).
  Severity: high
  Confidence: 0.72
  False-known: yes — state.json claims "CONFIRMED" for PPID = claude main, but the probe log shows
    PPID comm = "sh" for the hook path; the two empirical results are not explicitly reconciled
  Adjacent-risks: Session-end-cleanup.sh (the "established PPID convention") uses PPID in a
    hook-to-hook pattern (preflight write, postflight read) — this would be consistent even if PPID
    = sh, because both hooks see the same sh parent. The problematic case is hook→Bash-tool lookup.
```

```
FINDING-M6:
  Summary: PPID=1 edge case has no fallback in the new marker scheme — concurrent sessions on PPID=1 systems would all collide on the same marker key
  Section: Database/State Changes, Failure Modes
  Gap: session-end-cleanup.sh (the "established PPID convention" cited by the spec at line 101)
    explicitly handles PPID=1:
      if [ "$PPID" -eq 1 ]; then
          SIG_SUFFIX="$USER-$(pwd | md5sum | cut -c1-8)"
      else
          SIG_SUFFIX="$PPID"
      fi
    The new epistemic-marker.sh helper has no corresponding PPID=1 fallback. On systems where Claude
    Code hooks run as direct children of init/PID 1 (some Docker environments, systemd-based
    launchers), all sessions would key their marker to "1", recreating the original single-file
    clobber problem. The failure mode is silent — the hook writes successfully to
    ~/.claude/.current-session/1 and each new session clobbers the prior one's entry.
  Impact: On PPID=1 systems, the fix provides no isolation benefit. The clobber bug is fully
    reproduced. Since the target environment (Nick's WSL2) is not PPID=1, this would not be caught
    by local testing.
  Severity: medium
  Confidence: 0.85
  False-known: no — the spec doesn't mention PPID=1 and doesn't cite the session-end-cleanup.sh
    fallback handling as a pattern to replicate
  Adjacent-risks: The orphan sweep on PPID=1 systems: the marker at key "1" is never swept (process
    1 always exists in /proc), so stale markers from crashed sessions accumulate permanently.
```

```
FINDING-M7:
  Summary: Concurrent legacy-file migration has an unhandled ENOENT path when two sessions race to rename the same file
  Section: Database/State Changes (Migration), Failure Modes
  Gap: The migration step performs: rename .current-session → .current-session.legacy-${TS}, then
    mkdir -p .current-session/. If two sessions start simultaneously and both detect the legacy
    file, one session's rename succeeds; the other gets ENOENT (file no longer exists). The spec
    does not specify what session B should do when its rename fails: does it treat ENOENT as
    "migration already done by session A, proceed to mkdir" (correct) or does it treat the rename
    failure as an error and abort (incorrect)? The spec says "single rename + mkdir; no data lost"
    which describes the happy path only. Under concurrent startup (the exact scenario this fix
    addresses), the migration itself is not race-safe without explicit ENOENT handling.
  Impact: On systems where two claude sessions start within milliseconds on first install after
    upgrade, one session may fail to write its marker if the migration ENOENT is treated as an
    error — leaving that session untracked. The failure is session-specific (session B), not
    systemic. Given fail-open semantics, the session continues; only epistemic tracking is lost.
  Severity: medium
  Confidence: 0.82
  False-known: no — the spec describes single-session migration only
  Adjacent-risks: The rollback plan says "no action needed" after reverting hooks, implying the
    reverted hook can write to .current-session as a file. But after migration, .current-session
    is a DIRECTORY — the reverted hook's write silently fails. Rollback step 2 is misleading:
    manual cleanup of the directory IS needed before the reverted hook works correctly.
```

```
FINDING-M8:
  Summary: scripts/epistemic-marker.sh is not covered by test.sh syntax check (Category 1) or shellcheck (Category 2) — WU12 only mentions Category 7
  Section: Work Units (WU12), Success Criteria (AC7)
  Gap: test.sh Category 1 (shell syntax) runs bash -n only on hooks/*.sh, install.sh, and
    scripts/behavioral-smoke.sh. Category 2 (shellcheck) covers hooks/*.sh and install.sh. The new
    scripts/epistemic-marker.sh helper is in scripts/ but is NOT covered by either category. WU12
    says "Verify install.sh includes scripts/epistemic-marker.sh (tarball auto-extract — extend
    test.sh Category 7 if needed)" — Category 7 is the install dry-run, which confirms the file
    lands in the right place, not that its syntax is valid. A syntax error in epistemic-marker.sh
    would pass AC7 ("bash test.sh exits 0") because test.sh never runs bash -n on it.
  Impact: A syntactically broken helper would pass the full test suite, then fail silently at
    runtime (source returns non-zero, inline fallbacks activate, silent degradation). The test
    suite would give false confidence in the implementation.
  Severity: medium
  Confidence: 0.98
  False-known: yes — AC7 claims "existing test suite passes" implies complete coverage, but
    test.sh has a structural gap for scripts/ files other than behavioral-smoke.sh
  Adjacent-risks: shellcheck is also absent for the new helper, which could miss hook-convention
    violations (e.g., an accidental set -e sourced into a hook).
```

```
FINDING-M9:
  Summary: source="clear" (post-compaction SessionStart) is not handled — compaction breaks the resume path and creates a duplicate marker
  Section: Failure Modes, Database/State Changes
  Gap: The spec handles source="startup" (new session) and source="resume" (claude --resume). The
    probe captured source="startup". Claude Code may also fire SessionStart with source="clear"
    after a /compact operation (context window compaction). The spec never mentions source="clear"
    and provides no handling. Under the current design:
    - source="startup" → write new marker, overwriting any existing marker for this PPID
    - source="resume" → re-create marker preserving original session_id
    - source="clear" (unhandled) → falls through to startup branch → writes NEW session_id to
      marker, orphaning the original preflight from before compaction
    This means any session that uses /compact loses its preflight pairing. The postflight vectors
    will land in a different session entry than the preflight, silently splitting the calibration
    data. The Orient Phase debate-log notes this risk but the spec does not address it.
  Impact: Every user who runs /compact mid-session loses epistemic pairing for that session. Given
    that compaction is a normal workflow for long sessions (the exact sessions where calibration
    data is most valuable), this is a likely-to-trigger regression in the primary use case.
  Severity: high
  Confidence: 0.75
  False-known: no — the spec omits source="clear" without claiming it's handled; confidence
    below 0.9 because source="clear" vs. source="resume" for compaction is unconfirmed empirically
  Adjacent-risks: If source="clear" is treated the same as source="resume" (preserve session_id),
    the sweep behavior also needs adjustment — a sweep that removes the old marker before the
    "clear" write sees an already-correct marker (same PID, same session_id) and should be
    idempotent. The spec's sweep-before-write order for "resume" is correct, but "clear" may have
    different timing relative to the original marker's state.
```

```
FINDING-M10:
  Summary: The rollback plan incorrectly states "no action needed" for restoring marker writes — the reverted hook silently fails while the directory exists
  Section: Rollback Plan (Step 2)
  Gap: Rollback Step 2 says "Restore single-file marker on existing systems: no action needed —
    epistemic-preflight.sh rewrite restores original write-to-~/.claude/.current-session-file
    behavior." This is incorrect. After migration, ~/.claude/.current-session is a DIRECTORY. The
    reverted hook tries to write:
      echo "SESSION_ID=..." > ~/.current-session
    This is a redirect to a directory path — it fails with "Is a directory" but the error is
    suppressed by 2>/dev/null. The reverted hook then checks:
      if [ ! -f "$CURRENT_SESSION" ]; then
          echo "WARNING: .current-session write failed" >&2
    The -f test fails (it's a directory, not a file), and the warning fires to stderr. But the
    hook still exits 0 (fail-open), meaning the session starts with no marker — epistemic
    tracking silently breaks until the user manually runs `rm -rf ~/.claude/.current-session/`.
    Step 3 says `rm -rf` cleanup is "optional" — but it is REQUIRED for the reverted hook to work.
  Impact: After rollback, any user who does not run the cleanup command has silently broken
    epistemic tracking with no diagnostic beyond a stderr warning that may be missed. The rollback
    plan's "no action needed" gives false confidence that revert is sufficient.
  Severity: medium
  Confidence: 0.97
  False-known: yes — Step 2 explicitly claims no action is needed, but the reverted hook
    silently fails until the directory is removed
  Adjacent-risks: The rollback plan's testability claim ("bash test.sh should pass against reverted
    state") is also incorrect if ~/.claude/.current-session is a directory — the smoke test's -f
    check would fail, surfacing the issue, but test.sh runs against the repo not a live ~/.claude/.
```

### Correctness

```
FINDING-C1:
  Summary: Hook $PPID is sh-intermediate, not claude main — the "confirmed" PPID claim conflates two different invocation contexts
  Section: Dependencies ("PPID-as-Claude-main-PID confirmed on WSL2 + bash"), Database/State Changes, Summary
  Claim: The spec states "keyed by Claude main process PID" and marks "PPID-as-Claude-main-PID
    confirmed" as a resolved precondition. state.json empirical finding: "Bash tool $PPID = claude
    main process PID." But probe-sessionstart-stdin.log shows the SessionStart hook's PPID comm is
    "sh" — not "claude." Claude Code runs hooks via an intermediate shell: claude → sh → hook_script.
    The hook's $PPID is the sh intermediate, not the claude main process. The "confirmed" finding
    covers the Bash tool turn context (where claude is the direct parent of bash), NOT the hook
    context. In hook context, $PPID = sh; in Bash tool context, $PPID = claude. These are different
    values. A marker written by the hook (keyed by sh-PID) cannot be found by a Bash tool turn
    (looking up claude-PID) via a simple $PPID lookup.
  Assessment: FALSE
  Evidence: probe-sessionstart-stdin.log line 4: "PPID comm: sh". state.json Q1_PPID_is_claude_main
    explicitly qualifies "Bash tool $PPID = claude main process PID" — the qualifier "Bash tool"
    reveals this was measured from a turn context, not a hook context. These two contexts have
    architecturally different process hierarchies.
  Severity: critical
  Confidence: 0.85
  False-known: yes — the spec asserts PPID = claude main is confirmed, but the probe shows hook
    PPID = sh. The confirmation applies only to Bash tool turns, not to hook invocations.
  Adjacent-risks: The existing session-end-cleanup.sh per-PPID convention (cited as "established
    pattern" at line 101) may be similarly broken — if PostToolUse hooks and SessionEnd hooks have
    different sh parents, /tmp/.claude-fail-count-${PPID} files may never be cleaned up.
```

```
FINDING-C2:
  Summary: SessionEnd hook stdin availability is asserted resolved but not empirically verified
  Section: Dependencies (Q2 resolved), Work Units (WU3 "stdin fallback")
  Claim: "Q2 resolved: postflight gets session_id via marker (helper) OR stdin (fallback)." WU3:
    "fall back to stdin session_id if marker missing." This implies Claude Code provides a JSON
    stdin payload to SessionEnd hooks analogous to SessionStart. The probe confirms SessionStart
    receives stdin with session_id. But there is no probe log for SessionEnd. Q2's "resolution"
    substitutes a workaround (marker OR stdin) for the original empirical question ("does postflight
    $PPID match preflight $PPID?"). If SessionEnd hooks receive empty or structurally different
    stdin, the fallback silently produces empty session_id.
  Assessment: UNCERTAIN
  Evidence: Only SessionStart probe exists in plan artifacts. No SessionEnd probe was run. Q2's
    describe.md framing asked about PPID identity ("verify postflight's process ancestry matches
    preflight's") — the spec answers a different question (what data is available) rather than the
    original one (is $PPID the same).
  Severity: high
  Confidence: 0.80
  False-known: no — not a false claim, but an unvalidated assumption presented as a resolved
    precondition
  Adjacent-risks: If SessionEnd stdin lacks session_id, both the primary (marker lookup) and the
    fallback fail simultaneously. The postflight hook outputs a reminder but records nothing —
    indistinguishable from "user didn't submit postflight" with no error signal.
```

```
FINDING-C3:
  Summary: "source: clear" is listed as a confirmed valid value but only 'startup' appears in the probe
  Section: state.json empirical_findings (Q1_stdin_session_id_present)
  Claim: state.json lists "source ('startup'|'resume'|'clear')" as confirmed. But probe-sessionstart-
    stdin.log shows only source: "startup". The 'clear' value appears to be inferred from Claude Code
    behavior rather than empirically observed. The spec's resume handling (WU2) checks for
    source == "resume" but does not handle source == "clear." If /compact fires a SessionStart with
    source: "clear" using the existing session_id, it falls through to the startup branch, creates
    a new marker with a new session_id, and orphans the original preflight's entry.
  Assessment: UNCERTAIN
  Evidence: probe-sessionstart-stdin.log: source: "startup" only. The 'clear' entry in the state.json
    enumeration is not tagged as observed vs. inferred. Without a compaction probe, this is an
    unconfirmed value that the spec's handler silently misclassifies if it occurs.
  Severity: medium
  Confidence: 0.75
  False-known: no — cannot confirm the claim is wrong; probe coverage is insufficient to validate
  Adjacent-risks: Orient Phase debate-log specifically flags the 'clear' scenario as a risk; the
    spec does not close it.
```

```
FINDING-C4:
  Summary: Failure Modes incorrectly labels concurrent SessionStart per process as "impossible"
  Section: Failure Modes ("Two SessionStart hooks fire simultaneously (impossible — one per claude process)")
  Claim: "impossible — one per claude process." But the spec explicitly handles source: "resume"
    in WU2, which fires a SECOND SessionStart for the SAME claude process (same session_id, same
    process PID). One claude process CAN fire more than one SessionStart (startup then resume).
    The "impossible" label conflates simultaneous (impossible) with sequential multiple (possible
    and explicitly handled). The Failure Modes rationale is wrong: the scenario is not impossible,
    it is just non-simultaneous.
  Assessment: FALSE
  Evidence: WU2: "handle source: 'resume'" — resume fires another SessionStart for the same
    session. The failure mode table's parenthetical "(impossible — one per claude process)"
    contradicts WU2's explicit handling requirement.
  Severity: medium
  Confidence: 0.90
  False-known: yes — the spec asserts impossibility while simultaneously writing a handler for
    the non-simultaneous variant of the same scenario
  Adjacent-risks: An implementer trusting "impossible" could simplify WU2 by removing the
    resume-source check as dead code, breaking a needed behavior.
```

```
FINDING-C5:
  Summary: AC4 static check grep commands are syntactically invalid for directory arguments
  Section: Success Criteria (AC4)
  Claim: AC4 specifies runnable commands: `grep -c "epistemic_get_session_id\|epistemic_marker_path"
    hooks/ commands/ scripts/` and `grep -c "/.current-session\b" ...`. Without the -r flag, grep
    on a directory argument outputs "Is a directory" errors and exits non-zero on most systems.
    These commands cannot be run as written.
  Assessment: FALSE
  Evidence: Standard bash behavior: `grep "foo" /some/dir` → "grep: /some/dir: Is a directory",
    exit 2. The -c flag does not change directory handling. Additionally, the second grep requires
    semantic exclusion ("excluding directory references and migration code") that cannot be expressed
    as a grep pattern without a multi-stage pipeline — the spec does not provide the pipeline.
  Severity: medium
  Confidence: 0.95
  False-known: yes — the spec presents these as runnable shell checks; they fail at the shell level
    before evaluating any matches
  Adjacent-risks: An implementer copying AC4 verbatim for a CI check gets false failures that
    mask real issues or waste diagnostic time.
```

```
FINDING-C6:
  Summary: Migration failure (rename fails) is absent from Failure Modes table
  Section: Database/State Changes (migration), Failure Modes
  Claim: "Single rename + mkdir; no data lost." The Failure Modes table has no row for migration
    failure. If mv ~/.claude/.current-session ~/.claude/.current-session.legacy-${TS} fails
    (permissions, filesystem full, target already exists from a prior same-second migration),
    the subsequent mkdir -p finds the old file still blocking directory creation and also fails.
    The session proceeds without a marker, silently dropping epistemic tracking for that session.
  Assessment: TRUE (accurate claim about the happy path; gap is the unhandled failure branch)
  Evidence: Failure Modes table covers: stdin missing, /proc unavailable, mkdir fails, helper
    missing, PPID reuse. Migration failure is not listed. "No data lost" holds only when rename
    succeeds. The spec provides no behavior specification for rename failure.
  Severity: medium
  Confidence: 0.85
  False-known: no — the spec doesn't claim rename always succeeds; the gap is the missing failure row
  Adjacent-risks: Concurrent migration race (two sessions both detect the legacy file simultaneously):
    one rename succeeds, one gets ENOENT — the spec doesn't specify whether ENOENT is treated as
    "migration already done by peer, proceed" or as an error.
```

```
FINDING-C7:
  Summary: docs/PLANNING-STORAGE.md references .current-session but is absent from the change table
  Section: Files/Components Touched
  Claim: The spec's change table implies completeness for .current-session references. Grep of the
    repo (excluding _OLD, .git, and plans/) finds exactly 17 files referencing .current-session.
    The spec's change table lists 16 non-verify files. The missing file is docs/PLANNING-STORAGE.md
    (line 99: schema description string referencing "~/.claude/.current-session (primary storage)").
    AC4's second grep would fail on this file even after all listed files are updated.
  Assessment: TRUE (confirmed by grep)
  Evidence: `grep -n "current-session" /home/nick/claude-sail/docs/PLANNING-STORAGE.md` →
    line 99 has the reference. The file is not in the spec's change table.
  Severity: low
  Confidence: 0.99
  False-known: yes — the change table implies completeness but omits one file
  Adjacent-risks: AC4 second grep reports failure after all listed files are updated, sending the
    implementer hunting for a source they were not told about.
```

```
FINDING-C8:
  Summary: The Orient Phase "sweep race" concern is a false positive — the /proc liveness check is inherently safe
  Section: Orient Phase Known Risks (informs spec's unchallenged assumptions)
  Claim: Orient Phase: "session A's sweep could remove session B's freshly-written marker." This
    risk is carried forward unchallenged. The correctness analysis shows it is not real: the sweep
    removes markers only for PIDs where /proc/<pid> does NOT exist. If session B has written a
    marker with its PPID, session B is alive, and /proc/<B_PPID> exists. Session A's sweep sees
    /proc/<B_PPID> → exists → does NOT remove B's marker. The sweep algorithm is inherently safe
    against live-session marker removal.
  Assessment: FALSE (the stated risk does not exist given the specified algorithm)
  Evidence: Spec Failure Modes: "any marker whose /proc/<pid> directory does not exist is
    considered orphan." A process that has written its marker is alive, so /proc/<pid> exists,
    so the sweep condition (not-exist) is never true for live sessions.
  Severity: low (informational correction; no spec change needed, but the false concern should
    not generate work in the Challenge stage)
  Confidence: 0.90
  False-known: yes — the Orient Phase risk was an incorrect assessment
  Adjacent-risks: The REAL sweep risk (C9 below) is a consequence of C1: if hook PPID = sh that
    dies after hook exits, the NEXT sweep correctly identifies the dead sh-PID as an orphan and
    removes the marker before postflight fires.
```

```
FINDING-C9:
  Summary: If hook PPID = transient sh (C1), sweep correctly deletes the marker before SessionEnd fires
  Section: Failure Modes, Database/State Changes, Work Units (WU2/WU3)
  Claim: The spec's sweep removes markers for dead PIDs. If the SessionStart hook's PPID is an sh
    process that exits immediately after the hook completes (as C1 suggests), then at the next
    SessionStart (any parallel session), the sh-PID is dead, /proc/<sh_pid> doesn't exist, and the
    sweep CORRECTLY removes the marker per spec. The SessionEnd hook for the first session then
    cannot find its marker. This is not a sweep bug — it is the correct algorithm applied to a
    wrong key. The design assumption that the marker key PID stays alive between SessionStart and
    SessionEnd is violated if the key is a transient sh process.
  Assessment: TRUE (conditional on C1)
  Evidence: Follows directly from C1 (hook PPID = sh process that exits after hook completes)
    combined with the sweep algorithm (remove if /proc/<pid> doesn't exist). The spec does not
    account for this interaction because it assumes the marker key PID is the long-lived claude
    main process. If C1 is correct, C9 is a critical consequence.
  Severity: critical (conditional — severity is critical if C1 is confirmed; low if C1 is wrong)
  Confidence: 0.75
  False-known: no — derived correctness consequence, not a direct spec claim
  Adjacent-risks: C9 and C1 are linked: if C1 is resolved by using the claude main PID (via
    process tree traversal in the helper), C9 disappears. If C1 is resolved by using session_id
    as the key (content-addressed), C9 also disappears. C9 is a forcing function for resolving C1.
```

```
FINDING-C10:
  Summary: PPID=1 edge case has no fallback in the new scheme — recreates the single-file clobber bug
  Section: Database/State Changes, Failure Modes
  Claim: The spec's "established per-PPID convention" cites session-end-cleanup.sh:18. That file
    includes an explicit PPID=1 fallback: if PPID==1, use $USER-$(pwd|md5sum|cut) as suffix. The
    new epistemic-marker.sh helper has no equivalent PPID=1 fallback. On systems where hooks run as
    direct children of init/PID 1 (some Docker environments, systemd launchers), all sessions write
    their marker to ~/.claude/.current-session/1, and each new session clobbers the previous —
    exactly the bug this fix is supposed to solve. The PPID=1 case is not mentioned in Failure Modes.
  Assessment: TRUE
  Evidence: session-end-cleanup.sh lines 15-19: PPID=1 guard with fallback suffix. spec.md line 101:
    cites session-end-cleanup.sh:18 as the "established pattern" — but does not reproduce its
    PPID=1 guard in the new helper design.
  Severity: medium
  Confidence: 0.85
  False-known: no — the spec simply doesn't mention PPID=1; not a false claim, a missing case
  Adjacent-risks: On PPID=1 systems, the orphan sweep also cannot work — /proc/1 always exists,
    so the single marker key "1" is never swept. Stale data from crashed sessions accumulates
    permanently in the single marker file.
```

## Convergence Check

⚠ **Convergence signal**: All three lenses produced critical and high severity findings on the same axis (PPID identity / post-migration consumer breakage). This appears to be **substantive agreement**, not distributional conformity — each lens approached from a different angle (correctness via probe data, completeness via consumer enumeration, coherence via decision-vs-implementation gap) and converged on the same root issues.

## Interaction Scan

Read-only scan of compound interactions across the 30 findings. Flags pairs/groups where co-occurrence creates a worse failure than either alone.

### IF1 — PPID Identity Cascade (CRITICAL ELEVATED)
**Findings involved**: C1, C9, M5, H2, C10/M6, C1's adjacent-risk on session-end-cleanup.sh

**Pattern**: Five findings from all three lenses converge on a single empirical claim that fails: the spec asserts `$PPID = claude main process PID` is "confirmed" universally, but the probe log shows hook context's PPID = `sh` (intermediate shell), not `claude`. Bash tool context's PPID = `claude` (verified separately). These are **two architecturally different process hierarchies**, conflated in state.json's empirical_findings.

**Compound impact**:
- Hook writes marker at `~/.claude/.current-session/${sh_pid}` (sh process is short-lived)
- Bash tool reads marker at `~/.claude/.current-session/${claude_pid}` — different path, marker not found
- Sweep correctly removes orphan when sh dies, leaving SessionEnd unable to find own marker
- The *cited established convention* (`session-end-cleanup.sh:18`) is hook-to-hook (preflight write, postflight read) — same sh parent, so it works there. But hook→Bash-tool lookup is the new pattern this spec introduces, and it breaks under the same PPID asymmetry.

**Implication**: The design's discovery mechanism is structurally unsound as currently spec'd. Fix requires process-tree traversal in helper (`epistemic_claude_main_pid`) to find comm=claude, OR switching marker key to session_id (with a separate by-pid index for Claude-turn lookup).

### IF2 — Post-Migration Consumer Breakage (HIGH)
**Findings involved**: M1, M2, M3, M4

**Pattern**: Four different consumer-side regressions all caused by one root: `~/.claude/.current-session` becomes a directory, but consumers still treat it as a file:
- M1: `printf ... > ~/.claude/.current-session` (write fails on directory path)
- M2: `cat ~/.claude/.current-session` (returns empty on directory) + grep pattern matches old timestamp format only
- M3: `[ -f "$HOME/.claude/.current-session" ]` (-f returns false for directory)
- M4: `rm -f ~/.claude/.current-session` (no-op on directory)

**Compound impact**: WU5's description "refactor command bash blocks to use helper" is too high-level. Each of these four sites has distinct breakage that needs a specific fix. WU5 must enumerate per-file changes.

### IF3 — Lifecycle Coverage Gap (HIGH)
**Findings involved**: M9, C3, Orient note on source="clear"

**Pattern**: Spec handles `source: "startup"` and `source: "resume"` but not `source: "clear"`. Probe captured only "startup". Compaction is a normal workflow that fires SessionStart with potentially "clear" — falls through to startup branch and creates a NEW marker, orphaning the original preflight.

**Compound impact**: For long sessions (the ones where calibration is most valuable), `/compact` silently splits calibration data. This regresses the dominant power-user case.

### IF4 — Acceptance Criteria Quality (MEDIUM)
**Findings involved**: H3, H4, H5, H9, C5, M8

**Pattern**: AC4 has three independent flaws (count wrong, grep invalid, exclusion underspecified). AC9 has stage off-by-one. WU dependencies are incomplete (WU9 missing WU3). test.sh coverage gap for new helper. These are quality issues, not correctness; AC needs full rewrite.

### IF5 — Silent Fallback Chain (MEDIUM)
**Findings involved**: Orient note, C2, H6, M10

**Pattern**: Spec uses fallback layers (uuidgen on stdin parse fail, inline-fallback on helper-source fail, stdin-fallback on marker missing) but none provide observable signal. M10 specifically: rollback Step 2 silently fails because reverted hook can't write to a directory — only stderr warning.

**Compound impact**: Operator has no dashboard or signal to notice degradation. Fits the silent-failure-as-operational-risk pattern from vault.

### IF6 — Migration Race (LOW-MEDIUM)
**Findings involved**: M7 (standalone)

**Pattern**: Concurrent legacy-file migration has unhandled ENOENT path. Independent finding, not compound.

## Clash Phase

### Correctness Cross-Examination

```
REINFORCEMENT:
  Finding: M5
  Your finding: C1
  Agreement: Both identify that the spec conflates two different PPID values — hook-context PPID
    (= sh intermediate process) and Bash-tool-context PPID (= claude main process). M5 arrives from
    the completeness angle ("assertion not proven"); C1 arrives from the correctness angle ("probe
    data falsifies the claim"). The probe log line 4 — "PPID comm: sh" — is the same empirical anchor
    both findings depend on. Where the findings diverge: M5 treats the gap as a missing proof
    (confidence 0.72, "asserted but not proven"); C1 treats the gap as an active falsehood
    (confidence 0.85, "FALSE"). The probe is positive evidence that the hook's PPID IS sh, not merely
    absence of proof that it's claude. C1's stronger verdict is correct: the spec's "CONFIRMED"
    checkbox is factually wrong for the hook invocation path, not just under-evidenced.
  Combined confidence: 0.90
  Note: M5's confidence ceiling (0.72) reflects uncertainty about whether sh-parent is consistent
    across hook invocations. That uncertainty is real and C1 shares it — but it does not soften the
    finding that the "CONFIRMED" claim covers the wrong measurement context.
```

```
REINFORCEMENT:
  Finding: M5 (adjacent risk / IF1 cascade)
  Your finding: C9
  Agreement: C9 is the consequence of C1 that M5 also gestures at but does not fully develop.
    M5 notes the "problematic case is hook→Bash-tool lookup" but stops before tracing the sweep
    interaction. C9 extends this: if hook PPID = transient sh, the sweep algorithm CORRECTLY
    identifies the dead sh-PID as an orphan at the next SessionStart and removes the marker.
    SessionEnd then cannot find its own marker by PPID. This is not a bug in the sweep — it is the
    correct algorithm operating on a structurally wrong key. The compound severity is higher than
    either finding alone because the sweep's correctness makes the failure deterministic rather than
    probabilistic: the marker will be swept on any parallel-session scenario, every time.
  Combined confidence: 0.88 (conditional on C1 being confirmed; if sh-parent is stable and long-lived,
    both C9 and this reinforcement collapse to low severity)
```

```
REINFORCEMENT:
  Finding: C10 (my own) / M6
  Your finding: C10
  Agreement: C10 and M6 are independently derived instances of the same gap: session-end-cleanup.sh
    (the spec's own cited "established pattern") has an explicit PPID=1 guard that epistemic-marker.sh
    does not replicate. M6 adds one important detail C10 omits: the sweep interaction on PPID=1
    systems. Because /proc/1 always exists, the single marker key "1" is NEVER swept — stale markers
    from crashed sessions accumulate permanently. C10 already notes this in adjacent-risks but does
    not quantify the accumulation risk. M6's framing of "recreating the single-file clobber bug" is
    the cleaner characterization: on PPID=1 systems, the fix has zero isolation benefit.
  Combined confidence: 0.88
  Addendum: the spec explicitly cites session-end-cleanup.sh:18 as the "established pattern" (spec
    line 101) while silently dropping that pattern's PPID=1 guard. This is not just a missing case —
    it is an inconsistency with the spec's own cited precedent.
```

```
REBUTTAL:
  Finding: H1
  Your position: H1 overstates the severity and the "false-known" classification. The finding is
    correct that OQ1 is already decided in the spec body — that is a real documentation inconsistency.
    But H1 rates it critical and claims a Stage 3 challenger "would be misled" into spending effort
    on a decided question. The actual risk is lower: the OQ section's hedge ("Decision can flip
    based on Stage 3 findings") is a standard defensive hedge that experienced reviewers read as
    "we're open to challenge, but here's our current direction." Sophisticated reviewers check the
    Work Units before arguing against an OQ position. The severity should be medium, not critical —
    critical implies execution risk or correctness failure; this is a documentation clarity issue.
    The false-known label is also borderline: the spec does not claim OQ1 is unresolved in any
    asserted factual sense; it signals openness to challenge while already implementing the answer.
    That is a documentation pattern (hedge without tracking closure), not a false-known claim.
  Evidence: Three separate spec sections (Files/Components Touched, WU2, Failure Modes) all
    commit to SessionStart sweep. A reader doing any due diligence would see the commitment before
    spending time on a counter-argument. The adjacent-risk ("challenger could spend effort") is
    real but low-probability given how the spec is structured.
  Rebuttal confidence: 0.72
  Note: The resolution H1 proposes (close OQ1 explicitly as decided, remove hedge) is correct
    regardless — the concern is only that critical severity overstates the practical risk.
```

```
REINFORCEMENT:
  Finding: H2
  Your finding: C2
  Agreement: H2 (Coherence) and C2 (Correctness) both identify that Q2's resolution in the spec
    answers a different question than Q2 originally asked. H2 frames this as a contradiction
    between the spec's Q2 answer and describe.md's Q2 framing. C2 frames it as an unvalidated
    assumption: the spec claims Q2 is "resolved" but no SessionEnd probe exists to confirm stdin
    availability or PPID identity at hook-end. The two findings are complementary, not redundant.
    H2 covers the intra-document inconsistency (resolved wrongly); C2 covers the empirical gap
    (the resolution is unverified). Together they establish: (1) the answer given is not to the
    question asked, AND (2) even the given answer lacks empirical backing.
  Combined confidence: 0.90
  Key addition from C2 not in H2: if SessionEnd hooks receive structurally different or empty
    stdin (not confirmed either way), both the primary lookup (marker by PPID) and the fallback
    (stdin session_id) fail simultaneously — postflight records nothing with no error signal.
    H2 focuses on the PPID-mismatch path; C2 covers the stdin-unavailable path. Both need a probe.
```

```
REBUTTAL:
  Finding: M1 (partial — the adjacent-risk claim)
  Your position: M1's core finding is well-founded and not in dispute: the command-level fallback
    write to ~/.claude/.current-session will fail after migration, and WU5 does not address it.
    However, M1's adjacent-risk claim ("WU2 likely covers this, but the command-level fallback is
    not WU2") is too charitable to WU2. WU2's description explicitly says "handle migration of
    legacy single-file marker" and "write per-PPID marker via helper" — it covers the HOOK's write
    path. But the command bash block in epistemic-preflight.md is a SEPARATE code path that is
    WU5 scope, and WU5 says only "bash block reads marker via helper." The create-fallback in the
    command is distinct from both the read path (explicitly covered by WU5) and the hook's write
    path (WU2). Neither WU explicitly owns "command create-fallback must write to per-PPID path."
    M1 notes this correctly in the gap body but then softens it with "WU2 likely covers this" in
    adjacent-risks — that softening is wrong and should be removed. The gap is not covered.
  Evidence: WU2 files = hooks/epistemic-preflight.sh. WU5 files = commands/epistemic-preflight.md.
    WU5 description = "reads marker via helper." The create-fallback write path in the command is
    neither a read nor a hook — it is an uncovered gap in both WUs.
  Rebuttal confidence: 0.80
  Scope: this is a precision correction on the adjacent-risk phrasing, not a dispute of M1's
    severity or core conclusion.
```

```
REINFORCEMENT:
  Finding: M9 / IF3
  Your finding: C3
  Agreement: C3 and M9 both flag the source="clear" gap, arriving from different angles. C3 notes
    the empirical problem: state.json lists source="clear" as confirmed but the probe only shows
    "startup" — the enumeration is unverified. M9 notes the operational consequence: a compaction
    event falls through to the startup branch and orphans the original preflight. These findings are
    layered: C3 establishes the epistemic weakness (the "clear" value is assumed, not observed),
    M9 establishes the consequence if the assumption is correct. Neither finding alone fully captures
    the risk. The compound issue: the spec's WU2 resume handler is written for source="resume" but
    compaction may use source="clear" — if so, the handler silently creates the wrong behavior
    (new marker, new session_id) for what should be a preserve-session event. A compaction probe
    is the blocker for both findings.
  Combined confidence: 0.78 (confidence ceiling set by empirical uncertainty about whether
    compaction actually uses source="clear" vs source="resume" — without a compaction probe,
    we cannot confirm the failure mode triggers)
```

```
GAP:
  Gap: The IF1 cascade's two proposed fixes (process-tree traversal vs session_id-keyed marker)
    have materially different correctness properties that the spec and all three lenses leave
    unanalyzed. Process-tree traversal (walk up /proc/$$/status until comm=claude) is correct
    under the current design but introduces a new failure mode: it relies on /proc availability
    (already a listed failure mode) and is potentially O(depth) in process ancestry, adding latency
    to the timing-constrained SessionStart. Session_id-keyed marker (use session_id from stdin as
    the file key, with a separate index for Bash-tool lookup) is more robust — the key is durable
    across all invocation contexts — but requires defining how Bash tool turns discover their own
    session_id without reading stdin (which they cannot do). Neither fix was spec'd; IF1 correctly
    identifies the structural flaw and proposes both approaches without analyzing their tradeoffs.
    The Challenge stage needs to pick one and specify it before WU1 can be written.
  Section: Work Units (WU1 — the helper design is the locus), Dependencies (Preconditions),
    Senior Review Simulation
  Severity: critical
  Confidence: 0.50
```

### Coherence Cross-Examination

```
REINFORCEMENT:
  Finding: C1
  Your finding: H2
  Agreement: Both see the same PPID asymmetry from different angles. C1 attacks the empirical
    claim directly — state.json marks "PPID = claude main" as CONFIRMED, but the qualifier "Bash
    tool $PPID" exposes that this was only measured from a Claude-turn context, not from a hook
    context. H2 attacks the downstream consequence: Q2 is declared "resolved" via a workaround
    (marker OR stdin fallback), but the original describe.md question was an empirical identity
    check — does postflight's $PPID equal preflight's $PPID? H2 flags this as an unanswered
    empirical question dressed up as a workaround.
    The coherence angle on IF1 that neither lens fully named: state.json's marker_anchor_decision
    says "Use $PPID (Claude main PID) as the marker DISCOVERY key. Use Claude Code's session_id
    ... as the marker DATA value." This decision narrative was written in Claude-turn context
    (where $PPID = claude main), then applied globally to hook context (where $PPID = sh
    intermediate) without revision. The decision and its documented rationale are internally
    consistent — but only within one of the two contexts that will actually execute it. The spec's
    own rationale uses "Bash tool" and "Claude turns" as examples everywhere with hooks as the
    write path, but never explicitly reconciles the two contexts. That is a coherence gap, not
    just a correctness gap.
  Combined confidence: 0.93
```

---

```
REINFORCEMENT:
  Finding: C4
  Your finding: H1 (adjacent)
  Agreement: C4 flags FM ("Two SessionStart hooks fire simultaneously — impossible") as FALSE
    because WU2 explicitly handles source="resume", which fires a second SessionStart for the
    SAME process. H1 flagged that OQ1 was declared open while the spec body already committed
    SessionStart as the sweep location. These are related coherence failures in the same region
    of the spec: FM marks one scenario "impossible" while WU2 codes for it; OQ1 hedges the sweep
    location while three body sections commit it. Both failures stem from the same authoring
    pattern — body commitments written ahead of header-section cleanup. The compound effect: an
    implementer who trusts the FM "impossible" label has grounds to remove WU2's resume handler
    as dead code, breaking a needed behavior. The coherence failure (FM ↔ WU mismatch) elevates
    C4 beyond a standalone correctness error into a cross-section consistency hazard.
  Combined confidence: 0.91
```

---

```
REINFORCEMENT:
  Finding: C5
  Your finding: H4
  Agreement: Both lenses independently found the same defect — AC4's grep commands are invalid
    for directory arguments (missing -r flag). C5 assesses it as FALSE (runnable shell checks
    that fail before evaluating matches). H4 assesses it as medium severity / coherence issue
    (spec does not claim the command works, just leaves it underspecified).
    The coherence angle H4 adds: the AC section makes an implicit internal promise — these are
    executable verification steps. That promise is broken by commands that cannot execute.
    The spec's "Verification vocabulary" footnote explicitly distinguishes TESTED from VERIFIED
    and claims AC1-AC9 are TESTED. A TESTED criterion that cannot be run is self-contradictory
    within the spec's own vocabulary framework. The coherence failure is between the Verification
    vocabulary definition and AC4's actual executability.
  Combined confidence: 0.95
```

---

```
REBUTTAL:
  Finding: C8
  Your position: C8 concludes the Orient Phase sweep-race concern is a "false positive" because
    the /proc liveness check is inherently safe. C8 is correct that the stated risk does not exist
    under the specified algorithm — IF the marker key is the long-lived claude main process PID.
    But C8's unconditional "FALSE" label is wrong: it is only valid given C1 being wrong. If C1
    is correct (hook PPID = transient sh), the sweep-race reappears in a different form: the sh
    PID dies shortly after the hook exits; at the next SessionStart, /proc/<sh_pid> is absent;
    sweep correctly removes the marker as an orphan — before postflight fires. This is C9.
    C8's adjacency note acknowledges C9 but does not weaken the "FALSE" label. It should. The
    correct assessment is: "FALSE given the intended long-lived key; TRUE if C1 is confirmed and
    the key is a transient sh PID." Calling it an unconditional false positive removes the
    pressure to resolve C1 before concluding the sweep design is safe. C8 should not be used to
    deprioritize C1 resolution.
  Evidence: C8 body: "A process that has written its marker is alive, so /proc/<pid> exists."
    This is only true when the marker's key process is the same as the writing process and stays
    alive. Under C1, the key process (sh) exits after the hook script completes — it is no longer
    alive when the next SessionStart sweeps, even though the intended session is still alive.
  Rebuttal confidence: 0.82
```

---

```
REINFORCEMENT:
  Finding: M10
  Your finding: H2 (adjacent-risk on scoped rm -f)
  Agreement: M10 identifies the specific rollback incoherence: Rollback Step 2 says "no action
    needed" but the reverted hook cannot write to a directory path. H2 flagged the adjacent risk
    that postflight's scoped rm -f uses the wrong PPID path and orphaned markers accumulate.
    Both reinforce each other at the coherence level: the spec's Rollback Plan and Failure Modes
    table are not coherent with each other about post-migration filesystem state. Failure Modes
    lists "Marker directory creation fails → hook continues fail-open with stderr warning" —
    assuming the directory exists. The Rollback Plan promises the reverted hook restores
    file-write behavior "with no action needed" — assuming the directory does NOT block the file
    path. These two sections describe different post-migration world-states without acknowledging
    the contradiction. That is the coherence failure: same filesystem state, two incompatible
    descriptions of what succeeds vs. degrades gracefully.
  Combined confidence: 0.91
```

---

```
REBUTTAL:
  Finding: C7
  Your position: C7 is correct that docs/PLANNING-STORAGE.md is missing from the change table.
    But the coherence severity should be lower than the compound consequence C7 implies. The
    change table's heading ("Files/Components Touched") describes files to MODIFY — it is a work
    breakdown, not an exhaustive grep-coverage inventory for AC4. docs/PLANNING-STORAGE.md
    contains a documentation reference to .current-session as a description of the old design
    (explanation-type doc), not an active consumer. Its omission from the change table is a
    coverage oversight in a documentation file, not a decision-vs-implementation coherence gap.
    The AC4 consequence (grep reports failure after all listed files updated) is real, but it is
    a symptom of AC4's own underspecification (H4, H9, C5) — not a new coherence issue introduced
    by C7. C7's low severity rating is correct; its "false-known" classification is borderline —
    the table makes no explicit completeness claim, it just doesn't label itself as non-exhaustive.
  Evidence: The spec's change table lists 20 rows including "Verify only" entries. The implicit
    scope is "files that change or require verification during execution." A documentation-only
    architecture explanation that needs a prose update is plausibly in scope, but its omission
    is an authoring gap, not a logical contradiction between two committed spec positions.
  Rebuttal confidence: 0.72
```

---

```
GAP:
  Gap: The spec's Verification vocabulary footnote classifies AC3, AC5, and AC6 as TESTED via
    behavioral eval. But OQ4 explicitly acknowledges the eval mechanism is unvalidated: "simulate
    by directly invoking the hook with crafted stdin + controlled $PPID via bash -c subshells."
    This creates an internal coherence gap: the Verification vocabulary definition imports an
    epistemic standard ("TESTED" implies the mechanism checks what it claims to check), but the
    OQ4 disclaimer acknowledges the simulation's fidelity is unproven. AC10 alone carries the
    VERIFIED label. If the bash -c simulation does not replicate actual hook execution context
    (e.g., because $PPID injection into a subshell differs from how Claude Code sets $PPID in hook
    invocations), then AC1-AC3, AC5-AC6 are "TESTED" in name only — the same epistemic weakness
    that AC10's VERIFIED label is supposed to distinguish them from. The spec's own vocabulary
    framework is applied inconsistently: the TESTED/VERIFIED distinction is meaningful only if
    the test mechanism's fidelity is established, which OQ4 defers.
  Section: Success Criteria (verification footnote), Open Questions (OQ4)
  Severity: medium
  Confidence: 0.78
```

---

```
GAP:
  Gap: The spec's marker_anchor_decision in state.json names two separate uses of session_id —
    (a) as MARKER DATA (stored in the per-PPID file) and (b) as the KEY for epistemic.json
    pairing. The Failure Modes table says "Fall back to uuidgen; log to stderr" for stdin-parse
    failure. But the spec never reconciles what "uuidgen fallback" means for epistemic.json
    pairing: if the marker stores a uuidgen value (not Claude Code's UUID), the postflight hook
    reads that uuidgen value, writes the postflight entry under that key — and the two entries
    (preflight under one key, postflight under a different or absent key) cannot be paired.
    Worse: the marker_anchor_decision explicitly rejects uuidgen as a session identity ("Claude
    Code's own session_id is reusable as our key — no need for uuidgen"), yet the fallback
    re-introduces it. This is a direct internal contradiction between the design rationale
    (session_id = correct identity) and the fallback behavior (uuidgen = acceptable substitute).
    The two mentions of the fallback — Failure Modes "use uuidgen" vs. marker_anchor_decision
    "no need for uuidgen" — are never reconciled into a single definition of what session
    identity means when stdin is unavailable.
  Section: Failure Modes (stdin-missing row), Database/State Changes (marker contents),
    state.json marker_anchor_decision
  Severity: high
  Confidence: 0.85
```

### Completeness Cross-Examination

```
REINFORCEMENT:
  Finding: C1/C9 (PPID identity / sweep-deletes-live-marker)
  Your finding: M1, M2, M3, M4 (post-migration consumer breakage — IF2)
  Agreement: IF2's four consumer-breakage sites are individually high-severity,
    but C1/C9 compound them into an interlocking failure chain. The key
    interactions:
    (1) M4 (rm -f on directory is a no-op in epistemic-postflight.md Step 6)
    means the command bash block never cleans the per-PPID marker. The sh-pid
    marker persists until the NEXT SessionStart sweep. Under C9, sweep correctly
    sees a dead sh-pid and removes it — but this happens after postflight runs.
    If postflight's helper lookup uses claude-main PPID (different key) and
    finds nothing, the cleanup by sweep is moot; postflight already silently
    skipped its write.
    (2) M3 (-f guard in collect-insights and vault-curate blocks the helper
    call before it is reached) means the IF1 PPID asymmetry is invisible in
    those consumers — they report NO_SESSION whether the guard is wrong or the
    helper returns empty. Debugging IF1 in those commands is therefore harder
    than debugging it in the hook path.
    (3) M1 (create-fallback in epistemic-preflight.md writes to directory path)
    compounds with the C1 scenario: if the hook-written marker uses sh-pid as
    key and the command cannot find it, the command fallback tries to CREATE a
    new marker at the old file path — which also silently fails. Two independent
    create paths fail on the same directory collision.
    Combined confidence: 0.92
    Structural note: WU5 must enumerate per-file fix types (read guard, write
    path, delete path) for each of the six command files — not just "use helper."
    Each of the four M-findings requires a distinct fix pattern.
```

```
GAP:
  Gap: WU1 specifies three functions for epistemic-marker.sh: epistemic_marker_path,
    epistemic_get_session_id, epistemic_sweep_orphans. If C1 is accepted (hook
    PPID = sh intermediate, not claude main), the correct resolution requires a
    fourth function: epistemic_claude_main_pid() — walks /proc/$PPID/status PPid
    fields up the chain until comm=claude is found or a depth cap is reached,
    falling back to $PPID if not found. Without this function, an implementer
    writing WU1 from the spec as written will hardcode $PPID — which is the
    broken assumption. No Work Unit currently owns the process-tree traversal
    sub-problem. If Refine accepts C1, WU1 must be expanded before WU2-WU5
    can be correctly implemented on top of it.
  Section: Work Units (WU1), Dependencies (Preconditions — "PPID confirmed")
  Severity: critical
  Confidence: 0.88
```

```
REINFORCEMENT:
  Finding: C2 (SessionEnd stdin availability unverified)
  Your finding: M4 (command bash block Step 6 cleanup is a no-op)
  Agreement: C2 correctly identifies the missing SessionEnd probe. The
    completeness extension adds three specific scenarios that should be probed
    but are not:
    (1) Does SessionEnd hook receive ANY stdin JSON? WU3 adds a stdin fallback
    for the case where the marker is missing — but the current postflight hook
    (lines 26-36 of epistemic-postflight.sh) never reads stdin at all. If
    SessionEnd stdin is empty or absent, the fallback silently produces empty
    session_id with no signal distinguishable from "marker was not found."
    (2) Does SessionEnd stdin use the same field name as SessionStart? The probe
    confirms SessionStart uses "session_id"; SessionEnd field name is unverified.
    (3) Can the SessionEnd stdin probe be a sub-task of WU3 — "run and archive
    probe-sessionend-stdin.log before writing fallback code"? Without this
    gating requirement, WU3's fallback code is written against an assumed
    contract that has not been verified. The probe is a blocking empirical
    precondition for WU3, not just a nice-to-have verification.
  Combined confidence: 0.87
```

```
REINFORCEMENT:
  Finding: H6 (FM4 inline fallbacks not tracked in WU2/WU3/WU5)
  Your finding: M1 (epistemic-preflight.md create-fallback writes to wrong path)
  Agreement: H6 correctly identifies that FM4's fallback requirement is not
    tracked in any Work Unit. The completeness extension: the current inline
    fallback in epistemic-preflight.md Step 1 is not a read-only fallback — it
    actively creates a session marker (printf > ~/.claude/.current-session). After
    migration this write fails silently. When H6's fix is specified ("add inline
    fallback to WU5"), it must distinguish the CREATE path from the READ path:
    Option A: fallback creates a marker using hardcoded path construction ($PPID
    known in Bash tool context, but that is claude-main PID under IF1's model,
    a different value than what the hook wrote).
    Option B: command bash blocks only READ — no create fallback. /epistemic-
    preflight command requires the hook to have fired first. This is cleaner but
    breaks the current self-bootstrap behavior where /epistemic-preflight can
    create its own marker if none exists.
    WU5 must resolve which option applies. As written, WU5 says "reads marker
    via helper" — leaving the create path unaddressed, which is the regression
    vector M1 identified. The create path is more dangerous than a missing read
    fallback because a failed create silently prevents all subsequent writes in
    the same session.
  Combined confidence: 0.91
```

```
REINFORCEMENT:
  Finding: M9 / IF3 / C3 (source="clear" unhandled)
  Your finding: M9 (extended with additional unhandled source branches)
  Agreement: IF3 and C3 cover the known compaction case. The completeness
    extension: the spec's two-branch handler (startup / resume) leaves an open
    input tail with at least two more unhandled patterns:
    (1) source absent or null — if an older Claude Code version omits the field.
    The spec does not specify how WU2's jq parse handles null; a naive shell
    comparison `if [ "$SOURCE" = "resume" ]` treats null as startup, which is
    probably correct but is untested behavior.
    (2) A session that fires startup then resume then clear sequentially in one
    session lifetime. The spec handles resume as re-create, but does not specify
    what happens if clear fires after resume — the marker state machine has at
    least three transitions and the spec only defines two.
    WU2 should add: "emit stderr warning for unrecognized source values and
    treat them as startup." This converts unknown-unknown future source strings
    into observable-and-logged degradation without changing behavior for the
    two known cases.
  Combined confidence: 0.83
```

```
REINFORCEMENT:
  Finding: H2 / M5 (postflight PPID match unvalidated / PPID consistency
    between hook writes and Bash tool reads unproven)
  Your finding: M5 (extended with multi-context structural observation)
  Agreement: H2 and M5 both identify Q2's empirical gap. The completeness
    cross-examination adds a structural observation neither finding fully names:
    The spec's "established pattern" from session-end-cleanup.sh is hook-to-hook
    (PreToolUse write → SessionEnd read). Both fire in hook context, plausibly
    through the same sh parent — PPID consistency is plausible. The epistemic
    design introduces a new pattern: hook write at SessionStart (sh_A), Bash tool
    read mid-session (claude_main), hook read at SessionEnd (sh_B). Three
    distinct invocation contexts. The probe only validates hook context PPID.
    H2's resolution (b) — content-addressed delete using session_id — is the
    only resolution robust to multi-context PPID asymmetry. The spec needs to
    adopt it explicitly or provide probe evidence for all three contexts. The
    completeness gap: no WU currently owns "probe Bash tool $PPID vs hook $PPID
    in the same session and archive the result." This probe is a prerequisite for
    the entire design, not just for Q2's resolution.
  Combined confidence: 0.86
```

```
REINFORCEMENT:
  Finding: IF4 / M8 (test.sh coverage gap for epistemic-marker.sh)
  Your finding: M8 (extended — Category 5 hook-convention gap for sourced scripts)
  Agreement: IF4 groups M8 with AC quality issues. The completeness extension:
    test.sh Category 5 checks hooks/*.sh for no `set -e`, no `eval`, `set +e`
    presence. The new helper is sourced BY hooks — if it contains `set -e`, it
    overrides the hook's `set +e` and breaks fail-open semantics across all
    dependent hooks. Category 5 does not currently cover scripts/*.sh.
    This is a structural enforcement gap that is architecturally more dangerous
    than a missing syntax check: a `set -e` in the helper would pass ALL current
    test categories (Category 1 checks behavioral-smoke.sh only; Category 5
    checks hooks/*.sh only; Category 7 verifies file placement only). The test
    suite would give false confidence that the new helper respects hook
    conventions.
    WU12 must explicitly add: "extend test.sh Category 5 to check scripts
    sourced by hooks — at minimum epistemic-marker.sh — for set -e absence and
    set +e presence." Without this, the full test suite cannot certify that
    sourcing the helper does not break the hooks that source it.
  Combined confidence: 0.95
```

```
REINFORCEMENT:
  Finding: IF5 / M10 (silent fallback chain; rollback Step 2 misleading)
  Your finding: M10 (extended — full failure sequence post-revert)
  Agreement: IF5 correctly groups M10 with the silent-failure-chain pattern.
    The completeness extension traces the complete failure sequence after a
    standard rollback:
    (1) git revert → hook restored to write .current-session as a file path.
    (2) ~/.claude/.current-session is a DIRECTORY (migration ran at deploy time).
    (3) epistemic-preflight.sh line 53: write to "$CURRENT_SESSION" fails
    silently (Is a directory, 2>/dev/null).
    (4) Line 55: [ ! -f "$CURRENT_SESSION" ] → true → WARNING fires to stderr.
    (5) epistemic-postflight.sh line 26: [ ! -f "$CURRENT_SESSION" ] → true →
    hook exits 0 before issuing any reminder. The "postflight not submitted"
    warning never fires.
    (6) All command bash blocks: cat ~/.claude/.current-session → empty or error.
    SESSION_ID="". All epistemic writes silently fail.
    Result: complete tracking failure with one dismissable stderr warning.
    Rollback Step 2 must change from "no action needed" to a mandatory step with
    a concrete safe command: `rm -rf ~/.claude/.current-session/ && echo "marker
    directory removed"`. Step 3's "optional" label on the cleanup must be removed.
    The rollback plan's current wording produces a false sense of safety that
    would cause real data loss in production.
  Combined confidence: 0.94
```

## Converge Phase

## Verdict: REWORK

The spec's foundational empirical claim is incorrect: state.json declares "PPID = claude main process PID" CONFIRMED, but the SessionStart probe shows hook context PPID comm = `sh` (intermediate shell), not `claude`. The "Bash tool $PPID = claude main" qualifier in state.json reveals the measurement was taken from a Claude-turn context, not a hook context — these are architecturally different process hierarchies. Five findings across all three lenses (C1, C9, M5, H2, IF1 cascade) converge on this single root flaw, which propagates into a deterministic failure mode. Compounded by four post-migration consumer-breakage sites (M1-M4) and an unhandled `source: "clear"` branch. The fix is not a discard — design direction is sound and empirical findings are real. But WU1's helper design must be expanded with a process-tree-traversal function (or switched to session_id-keyed markers) BEFORE WU2-WU5 can be correctly written. Regression target: **specify** (Stage 2). Re-validate Q2/Q3 empirically (SessionEnd stdin probe + compaction probe) before re-locking the spec.

## Findings Summary

| ID | Finding | Severity | Confidence | Disposition | Compound? |
|----|---------|----------|-----------|-------------|-----------|
| CF-1 | Hook PPID is sh (transient), not claude main — discovery key is structurally wrong | critical | 0.95 | escalate | Yes (IF1) |
| CF-2 | Sweep correctly deletes live session's marker because key sh-PID dies after hook | critical | 0.88 | escalate | Yes (IF1) |
| CF-3 | WU1 missing `epistemic_claude_main_pid()` function — no WU owns process-tree traversal | critical | 0.93 | mitigate | Yes (IF1) |
| CF-4 | Post-migration consumers treat directory as file: write/cat/-f/rm-f all break | critical | 0.95 | mitigate | Yes (IF2) |
| CF-5 | `source: "clear"` (compaction) unhandled — falls to startup branch, orphans preflight | high | 0.85 | mitigate | Yes (IF3) |
| CF-6 | Q2 declared resolved without empirical verification (no SessionEnd stdin probe) | high | 0.90 | mitigate | No |
| CF-7 | uuidgen fallback contradicts marker_anchor_decision — pairing breaks under fallback | high | 0.92 | mitigate | Yes (IF5) |
| CF-8 | PPID=1 edge case absent — recreates the original clobber bug on Docker/systemd | medium | 0.87 | mitigate | No |
| CF-9 | Rollback Step 2 silently fails — directory blocks file-write after revert | high | 0.97 | mitigate | Yes (IF5) |
| CF-10 | FM4 inline-fallback requirement not tracked in any WU; CREATE path uncovered | high | 0.92 | mitigate | Yes (IF2) |
| CF-11 | AC4 grep commands invalid (no -r), count wrong (13 vs 9), exclusion unspecified | medium | 0.95 | mitigate | Yes (IF4) |
| CF-12 | OQ1 declared open while spec body locks SessionStart in 3 sections | medium | 0.85 | mitigate | No |
| CF-13 | "Two SessionStart hooks impossible" contradicts WU2 resume handler | medium | 0.90 | mitigate | No |
| CF-14 | Migration race ENOENT path unhandled when two sessions detect legacy file | medium | 0.82 | watch | No |
| CF-15 | test.sh has no syntax/shellcheck/Category-5 coverage for sourced helper | medium | 0.97 | mitigate | Yes (IF4) |
| CF-16 | TESTED/VERIFIED vocabulary inconsistent — OQ4 simulation fidelity unproven | medium | 0.78 | mitigate | No |
| CF-17 | docs/PLANNING-STORAGE.md missing from change table | low | 0.99 | mitigate | No |
| CF-18 | AC9 stage off-by-one (Stage 6 = review, not test); WU9 missing WU3 dep | low | 0.85 | mitigate | No |
| CF-19 | describe.md says "7 hooks" but enumerates 9 | low | 0.95 | mitigate | No |
| CF-20 | scope-drift: describe.md placed sweep at SessionEnd; spec moved to SessionStart silently | low | 0.85 | accept | No |

## Unresolved Tensions

- **PPID resolution path** (GAP from Correctness Clash): two valid fixes for IF1 (process-tree traversal vs session_id-keyed), materially different correctness/performance properties. Refine was skipped (Standard tier); Stage 2 specify must pick one.
- **H1 severity** (Coherence vs Correctness Clash): is OQ1-decided-but-marked-open critical (challenger wastes effort) or medium (sophisticated reviewers check WUs)? Unresolved at 0.72 rebuttal confidence.
- **C7 severity** (Correctness vs Coherence Clash): is docs/PLANNING-STORAGE.md change-table omission an inventory gap or just authoring oversight? Unresolved.
- **C8 vs C1/C9** (Coherence Clash rebuttal): C8's "FALSE" verdict on the sweep-race is unconditional, but Coherence rebutted it as conditional on C1's status. If C1 holds, the race reappears in different form (sweep deletes orphan sh-PID before postflight fires).

## Direction (Not Implementation)

- **CF-1, CF-2, CF-3 (IF1)**: Commit to ONE PPID-resolution approach (process-tree traversal OR session_id-keyed). Re-probe BOTH hook-context PPID and Bash-tool-context PPID in same session. Update state.json "CONFIRMED" line with context qualifier.
- **CF-4 (IF2)**: Expand WU5 to enumerate per-file fix types — read guard, write path, delete path — for each of M1-M4.
- **CF-5 (IF3)**: Run compaction probe; add explicit handler for `source: "clear"`; add default branch with stderr warning for unrecognized source values.
- **CF-6**: Run SessionEnd stdin probe before writing WU3 fallback code.
- **CF-7**: Resolve uuidgen contradiction — either remove fallback entirely or accept unpaired entry consequence and document.
- **CF-8**: Replicate session-end-cleanup.sh:18's PPID=1 guard in epistemic-marker.sh.
- **CF-9**: Rewrite Rollback Step 2 with mandatory cleanup commands; remove "optional" label from Step 3.
- **CF-10**: Either add inline-fallback to WU2/3/5 explicitly OR fold into WU1 helper graceful degradation path.
- **CF-11, CF-15, CF-18**: Rewrite AC4 with valid commands, correct count (9), specified exclusion. Fix AC9 stage. Add WU3 to WU9. Extend test.sh Categories 1+2+5 to cover scripts/epistemic-marker.sh.
- **CF-12, CF-13**: Close OQ1 as decided (SessionStart). Rewrite "two SessionStart impossible" row to acknowledge non-simultaneous multi-fire (startup→resume→clear).
- **CF-14**: Add Failure Modes row for migration race ENOENT — ENOENT means peer migrated first, proceed.
- **CF-16**: Resolve TESTED/VERIFIED vocabulary gap — either downgrade AC1-3,5-6 to VERIFIED or include OQ4 fidelity as Stage 7 prerequisite.
- **CF-17, CF-19**: Add docs/PLANNING-STORAGE.md to change table; fix describe.md "7 hooks" → "9".
- **CF-20**: One-line note in OQ1 traceability for SessionEnd→SessionStart sweep relocation.

```json
{
  "findings": [
    {
      "id": "CF-1",
      "summary": "Hook PPID is sh (transient intermediate), not claude main — discovery key structurally wrong",
      "source_findings": ["C1", "M5"],
      "agreement_count": 2,
      "severity": "critical",
      "confidence": 0.95,
      "false_known": true,
      "compound": true,
      "section": "Dependencies (Preconditions), Database/State Changes, Summary, state.json empirical_findings",
      "direction": "Commit to one PPID-resolution approach (process-tree traversal OR session_id-keyed). Re-probe both hook-context and Bash-tool-context PPID in same session. Update state.json 'CONFIRMED' with context qualifier.",
      "disposition": "escalate",
      "disposition_trigger": "A new probe showing hook PPID comm=claude (i.e., no sh intermediate) on the target environment would downgrade to medium; absent that evidence, structural redesign is required.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-2",
      "summary": "Sweep correctly deletes live session's marker because key sh-PID dies after hook completes",
      "source_findings": ["C9"],
      "agreement_count": 1,
      "severity": "critical",
      "confidence": 0.88,
      "false_known": false,
      "compound": true,
      "section": "Failure Modes, Database/State Changes, Work Units (WU2/WU3)",
      "direction": "Resolution flows from CF-1 — if PPID=claude-main is established (via traversal or content-addressed key), CF-2 collapses. No standalone fix needed.",
      "disposition": "escalate",
      "disposition_trigger": "CF-1 resolution. If CF-1 is rejected (sh-parent is stable and long-lived), CF-2 reduces to low severity.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-3",
      "summary": "WU1 missing epistemic_claude_main_pid() function — no WU owns process-tree traversal sub-problem",
      "source_findings": ["GAP-Completeness"],
      "agreement_count": 1,
      "severity": "critical",
      "confidence": 0.93,
      "false_known": false,
      "compound": true,
      "section": "Work Units (WU1), Dependencies",
      "direction": "If process-tree traversal is the chosen fix for CF-1, WU1 must add a fourth function (epistemic_claude_main_pid) that walks /proc/$PPID/status PPid until comm=claude or depth cap. If session_id-keyed is chosen, WU1 instead needs a by-PID index file design. Either way, WU1 expands before WU2-WU5 can be implemented correctly.",
      "disposition": "mitigate",
      "disposition_trigger": "CF-1 resolution path determines which WU1 expansion is needed.",
      "addressed": "needs-new-section"
    },
    {
      "id": "CF-4",
      "summary": "Post-migration consumers treat directory as file: printf > path, cat path, [ -f path ], rm -f path all break",
      "source_findings": ["M1", "M2", "M3", "M4", "IF2"],
      "agreement_count": 5,
      "severity": "critical",
      "confidence": 0.95,
      "false_known": false,
      "compound": true,
      "section": "Work Units (WU5), Failure Modes, Files/Components Touched",
      "direction": "Expand WU5 from 'reads marker via helper' to enumerate per-file fix types: (a) read-guard replacement [-f → helper existence check], (b) write replacement [printf → helper write], (c) cat replacement [→ helper read], (d) delete replacement [rm -f → helper scoped delete]. State per-file which operations apply.",
      "disposition": "mitigate",
      "disposition_trigger": "Spec rewrite of WU5 with per-file enumeration; verification via spec-blind grep that no command bash block retains the old patterns.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-5",
      "summary": "source: 'clear' (compaction) unhandled — falls to startup branch, orphans preflight on every /compact",
      "source_findings": ["M9", "C3", "IF3"],
      "agreement_count": 3,
      "severity": "high",
      "confidence": 0.85,
      "false_known": false,
      "compound": true,
      "section": "Failure Modes, Database/State Changes, Work Units (WU2)",
      "direction": "Run a compaction probe before locking spec. Add explicit handler for source='clear' (likely same as resume — preserve session_id). Add default branch with stderr warning for unrecognized source values; treat as startup but log divergence.",
      "disposition": "mitigate",
      "disposition_trigger": "Compaction probe artifact (probe-sessionstart-compact.log) showing observed source value, plus WU2 handler covering it.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-6",
      "summary": "Q2 declared resolved without empirical verification — no SessionEnd stdin probe exists",
      "source_findings": ["H2", "C2"],
      "agreement_count": 2,
      "severity": "high",
      "confidence": 0.90,
      "false_known": true,
      "compound": false,
      "section": "Dependencies (Q2 resolved), Work Units (WU3)",
      "direction": "Run SessionEnd stdin probe; archive probe-sessionend-stdin.log. Confirm field name, JSON structure, presence. Write WU3's stdin fallback against verified contract. Q2 re-resolution must answer the original empirical question, not substitute a workaround.",
      "disposition": "mitigate",
      "disposition_trigger": "Probe artifact exists and Q2 wording reflects verified vs assumed.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-7",
      "summary": "uuidgen fallback contradicts marker_anchor_decision — pairing breaks under fallback",
      "source_findings": ["GAP-Coherence"],
      "agreement_count": 1,
      "severity": "high",
      "confidence": 0.92,
      "false_known": true,
      "compound": true,
      "section": "Failure Modes (stdin-missing row), Database/State Changes, state.json marker_anchor_decision",
      "direction": "Resolve contradiction: either (a) remove uuidgen fallback entirely — if stdin parse fails, hook continues fail-open with NO marker, postflight skips with explicit warning; or (b) accept that uuidgen fallback creates unpaired entry and document consequence. Current spec asserts both 'no need for uuidgen' AND 'fall back to uuidgen.'",
      "disposition": "mitigate",
      "disposition_trigger": "Spec picks one path and removes the contradicting language.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-8",
      "summary": "PPID=1 edge case absent from helper — recreates original clobber bug on Docker/systemd hosts",
      "source_findings": ["M6", "C10"],
      "agreement_count": 2,
      "severity": "medium",
      "confidence": 0.87,
      "false_known": false,
      "compound": false,
      "section": "Database/State Changes, Failure Modes",
      "direction": "Replicate session-end-cleanup.sh:18's PPID=1 guard in epistemic-marker.sh. Use $USER-$(pwd | md5sum | cut -c1-8) suffix when PPID=1. Document in helper file header that this matches existing toolkit convention.",
      "disposition": "mitigate",
      "disposition_trigger": "Helper code includes PPID=1 guard with documented rationale.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-9",
      "summary": "Rollback Step 2 silently fails — directory blocks file-write after revert",
      "source_findings": ["M10", "IF5"],
      "agreement_count": 2,
      "severity": "high",
      "confidence": 0.97,
      "false_known": true,
      "compound": true,
      "section": "Rollback Plan (Step 2, Step 3)",
      "direction": "Rewrite Step 2 from 'no action needed' to mandatory step: 'rm -rf ~/.claude/.current-session/ && echo cleaned'. Remove 'optional' label from Step 3. Add Failure Modes row for post-revert directory-blocks-file write.",
      "disposition": "mitigate",
      "disposition_trigger": "Rollback Plan section explicitly enumerates the cleanup as mandatory with concrete safe commands.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-10",
      "summary": "FM4 inline-fallback requirement floats with no WU ownership; CREATE path uncovered",
      "source_findings": ["H6", "M1-extension"],
      "agreement_count": 2,
      "severity": "high",
      "confidence": 0.92,
      "false_known": false,
      "compound": true,
      "section": "Failure Modes (FM4), Work Units (WU2/WU3/WU5)",
      "direction": "Either add inline-fallback responsibility to WU2/3/5 descriptions explicitly, OR fold the fallback into WU1 helper as a graceful no-op degradation path that all sourcers inherit. Distinguish CREATE path from READ path — currently only READ is covered; the create-fallback in /epistemic-preflight command writes via the old single-file path.",
      "disposition": "mitigate",
      "disposition_trigger": "Each WU description references which fallback responsibility it owns.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-11",
      "summary": "AC4 grep commands invalid (no -r flag), count wrong (13 vs 9), exclusion unspecified",
      "source_findings": ["H3", "H4", "H9", "C5"],
      "agreement_count": 4,
      "severity": "medium",
      "confidence": 0.95,
      "false_known": true,
      "compound": true,
      "section": "Success Criteria (AC4)",
      "direction": "Replace grep -c <dirs> with grep -rl ... | wc -l or equivalent. Specify exclusion as concrete pipeline (| grep -v 'legacy\\|migration') or enumerate file+line exceptions. Recount readers from WU file list (9, not 13).",
      "disposition": "mitigate",
      "disposition_trigger": "AC4 rewritten with executable shell commands and correct count.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-12",
      "summary": "OQ1 declared open while spec body locks SessionStart in three sections",
      "source_findings": ["H1", "H7"],
      "agreement_count": 2,
      "severity": "medium",
      "confidence": 0.85,
      "false_known": true,
      "compound": false,
      "section": "Open Questions (OQ1) vs Files/Components Touched, WU2, Failure Modes",
      "direction": "Close OQ1 explicitly: 'Decided: SessionStart, rationale: synchronous gate before write.' Remove 'decision can flip' hedge. Note traceability: describe.md placed sweep tentatively at SessionEnd; spec moved to SessionStart with rationale.",
      "disposition": "mitigate",
      "disposition_trigger": "OQ1 reframed as a closed decision with rationale and traceability note.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-13",
      "summary": "'Two SessionStart hooks fire simultaneously' labeled impossible but WU2 explicitly handles resume firing a second SessionStart",
      "source_findings": ["C4"],
      "agreement_count": 1,
      "severity": "medium",
      "confidence": 0.90,
      "false_known": true,
      "compound": false,
      "section": "Failure Modes",
      "direction": "Rewrite the row: one process CAN fire multiple SessionStart hooks (startup, resume, possibly clear) but never simultaneously — handled by WU2's source-branching. Remove the 'impossible' label.",
      "disposition": "mitigate",
      "disposition_trigger": "Failure Modes row updated to acknowledge multi-fire non-simultaneous case.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-14",
      "summary": "Migration race ENOENT path unhandled when two sessions detect legacy file simultaneously",
      "source_findings": ["M7", "C6"],
      "agreement_count": 2,
      "severity": "medium",
      "confidence": 0.82,
      "false_known": false,
      "compound": false,
      "section": "Database/State Changes (Migration), Failure Modes",
      "direction": "Add Failure Modes row for migration-race ENOENT. Specify behavior: ENOENT on rename means peer session migrated first, proceed to mkdir without error.",
      "disposition": "watch",
      "disposition_trigger": "If parallel-startup migration becomes a frequent path post-deployment, escalate to mitigate. For now, the failure mode is rare (first-install only) and fail-open semantics catch it.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-15",
      "summary": "test.sh Category 1, 2, 5 do not cover scripts/epistemic-marker.sh — broken helper passes test suite",
      "source_findings": ["M8", "IF4-extension"],
      "agreement_count": 2,
      "severity": "medium",
      "confidence": 0.97,
      "false_known": true,
      "compound": true,
      "section": "Work Units (WU12), Success Criteria (AC7)",
      "direction": "Extend test.sh Category 1 (bash -n) and Category 2 (shellcheck) to include scripts/epistemic-marker.sh. Extend Category 5 (no set -e, set +e present) to scripts sourced by hooks. Update WU12 to require these test.sh changes.",
      "disposition": "mitigate",
      "disposition_trigger": "test.sh extensions present and verified; AC7 covers them.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-16",
      "summary": "TESTED/VERIFIED vocabulary inconsistent — OQ4 simulation fidelity unproven yet AC1-3,5-6 labeled TESTED",
      "source_findings": ["GAP-Coherence-AC"],
      "agreement_count": 1,
      "severity": "medium",
      "confidence": 0.78,
      "false_known": false,
      "compound": false,
      "section": "Success Criteria (verification footnote), Open Questions (OQ4)",
      "direction": "Either (a) downgrade AC1-3, AC5-6 to VERIFIED until OQ4 simulation fidelity is established; or (b) treat OQ4 simulation fidelity validation as an explicit Stage 7 prerequisite and ship a worked example before behavioral evals are written.",
      "disposition": "mitigate",
      "disposition_trigger": "Vocabulary footnote and OQ4 reconciled into a single coherent statement of what TESTED means in this spec.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-17",
      "summary": "docs/PLANNING-STORAGE.md missing from change table — will fail AC4 even after listed files updated",
      "source_findings": ["C7"],
      "agreement_count": 1,
      "severity": "low",
      "confidence": 0.99,
      "false_known": true,
      "compound": false,
      "section": "Files/Components Touched",
      "direction": "Add a prose-reference row for docs/PLANNING-STORAGE.md to the change table.",
      "disposition": "mitigate",
      "disposition_trigger": "File added to change table.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-18",
      "summary": "AC9 references Stage 6 (review) but means Stage 7 (test); WU9 missing WU3 dependency",
      "source_findings": ["H5", "H8"],
      "agreement_count": 2,
      "severity": "low",
      "confidence": 0.85,
      "false_known": false,
      "compound": false,
      "section": "Success Criteria (AC9), Work Units (WU9)",
      "direction": "Change AC9 'Stage 6' → 'Stage 7' for consistency with AC10. Add WU3 to WU9 depends_on list.",
      "disposition": "mitigate",
      "disposition_trigger": "Both edits applied.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-19",
      "summary": "describe.md says '7 hooks' but enumerates 9 — internal arithmetic inconsistency",
      "source_findings": ["H10"],
      "agreement_count": 1,
      "severity": "low",
      "confidence": 0.95,
      "false_known": true,
      "compound": false,
      "section": "describe.md Success Criteria",
      "direction": "Correct '7 hooks' to '9 hooks' OR remove audit-log consumers from the enumeration. Match number to enumeration.",
      "disposition": "mitigate",
      "disposition_trigger": "describe.md edit applied.",
      "addressed": "needs-update"
    },
    {
      "id": "CF-20",
      "summary": "Scope-drift: describe.md placed sweep tentatively at SessionEnd; spec silently moved to SessionStart",
      "source_findings": ["H7"],
      "agreement_count": 1,
      "severity": "low",
      "confidence": 0.85,
      "false_known": false,
      "compound": false,
      "section": "describe.md In Scope vs spec.md Files/Components Touched",
      "direction": "One-line note in OQ1 documenting the SessionEnd→SessionStart relocation with rationale ('sweep-before-write ordering required for correct isolation'). Traceability cleanup; subsumed by CF-12 fix.",
      "disposition": "accept",
      "disposition_trigger": "Subsumed by CF-12. No standalone change required.",
      "addressed": "already-in-spec"
    }
  ],
  "verdict": "REWORK",
  "verdict_rationale": "The spec contains a structurally critical empirical error (CF-1: state.json's 'PPID = claude main' CONFIRMED claim is measured from Bash-tool context, not hook context, where the probe shows PPID comm = sh) which propagates through CF-2 (sweep correctly deletes live marker because sh-PID dies) and CF-3 (no WU owns the process-tree traversal needed to fix it). This is reinforced by CF-4 (four post-migration consumer-breakage sites where commands still treat the directory as a file), CF-5 (compaction's source='clear' unhandled), and CF-6 (Q2 declared resolved without SessionEnd stdin probe). Five compound failure clusters (IF1-IF5) are real. The fix is not a discard — design direction (per-process markers) is sound, vault findings and three confirmed incidents are real, and probe artifacts exist. Regression to specify (Stage 2) is required to: (1) commit to one PPID-resolution approach (process-tree traversal vs session_id-keyed), (2) re-probe SessionEnd stdin and compaction's source value, (3) expand WU1 to include the chosen helper function, (4) enumerate per-file fixes in WU5 covering all four breakage modes, (5) resolve uuidgen contradiction, (6) rewrite Rollback Step 2 with mandatory cleanup, (7) fix AC4/AC9/WU9 quality issues. Regressing to describe (Stage 1) is not warranted — the problem framing and decomposition are correct; only the spec's empirical and structural commitments need revision.",
  "critical_count": 4,
  "false_known_count": 10,
  "compound_count": 10,
  "unresolved_tensions": [
    "PPID resolution path: process-tree traversal vs session_id-keyed marker — materially different correctness/performance properties; Refine was skipped (Standard tier); Stage 2 specify must pick one before WU1 can be expanded.",
    "H1 severity: critical (challenger wastes effort) vs medium (sophisticated reviewers check WUs) — rebuttal at 0.72 leaves unresolved.",
    "C7 severity: change-table omission an inventory gap or just authoring oversight? Coherence rebutted at 0.72; no resolution.",
    "C8 unconditional FALSE vs conditional FALSE: C8 declared the Orient sweep-race FALSE without acknowledging the verdict depends on C1's status. Coherence rebutted at 0.82. If C1 holds, the race reappears in different form (sweep correctly kills marker for dead sh-PID before SessionEnd). Underlying assumption difference: whether finding-correctness can be evaluated independently of upstream finding status."
  ],
  "uncovered_sections": [
    "Senior Review Simulation (no lens engaged this section directly; only adjacent references)",
    "Preservation Contract single-session behavior bullet (asserted; not probed under the new design)"
  ],
  "regression_target": "specify"
}
```

