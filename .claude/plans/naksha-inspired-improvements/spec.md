# Specification: Naksha-Inspired Improvements (Revision 2)

## Revision History

| Rev | Date | Trigger | Changes |
|-----|------|---------|---------|
| 1 | 2026-03-18 | Initial spec | Full specification |
| 2 | 2026-03-18 | Debate R1 regression (4 critical, 8 high) | F1: dynamic counts, F8/F12: context passing contract, F9: restricted YAML subset, F13: input sanitization |
| 3 | 2026-03-18 | Debate R2 regression (2 critical, 5 high) | F-R2-01: test.sh set-e fix, F-R2-M01: step status detection contract, F-R2-04/06: artifact validation, F-R2-M03: recursion guard, F-R2-M02: lint subcommand |
| 4 | 2026-03-18 | Edge case regression (3 critical) | EC-01/09: recursion guard teardown, EC-04: vacuous PASS guard, EC-07: NOOP status category |

## Overview

Three new capabilities for claude-sail, inspired by naksha-studio analysis. All additive, no breaking changes.

**Scope boundaries:**
- IN: /sail-doctor command, /pipeline command, behavioral evals, CLAUDE.md updates
- OUT: scored quality rubrics, CI workflow templates, multi-platform templates (deferred to future work)
- UNCHANGED: existing commands, hooks, agents, test.sh structure (extended, not rewritten)

---

## Feature 1: `/sail-doctor` — Toolkit Health Check

### Purpose

Runtime self-diagnostic that validates claude-sail's installed state inside a Claude Code session. Positioned as **toolkit health** (not system health — that's `claude doctor`'s job).

### Command Definition

**File:** `commands/sail-doctor.md`

**Frontmatter:**
```yaml
description: Use when Claude Sail may have drifted, hooks aren't firing, or after re-installing. Validates toolkit integrity and suggests fixes.
argument-hint: --fix to show remediation steps, --quiet for pass/fail only
allowed-tools:
  - Read
  - Glob
  - Bash
  - Grep
```

**Enforcement tier:** Utility (`Use when...`)

### Diagnostic Categories

The command runs 6 categories of checks, presented sequentially:

#### Category 1: File Count Verification
Compare installed file counts against expected values.

**[F1 Resolution] Single source of truth for counts:**

Expected counts are derived dynamically — NOT hardcoded. The canonical source is `test.sh` in the claude-sail repo. At runtime, sail-doctor uses the following strategy:

1. **If claude-sail repo is accessible** (cwd is the repo, or `~/.claude/.sail-repo-path` exists pointing to it): parse expected counts from `test.sh` using `grep -oP '(?<=_EXPECTED=)\d+'` patterns.
2. **If repo is not accessible**: use a fallback counts file `~/.claude/.sail-counts.json` that `install.sh` writes during installation:
   ```json
   {"commands": 53, "agents": 6, "hooks": 18, "hookify_rules": 7, "stock_total": 12, "stock_pipelines": 3, "installed_at": "2026-03-18T00:00:00Z"}
   ```
   **[F-R2-09]** `stock_pipelines` count included to track pipeline files alongside other artifacts.
3. **If neither exists**: skip count verification with warning "Cannot determine expected counts — re-run install.sh to generate .sail-counts.json"

This eliminates the rot problem: `install.sh` stamps counts at install time from the actual file set, and test.sh remains the development-time source.

| Check | Expected Source | Location |
|-------|----------------|----------|
| Commands | `.sail-counts.json` or test.sh | `~/.claude/commands/*.md` (excluding README) |
| Agents | `.sail-counts.json` or test.sh | `~/.claude/agents/*.md` |
| Hooks | `.sail-counts.json` or test.sh | `~/.claude/hooks/*.sh` |
| Hookify rules | `.sail-counts.json` or test.sh | `~/.claude/hookify-rules/*.local.md` |
| Stock elements | `.sail-counts.json` or test.sh | `~/.claude/commands/templates/stock-*` |

**install.sh change required:** After copying files, write `.sail-counts.json` by counting the files just installed. This makes the counts self-updating — no manual sync needed.

**Output format per check:**
```
✓ Commands: 53 (expected 53)
✗ Hooks: 16 (expected 18) — 2 missing
```

#### Category 2: Hook Wiring Validation
Read `~/.claude/settings.json` (or `~/.claude/settings.local.json`) and verify:

1. All hooks referenced in settings-example.json exist in settings.json
2. All hook .sh files referenced in settings.json exist on disk
3. Hook .sh files are executable (`test -x`)

**Checks:**
- For each hook entry in settings-example.json, verify a matching entry exists in the user's settings.json (match by `command` path)
- For each hook path in user's settings.json, verify the file exists and is executable
- Report: "N/M expected hooks wired", list any missing

**Output format:**
```
✓ Hook wiring: 18/18 hooks from settings-example.json found in settings.json
✓ Hook files: all referenced .sh files exist and are executable
  OR
✗ Hook wiring: 16/18 — missing: secret-scanner.sh, tdd-guardian.sh
✗ Hook files: 2 referenced files not found: ~/.claude/hooks/missing-hook.sh
```

#### Category 3: Settings Drift Detection
Compare user's settings.json against settings-example.json for structural drift.

**[F2 Resolution] Explicit comparison boundary:**

The comparison operates at **event-type key level only**. Specifically:
- **Check:** Top-level keys under `"hooks"` in settings-example.json (e.g., `SessionStart`, `PreToolUse`, `PostToolUse`, `Stop`, `SessionEnd`, `Notification`) exist in user's settings.json
- **Do NOT check:** individual hook entries within an event type, matcher patterns, timeout values, array ordering, or any keys not under `"hooks"`
- **Do NOT flag:** user-added event types not in the example (these are intentional customization)

In short: "Are all expected event categories wired?" — not "Are all hooks identical?"

**Output:**
```
✓ Settings: all 6 event types from settings-example.json present
  OR
⚠ Settings drift: 2 event types missing from your settings.json
    - SessionEnd: not configured (example has session-end-cleanup.sh, session-end-vault.sh)
    - Stop: not configured (example has failure-escalation.sh)
```

#### Category 4: MCP Server Availability
Probe for MCP servers that claude-sail integrates with. These are informational — unavailability does NOT mark the toolkit unhealthy.

**Servers to probe:**
- Empirica: attempt `mcp__empirica__system_status` (if available)
- Context7: attempt `mcp__context7__resolve-library-id` with a known library (if available)
- Obsidian: check vault config via `source ~/.claude/hooks/vault-config.sh && echo $VAULT_ENABLED`

**Output:**
```
MCP Availability (informational):
  ✓ Empirica: connected
  ✗ Context7: not available
  ✓ Obsidian vault: /path/to/vault (enabled)
```

**[F4 Resolution] MCP probe timeout and mechanism:**

MCP probing happens **inside Claude's context** (this is a slash command, not a shell script). Claude attempts to call each MCP tool directly. The mechanism:
- Empirica: call `mcp__empirica__system_status` — if tool exists and responds, it's available
- Context7: call `mcp__context7__resolve-library-id` with `"react"` — if responds, available
- Obsidian: use Bash tool to run `source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo $VAULT_ENABLED`

**[F6/M6 Resolution]:** These are Claude tool calls, not shell invocations. If a tool doesn't exist in the session, Claude simply reports "not available" — there is no hanging probe. The Obsidian check uses a shell command with a 5-second timeout: `timeout 5 bash -c 'source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo $VAULT_ENABLED'`.

MCP results are **always informational** — they never affect the overall health status.

#### Category 5: Target Project Health (if in a project)

**[F6 Resolution] Detection heuristic:** A "bootstrapped project" is detected by the presence of `.claude/CLAUDE.md` in the current working directory. The mere existence of `.claude/` is insufficient (it could be plans-only). `.claude/CLAUDE.md` is the canonical marker left by `/bootstrap-project`.

**[M1 Resolution] Self-exclusion guard:** If `$PWD` equals `$HOME/.claude` or is a parent/subdirectory of the claude-sail source repo (detected via `git remote -v 2>/dev/null | grep -q "claude-sail"`), skip target project checks with: "Running from toolkit install/source directory — skipping target project checks."

If the current working directory has `.claude/CLAUDE.md` (indicating a bootstrapped project), check:

- `.claude/CLAUDE.md` exists
- `.claude/sail-manifest.json` or `.claude/bootstrap-manifest.json` exists
- Stock elements referenced in manifest are present
- No orphaned plan directories (plans with missing state.json)

**Output:**
```
Target Project: /home/user/my-project
  ✓ CLAUDE.md present
  ✓ Manifest: sail-manifest.json (bootstrapped 2026-03-10)
  ⚠ Orphaned plan: .claude/plans/abandoned-feature/ (no state.json)
```

If not in a project (no `.claude/` in cwd): `"Not in a bootstrapped project — skipping target project checks."`

#### Category 6: Version Alignment

**[F5 Resolution]:** This spec introduces a `VERSION` file at the repo root (e.g., `0.9.0`). `install.sh` copies it to `~/.claude/.sail-version`. sail-doctor compares the two.

- Read installed version from `~/.claude/.sail-version`
- If the claude-sail repo is the cwd, compare against `VERSION` in repo root
- If versions differ: `⚠ Version mismatch: installed 0.8.0, repo 0.9.0 — re-run install.sh`
- If `~/.claude/.sail-version` doesn't exist: `⚠ No version stamp — re-run install.sh to add`
- If not in repo: skip with note "Version check skipped (not in claude-sail repo)"

**New file required:** `VERSION` at repo root, updated manually on releases. `install.sh` copies it to `~/.claude/.sail-version`.

### `--fix` Flag Behavior

When `--fix` is passed, after each failing check, append numbered remediation steps:

```
✗ Hooks: 16 (expected 18) — 2 missing

  ⚠ Review these suggestions before running — they may overwrite
    customizations in your settings.json or hook files.

  Suggested fix:
    1. Re-run the installer: cd /path/to/claude-sail && bash install.sh
    2. Or manually copy missing hooks:
       # cp hooks/secret-scanner.sh ~/.claude/hooks/
       # cp hooks/tdd-guardian.sh ~/.claude/hooks/
       # chmod +x ~/.claude/hooks/secret-scanner.sh ~/.claude/hooks/tdd-guardian.sh
```

**[F3 Resolution]:** The `--fix` flag is diagnostic-only — it prints remediation steps but does NOT auto-patch. All suggested shell commands are **commented out** (prefixed with `#`) to prevent blind copy-paste execution. Each fix section includes a warning header: "Review these suggestions before running — they may overwrite customizations."

### `--quiet` Flag Behavior

Only output failing checks and the summary line. Passing checks are suppressed.

**[M3 Resolution] Flag interaction rules:**
- `--quiet` alone: suppress passing checks, show failures + summary only
- `--fix` alone: show all checks + remediation steps for failures
- `--quiet --fix`: show failures + remediation steps only (suppress passing checks, but DO show fix suggestions for failures). The summary line is always shown.
- Precedence: `--fix` wins over `--quiet` for failing checks (you always see the fix). `--quiet` suppresses passing checks regardless of `--fix`.

### Summary Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SAIL DOCTOR │ Toolkit Health Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. File Counts        ✓ All match
  2. Hook Wiring        ✗ 2 hooks not wired
  3. Settings Drift     ⚠ 1 event type missing
  4. MCP Availability   ✓ 2/3 connected (informational)
  5. Target Project     ✓ Healthy
  6. Version            — Skipped (not in repo)

  Status: NEEDS ATTENTION — 1 failure, 1 warning

  Run /sail-doctor --fix for remediation steps.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**[F7 Resolution] Status aggregation rules:**
- `HEALTHY`: All categories pass (✓)
- `NEEDS ATTENTION`: At least one warning (⚠) but no failures
- `UNHEALTHY`: At least one failure (✗)

Overall status = worst status across all non-informational categories. Category 4 (MCP Availability) is always informational and **never affects overall status**. Categories 1-3 and 5-6 contribute to aggregation.

---

## Feature 2: `/pipeline` — Declarative Workflow Chains

### Purpose

YAML-defined multi-step workflow orchestration. Chains existing claude-sail commands into repeatable sequences with context passing between steps.

### Command Definition

**File:** `commands/pipeline.md`

**Frontmatter:**
```yaml
description: Use when you want to run a predefined sequence of commands as a single workflow. Chains commands with context passing.
argument-hint: list | show <name> | run <name> [input]
allowed-tools:
  - Read
  - Glob
  - Bash
  - Grep
  - Skill
```

**Enforcement tier:** Utility (`Use when...`)

### Pipeline File Format

**[F9 Resolution] No YAML parser required.** Pipeline files use a **restricted line-oriented subset** of YAML that is parseable with `grep`, `sed`, and `awk`. The format is deliberately constrained:

- One key-value pair per line
- No multi-line strings
- No nested objects deeper than the `steps` array
- No YAML anchors, aliases, or advanced features
- Steps are identified by the `  - command:` pattern (2-space indent + dash)
- Step fields use 4-space indent

The `/pipeline` command parses these files using line-oriented POSIX tools, not a YAML library. This preserves the no-dependency constraint.

**Parsing approach:**
```bash
# Extract top-level fields
name=$(grep '^name:' "$file" | sed 's/^name: *//')
description=$(grep '^description:' "$file" | sed 's/^description: *//')
on_error=$(grep '^on-error:' "$file" | sed 's/^on-error: *//')

# Extract steps (each starts with "  - command:")
grep -n '  - command:' "$file"  # gives step line numbers
# Then extract fields between consecutive step lines
```

Pipelines are stored as these restricted-format files. Search order:
1. `.claude/pipelines/*.yaml` (project-specific, user-defined)
2. `~/.claude/pipelines/*.yaml` (global, user-defined)
3. `~/.claude/commands/templates/stock-pipelines/*.yaml` (shipped defaults)

**[F10 Resolution] Shadow detection:** When a project-local pipeline has the same name as a global or stock pipeline, `/pipeline run` displays a warning before the confirmation prompt:
```
⚠ Pipeline "ship-feature" from .claude/pipelines/ shadows
  the stock pipeline of the same name. Verify this is intentional.
```
The `list` subcommand shows **all** instances with provenance labels (not deduplicated), so users can see when shadowing occurs.

Project-specific pipelines take precedence over global, which take precedence over stock. This matches how `.claude/CLAUDE.md` overrides `~/.claude/CLAUDE.md`.

**Schema:**
```yaml
name: ship-feature                          # required, kebab-case
description: Plan, test, and push a feature # required, one line
steps:                                      # required, 2+ steps
  - command: describe-change                # required, command name (without /)
    args: "$INPUT"                          # optional, $INPUT = user's initial input
    description: "Triage the change"        # required, human-readable purpose
  - command: blueprint
    pass-output-as: context                 # optional: feed previous step's output as context
    description: "Full planning workflow"
  - command: test
    pass-output-as: context
    description: "Run test suite"
  - command: push-safe
    description: "Safe push with checks"
on-error: stop                              # required: "stop" | "continue" | "ask"
```

**Field definitions:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | kebab-case identifier, must be unique within its search path directory. [F-R2-02] Same name across different search paths triggers shadow warning, not an error. |
| `description` | string | yes | One-line human-readable description |
| `steps` | array | yes | 2+ step objects (single-step pipelines are just commands) |
| `steps[].command` | string | yes | Command name without `/` prefix |
| `steps[].args` | string | no | Arguments string. `$INPUT` is a placeholder (see Input Handling below). **[R3-F3]** If a step references `$INPUT` and no `[input]` was provided by the user, the pipeline runner MUST emit a warning before execution and substitute an empty string. It MUST NOT abort. |
| `steps[].pass-output-as` | string | no | `"context"` or `"artifact"` (see Context Passing Contract below) |
| `steps[].description` | string | yes | Human-readable purpose of this step |
| `on-error` | string | yes | `"stop"`, `"continue"`, or `"ask"` |

**[F13 Resolution] Input Handling — NO SHELL INTERPOLATION:**

`$INPUT` is a **placeholder token**, not a shell variable. The `/pipeline` command performs textual replacement of the literal string `$INPUT` with the user's input. This replacement happens inside Claude's context (in the markdown prompt), never in a shell command string.

- User input is passed to commands via the Skill tool's `args` parameter, which is a string argument to a Claude Code skill invocation — NOT a shell command.
- There is no `eval`, no backtick expansion, no shell interpolation at any point.
- The existing hook convention (`input=$(cat)` via stdin) is not applicable here because pipeline orchestration happens in Claude's context, not in bash.

**[F11 Resolution] Non-interactive `on-error: ask`:**

If `on-error: ask` is specified but the session is non-interactive (determined by Claude detecting it is in a background agent, subagent, or CI context), `ask` degrades to `stop`. The pipeline command checks this at the start of `run` and notes: "Non-interactive session detected: on-error 'ask' will behave as 'stop'."

**[F15 Resolution] Command availability preflight:**

At the start of `pipeline run`, verify all referenced commands exist:
```
for step in steps:
    glob ~/.claude/commands/{step.command}.md
    if not found: error "Step N references command '{step.command}' which is not installed"
```
This catches missing commands before execution begins, not mid-pipeline.

**Validation rules:**
- `name` must be kebab-case (`^[a-z][a-z0-9-]*$`)
- `steps` must have 2+ entries
- `command` must reference an existing command (validated at `run` time preflight, before execution)
- `on-error` must be one of: `stop`, `continue`, `ask`
- `pass-output-as` must be one of: `context`, `artifact` (or absent)
- `pass-output-as` on step 1 is ignored (no previous output)

### Subcommands

#### `/pipeline list`

Discover and display all available pipelines:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINES │ Available Workflows
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Name              Steps  Source     Description
  ─────────────────────────────────────────────────
  ship-feature      4      stock      Plan, test, and push a feature
  quality-check     3      stock      Sweep, gate, and review
  quick-fix         2      project    Describe and execute a small fix
  full-audit        5      global     Complete quality and security audit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Source column: `stock` (shipped), `global` (`~/.claude/pipelines/`), `project` (`.claude/pipelines/`)

#### `/pipeline show <name>`

Display a pipeline's definition in a readable format:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Description: Plan, test, and push a feature
  Steps: 4 │ On Error: stop
  Source: stock

  Step  Command           Context    Description
  ────────────────────────────────────────────────
  1     describe-change   $INPUT     Triage the change
  2     blueprint         ← step 1   Full planning workflow
  3     test              ← step 2   Run test suite
  4     push-safe         —          Safe push with checks

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### `/pipeline lint <name>` (or `/pipeline lint --all`)

**[F-R2-M02 Resolution]** Validate pipeline file(s) without executing:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE LINT │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ Required fields: name, description, steps, on-error
  ✓ Steps: 4 (minimum 2 ✓)
  ✓ All steps have command + description
  ✓ on-error value: stop (valid)
  ✓ Commands exist: describe-change, blueprint, test, push-safe

  Result: VALID
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Checks performed:**
1. Required top-level fields present (`name`, `description`, `steps`, `on-error`)
2. `name` is kebab-case
3. `steps` has 2+ entries
4. Each step has `command` and `description`
5. `on-error` is one of: `stop`, `continue`, `ask`
6. `pass-output-as` values are `context` or `artifact` (if present)
7. All referenced commands exist in `~/.claude/commands/`

`--all` validates every pipeline in all search paths.

**[F-R2-10 Resolution]** test.sh YAML validation for stock pipelines uses the same checks as `/pipeline lint`: grep for required fields, validate field values. Specifically:
```bash
for f in "$SCRIPT_DIR"/commands/templates/stock-pipelines/*.yaml; do
    name=$(basename "$f")
    grep -q '^name:' "$f" && grep -q '^description:' "$f" && \
    grep -q '^steps:' "$f" && grep -q '^on-error:' "$f" && \
    pass "$name — required fields present" || fail "$name — missing required fields"
done
```

#### `/pipeline run <name> [input]`

Execute a pipeline:

**Phase 0: Guards**

**[F-R2-M03 Resolution] Recursion guard:** Before any execution, check if we're already inside a pipeline run. The `/pipeline` command sets a context flag (tracked in Claude's conversation state) when it starts. If the flag is already set when `/pipeline run` is invoked, abort immediately:
```
Error: Recursive pipeline detected. /pipeline run cannot be called
from within a running pipeline. Restructure your workflow to avoid
pipeline nesting.
```
This prevents infinite recursion from a pipeline step that calls `/pipeline run`.

**[EC-01/EC-09 Resolution] Recursion guard teardown:** The recursion flag MUST be cleared on pipeline exit — whether the pipeline completes successfully, fails, is aborted by the user (Ctrl-C), or encounters any error. The flag is set at the start of Phase 0 and cleared at the end of Phase 4 (summary) or at any early-exit point. This is a finally-block pattern: every exit path clears the flag. Failure to clear the flag would block all subsequent pipeline runs in the same session.

**[F-R2-05 Resolution] Interactive-only note:** Pipelines require an interactive Claude Code session. They are not designed for headless, CI, or automated invocation.

**Phase 1: Resolution & Validation**
1. Locate pipeline YAML (search order: project → global → stock)
2. Parse and validate YAML against schema
3. Verify all referenced commands exist (glob `~/.claude/commands/<command>.md`)
4. Display execution plan and request confirmation:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE RUN │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  About to execute 4 steps:

    1. /describe-change "Add user avatar uploads"
    2. /blueprint (receives step 1 output as context)
    3. /test (receives step 2 output as context)
    4. /push-safe

  On error: stop (pipeline halts on first failure)

  Proceed? (Y/n)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Phase 2: Sequential Execution**
Execute each step by invoking the command via the Skill tool:
- Step 1 receives the user's `[input]` as its argument
- Subsequent steps with `pass-output-as: context` receive a preamble: "Previous step (`/command-name`) produced the following output, use it as context: [output summary]"
- Display progress after each step:

```
  ✓ Step 1/4: /describe-change — complete
  → Step 2/4: /blueprint — running...
```

**Phase 3: Error Handling**
When a step fails (command errors, user aborts mid-step):

| on-error | Behavior |
|----------|----------|
| `stop` | Halt pipeline. Show completed steps and remaining steps with instructions for manual continuation. |
| `continue` | Log warning, skip to next step. Note: next step won't receive failed step's output. |
| `ask` | Prompt user: `[1] Retry step [2] Skip and continue [3] Abort pipeline` |

**Phase 4: Summary**
After all steps complete (or pipeline halts):

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE COMPLETE │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓ Step 1: /describe-change
  ✓ Step 2: /blueprint
  ✓ Step 3: /test
  ✓ Step 4: /push-safe

  All 4 steps completed successfully.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Context Passing Contract

**[F8/F12 Resolution] This section defines the exact mechanism for passing output between pipeline steps.**

The `/pipeline run` command orchestrates by invoking each step's command via the Skill tool. Context passes between steps using one of two modes:

#### Mode 1: `pass-output-as: context` (default)

After step N completes, the `/pipeline` command writes a **structured handoff block** that is prepended to step N+1's invocation:

```
━━━ PIPELINE CONTEXT (from step N: /command-name) ━━━
Status: complete | failed
Key output:
  - [bullet 1: most important result]
  - [bullet 2: secondary result]
  - [bullet 3: if applicable]
Artifacts produced: [file paths, if any]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Who writes the handoff block:** Claude (the `/pipeline` command itself). After each step completes, the pipeline command inspects the step's output and produces the handoff block. This is an LLM summarization step — it runs inside Claude's context window, not in bash.

**What the handoff MUST preserve:**
- File paths produced or modified
- Pass/fail status
- Key decisions made (e.g., "Triage recommended Full path")
- Numeric values (counts, scores)

**What the handoff MAY drop:**
- Formatting, decorative output
- Intermediate reasoning
- Repeated context from earlier steps

**Handoff length:** 3-7 bullet points, maximum ~2000 characters. **[F-R2-14]** If the natural summary exceeds 2000 characters, truncate with a note: "[truncated — full output was N characters]". This prevents context bloat in long pipelines while preserving the most important information.

#### Mode 2: `pass-output-as: artifact`

For steps that produce a file-based artifact (e.g., `/blueprint` produces `spec.md`, `/describe-change` produces `describe.md`), `artifact` mode passes the **file path** instead of a summary.

**[F-R2-04 Resolution] Artifact path discovery:**

The pipeline orchestrator discovers artifact paths using **semantic inspection** — after the step completes, Claude identifies what file(s) the command produced by examining:
1. The command's output (most commands announce what they wrote, e.g., "Spec written to .claude/plans/feature-x/spec.md")
2. Known conventions (e.g., `/describe-change` within a blueprint always writes to `.claude/plans/<name>/describe.md`)

If the orchestrator cannot determine the artifact path, it falls back to `context` mode with a warning: "Could not determine artifact path — falling back to context summary."

This approach is appropriate because the orchestrator IS Claude — it understands command output semantics and project conventions. A rigid `artifact-path:` YAML field would be brittle (paths depend on runtime context like blueprint names).

**[F-R2-06 Resolution] Post-step artifact validation:**

After identifying the artifact path, the orchestrator MUST verify the file exists:
```
Use the Read tool to check if the artifact file exists.
If file does not exist:
  - Log warning: "Step N claimed artifact at <path> but file not found"
  - Fall back to context mode (summarize whatever output the step produced)
  - Mark step status as PARTIAL (not FAIL — the step may have succeeded at its primary task)
```

**Handoff format:**
```
━━━ PIPELINE ARTIFACT (from step N: /command-name) ━━━
Artifact: .claude/plans/feature-x/describe.md
Read this file for full context from the previous step.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

This avoids lossy summarization for commands that write structured output to disk. The next step reads the artifact file directly.

**When to use which:**
- `context`: for commands whose output is conversational (e.g., `/test`, `/quality-gate`)
- `artifact`: for commands that write plan files (e.g., `/describe-change`, `/blueprint`, `/spec-change`)

#### Context Scope

Context is **non-cumulative.** Each step receives only the immediately previous step's handoff, not the full chain. This prevents context bloat in long pipelines. If step 3 needs context from step 1, the pipeline should be restructured or step 2's handoff should carry forward the relevant information.

### Step Status Detection Contract

**[F-R2-M01 Resolution] This section defines how the pipeline orchestrator determines whether a step succeeded or failed.**

In Claude Code, slash commands return natural language — not exit codes. The pipeline orchestrator (Claude itself) cannot rely on process exit codes to detect step success. Instead, the orchestrator uses a **structured self-assessment** after each step completes.

**Mechanism:** After each step's command finishes executing, the `/pipeline` command performs a structured assessment:

```
After step N (/command-name) completed, assess:
1. Did the command produce its expected output type?
   (e.g., /describe-change → triage result, /test → pass/fail report)
2. Did the command indicate any errors, failures, or blockers?
3. Was the command's output substantive or did it abort early?

Based on this assessment, classify:
  PASS  — command completed its intended function
  FAIL  — command encountered an error, was blocked, or aborted
  PARTIAL — command completed but with warnings or incomplete results
```

**Status mapping:**
| Assessment | Pipeline behavior |
|------------|-------------------|
| PASS | Proceed to next step, pass context/artifact |
| FAIL | Trigger on-error handler (stop/continue/ask) |
| PARTIAL | Treat as PASS with a warning note in the handoff block |
| NOOP | Proceed to next step, no context passed (step had nothing to do) |

**[EC-07 Resolution]:** Commands that legitimately produce no substantive output (e.g., `/push-safe` when working tree is clean, `/test` when no tests exist) MUST be classified as NOOP, not PARTIAL. The assessment heuristic must distinguish "no output because nothing needed doing" (NOOP) from "no output because something went wrong" (PARTIAL/FAIL). Key signal: if the command's output explicitly states nothing was needed (e.g., "Nothing to push", "No tests found"), classify as NOOP. If the command produced no output at all with no explanation, classify as PARTIAL.

**Why this works:** The pipeline orchestrator IS Claude — it has full semantic understanding of each step's output. Unlike a bash pipeline where exit codes are the only signal, Claude can read the output of `/test` and determine whether tests passed or the command errored. This is actually *more* reliable than exit code detection for commands that succeed (exit 0) but report failures in their output (e.g., a test runner that exits 0 but reports 3 failing tests).

**Known limitation:** This is an LLM judgment call, not a deterministic check. A step that produces ambiguous output (e.g., partial success with warnings) requires Claude to make a classification decision. The PARTIAL status exists to handle this ambiguity explicitly rather than forcing a binary pass/fail.

**Fallback for ambiguous cases:** If Claude cannot confidently classify a step's status, it should:
1. Default to PARTIAL (not FAIL — avoid false negatives that halt pipelines unnecessarily)
2. Include the ambiguity in the handoff block: "Step status uncertain — output was [description]"
3. If `on-error: ask`, prompt the user for clarification

#### Failure Handling in Context

If step N fails and `on-error: continue` is set:
- Step N+1 receives: `"Previous step (/command-name) FAILED. No output available. Proceeding without context from that step."`
- The `pass-output-as` field is effectively nullified for the failed step.

### Stock Pipelines

Ship 3 example pipelines in `commands/templates/stock-pipelines/`:

#### `ship-feature.yaml`
```yaml
name: ship-feature
description: Plan, test, and push a feature
steps:
  - command: describe-change
    args: "$INPUT"
    description: "Triage the change and determine planning path"
  - command: blueprint
    pass-output-as: context
    description: "Run full planning workflow based on triage"
  - command: test
    pass-output-as: context
    description: "Verify implementation passes tests"
  - command: push-safe
    description: "Pre-push safety checks and push"
on-error: stop
```

#### `quality-check.yaml`
```yaml
name: quality-check
description: Run quality sweep, gate check, and optional review
steps:
  - command: quality-sweep
    args: "$INPUT"
    description: "Structured review sweep with all reviewer agents"
  - command: quality-gate
    pass-output-as: context
    description: "Score against quality rubric"
  - command: push-safe
    description: "Pre-push safety checks"
on-error: ask
```

#### `quick-fix.yaml`
```yaml
name: quick-fix
description: Fast path for small changes — triage then execute
steps:
  - command: describe-change
    args: "$INPUT"
    description: "Triage the change (expects Light path)"
  - command: test
    description: "Verify the fix passes tests"
on-error: stop
```

### Pipeline Audit Trail

**[M2 Resolution]** Every `pipeline run` execution appends a timestamped entry to `.claude/pipeline-runs.log` (in the current project directory, if bootstrapped) or `~/.claude/pipeline-runs.log` (global fallback):

```
[2026-03-18T14:32:00Z] pipeline=ship-feature steps=4 status=complete
  step1=/describe-change status=complete
  step2=/blueprint status=complete
  step3=/test status=complete
  step4=/push-safe status=complete

[2026-03-18T15:10:00Z] pipeline=quality-check steps=3 status=failed_at_step_2
  step1=/quality-sweep status=complete
  step2=/quality-gate status=failed
  step3=/push-safe status=skipped
```

**[R3-F5]** Failures to write pipeline-runs.log are non-fatal. The runner MUST emit a single warning and continue. Pipeline execution is not affected by log failures.

This is append-only, human-readable, and grep-able. The audit trail enables:
- Debugging failed pipeline runs (what completed, what didn't)
- `/sail-doctor` to check pipeline health (recent failures, common patterns)

### Bootstrap Integration

Update `commands/bootstrap-project.md` to:
1. Create `.claude/pipelines/` directory in target projects during bootstrap
2. Note in bootstrap output: "Created .claude/pipelines/ — add custom workflow YAML files here"
3. Stock pipelines remain in `~/.claude/commands/templates/stock-pipelines/` (NOT copied to projects — they're discovered via search path)

**[F-R2-13 Resolution] Existing project migration:** `/pipeline run` gracefully creates `.claude/pipelines/` via `mkdir -p` if it doesn't exist (before searching for project-local pipelines). This means existing projects bootstrapped before the pipeline feature work seamlessly — the directory is created on first use, not required in advance.

### Pipeline Directory in This Repo

Stock pipeline files live at `commands/templates/stock-pipelines/`. The installer copies them to `~/.claude/commands/templates/stock-pipelines/`.

**[M4 Resolution] Stock pipeline upgrade safety:** `install.sh` uses a **copy-if-not-exists** pattern for stock pipelines. **[R3-F2]** Normative definition: copy-if-not-exists means if the destination file already exists, skip the copy and emit a single-line warning to stdout. Never overwrite. Never prompt.

**[F-R2-07 Resolution] Staleness acknowledgment:** Stock pipelines are intentionally **user-owned after first install**. This is a deliberate design choice matching how stock hooks work. Each stock pipeline includes a `# toolkit-version: X.Y.Z` comment header. `/pipeline list` displays this version alongside the installed toolkit version from `.sail-version`, making staleness visible:
```
  ship-feature    4  stock (v0.9.0, toolkit v1.0.0 — update available)
```
Users who want updates can delete the stock pipeline and re-run `install.sh`. A `/pipeline update-stock` command is deferred to future work.

**[F-R2-M04 Resolution] Global vs per-project scope:** Stock pipelines are intentionally **global** (installed to `~/.claude/commands/templates/stock-pipelines/`), unlike stock hooks/agents which are per-project. This is because:
- Pipelines define *workflow sequences* that are toolkit-level, not project-level
- Project-specific pipelines go in `.claude/pipelines/` (per-project, user-defined)
- Stock pipelines are templates — users can copy a stock pipeline to `.claude/pipelines/` and customize it for a specific project

The search order (project → global → stock) ensures project customizations always win.

The `/pipeline` command's search path discovers them there.

---

## Feature 3: Behavioral Evals

### Purpose

Fixture-based testing of command reasoning quality. Extends the test suite to catch regressions in how commands behave, not just that they exist.

**[F17 Resolution] Test suite contract:** Behavioral evals are **offline, deterministic tests** against pre-captured fixtures. They do NOT invoke Claude or any LLM. The fixtures are manually curated markdown files representing expected output. The smoke script validates these files against structural assertions using grep/awk. This preserves test.sh's contract: fast, offline, no credentials required.

**[M5 Resolution] Circular validation acknowledged:** Fixtures represent "what good output looks like" as judged by humans at capture time. They test that the fixture hasn't been accidentally corrupted or deleted, and that the assertion definitions remain consistent with the fixtures. They do NOT test live Claude behavior. This is a **baseline integrity check**, not an LLM eval.

**[F19 Resolution] Install path:** Evals are **dev-only artifacts**. They are NOT copied by `install.sh` and are NOT part of the distribution. They exist in the repo for contributors running `bash test.sh` from a clone. The test.sh integration gracefully skips if `evals/` doesn't exist (which is the case for installed users).

**[F18 Resolution] Assertion stability tiers:**

| Tier | Assertion Types | Stability | Use For |
|------|----------------|-----------|---------|
| Structural | `min-headers`, `min-length` | High | Always — these rarely break |
| Keyword | `contains`, `contains-any`, `not-contains` | Medium | Section names, status values, command names |
| Pattern | `regex` | Low | Use sparingly — format-sensitive |

Fixtures should prefer structural and keyword assertions. Pattern assertions (`regex`) should only be used when the other types are insufficient.

### Architecture

```
evals/
├── evals.json          # Eval definitions with prompts + assertions
├── fixtures/           # Pre-captured reference outputs
│   ├── describe-change-simple.md
│   ├── describe-change-complex.md
│   ├── sail-doctor-healthy.md
│   └── ...
└── README.md           # Documents eval format and how to add new evals

scripts/
└── behavioral-smoke.sh # Validates fixtures against assertions
```

### Eval Format (`evals/evals.json`)

```json
[
  {
    "id": 1,
    "name": "describe-change-simple",
    "command": "describe-change",
    "scenario": "Single-file CSS color change, no risk flags",
    "fixture": "fixtures/describe-change-simple.md",
    "assertions": [
      {
        "type": "contains",
        "value": "Light",
        "description": "Should recommend Light path for trivial change"
      },
      {
        "type": "contains-any",
        "values": ["1-3", "1 step", "2 step", "3 step"],
        "description": "Should identify low step count"
      },
      {
        "type": "not-contains",
        "value": "Full",
        "description": "Should NOT recommend Full path for trivial change"
      },
      {
        "type": "min-headers",
        "value": 2,
        "description": "Output should have structured sections"
      },
      {
        "type": "min-length",
        "value": 200,
        "description": "Output should be substantive"
      }
    ]
  },
  {
    "id": 2,
    "name": "describe-change-complex",
    "command": "describe-change",
    "scenario": "14-step change with auth risk flag",
    "fixture": "fixtures/describe-change-complex.md",
    "assertions": [
      {
        "type": "contains",
        "value": "Full",
        "description": "Should recommend Full path for complex change"
      },
      {
        "type": "contains-any",
        "values": ["authentication", "authorization", "security"],
        "description": "Should identify auth-related risk flag"
      },
      {
        "type": "min-headers",
        "value": 3,
        "description": "Should have structured sections"
      }
    ]
  },
  {
    "id": 3,
    "name": "sail-doctor-healthy",
    "command": "sail-doctor",
    "scenario": "All checks pass, no MCP issues",
    "fixture": "fixtures/sail-doctor-healthy.md",
    "assertions": [
      {
        "type": "contains",
        "value": "HEALTHY",
        "description": "Should report healthy status"
      },
      {
        "type": "not-contains",
        "value": "UNHEALTHY",
        "description": "Should not report unhealthy"
      },
      {
        "type": "min-headers",
        "value": 2,
        "description": "Should have structured report sections"
      }
    ]
  },
  {
    "id": 4,
    "name": "sail-doctor-drift",
    "command": "sail-doctor",
    "scenario": "Settings drift detected, 2 hooks missing",
    "fixture": "fixtures/sail-doctor-drift.md",
    "assertions": [
      {
        "type": "contains-any",
        "values": ["NEEDS ATTENTION", "UNHEALTHY"],
        "description": "Should flag non-healthy status"
      },
      {
        "type": "contains",
        "value": "missing",
        "description": "Should identify missing hooks"
      },
      {
        "type": "contains",
        "value": "--fix",
        "description": "Should suggest --fix flag"
      }
    ]
  },
  {
    "id": 5,
    "name": "pipeline-list",
    "command": "pipeline",
    "scenario": "List available pipelines with stock defaults",
    "fixture": "fixtures/pipeline-list.md",
    "assertions": [
      {
        "type": "contains",
        "value": "ship-feature",
        "description": "Should list the ship-feature stock pipeline"
      },
      {
        "type": "contains",
        "value": "stock",
        "description": "Should show source column"
      },
      {
        "type": "min-length",
        "value": 100,
        "description": "Should be substantive output"
      }
    ]
  }
]
```

### Assertion Types

| Type | Fields | Behavior |
|------|--------|----------|
| `contains` | `value` (string) | Case-insensitive grep for value in fixture |
| `contains-any` | `values` (string[]) | At least one value found (case-insensitive) |
| `not-contains` | `value` (string) | Value must NOT appear in fixture |
| `min-headers` | `value` (int) | Count `^## ` lines, must be >= value |
| `min-length` | `value` (int) | Character count must be >= value |
| `regex` | `value` (string) | Extended regex match (`grep -Ei`) |

### Behavioral Smoke Script (`scripts/behavioral-smoke.sh`)

```bash
#!/bin/bash
# Validates eval fixtures against assertion definitions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
EVALS_FILE="$REPO_DIR/evals/evals.json"
FIXTURES_DIR="$REPO_DIR/evals/fixtures"

PASS=0
FAIL=0
WARN=0
SKIP=0

# ... (color functions matching test.sh pattern) ...
```

**Processing logic per eval:**

1. Read eval entry from evals.json (requires `jq`)
2. Check if fixture file exists and is non-empty
   - If missing: SKIP with warning "fixture not populated"
   - If empty: SKIP with warning
3. For each assertion:
   - `contains`: `grep -qi "$value" "$fixture_file"`
   - `contains-any`: loop values, pass if any match
   - `not-contains`: `! grep -qi "$value" "$fixture_file"`
   - `min-headers`: `grep -c "^## " "$fixture_file"` >= value
   - `min-length`: `wc -c < "$fixture_file"` >= value
   - `regex`: `grep -Eqi "$value" "$fixture_file"`
4. If all assertions pass: PASS
5. If any assertion fails: FAIL (report which assertion failed)

**Exit codes:**
- 0: All populated fixtures pass
- 1: Any fixture fails assertions
- (Unpopulated fixtures are warnings, not failures)

### Fixture Files

Pre-captured reference outputs that represent expected command behavior. These are **manually curated** — not auto-generated from live runs.

**Initial fixtures to create (5):**
1. `fixtures/describe-change-simple.md` — Light path triage for trivial change
2. `fixtures/describe-change-complex.md` — Full path triage for complex, risky change
3. `fixtures/sail-doctor-healthy.md` — All-pass health report
4. `fixtures/sail-doctor-drift.md` — Health report with drift/missing hooks
5. `fixtures/pipeline-list.md` — Pipeline list output with stock pipelines

Each fixture is a markdown file containing the expected output structure of the command for its scenario. They don't need to be exact — they need to contain the keywords and structural elements that the assertions check for.

### Integration into test.sh

Add a new category (Category 8) to test.sh:

```bash
# ─── 8. Behavioral Evals ────────────────────────────────────────

bold "8. Behavioral Evals"

if [ -f "$SCRIPT_DIR/evals/evals.json" ] && command -v jq &>/dev/null; then
    if [ -x "$SCRIPT_DIR/scripts/behavioral-smoke.sh" ]; then
        # [F-R2-01] CRITICAL: must capture exit code without triggering set -e.
        # Under set -euo pipefail, a failing $() aborts the parent shell.
        # The || true pattern prevents propagation; we capture the real exit via $?.
        eval_exit=0
        eval_output=$("$SCRIPT_DIR/scripts/behavioral-smoke.sh" 2>&1) || eval_exit=$?
        # Parse output for pass/fail/warn counts and display inline
        echo "$eval_output"
        if [ "$eval_exit" -ne 0 ]; then
            fail "Behavioral evals: $eval_exit fixture(s) failed"
        else
            pass "Behavioral evals: all fixtures passed"
        fi
    else
        warn "scripts/behavioral-smoke.sh not executable"
    fi
else
    if ! [ -f "$SCRIPT_DIR/evals/evals.json" ]; then
        warn "evals/evals.json not found — skipping behavioral evals"
    elif ! command -v jq &>/dev/null; then
        warn "jq not installed — skipping behavioral evals"
    fi
fi
```

**[F-R2-01 Resolution]:** The `|| eval_exit=$?` pattern prevents `set -e` from aborting test.sh when behavioral-smoke.sh exits non-zero. This matches how the existing shellcheck category handles tool failures.

**[F-R2-08 Resolution]:** `behavioral-smoke.sh` itself must also include a jq guard at the top:
```bash
command -v jq >/dev/null 2>&1 || { echo "Error: jq required but not found"; exit 1; }
```

**[R3-F1 Resolution]:** `behavioral-smoke.sh` MUST NOT use `set -euo pipefail` at the top level. Each jq invocation in the eval loop MUST handle parse failure explicitly (e.g., `|| echo 'PARSE_ERROR'`) and record a FAIL result for that eval entry rather than halting the entire run. This ensures malformed eval entries produce diagnostics, not silent aborts.

**[EC-04 Resolution]:** Before iterating assertions for an eval entry, the smoke script MUST verify the `assertions` array is non-null and has at least 1 element. If null, empty, or missing, the entry MUST be recorded as INVALID (counted as FAIL), not silently passed with 0 assertions checked. A vacuous PASS (0 assertions evaluated = green) is a test suite integrity violation.

The behavioral smoke script outputs in the same `pass`/`fail`/`warn` format as test.sh, so its output can be displayed inline.

---

## Work Units

### WU1: `/sail-doctor` command
**Files created:**
- `commands/sail-doctor.md`

**Files modified:**
- `test.sh` (update CMD_EXPECTED count: 51 → 53)
- `README.md` (add to command table, update count)
- `commands/README.md` (add to appropriate category)

**Dependencies:** None (can start immediately)

### WU2: `/pipeline` command + stock pipelines
**Files created:**
- `commands/pipeline.md`
- `commands/templates/stock-pipelines/ship-feature.yaml`
- `commands/templates/stock-pipelines/quality-check.yaml`
- `commands/templates/stock-pipelines/quick-fix.yaml`

**Files modified:**
- `commands/bootstrap-project.md` (add pipeline directory creation)
- `test.sh` (update CMD_EXPECTED count, add YAML validation for stock pipelines)
- `README.md` (add to command table, update count, add pipelines section)
- `commands/README.md` (add to appropriate category)

**Dependencies:** None (can start immediately, parallel with WU1)

### WU3: Behavioral evals
**Files created:**
- `evals/evals.json`
- `evals/fixtures/describe-change-simple.md`
- `evals/fixtures/describe-change-complex.md`
- `evals/fixtures/sail-doctor-healthy.md`
- `evals/fixtures/sail-doctor-drift.md`
- `evals/fixtures/pipeline-list.md`
- `scripts/behavioral-smoke.sh`

**Files modified:**
- `test.sh` (add Category 8: Behavioral Evals)
- `README.md` (add evals section, update test check count)

**Dependencies:** WU1 and WU2 should be at least specified (fixture content references their output formats). However, fixtures can be written based on the spec above without waiting for implementation.

### WU4: Shared updates and integration

**[F22 Resolution] Explicit scope — each file has a defined change:**

**Files modified:**
- `test.sh`:
  - Update `CMD_EXPECTED` count (51 → 53, for sail-doctor + pipeline)
  - Add stock-pipeline count check in Category 3 (count `*.yaml` in stock-pipelines/)
  - Add Category 8: Behavioral Evals (call behavioral-smoke.sh if evals/ exists)
  - Add syntax check for `scripts/behavioral-smoke.sh` in Category 1
- `README.md`:
  - Update command count in "Commands at a Glance" section
  - Add `/sail-doctor` and `/pipeline` to command table
  - Add "Pipelines" subsection under Architecture Overview
  - Add "Behavioral Evals" subsection under Testing
  - Update test check count (60 → ~65)
- `commands/README.md`:
  - Add `/sail-doctor` to Utility category table
  - Add `/pipeline` to Utility category table
- `install.sh`:
  - Write `.sail-counts.json` after file copy (see F1 resolution)
  - Copy `VERSION` file to `~/.claude/.sail-version`
  - Use copy-if-not-exists for stock pipelines (see M4 resolution)
  - Update summary output message with new counts
- `.claude/CLAUDE.md` (this repo's project CLAUDE.md):
  - **[F24 Resolution]** Add `evals/`, `scripts/`, `commands/templates/stock-pipelines/` to architecture overview
  - Add pipeline YAML format documentation to Key Conventions
  - Add behavioral eval convention to Testing section

**Files created:**
- `VERSION` — version string file at repo root (e.g., `0.9.0`)

**[M7 Resolution] Count governance:** After this work, there is ONE canonical count source: `test.sh`. `install.sh` derives `.sail-counts.json` from actual installed files (not from test.sh constants). `/sail-doctor` reads `.sail-counts.json`. test.sh remains the development-time source for CI. The chain is: `test.sh constants` → verified by CI → `install.sh` counts actual files → `.sail-counts.json` → `sail-doctor` reads it. No circular dependencies.

**Dependencies:** WU1, WU2, WU3 complete

## Work Graph

```
WU1 (sail-doctor) ──────┐
                         ├──→ WU4 (shared updates)
WU2 (pipeline + stock) ──┤
                         │
WU3 (behavioral evals) ──┘
```

**Parallelization:** WU1, WU2, WU3 are fully independent and can be implemented in parallel. WU4 is a sequential merge step.

**Width:** 3 (WU1 + WU2 + WU3 in parallel)
**Critical path length:** 2 (any WU → WU4)

---

## Acceptance Criteria

### /sail-doctor
- [ ] Command exists with correct frontmatter and enforcement tier
- [ ] All 6 diagnostic categories produce output
- [ ] [F1] Counts derived from `.sail-counts.json`, NOT hardcoded
- [ ] [F3/M3] `--fix` shows commented-out suggestions with safety warnings
- [ ] [M3] `--quiet --fix` shows failures + fixes only, suppresses passes
- [ ] [F4/M6] MCP probes use Claude tool calls (not shell), best-effort, never block
- [ ] [F7] Status aggregation: overall = worst non-informational category
- [ ] [F6/M1] Self-exclusion guard for `~/.claude/` and repo directory
- [ ] [F5] `VERSION` file exists, `install.sh` copies to `~/.claude/.sail-version`

### /pipeline
- [ ] `list` discovers pipelines from all 3 search paths, shows all (no dedup)
- [ ] [F10] `list` and `run` warn when project pipeline shadows global/stock
- [ ] `show <name>` displays readable pipeline definition
- [ ] [F9] Pipeline files parsed with grep/sed/awk, no YAML library
- [ ] [F13] No shell interpolation of `$INPUT` — passed via Skill tool args
- [ ] [F8/F12] Context passing uses structured handoff blocks with defined preservation rules
- [ ] `pass-output-as: artifact` mode passes file paths for plan-producing commands
- [ ] [F11] `on-error: ask` degrades to `stop` in non-interactive contexts
- [ ] [F15] Command availability verified at preflight (before execution)
- [ ] [M2] Audit trail written to `.claude/pipeline-runs.log`
- [ ] [M4] `install.sh` uses copy-if-not-exists for stock pipelines
- [ ] 3 stock pipelines exist and parse correctly with line-oriented parser

### Behavioral Evals
- [ ] [F17/M5] Evals are offline, deterministic — no LLM invocation
- [ ] [F19] evals/ NOT in install path, test.sh skips gracefully if missing
- [ ] [F18] Assertions categorized by stability tier in spec and evals.json
- [ ] `evals/evals.json` validates as JSON
- [ ] `scripts/behavioral-smoke.sh` runs without errors
- [ ] All 6 assertion types work correctly
- [ ] Unpopulated fixtures produce warnings, not failures
- [ ] At least 5 eval entries with 5 fixtures
- [ ] Integrated into test.sh as Category 8

### Cross-cutting
- [ ] test.sh passes after all changes (updated counts, new categories)
- [ ] install.sh dry run succeeds (new files land correctly, .sail-counts.json written)
- [ ] No escape-hatch language in new command descriptions
- [ ] [F24] CLAUDE.md updated with new directories (evals/, scripts/, stock-pipelines/)
- [ ] [M7] Single count governance chain: test.sh → install.sh → .sail-counts.json → sail-doctor
- [ ] Both README.md files updated with accurate counts
- [ ] VERSION file exists at repo root
