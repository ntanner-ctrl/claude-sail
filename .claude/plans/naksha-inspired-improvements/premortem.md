# Pre-Mortem: Naksha-Inspired Improvements

## Premise
These features were deployed two weeks ago and failed. Focus: operational failures only.

## Root Cause
install.sh artifact generation gap — .sail-counts.json spec'd as runtime dependency but never added to installer write step. Every first-run user hits missing-file fallback.

## Contributing Factors

| Factor | Classification | Impact |
|--------|---------------|--------|
| No post-install smoke test path for users | NEW | Users can't verify operational health after install |
| .sail-counts.json not in install manifest | NEW | F1 resolved read side; write side unspecified |
| SessionEnd hook doesn't fire on SIGKILL (recursion guard stale) | NEW (operational) | EC-01/09 covered design; abnormal termination recovery gap |
| Fixture rot with no update protocol | NEW (operational) | F18/M5 identified flakiness; remediation process undefined |
| No rollback path for bad releases | NEW | VERSION file added (F5) but recovery not addressed |

## Recommendations

### R1: Install-time artifact generation (HIGH PRIORITY)
install.sh must write .sail-counts.json and .sail-version in BOTH local and remote paths. Add test.sh assertion for presence.

### R2: sail-doctor self-bootstrap check
First action: verify own runtime artifacts exist. If missing, direct user to re-run install.sh. Graceful degradation, not crash.

### R3: Stale lock file recovery
session-sail.sh (SessionStart) should check for stale recursion guard files where owning PID no longer exists. Clear automatically.

### R4: Fixture rotation protocol
Add FIXTURE_DATE to evals.json entries. behavioral-smoke.sh warns (not fails) on fixtures > 30 days old. Annotate failures as STALE? vs REGRESSION based on command file modification dates.

### R5: Install rollback path
Backup ~/.claude/{commands,hooks,agents} to ~/.claude/.sail-backup-<date>/ before copying. Retain 7 days. Add --rollback flag.

### R6: Post-install verification message
install.sh final output: "Verify: start a Claude Code session and run /sail-doctor"

## Key Observation
Operational failures came from the gap between specification and deployment — the spec describes artifacts and behavior, but install.sh + test.sh weren't updated atomically with the spec. In a no-CI, no-staging toolkit, that gap is the primary operational risk surface.
