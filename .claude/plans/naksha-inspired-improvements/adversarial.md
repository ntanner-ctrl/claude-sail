# Adversarial Findings: Naksha-Inspired Improvements

## Stage 3: Challenge (Debate Mode)

### Debate Summary

- **Challenger:** 24 findings (3 critical, 10 high, 8 medium, 3 low)
- **Defender:** Validated most, downgraded 3 (F3, F18, F23), added 7 new findings (M1-M7)
- **Judge verdict:** REGRESS — 4 critical findings require spec updates before proceeding

### Critical Findings (Must Resolve)

| ID | Finding | Convergence | Resolution Needed |
|----|---------|-------------|-------------------|
| F1 | Hardcoded counts in sail-doctor will rot. No single source of truth. | both-agreed | Derive counts dynamically from one canonical source (manifest or README parse) |
| F8/F12 | Context passing between pipeline steps is undefined. "2-5 sentence summary" has no injection contract, no mechanism, no failure mode. | both-agreed | New spec section: define exactly how output from step N becomes input to step N+1 |
| F9 | YAML parsing requires external dependency. Toolkit is no-dependency. | both-agreed | Define restricted YAML subset parseable with grep/sed/awk. Document parser approach. |
| F13 | $INPUT interpolation into shell commands is injection vector. | both-agreed | Prohibit shell interpolation. Specify stdin/temp-file handoff. |

### High Severity Findings (Should Resolve)

| ID | Finding | Convergence | Resolution |
|----|---------|-------------|------------|
| F2 | Settings drift comparison boundary undefined | both-agreed | Restrict to event-type keys only |
| F4 | MCP probe timeout unspecified | both-agreed | Add 5-second timeout |
| F10 | Pipeline search path shadow-attack | both-agreed | Document order, warn on shadow |
| F11 | on-error: ask undefined for non-interactive | both-agreed | Degrade to stop when no TTY |
| F17 | Evals change test suite contract (offline→online) | both-agreed | Gate on API key, skip with warning |
| F22 | WU4 is monolithic catch-all | both-agreed | Enumerate specific files |
| M3 | --quiet + --fix interaction undefined | newly-identified | Define precedence rules |
| M4 | install.sh overwrites user-modified stock pipelines | newly-identified | Use copy-if-not-exists pattern |

### Medium Severity Findings (Address in Spec Update)

| ID | Finding | Resolution |
|----|---------|------------|
| F3 | --fix could mislead users | Add "Review before running" header |
| F5 | Version alignment has no source | Create VERSION file or remove category |
| F6 | Target project detection underspecified | Define heuristic: check for .claude/CLAUDE.md |
| F14 | Confirmation UX undefined | Same TTY detection as F11 |
| F15 | Stock pipelines assume command availability | Add preflight command check at run time |
| F18 | Assertions flaky for LLM outputs | Define stability tiers for assertion types |
| F19 | evals/ not in install path | Document as dev-only, not distributed |
| F20 | Fixture format underspecified | Add example fixture to spec |
| F24 | New directories not in CLAUDE.md | Update CLAUDE.md architecture section |
| M1 | sail-doctor self-exclusion from ~/.claude/ | Add guard for toolkit install directory |
| M2 | /pipeline run has no audit trail | Add .claude/pipeline-runs.log |
| M5 | Evals are epistemically circular | Restrict to structural assertions, acknowledge limitation |
| M6 | MCP availability check invocation context | Clarify: Claude probes directly via tool calls, not shell |
| M7 | More count sources without governance | Use single canonical count source |

### Low Severity (Note and Continue)

| ID | Finding |
|----|---------|
| F7 | Status aggregation: overall = worst category |
| F16 | List shows both with provenance labels |
| F21 | Fixture count derived dynamically |
| F23 | Partial install is additive, acceptable risk |

---

## Stage 3 Re-Challenge (Debate Mode, Round 2 — Revised Spec)

### Debate Summary

- **Challenger R2:** 18 findings (2 critical, 6 high, 6 medium, 4 low)
- **Defender R2:** Validated 14, overstated 4 (F-R2-02→medium, F-R2-05→low, F-R2-08→low, F-R2-12→low), falsified 1 (F-R2-03), added 5 new findings (M-01 through M-05)
- **Judge R2 verdict:** REGRESS — 2 critical findings

### Critical Findings (Must Resolve)

| ID | Finding | Convergence | Resolution Needed |
|----|---------|-------------|-------------------|
| F-R2-01 | test.sh `set -e` aborts on behavioral smoke failure. `$()` exits parent before `$?` capture. | both-agreed | Use `|| eval_exit=$?` capture pattern |
| F-R2-M01 | Skill tool returns prose, not exit codes. Pipeline orchestrator can't reliably detect step failure. | newly-identified | Define structured output contract for step status detection |

### High Severity Findings (Should Resolve)

| ID | Finding | Convergence |
|----|---------|-------------|
| F-R2-04 | artifact mode has no path discovery mechanism | both-agreed |
| F-R2-06 | No post-step artifact existence validation | both-agreed |
| F-R2-07 | Stock pipelines never update (copy-if-not-exists) | both-agreed |
| F-R2-M03 | No recursion guard for self-referencing pipelines | newly-identified |
| F-R2-M04 | Stock pipelines global but stock hooks/agents per-project | newly-identified |

### Medium Severity (Address in Spec)

| ID | Finding |
|----|---------|
| F-R2-02 | Schema uniqueness contradicts shadow detection (rephrase) |
| F-R2-09 | .sail-counts.json missing stock-pipeline count |
| F-R2-10 | YAML validation in test.sh underspecified |
| F-R2-11 | Category 5 manifest check underspecified |
| F-R2-13 | Existing projects won't have .claude/pipelines/ |
| F-R2-14 | No max handoff length |
| F-R2-M02 | No pipeline lint subcommand |

### Low Severity (Note)

F-R2-03, F-R2-05, F-R2-08, F-R2-12, F-R2-15, F-R2-16, F-R2-17, F-R2-18, F-R2-M05

---

## Stage 3 Final Challenge (Debate Mode, Round 3 — Rev 3 Spec)

### Debate Summary

- **Challenger R3:** 5 findings (1 critical, 2 high, 2 medium)
- **Defender R3:** Validated 4, overstated 1 (F4→LOW). Downgraded F1 from CRITICAL to HIGH.
- **Judge R3 verdict:** PASS_WITH_NOTES — 0 critical, 6 notes to incorporate

### Judge Verdict: PASS_WITH_NOTES

No finding survives scrutiny at CRITICAL severity. All 6 findings close with 1-3 sentences each. Notes incorporated into spec revision 3 before advancing.

| ID | Finding | Judge Severity | Resolution |
|----|---------|---------------|------------|
| R3-F1 | behavioral-smoke.sh set -e kills on jq error | HIGH | No set -euo pipefail; explicit jq error handling |
| R3-F2 | copy-if-not-exists pattern underspecified | HIGH | Normative definition: skip + warn, never overwrite |
| R3-F3 | Missing $INPUT produces degraded output | MEDIUM | Warn + empty string substitution, don't abort |
| R3-F4 | lint uses installed path | LOW | No action (out of scope) |
| R3-F5 | Log write failure posture | MEDIUM | Non-fatal, warn and continue |
| R3-F6 | Pipeline name collision | LOW | Fail with error, don't overwrite |

---

## Stage 4: Edge Cases (Debate Mode)

### Summary

Boundary Explorer mapped ~60 boundaries across 12 clusters (input, state, concurrency, time). Stress Tester identified 10 priority issues. Synthesizer rated 3 as critical.

### Critical Edge Cases (Resolved in Rev 4)

| ID | Edge Case | Likelihood | Resolution |
|----|-----------|------------|------------|
| EC-01/09 | Recursion guard never cleared → blocks all subsequent pipeline runs in session | common | Clear flag on every exit path (success, failure, abort, interrupt) |
| EC-04 | Eval entry with missing assertions passes vacuously (0 checks = green) | uncommon | Require assertions array non-null and len >= 1; INVALID if missing |
| EC-07 | Silent-success commands misclassified as PARTIAL → spurious on-error | common | Add NOOP status category for legitimate no-output commands |

### High Edge Cases (Noted, not blocking)

| ID | Edge Case | Likelihood | Resolution |
|----|-----------|------------|------------|
| EC-03 | Artifact mode: multiple paths, wrong one selected | uncommon | Noted for implementation: prefer primary output convention |
| EC-05 | Malformed config JSON → cryptic jq error | uncommon | Implementation should wrap jq with error handling |
| EC-02 | 0-step pipeline vacuous success | rare | Runtime should enforce 2+ steps (defense-in-depth) |

### Medium/Low (Implementation Notes)

| ID | Edge Case | Note |
|----|-----------|------|
| EC-06 | Tabs in YAML → confusing "0 steps" error | Reject tabs explicitly in parser |
| EC-08 | No step timeout (architectural — deferred) | Document as known limitation for v1 |
| EC-10 | Concurrent audit log interleaving | Add run ID to log entries |

### Architectural Flag

EC-08 (step timeout) implies a new YAML field and enforcement logic. Deferred to post-v1 but recorded as a known gap. Retrofitting timeout semantics would be a breaking spec change.

---

## Stage 4.5: Pre-Mortem (Operational Failures)

### NEW Findings (not previously identified in Stages 3-4)

| ID | Finding | Priority | Recommendation |
|----|---------|----------|----------------|
| PM-01 | install.sh never writes .sail-counts.json — spec resolved read side (F1) but not write side | HIGH | R1: Add artifact generation to both install paths + test.sh assertion |
| PM-02 | No post-install verification path for users | MEDIUM | R6: Add "run /sail-doctor" message to install output |
| PM-03 | SessionEnd hook doesn't fire on SIGKILL — stale recursion guard | MEDIUM | R3: SessionStart checks for stale lock files via PID |
| PM-04 | Fixture rot with no update protocol | MEDIUM | R4: FIXTURE_DATE field + staleness warning |
| PM-05 | No install rollback path | MEDIUM | R5: Backup before copy, --rollback flag |

### COVERED Findings (already in spec from Stages 3-4)
- Shell injection: F13 ✓
- set -e abort: F-R2-01 ✓
- Recursion guard design: EC-01/09 ✓
- Shadow detection: F10 ✓
- Flag interaction: M3 ✓

### Key Observation
The operational failures are NOT design gaps — they're deployment gaps. The spec describes what exists and how it behaves, but install.sh and test.sh weren't spec'd with the same rigor as the commands themselves.

### Raw Debate Transcript

Preserved in `debate-log.md` for reference.
