# Pre-Mortem: epistemic-session-race

**Premise**: This fix shipped to all claude-sail users two weeks ago (notional date 2026-05-18). Today (2026-06-01) Nick discovered something is silently wrong with calibration data again. We are writing the operational post-mortem.

Focus: **OPERATIONAL failures** — deployment, monitoring, rollback, on-call, observability. Design failures (Stages 3) and boundary failures (Stage 4) are EXCLUDED — they have their own findings.

## Question 1 — Most Likely Single Cause

Three plausible top causes ranked by likelihood:

### PM-1 (high likelihood) — Silent helper-source failure on a corrupted install

**What happens**: User runs `bash install.sh` to update. Mid-install, network blip drops a chunk of `scripts/epistemic-marker.sh`. Tarball extract fails partway. User sees no error (or misses it). Subsequent SessionStart fires `source ~/.claude/scripts/epistemic-marker.sh`, which returns non-zero. Per the spec: hook exits fail-open with stderr warning, no marker written. **All subsequent sessions silently lose epistemic tracking.** No crash, no visible degradation — just unpaired entries piling up in epistemic.json.

**Why it's the top candidate**: Three ingredients align — silent failure, fail-open, no observability. The user has no dashboard to notice their last 2 weeks of calibration didn't pair.

**Status**: **NEW** — spec acknowledges this in FM ("Helper file missing → stderr warning") but does NOT track it as a recoverable monitored event. No alert path, no post-install verification.

### PM-2 (medium likelihood) — Marker dir on tmpfs cleared at reboot

**What happens**: User configures `$HOME/.claude/` on tmpfs (some power users do this for SSD wear reduction). Reboot wipes the marker directory. Next claude session works fine (writes new marker), but any sessions tracking via accumulated markers (resume case) lose state. More significantly: the LEGACY-`<TS>` migration backups disappear on reboot — silent loss of the only forensic record of pre-migration state.

**Status**: **PARTIALLY COVERED** — adversarial finding noted that `~/.claude/` can be on different filesystems, but tmpfs-specific behavior at reboot is not addressed. Spec assumes persistent storage for `~/.claude/`.

### PM-3 (medium likelihood) — Hook timing budget breach on slow IO

**What happens**: Process-tree traversal + orphan sweep + atomic write completes in <100ms on Nick's WSL2 SSD. On a user with `$HOME` on a slow NFS mount or encrypted filesystem with high syscall overhead, the SessionStart hook exceeds Claude Code's 2-second timeout. Hook is killed. Marker not written. Session proceeds without tracking. User sees no error.

**Status**: **PARTIALLY COVERED** — AC10 measures timing on Nick's instance only. Spec preservation contract says "<2s" but no continuous monitoring. The sweep (O(active session files)) could be slow if accumulated orphan markers reach hundreds (cf. PM-2 with non-cleaning tmpfs).

## Question 2 — Contributing Factors That Make It Worse

| Factor | How It Compounds |
|--------|------------------|
| **No installation success signal**: `install.sh` doesn't post-verify that `epistemic_get_session_id` returns non-empty after install | PM-1 fails silently because nobody tested the helper post-install |
| **No epistemic.json health check**: Nothing flags a high unpaired-session ratio | PM-1, PM-3 accumulate undetected |
| **Marker visibility absent from `/start`, `/dashboard`, `/status`**: Commands don't show "active marker file at <path>" | User has no organic way to see when tracking has degraded |
| **Cross-session correlation is the goal but failure is per-session**: A single broken session is invisible; the bug only manifests as "calibration data looks weird in week 3" | Long detection latency |
| **The bug we're fixing was discovered by user noticing**: We're replacing one silent failure mode with potentially others | Silent → silent transition risk |

## Question 3 — Early Warning Signs Missed During Planning

| Sign | What It Should Have Triggered |
|------|-------------------------------|
| Vault pattern note "silent-failure-as-operational-risk.md" was cited in Orient brief but not woven into Failure Modes | Spec should have a row: "Helper missing/corrupt — DETECTED HOW?" with explicit observability requirement |
| Three confirmed incidents in one day BEFORE the fix shipped | Suggests epistemic tracking is fragile by nature; rebuild should have monitoring built-in, not added later |
| User's own probe disconfirmed a load-bearing claim (rev1 PPID issue) | Pattern: empirical data was available but not weighed against prior commitment. If this happens once at design time, it can happen at rollout time too |
| `/proc` filesystem dependency is platform-specific | macOS/BSD users will hit silent degradation; spec acknowledges this but treats it as "out of scope" — operationally that's the same as "ignored at rollout" |

## Question 4 — Recommended Changes

| Change | Section | Status |
|--------|---------|--------|
| **PM-Fix-1**: Add post-install verification in `install.sh` — after copying files, run a dry-run of `epistemic_get_session_id` and confirm it returns either a value or an explicit empty (not a source error). Print explicit "✓ epistemic-marker.sh installed and sourceable" line. | install.sh / WU12 | **NEW** — spec recommends but doesn't track |
| **PM-Fix-2**: Add a hookify rule or cron-style health probe: weekly check of epistemic.json's last 10 sessions; if >50% unpaired, surface a stderr warning at next SessionStart "Epistemic tracking may be degraded — N unpaired sessions in last week. Run sail-doctor." | new (out of scope?) | **NEW** — operational concern, would benefit a follow-up blueprint |
| **PM-Fix-3**: Extend `/start` and `/status` to show marker file path + freshness ("Marker: ~/.claude/.current-session/12345 (created 17:04Z, age 2m)"). Single-line addition; gives organic visibility. | WU5d (already touches /start) — could fold in | **NEW** — additive, low cost |
| **PM-Fix-4**: Spec must add explicit AC: "after install, `bash scripts/epistemic-smoke-test.sh` exits 0 AND outputs SESSION_ID=<value> for the current session." This is an installation-verification check, not just a test-suite check. | AC table | **NEW** — bridges install vs runtime gap |
| **PM-Fix-5**: Document the macOS/BSD silent degradation as a **stderr warning at SessionStart** (already drafted in NEW-3 patch). Confirm it's actually emitted. | WU2 — stderr warning text already specified | **PARTIALLY COVERED** — patch exists but operational verification (does the warning actually surface to user?) is open |

## Findings Classification

| Finding | Status | Disposition |
|---------|--------|-------------|
| PM-1 (silent corrupt install) | NEW | **Mitigate via PM-Fix-1, PM-Fix-4** — fold into WU12 |
| PM-2 (tmpfs reboot loss) | PARTIALLY COVERED | **Watch** — document as known limitation; not blocking |
| PM-3 (timing budget breach) | PARTIALLY COVERED | **Mitigate via PM-Fix-2** — out of scope for THIS blueprint, queue a follow-up |
| PM-Fix-3 (visibility in /start, /status) | NEW | **Mitigate** — fold into WU5d (additive line; trivial cost) |

## Overlap Detection (vs. adversarial.md)

| PM Finding | Overlap | Match |
|------------|---------|-------|
| PM-1 | CF-10 (FM4 inline-fallback) addressed code-path, not install verification | partial overlap — different angle |
| PM-2 | CF-3 traversal + cross-filesystem (E2) | adjacent; tmpfs-at-reboot is operational, not data-flow |
| PM-3 | AC10 (SessionStart timing) | covered as hardware-dependent VERIFIED, not operationally monitored |
| PM-Fix-3 | None — additive operational visibility | NEW |

Overlap ratio: 2/4 = 50%. Below the 0.8 high-overlap threshold. Pre-mortem is producing genuinely new operational findings, not echoing prior stages.

## Verdict

**No regression triggered.** PM findings are operational and additive. PM-Fix-1, PM-Fix-3, PM-Fix-4 are folded into existing WUs (WU12, WU5d) as one-sentence additions. PM-Fix-2 is a genuinely-new monitoring capability deferred to a follow-up blueprint. PM-2 documented as known limitation.

**Confidence**: 0.85. Pre-mortem produced 4 actionable items, 3 absorbable inline, 1 deferred. The biggest residual operational risk is "silent corrupt install" (PM-1) and the inline fix (post-install verification) is straightforward.

**Recommended next stage**: Stage 5 (Review) — optional, but worth a one-pass to catch what familiarity blinds us to. If skipping, advance to Stage 6 (Test).
