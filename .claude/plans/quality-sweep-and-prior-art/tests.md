# Test Plan: quality-sweep-and-prior-art

## Test Strategy

This toolkit has no automated test suite. Verification is manual.
Tests are structured as: scenario → action → expected result → verification command (where applicable).

---

## T1: File Existence (Acceptance Criteria 12-15)

| Test | Action | Expected | Verify |
|------|--------|----------|--------|
| T1.1 | `ls commands/prior-art.md` | File exists | Exit code 0 |
| T1.2 | `ls commands/quality-sweep.md` | File exists | Exit code 0 |
| T1.3 | `grep -c "Prior Art Gate" commands/blueprint.md` | Returns 1 | Output = 1 |
| T1.4 | `grep -c "quality-sweep" commands/blueprint.md` | Returns >= 1 | Output >= 1 |
| T1.5 | Command count | 49 commands | `ls commands/*.md \| grep -v README \| wc -l` = 49 |

## T2: /prior-art — Standalone Behavior

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T2.1 | Basic invocation | `/prior-art "JWT token rotation"` in a JS project | Produces report with GitHub + npm candidates, build-vs-adopt recommendation |
| T2.2 | Scope=github only | `/prior-art "JWT" scope=github` | Searches GitHub only, skips package registries |
| T2.3 | Scope=packages only | `/prior-art "JWT" scope=packages` | Searches npm only, skips GitHub |
| T2.4 | No topic provided | `/prior-art` with no argument or context | Asks clarifying questions (problem, language/framework) |
| T2.5 | No results found | `/prior-art "extremely obscure nonexistent library xyz123"` | Reports "Build" with "No viable candidates found" |
| T2.6 | User override | `/prior-art` then say "I already know about express, skip" | Notes override in output |
| T2.7 | WebSearch unavailable | Invoke when WebSearch tool is not available | Reports "Search unavailable" and skips gracefully |

## T3: /prior-art — Blueprint Gate Behavior

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T3.1 | Gate fires on Standard path | Start `/blueprint test-feature`, complete Stage 1 | Prior-art gate runs before Stage 2 |
| T3.2 | Gate fires on Full path | Start `/blueprint test-feature --challenge=debate`, complete Stage 1 | Prior-art gate runs before Stage 2 |
| T3.3 | Gate skips on Light path | Start blueprint, get Light path triage | Prior-art gate does NOT fire, proceeds directly to Stage 7 |
| T3.4 | Adopt recommendation | Prior art finds a perfect-fit library | Prompts: "adopt (skip blueprint) or continue?" |
| T3.5 | Supersede then resume | Choose adopt, then later change state.json status to in-progress | If report >30 days old, prompts to re-run search |
| T3.6 | Cached result reuse | Run prior-art, complete gate, then re-enter Stage 1→2 | Offers to reuse report if <7 days old |
| T3.7 | Backward compat | Resume an existing blueprint that predates prior-art gate (no prior_art_gate key, stage >= 2) | Gate treated as legacy-skipped, no prompt |

## T4: /quality-sweep — Standalone Behavior

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T4.1 | Auto detection | `/quality-sweep` on a branch with changes | Detects base branch dynamically, lists changed files |
| T4.2 | Blueprint target | `/quality-sweep my-blueprint` where blueprint exists | Reads spec, scopes to blueprint work units |
| T4.3 | Missing blueprint | `/quality-sweep nonexistent-name` | Error: "Blueprint not found", lists existing blueprints |
| T4.4 | Empty diff | `/quality-sweep` with no changes | "No changes detected. Nothing to sweep." |
| T4.5 | Not a git repo | `/quality-sweep` outside any git repo | Error: "Not a git repository. Provide a directory or blueprint name." |
| T4.6 | Report-only mode | `/quality-sweep fix=report-only` | Produces findings report, does NOT dispatch fixes |

## T5: /quality-sweep — Reviewer Selection

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T5.1 | With spec | Blueprint context with spec.md | spec-reviewer is recommended |
| T5.2 | Without spec | Standalone or blueprint without spec.md | spec-reviewer is NOT recommended, note shown |
| T5.3 | Auth files changed | Files matching auth/crypto patterns changed | security-reviewer is recommended |
| T5.4 | No security signals | Only CSS/HTML files changed | security-reviewer is NOT recommended |
| T5.5 | User adjusts selection | Remove a recommended reviewer | Selection respected, removed reviewer not dispatched |
| T5.6 | All reviewers selected | User adds all 6 | All 6 dispatched (no hard cap on reviewer dispatch) |

## T6: /quality-sweep — Triage and Fix Dispatch

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T6.1 | Severity parsing (emoji) | Reviewer returns `🔴 CRITICAL: ...` | Parsed as severity=critical |
| T6.2 | Severity parsing (text) | Reviewer returns `high: ...` | Parsed as severity=high |
| T6.3 | No severity markers | Reviewer returns plain prose | Defaulted to severity=medium with flag |
| T6.4 | Deduplication | Two reviewers flag same file:line | One finding in triage, cross-referenced |
| T6.5 | Pre-dispatch validation | Finding references nonexistent file | Flagged as "[reference unverifiable]", excluded from fix dispatch |
| T6.6 | Pre-dispatch validation | Finding references line beyond file length | Flagged as "[reference unverifiable]", excluded from fix dispatch |
| T6.7 | Git checkpoint | User approves fixes | `git stash list` shows "quality-sweep-checkpoint" BEFORE agents dispatch |
| T6.8 | Same-file fixes | Two findings in same file approved | Fixed sequentially, not in parallel |
| T6.9 | Fix agent timeout | Fix agent exceeds 5 min (simulated) | Marked "fix failed", touched-files list emitted |
| T6.10 | Regression check | Fix applied, re-run reviewer | Only changed files re-reviewed |
| T6.11 | Regression cap | 2 regression cycles exhausted | Offers rollback to checkpoint or manual resolution |

## T7: /quality-sweep — Final Score

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T7.1 | Quality gate runs | Sweep completes | `/quality-gate` invoked, score displayed |
| T7.2 | Standalone mode | No blueprint context | Quality gate works without blueprint spec path |

## T8: Blueprint Wiring

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T8.1 | Stage 7 suggestion | Complete a blueprint through Stage 7 | `/quality-sweep [name]` appears first in post-implementation options |
| T8.2 | README entries | Check commands/README.md | Both commands listed in appropriate categories |
| T8.3 | README count | Check README.md | Command count reads 49 |

## T9: Enforcement Conventions

| Test | Scenario | Action | Expected |
|------|----------|--------|----------|
| T9.1 | prior-art description | `grep "^description:" commands/prior-art.md` | Process-Critical tier, no escape-hatch language |
| T9.2 | quality-sweep description | `grep "^description:" commands/quality-sweep.md` | Utility tier, no "ANY" quantifier, no escape-hatch |
| T9.3 | Lint check | `grep -rn "^description:.*\(consider\|might\|optionally\)" commands/prior-art.md commands/quality-sweep.md` | Returns nothing |

---

## Edge Case Tests (from Stage 4)

| Test | Edge Case | Expected |
|------|-----------|----------|
| T-EC-C | Git stash persistence | SHA in state.json AND stash labeled in `git stash list` |
| T-EC-D | Fix timeout partial edits | Touched-files log emitted with failure message |
| T-EC-I | Hallucinated file:line | Pre-dispatch validation catches, excludes from fix |
| T-EC-L | Pre-existing blueprint resume | Gate skipped with legacy-skipped status |
| T-EC-F | Prior-art cache age | run_at field present in state.json, used for 7-day comparison |

---

## Pre-Mortem Tests (from Stage 4.5)

| Test | Scenario | Expected |
|------|----------|----------|
| T-PM-3 | Emoji severity parsing | 🔴→critical, 🟡→high, 🔵→medium correctly parsed |
