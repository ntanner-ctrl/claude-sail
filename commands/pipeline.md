---
description: Use when you want to run a predefined sequence of commands as a single workflow. Chains commands with context passing.
argument-hint: list | show <name> | lint <name> | run <name> [input]
allowed-tools:
  - Read
  - Glob
  - Bash
  - Grep
  - Skill
---

# Pipeline

Run predefined command sequences as coordinated workflows with context passing between steps.

---

## Subcommands

| Subcommand | Purpose |
|------------|---------|
| `list` | Show all available pipelines with provenance |
| `show <name>` | Display a pipeline definition in readable form |
| `lint <name>` | Validate a pipeline without executing it |
| `run <name> [input]` | Execute a pipeline |

---

## `/pipeline list`

Search three paths and display ALL pipelines found, with provenance labels. Do NOT deduplicate — if the same name appears in multiple paths, show all instances.

### Search Paths

1. `.claude/pipelines/` — project pipelines
2. `~/.claude/pipelines/` — global pipelines
3. `~/.claude/commands/templates/stock-pipelines/` — stock pipelines

### Output Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE │ Available Pipelines
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  [project]  ship-feature       Plan, test, and push a feature
  [global]   deploy-staging     Deploy to staging environment
  [stock]    ship-feature       Plan, test, and push a feature
  [stock]    quality-check      Run quality sweep, gate check, and optional review
  [stock]    quick-fix          Fast path for small changes — triage then execute

  Total: 5 pipelines (2 project, 1 global, 2 stock)
  Note: 'ship-feature' exists in multiple locations — project takes precedence on run.

  Run /pipeline show <name> to see step details.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Implementation

Use Glob to find `*.yaml` files in each path. For each file found:
- Label it with its source path (`[project]`, `[global]`, `[stock]`)
- Extract `name:` and `description:` fields via Grep
- Display in order: project first, global second, stock last

If no pipelines found anywhere, display:
```
No pipelines found. Stock pipelines are available at:
  ~/.claude/commands/templates/stock-pipelines/

  Run /bootstrap-project to install stock pipelines into your project.
  Or create a pipeline at .claude/pipelines/<name>.yaml
```

---

## `/pipeline show <name>`

Find and display a pipeline definition in human-readable form.

### Resolution Order

Project (`.claude/pipelines/`) → global (`~/.claude/pipelines/`) → stock (`~/.claude/commands/templates/stock-pipelines/`)

Use the FIRST match found.

### Output Format

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Description:  Plan, test, and push a feature
  Source:        [project] .claude/pipelines/ship-feature.yaml
  On error:      stop

  Steps:
  ┌─────┬──────────────────┬────────────────────────────────────────┬──────────────────────┐
  │  #  │ command          │ description                            │ context passing      │
  ├─────┼──────────────────┼────────────────────────────────────────┼──────────────────────┤
  │  1  │ describe-change  │ Triage the change and determine path   │ —                    │
  │  2  │ blueprint        │ Run full planning workflow             │ pass-output-as: context│
  │  3  │ test             │ Verify implementation passes tests     │ pass-output-as: context│
  │  4  │ push-safe        │ Pre-push safety checks and push        │ —                    │
  └─────┴──────────────────┴────────────────────────────────────────┴──────────────────────┘

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If the pipeline name is not found in any location:
```
Pipeline not found: '<name>'

Searched:
  .claude/pipelines/<name>.yaml         — not found
  ~/.claude/pipelines/<name>.yaml       — not found
  ~/.claude/commands/templates/stock-pipelines/<name>.yaml  — not found

Run /pipeline list to see available pipelines.
```

---

## `/pipeline lint <name>` or `/pipeline lint --all`

Validate a pipeline file without executing it. Run 7 checks in order.

### Lint Checks

| # | Check | Pass | Fail |
|---|-------|------|------|
| 1 | Required fields present (`name`, `description`, `steps`, `on-error`) | all found | list missing |
| 2 | `name` is kebab-case (lowercase letters, digits, hyphens only) | matches pattern | show actual value |
| 3 | `steps` has 2 or more entries | count >= 2 | show actual count |
| 4 | Each step has `command` and `description` fields | all steps valid | list step numbers missing fields |
| 5 | `on-error` is one of: `stop`, `continue`, `ask` | valid value | show actual value |
| 6 | `pass-output-as` values (if present) are `context` or `artifact` | valid or absent | list steps with invalid values |
| 7 | All referenced commands exist in `~/.claude/commands/` | all found | list missing command names |

### Output Format (single pipeline)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE LINT │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Source: .claude/pipelines/ship-feature.yaml

  ✓ Required fields present
  ✓ name is kebab-case
  ✓ steps has 3 entries (>= 2)
  ✓ All steps have command + description
  ✓ on-error is valid (stop)
  ✓ pass-output-as values are valid
  ✗ Command not found: 'blueprint' (not in ~/.claude/commands/)

  Result: 1 error — pipeline cannot run until resolved.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If all checks pass:
```
  Result: OK — pipeline is valid and ready to run.
```

### `--all` variant

Run lint on ALL pipelines found across all search paths. Report per-file results. Show a summary at the end:
```
  Lint summary: 4 OK, 1 error (quality-check: on-error value invalid)
```

---

## `/pipeline run <name> [input]`

Execute a pipeline sequentially with context passing between steps.

> **Note:** Pipelines require an interactive Claude Code session. Each step is run via the Skill tool, which invokes the corresponding slash command in the current session.

---

### Phase 0: Guards

**Recursion guard:** Check whether a pipeline is already executing in this session (look for context marker: `PIPELINE_EXECUTING=<name>`). If found:
```
Error: Recursive pipeline detected.
  Running pipeline: [current pipeline name]
  Attempted to start: [requested pipeline name]

Pipelines cannot call other pipelines. If you need nested workflows,
compose them manually or use /delegate for parallel execution.
```

Set a session-level recursion marker at the START of execution. Pattern: `PIPELINE_EXECUTING=<name>`.

**CRITICAL — finally-block pattern:** The recursion marker MUST be cleared on ALL exit paths:
- Successful completion
- Step failure with on-error: stop
- User abort (at confirmation or ask prompt)
- Any error during parsing or validation

Treat this like a `finally` block — it runs regardless of how execution ends.

---

### Phase 1: Resolution & Validation

**1. Locate the pipeline file**

Search order: project (`.claude/pipelines/`) → global (`~/.claude/pipelines/`) → stock (`~/.claude/commands/templates/stock-pipelines/`)

Use the FIRST match. If not found:
```
Pipeline not found: '<name>'
Run /pipeline list to see available pipelines.
```

**2. Parse the pipeline**

Use line-oriented parsing with Bash grep/sed/awk. No YAML library available.

Parsing approach:
- Extract top-level fields: `grep "^name:" file`, `grep "^description:" file`, `grep "^on-error:" file`
- Find step boundaries: `grep -n "^  - command:" file` to get line numbers
- For each step, read lines from its start line to the next step's start line minus 1
- Extract step fields: `command`, `args`, `description`, `pass-output-as` via grep within each step's line range
- Strip leading/trailing whitespace and quotes from values
- NOTE: No tabs allowed in pipeline files — spaces only. If a tab is found, report it as a parse error.

**3. Shadow detection**

If a project pipeline was found AND a global or stock pipeline of the same name also exists:
```
Warning: Project pipeline '.claude/pipelines/ship-feature.yaml' shadows
  global: ~/.claude/pipelines/ship-feature.yaml

Using project version. Run /pipeline show ship-feature to review.
```

**4. Command preflight**

For each step's `command` value, verify `~/.claude/commands/<command>.md` exists. If any are missing:
```
Preflight failed: referenced commands not found:
  • blueprint — ~/.claude/commands/blueprint.md (not found)
  • push-safe  — ~/.claude/commands/push-safe.md (not found)

Install claude-sail or check command names before running.
```

**5. $INPUT handling**

If any step uses `$INPUT` in its `args` field but no input was provided to `/pipeline run`:
```
Warning: Pipeline uses $INPUT but no input was provided.
  Affected steps: 1 (describe-change)
  $INPUT will be substituted as empty string.

Continue? [y/n]
```

Do NOT abort — warn and continue if user confirms.

**6. Display execution plan and request confirmation**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Description:  Plan, test, and push a feature
  Steps:        4
  On error:     stop
  Input:        "implement OAuth login"

  Execution plan:
    1. describe-change "implement OAuth login"
       Triage the change and determine planning path
    2. blueprint   [receives context from step 1]
       Run full planning workflow based on triage
    3. test        [receives context from step 2]
       Verify implementation passes tests
    4. push-safe
       Pre-push safety checks and push

  Proceed? [y/n/abort]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If user says `n` or `abort`: clear recursion guard and stop.

---

### Phase 2: Sequential Execution

Execute steps one by one using the Skill tool.

**Ensure the `.claude/pipelines/` directory exists** before attempting to write to it:
```bash
mkdir -p .claude/pipelines/
```

#### Step Status Detection

After each step completes, assess the outcome semantically:

| Status | Meaning | Condition |
|--------|---------|-----------|
| **PASS** | Step completed its intended function | Normal completion |
| **FAIL** | Step encountered an error, was blocked, or aborted | Error output, tool refusal, explicit failure |
| **PARTIAL** | Step completed but with warnings or caveats | Completed with notes, partial results |
| **NOOP** | Step had nothing to do | e.g., push-safe with a clean working tree |

- PARTIAL → treat as PASS, but note the warnings in the step summary
- NOOP → proceed to next step; do NOT pass context (there is none)

If a step results in FAIL, trigger the on-error handler (Phase 3).

#### Context Passing

Two modes, controlled by `pass-output-as` in the step definition.

**`pass-output-as: context`**

Construct a structured handoff block from the completed step's output. Format:

```
[Pipeline context from step N: <command>]
• [key finding or decision 1]
• [key finding or decision 2]
• [key finding or decision 3]
[3-7 bullets total]
```

Rules:
- Bullets should capture decisions, findings, and state the next step needs to know
- Maximum 2000 characters total. If the natural summary exceeds 2000 chars, truncate and append: `[truncated — 2000 char limit reached]`
- Pass this block as a prefix to the next step's invocation

**`pass-output-as: artifact`**

The step produces a file artifact (e.g., a spec, a report). Discover the file path:
1. Inspect the step's output semantically — look for file paths mentioned in the output
2. Validate the path exists using the Read tool
3. If path found and valid: pass the file path as context to the next step with prefix: `[Pipeline artifact from step N: <path>]`
4. If path NOT found or file doesn't exist: fall back to `context` mode with a warning: `Warning: Could not locate artifact from step N — falling back to context mode.`

**No `pass-output-as` field**

No context is passed. The next step runs without pipeline context.

**On failed step with `on-error: continue`**

Inform the next step:
```
[Pipeline context from step N: FAILED — no output available]
Previous step '<command>' failed. Proceeding without its output.
```

#### Progress Display

Show step status as execution proceeds:

```
  [■■□□] Step 2/4
    ✓ Step 1: describe-change — PASS
    ► Step 2: blueprint       — running...
    ○ Step 3: test
    ○ Step 4: push-safe
```

---

### Phase 3: Error Handling

When a step results in FAIL, consult `on-error`:

**`on-error: stop`**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE STOPPED │ Step 2 failed
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Failed step: blueprint (step 2/4)

  Completed:
    ✓ Step 1: describe-change

  Remaining (not run):
    ○ Step 3: test
    ○ Step 4: push-safe

  Resolve the issue and re-run: /pipeline run ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Clear recursion guard. Write audit trail entry (see Phase 4). Stop.

**`on-error: continue`**

Log the failure, inject the failure notice as context for the next step, and proceed.

```
  Step 2 FAILED — continuing (on-error: continue)
  Next step will receive: [Pipeline context from step 2: FAILED]
```

**`on-error: ask`**

```
  Step 2 FAILED: blueprint

  [1] Retry — run this step again
  [2] Skip  — skip this step and continue
  [3] Abort — stop the pipeline here

  Choice: _
```

- Retry: re-run the step (no limit on retries — user controls this)
- Skip: proceed to step 3, injecting failure context
- Abort: show stop report, clear recursion guard, write audit trail, stop

---

### Phase 4: Summary & Cleanup

On pipeline completion (success or handled failure), display a summary and write the audit trail.

#### Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PIPELINE COMPLETE │ ship-feature
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Status:    Completed (4/4 steps)
  Input:     "implement OAuth login"
  Duration:  [step count only — no time tracking]

  Steps:
    ✓ Step 1: describe-change    — PASS
    ✓ Step 2: blueprint          — PASS
    ✓ Step 3: test               — PARTIAL (2 tests skipped)
    ✓ Step 4: push-safe          — PASS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### Audit Trail

Append a log entry to `.claude/pipeline-runs.log` (create if missing):

```
2026-03-18T14:32:00Z | ship-feature | 4/4 steps | input: "implement OAuth login" | COMPLETE
2026-03-18T15:10:00Z | quality-check | 2/3 steps | input: "" | STOPPED (step 2 failed)
```

Format: `<ISO-8601 timestamp> | <pipeline name> | <completed>/<total> steps | input: "<input>" | <COMPLETE|STOPPED|ABORTED>`

**Log write failures are NON-FATAL.** If the write fails for any reason (permissions, missing directory, etc.), display a warning and continue:
```
Warning: Could not write to .claude/pipeline-runs.log — audit trail skipped.
```

#### Finally-Block Cleanup

**ALWAYS** clear the recursion guard marker at this point, regardless of outcome. This is the finally block — it runs on every exit path.

---

## Pipeline File Format

Pipeline files are restricted line-oriented YAML. No complex YAML features.

```yaml
# toolkit-version: 0.9.0
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

### Field Reference

| Field | Required | Values | Notes |
|-------|----------|--------|-------|
| `name` | yes | kebab-case string | Must be unique within its directory |
| `description` | yes | string | Human-readable summary |
| `steps` | yes | list of step objects | Minimum 2 steps |
| `on-error` | yes | `stop`, `continue`, `ask` | Applied to all failing steps |
| `steps[].command` | yes | command name | Must exist in `~/.claude/commands/` |
| `steps[].description` | yes | string | Shown in execution plan and summary |
| `steps[].args` | no | string | Passed to command. `$INPUT` is replaced by pipeline input |
| `steps[].pass-output-as` | no | `context`, `artifact` | How to pass output to the next step |

### Rules

- Use spaces only — no tabs
- Top-level keys (`name`, `description`, `steps`, `on-error`) must have NO leading indentation
- Step list items use 2-space indentation: `  - command: ...`
- Step fields use 4-space indentation: `    args: ...`
- String values may be quoted or unquoted; quotes are stripped during parsing
- The `# toolkit-version:` comment is optional but recommended for compatibility tracking

### Where to Store Pipelines

| Location | Scope | Notes |
|----------|-------|-------|
| `.claude/pipelines/` | Project-local | Version-controlled with your project |
| `~/.claude/pipelines/` | Global | Available in all sessions |
| `~/.claude/commands/templates/stock-pipelines/` | Stock | Installed by claude-sail, read-only |

Project pipelines take precedence over global and stock on `/pipeline run`. If a name collision exists, a shadow warning is displayed.

---

## Examples

```
/pipeline list
/pipeline show ship-feature
/pipeline lint quality-check
/pipeline lint --all
/pipeline run quick-fix "fix null pointer in UserService"
/pipeline run ship-feature "add rate limiting to API"
```

$ARGUMENTS
