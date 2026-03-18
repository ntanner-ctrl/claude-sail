# Specification Revision History

## Revision 1 (initial)
- Created: 2026-03-18
- Sections: Overview, Feature 1 (sail-doctor), Feature 2 (pipeline), Feature 3 (evals), Work Units, Work Graph, Acceptance Criteria
- Work Units: 4

## Revision 1 → Revision 2
- Trigger: Debate chain regression — 4 critical, 8 high findings
- Date: 2026-03-18

### Sections modified:
- **Overview**: Added revision history table, added CLAUDE.md to scope
- **Feature 1 - Category 1 (File Counts)**: Replaced hardcoded counts with dynamic `.sail-counts.json` derivation [F1]
- **Feature 1 - Category 3 (Settings Drift)**: Defined explicit comparison boundary — event-type keys only [F2]
- **Feature 1 - Category 4 (MCP)**: Defined probe mechanism (Claude tool calls, not shell), timeout via tool availability [F4, M6]
- **Feature 1 - Category 5 (Target Project)**: Defined detection heuristic (`.claude/CLAUDE.md`), added self-exclusion guard [F6, M1]
- **Feature 1 - Category 6 (Version)**: Introduced `VERSION` file at repo root, `install.sh` copies to `~/.claude/.sail-version` [F5]
- **Feature 1 - --fix flag**: Added safety warnings, commented-out commands, "Review before running" header [F3]
- **Feature 1 - --quiet flag**: Defined --quiet + --fix interaction rules [M3]
- **Feature 1 - Summary**: Defined status aggregation rules [F7]
- **Feature 2 - File Format**: Replaced "YAML" with "restricted line-oriented subset", defined grep/sed/awk parser approach [F9]
- **Feature 2 - Field definitions**: Added input handling (no shell interpolation), non-interactive ask fallback, command preflight [F13, F11, F15]
- **Feature 2 - Context Passing**: Complete rewrite — defined structured handoff blocks, `context` vs `artifact` modes, preservation rules [F8, F12]
- **Feature 2 - Search path**: Added shadow detection warning [F10]
- **Feature 3 - Purpose**: Clarified offline/deterministic contract, acknowledged circular validation limitation, defined evals as dev-only, added assertion stability tiers [F17, M5, F19, F18]

### Sections added:
- **Pipeline Audit Trail**: `.claude/pipeline-runs.log` with timestamped entries [M2]
- **Stock pipeline upgrade safety**: copy-if-not-exists pattern [M4]
- **Revision History table** in Overview

### Work units affected:
- WU2 (pipeline): complexity upgraded low→high due to context passing contract and line-oriented parser
- WU4 (shared updates): scope explicitly enumerated per file, added VERSION file and .sail-counts.json generation, added CLAUDE.md update [F22, F24, M7]

### Adversarial findings addressed: 26/30
- Critical: 4/4 (F1, F8/F12, F9, F13)
- High: 8/8 (F2, F3→medium, F4, F10, F11, F17, F22, M3, M4)
- Medium: 11/14 (F5, F6, F14, F15, F18, F19, F24, M1, M2, M5, M6, M7)
- Low: noted, not spec'd (F7, F16, F21, F23)
- Remaining: F20 (fixture example — will be self-evident from implementation)

## Revision 2 → Revision 3
- Trigger: Debate R2 regression — 2 critical, 5 high findings
- Date: 2026-03-18

### Sections added:
- **Step Status Detection Contract** — defines how pipeline orchestrator detects step success/failure from natural language output (PASS/FAIL/PARTIAL classification) [F-R2-M01]
- **Pipeline lint subcommand** — `/pipeline lint <name>` validates schema without executing [F-R2-M02]
- **Recursion guard** — prevents `/pipeline run` from being called within a running pipeline [F-R2-M03]

### Sections modified:
- **test.sh Category 8**: Fixed set -e abort bug with `|| eval_exit=$?` pattern [F-R2-01]
- **behavioral-smoke.sh**: Added jq guard requirement [F-R2-08]
- **artifact mode**: Added semantic path discovery and post-step existence validation with fallback to context mode [F-R2-04, F-R2-06]
- **Stock pipeline upgrade**: Added toolkit-version comment header and staleness visibility in list output [F-R2-07]
- **Stock pipeline scope**: Documented intentional global-vs-per-project split with rationale [F-R2-M04]
- **Schema name field**: Changed "unique across all search paths" to "unique within its search path directory" [F-R2-02]
- **.sail-counts.json**: Added stock_pipelines count [F-R2-09]
- **Handoff length**: Added 2000 character max with truncation note [F-R2-14]
- **Bootstrap/existing projects**: pipeline run creates .claude/pipelines/ via mkdir -p on first use [F-R2-13]
- **Pipeline run Phase 0**: Added recursion guard and interactive-only note [F-R2-M03, F-R2-05]

### Round 2 findings addressed: 16/23
- Critical: 2/2 (F-R2-01, F-R2-M01)
- High: 5/5 after severity adjustment (F-R2-04, F-R2-06, F-R2-07, F-R2-M03, F-R2-M04)
- Medium: 6/7 (F-R2-02, F-R2-09, F-R2-10, F-R2-13, F-R2-14, F-R2-M02)
- Low: 3/9 noted (F-R2-05, F-R2-08, F-R2-M05 — remainder are implementation-level)
- Deferred: F-R2-11 (manifest hash check — existence-only is sufficient for v1), F-R2-12 (self-exclusion refinement — current approach is good enough)
