# Test Plan: Naksha-Inspired Improvements

Generated from spec (rev 4) without reading implementation. These are acceptance criteria that must pass before the blueprint is marked complete.

---

## T1: Structural Tests (verifiable by test.sh)

### T1.1: File existence and counts
```
[ ] commands/sail-doctor.md exists with description: field
[ ] commands/pipeline.md exists with description: field
[ ] commands/templates/stock-pipelines/ship-feature.yaml exists
[ ] commands/templates/stock-pipelines/quality-check.yaml exists
[ ] commands/templates/stock-pipelines/quick-fix.yaml exists
[ ] evals/evals.json exists and is valid JSON
[ ] evals/fixtures/ contains >= 5 .md files
[ ] scripts/behavioral-smoke.sh exists and is executable
[ ] VERSION file exists at repo root with semver content
[ ] test.sh CMD_EXPECTED updated to reflect new command count
```

### T1.2: Command frontmatter compliance
```
[ ] sail-doctor.md: description starts with "Use when" (Utility tier)
[ ] sail-doctor.md: no escape-hatch language (consider, might, optionally)
[ ] pipeline.md: description starts with "Use when" (Utility tier)
[ ] pipeline.md: no escape-hatch language
[ ] Both commands have allowed-tools in frontmatter
```

### T1.3: Stock pipeline validation
```
[ ] Each stock pipeline .yaml has: name, description, steps, on-error
[ ] Each name field is kebab-case (matches ^[a-z][a-z0-9-]*$)
[ ] Each on-error is one of: stop, continue, ask
[ ] Each step has: command, description
[ ] ship-feature.yaml has 4 steps
[ ] quality-check.yaml has 3 steps
[ ] quick-fix.yaml has 2 steps
[ ] Each stock pipeline has # toolkit-version: comment header
[ ] No tabs in any stock pipeline file (spaces only)
```

### T1.4: Behavioral smoke infrastructure
```
[ ] behavioral-smoke.sh does NOT contain "set -euo pipefail" or "set -e"
[ ] behavioral-smoke.sh contains jq guard (command -v jq)
[ ] behavioral-smoke.sh contains explicit error handling per jq call
[ ] evals.json: every entry has id, name, command, scenario, fixture, assertions
[ ] evals.json: every assertion has type and (value or values)
[ ] evals.json: no entry has empty assertions array
[ ] evals.json: all fixture paths reference files that exist in evals/fixtures/
```

### T1.5: Install integration
```
[ ] install.sh dry run: new commands land in ~/.claude/commands/
[ ] install.sh dry run: stock pipelines land in ~/.claude/commands/templates/stock-pipelines/
[ ] install.sh dry run: .sail-counts.json written to ~/.claude/
[ ] install.sh dry run: .sail-version written to ~/.claude/
[ ] install.sh dry run: stock pipelines use copy-if-not-exists (second run doesn't overwrite)
[ ] .sail-counts.json contains: commands, agents, hooks, hookify_rules, stock_total, stock_pipelines
[ ] .sail-counts.json values match actual installed file counts
```

---

## T2: Behavioral Tests (verifiable by behavioral-smoke.sh)

### T2.1: Assertion types work correctly
```
[ ] contains: "HEALTHY" found in sail-doctor-healthy fixture → PASS
[ ] contains-any: at least one of ["NEEDS ATTENTION", "UNHEALTHY"] in sail-doctor-drift → PASS
[ ] not-contains: "UNHEALTHY" NOT in sail-doctor-healthy → PASS
[ ] not-contains: "Full" NOT in describe-change-simple → PASS
[ ] min-headers: >= 2 "## " headers in each fixture → PASS
[ ] min-length: >= 200 chars in substantive fixtures → PASS
```

### T2.2: Edge cases in behavioral smoke
```
[ ] Missing fixture file → SKIP with warning (not FAIL)
[ ] Empty fixture file → SKIP with warning
[ ] Eval entry with missing assertions field → INVALID/FAIL (not vacuous PASS)
[ ] jq absent → script exits with clear message, exit 0
[ ] Malformed evals.json → per-entry error handling, no abort
```

### T2.3: test.sh Category 8 integration
```
[ ] Category 8 appears in test.sh output
[ ] If evals/ missing: graceful skip with warning
[ ] If jq missing: graceful skip with warning
[ ] If behavioral-smoke.sh fails: test.sh captures exit code (no set-e abort)
[ ] If behavioral-smoke.sh succeeds: pass count incremented
```

---

## T3: Spec Compliance Tests (manual verification in Claude session)

### T3.1: /sail-doctor behavior
```
[ ] Running /sail-doctor produces output with 6 diagnostic categories
[ ] Category 1 reads counts from .sail-counts.json (not hardcoded)
[ ] Category 2 compares settings.json hook entries against settings-example.json
[ ] Category 3 checks event-type keys only (not individual hook entries)
[ ] Category 4 probes MCP servers (informational, never affects status)
[ ] Category 5 detects bootstrapped project via .claude/CLAUDE.md presence
[ ] Category 5 self-excludes when run from ~/.claude/ or claude-sail repo
[ ] Category 6 compares .sail-version vs VERSION file
[ ] Overall status = worst non-informational category
[ ] --fix shows commented-out suggestions with safety warnings
[ ] --quiet suppresses passing checks
[ ] --quiet --fix shows failures + fixes, suppresses passes
[ ] Missing .sail-counts.json → graceful skip with message (not crash)
[ ] Malformed .sail-counts.json → graceful skip with message
```

### T3.2: /pipeline behavior
```
[ ] /pipeline list discovers pipelines from all 3 search paths
[ ] /pipeline list shows source column (stock/global/project)
[ ] /pipeline list shows all instances when shadows exist (no dedup)
[ ] /pipeline show <name> displays readable definition
[ ] /pipeline lint <name> validates all 7 checks
[ ] /pipeline lint catches: missing fields, non-kebab name, invalid on-error
[ ] /pipeline run <name> shows confirmation prompt before executing
[ ] /pipeline run <name> executes steps sequentially via Skill tool
[ ] /pipeline run validates all commands exist before execution (preflight)
[ ] Context mode: handoff block with 3-7 bullets, max 2000 chars
[ ] Artifact mode: file path in handoff, existence validated via Read tool
[ ] Artifact mode: falls back to context if file not found
[ ] Step status: PASS/FAIL/PARTIAL/NOOP correctly classified
[ ] NOOP: silent-success commands (nothing to do) classified as NOOP not PARTIAL
[ ] on-error: stop halts pipeline on failure
[ ] on-error: continue skips failed step, proceeds
[ ] on-error: ask prompts user for decision
[ ] Shadow warning displayed when project pipeline shadows stock/global
[ ] $INPUT with no input provided: warning + empty string (not abort)
[ ] Recursion guard: second /pipeline run in same session works (flag cleared)
[ ] Recursion guard: /pipeline run from within pipeline step → blocked
[ ] Audit trail: .claude/pipeline-runs.log written with timestamped entries
[ ] Audit trail: log write failure → warning, pipeline continues
[ ] .claude/pipelines/ created via mkdir -p on first use if missing
```

### T3.3: Cross-cutting
```
[ ] README.md updated with new commands and accurate counts
[ ] commands/README.md updated with new commands in correct categories
[ ] .claude/CLAUDE.md updated with evals/, scripts/, stock-pipelines/ in architecture
[ ] CLAUDE.md documents scripts/ vs hooks/ convention difference
[ ] bash test.sh passes with all new files and categories
[ ] install.sh --rollback or backup mechanism (PM-05, if implemented)
[ ] install.sh final output includes "run /sail-doctor" verification message (PM-02)
```

---

## T4: Pre-Mortem Recommendations Verification

These are operational recommendations from Stage 4.5. Not all may be implemented in v1 — check which were scoped in.

```
[ ] PM-01: install.sh writes .sail-counts.json (MUST — blocking)
[ ] PM-02: install.sh output includes verification message (SHOULD)
[ ] PM-03: SessionStart checks for stale recursion guard locks (SHOULD)
[ ] PM-04: Fixture rotation protocol with FIXTURE_DATE (COULD — defer to v2)
[ ] PM-05: Install backup/rollback path (COULD — defer to v2)
[ ] PM-06: Post-install verification message (SHOULD)
```

---

## Test Execution Strategy

**Automated (test.sh):** T1 and T2 — run `bash test.sh` and verify all categories pass.

**Manual (Claude session):** T3 — start a Claude Code session in a test project and run each command, verifying behavior matches spec.

**Pre-mortem (selective):** T4 — verify PM-01 (blocking), others as time permits.

**Gate:** All T1 + T2 tests must pass. T3 tests verified via spot-check during implementation. T4.PM-01 is blocking; others are stretch goals.
