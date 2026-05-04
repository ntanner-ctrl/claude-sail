# Describe: epistemic-session-race

**Created:** 2026-05-01
**Source brief:** `~/.claude/projects/-home-nick-claude-sail/memory/project_epistemic_session_race.md`
**Vault evidence:** `Engineering/Findings/2026-05-01-current-session-marker-race-confirmed-incident.md`, `Engineering/Findings/2026-05-01-current-session-marker-single-file-race.md`

## Triage Result

**Change:** Replace the single-file `~/.claude/.current-session` marker with per-process (or per-Claude-session-ID) markers so concurrent Claude sessions don't clobber each other's epistemic tracking.

**Steps:** 7 discrete actions
**Risk flags:** User-facing behavior change · Deletion logic · Cross-cutting helper change
**Execution preference:** Simplicity (sequential)
**Recommended path:** Full

## Problem Statement

`~/.claude/hooks/epistemic-preflight.sh:48-53` unconditionally overwrites `~/.claude/.current-session` on every SessionStart. The justifying comment ("stale markers from crashed sessions are safe to replace") is correct for a single-active-session model but fails under parallel sessions: session B's preflight clobbers session A's marker, and session A's `/end` then reads the now-incorrect marker and writes its postflight under session B's ID — overwriting session B's postflight slot with session A's data.

This is **not theoretical**. It has been confirmed twice:
- **2026-05-01 (first incident):** parallel Claude session corrupted Nick's preflight entry; manual restore required (`/tmp/epistemic-race-snapshot.json`).
- **2026-05-01 (second incident, same day):** parallel `slims-device-updater` deploy session overwrote our test-debt-in-prism postflight slot; recovered via fresh `recovery-` prefixed session ID rather than overwriting the parallel session's data.

The brief was originally framed as "non-blocking severity — data is recoverable manually." Two strikes in one week elevates this to active recurring incident.

## Steps

1. **Investigate marker scheme** — Determine whether Claude Code exposes a stable per-session UUID via env at hook fire time (`$CLAUDE_SESSION_ID` or similar). If yes, prefer it over `$$` (PID), since postflight may run in a different shell process tree than preflight. Document finding before locking the design.
2. **Update `hooks/epistemic-preflight.sh`** — Write per-process/per-session marker instead of clobbering the global file. Preserve fail-open behavior (always exit 0).
3. **Update `hooks/epistemic-postflight.sh`** — Resolve its own per-process marker (not the global file). Scope marker cleanup (`rm -f`) to its own marker, not all markers.
4. **Update `hooks/_audit-log.sh`** — Central read helper, sourced by 6 other hooks (secret-scanner, anti-pattern-write-check, tdd-guardian, freeze-guard, protect-claude-md, dangerous-commands). Per-process resolution lives in the helper so call sites stay stable.
5. **Add orphan cleanup** — Sweep stale per-process markers older than N hours. Candidate homes: `session-end-cleanup.sh` (existing), or new sweep at SessionStart.
6. **Add behavioral eval** — Simulate two concurrent preflights and verify each session's postflight lands under its own preflight ID. Asserts the failure mode from the May 1 incidents, not merely "no data lost."
7. **Update `scripts/epistemic-smoke-test.sh`** — Existing tests reference the old marker path; align with the new scheme.

## In Scope

- Per-process or per-Claude-session-ID marker scheme (decision deferred to Stage 2 spec, after env-var investigation)
- Updates to `epistemic-preflight.sh`, `epistemic-postflight.sh`, `_audit-log.sh`
- Orphan cleanup of stale markers (likely SessionEnd or session-end-cleanup.sh)
- Behavioral eval simulating parallel preflights
- Update to `scripts/epistemic-smoke-test.sh`

## Out of Scope (Explicit)

- Survey of other hook issues (`project_hook_fixes_2026-03.md` is shipped; no current queue)
- Changes to `epistemic.json` schema (markers are routing, not data)
- Hookify rule to *detect* clobbers (paper cut over the structural fix)
- Backward-compat shim for old marker path (no external consumers; toolkit is fully versioned)

## Success Criteria

- Two concurrent Claude sessions can each submit preflight + postflight without cross-contamination of `epistemic.json` entries.
- All 7 hooks that read the marker (preflight, postflight, audit-log + 6 audit-log consumers) resolve to the correct per-session ID.
- Behavioral eval simulating concurrent preflights passes — each session's postflight task_summary lands under its own preflight values, not someone else's.
- `bash test.sh` continues to pass.
- Existing single-session usage shows zero behavior change (calibration feedback continues to fire normally on first read).

## Open Questions for Stage 2 (Spec Discovery)

The brief explicitly flagged these — they are spec-discovery items, NOT describe-stage items:

- **Q1 (env-var investigation, gates marker scheme decision):** Does Claude Code expose `$CLAUDE_SESSION_ID` (or similar) at SessionStart and SessionEnd hook fire time? If yes, that becomes the marker key. If no, fall back to `$PPID` or some derived per-shell-tree value.
- **Q2 (postflight discovery):** How does postflight find its own marker filename? It currently reads a global path; under per-process, it must compute from env or process ancestry. Verify postflight's process ancestry matches preflight's.
- **Q3 (cleanup ownership):** Where does the per-process marker live and who deletes it? `session-end-cleanup.sh` is the natural home but currently does not know about epistemic markers. Alternative: SessionStart sweep of markers older than N hours.
- **Q4 (test plan):** Behavioral eval design — fixture that simulates two parallel preflights and verifies postflight isolation. Pre-impl empirical gate per `feedback_pre_impl_gating_for_empirical_acs.md`.

These are pre-impl empirical gates, not spec assumptions. Stage 2 must validate Q1 before locking the marker scheme.

## Related

- Pre-session brief: `project_epistemic_session_race.md`
- Vault findings: `Engineering/Findings/2026-05-01-current-session-marker-race-confirmed-incident.md`, `Engineering/Findings/2026-05-01-current-session-marker-single-file-race.md`
- Memory: `feedback_pre_impl_gating_for_empirical_acs.md` (force pre-impl gates for AC the spec can't dictate)
- Memory: `feedback_verification_word_precision.md` (don't claim "verified" when the mechanism is text conformity)
