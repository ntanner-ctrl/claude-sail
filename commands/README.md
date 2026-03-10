# Commands Reference

Complete reference for all Claude Sail commands.

---

## Quick Reference

### Start Here

| Command | One-liner |
|---------|-----------|
| `/start` | Assess state, recommend next task |
| `/describe-change` | Triage a change to determine planning depth |
| `/toolkit` | Quick reference for all commands |

### Workflow Wizards (Guided Paths)

| Command | One-liner |
|---------|-----------|
| `/blueprint [name]` | Full planning workflow — walks through all stages |
| `/review [target]` | Adversarial review workflow — challenge a blueprint |
| `/test [name]` | Testing workflow — spec to tests to verification |

### Planning (Before You Build)

| Command | One-liner |
|---------|-----------|
| `/spec-change` | Create complete change specification |
| `/spec-agent` | Define a new agent |
| `/spec-hook` | Define a new hook |
| `/preflight` | Pre-flight safety checklist |
| `/brainstorm` | Structured problem analysis |
| `/decision` | Record a non-obvious decision |
| `/design-check` | Pre-implementation prerequisite check (6-point) |
| `/requirements-discovery` | Extract validated requirements |

### Adversarial (Challenge Your Blueprint)

| Command | One-liner |
|---------|-----------|
| `/devils-advocate` | Challenge assumptions |
| `/overcomplicated` | Question complexity |
| `/edge-cases` | Probe boundaries and limits |
| `/gpt-review` | External model review (different perspective) |

### Quality & Testing

| Command | One-liner |
|---------|-----------|
| `/tdd` | TDD-enforced development with RED-GREEN-REFACTOR discipline |
| `/quality-gate` | Quality threshold check before completing implementation |
| `/spec-to-tests` | Generate tests from spec (spec-blind) |
| `/security-checklist` | 8-point OWASP-style security audit |
| `/debug` | Scientific debugging (OBSERVE-HYPOTHESIZE-PREDICT-EXPERIMENT-CONCLUDE) |

### Execution

| Command | One-liner |
|---------|-----------|
| `/dispatch` | Single-task subagent dispatch with fresh context and optional review lenses |
| `/delegate` | Multi-task delegation with orchestration, lenses, and worktree isolation |
| `/checkpoint` | Manual context-save for session continuity |
| `/end` | Graceful session close with Empirica postflight and vault export |
| `/push-safe` | Safe git push with secret scanning |

### Vault Integration

| Command | One-liner |
|---------|-----------|
| `/vault-save` | Capture knowledge, ideas, or findings to Obsidian vault |
| `/vault-query` | Search vault for past decisions, patterns, findings |
| `/collect-insights` | Flush pending insights to Obsidian vault and Empirica |
| `/vault-curate` | Interactive multi-stage vault triage (inventory, health, triage, synthesis, prune, report) |
| `/promote-finding` | Promote a recurring finding to a CLAUDE.md rule (capacity checking) |
| `/review-findings` | DEPRECATED — use `/vault-curate --quick --section findings` |

### Status & Tracking

| Command | One-liner |
|---------|-----------|
| `/status [name]` | Show current blueprint workflow state |
| `/blueprints` | List all in-progress blueprints |
| `/dashboard` | Aggregated view of all active work (blueprints, TDD, checkpoints) |
| `/overrides` | Review override patterns |
| `/approve [blueprint]` | Approve a planning stage |

### Integration

| Command | One-liner |
|---------|-----------|
| `plugin-enhancers` | Plugin registry — maps installed plugins to workflow enhancements (reference, not user-invoked) |

### Setup

| Command | One-liner |
|---------|-----------|
| `/bootstrap-project` | Full project setup with CLAUDE.md + hooks + agents |
| `/check-project-setup` | Quick drift detection |
| `/assess-project` | CLAUDE.md generation only |
| `/setup-hooks` | Configure formatting hooks |

### Documentation

| Command | One-liner |
|---------|-----------|
| `/refresh-claude-md` | Update CLAUDE.md with recent changes |
| `/migrate-docs` | Migrate documentation to Diataxis framework |
| `/process-doc` | Generate How-to Guides |

---

## Workflow Wizards

Guided paths through the toolkit for common scenarios.

### `/blueprint [name]`

**Full planning workflow.** Walks through all stages with appropriate prompts based on change complexity.

```
/blueprint feature-auth
```

Stages:
1. **Describe** → `/describe-change` (triage)
2. **Specify** → `/spec-change` (full specification + work graph)
3. **Challenge** → Adversarial challenge (mode-dependent)
4. **Edge Cases** → Boundary probing (mode-dependent)
4.5. **Pre-Mortem** → Operational failure exercise [optional]
5. **Review** → `/gpt-review` (external perspective) [optional]
6. **Test** → `/spec-to-tests` (spec-blind tests)
7. **Execute** → Implementation (with manifest handoff + work graph)

Challenge modes for Stages 3 and 4:
```
/blueprint feature-auth                      # debate mode (default)
/blueprint feature-auth --challenge=vanilla  # single-agent
/blueprint feature-auth --challenge=family   # generational debate (deep specs)
/blueprint feature-auth --challenge=team     # agent teams (experimental)
```

See [docs/BLUEPRINT-MODES.md](../docs/BLUEPRINT-MODES.md) for mode comparison.

The triage in Stage 1 determines path depth:
- **Light path:** 1 → 7 (skip 2-6)
- **Standard path:** 1 → 2 → 7 (skip 3-6)
- **Full path:** All stages

**When to use:** Any non-trivial change where you want guided planning discipline.

---

### `/review [target]`

**Adversarial review workflow.** Focused challenge of an existing blueprint or implementation.

```
/review feature-auth
/review --quick devils-advocate [target]
```

Runs through:
1. Devil's Advocate — Challenge assumptions
2. Simplify — Question complexity
3. Edge Cases — Probe boundaries
4. External Review — GPT review (optional)

**When to use:** You have a blueprint and want to stress-test it without full planning workflow.

---

### `/test [name]`

**Testing workflow.** Ensures tests are derived from specification, not implementation.

```
/test feature-auth
```

Stages:
1. **Spec Review** — Verify spec has testable criteria
2. **Generate** — Create tests from spec (spec-blind)
3. **Verify** — Run tests, check for tautologies

**When to use:** After specification is complete, before or during implementation.

---

## Planning Commands

### `/describe-change`

**Triage gateway.** Every change starts here. Determines how much planning infrastructure to invoke.

```
/describe-change add-user-avatars
```

Process:
1. Describe the change (plain English)
2. List discrete steps (actively decomposes combined actions)
3. Quick risk scan (database, auth, deletion, external APIs, etc.)
4. Determine path (Light / Standard / Full)

**When to use:** Start of any non-trivial change.

---

### `/spec-change`

**Complete change specification.** Forces thoroughness before implementation.

```
/spec-change
```

Sections:
- Summary
- What Changes (files, dependencies, database)
- **Preservation Contract** (what must NOT change)
- Success Criteria (testable)
- Failure Modes (what could go wrong)
- Rollback Plan
- Open Questions

**When to use:** Standard and Full path changes. The backbone of planning discipline.

---

### `/preflight`

**Pre-flight safety checklist.** Quick verification before executing.

```
/preflight
```

Covers:
- Assumptions inventory (confidence levels)
- Blast radius assessment
- Dependency check
- **The 3 AM Test** — Would you be comfortable if this ran at 3 AM?
- Go/No-Go decision

**When to use:** Before any significant operation. Required for Light path, recommended for all.

---

### `/spec-agent` / `/spec-hook`

**Meta-specifications.** Define agents and hooks before implementing them.

```
/spec-agent cache-invalidator
/spec-hook production-db-guard
```

Forces explicit definition of:
- Role and trigger conditions
- Inputs and outputs
- **Constraints** (what it must NOT do)
- Failure states
- Integration points

**When to use:** Before creating any new agent or hook.

---

### `/decision`

**Decision record.** Capture non-obvious choices for future reference.

```
/decision use-postgres-over-mysql
```

Sections:
- Context
- Options Considered (with pros/cons/risks)
- Decision and rationale
- Consequences (gains, losses, implications)
- Review triggers

**When to use:** When making a choice that won't be self-evident from the code.

---

### `/design-check`

**Pre-implementation prerequisites.** Verifies 6 dimensions are resolved before coding begins.

```
/design-check add-user-avatars
```

Checks:
1. **Requirements** — Can you state testable acceptance criteria?
2. **Architecture** — Which components are involved?
3. **Interfaces** — Inputs, outputs, errors defined?
4. **Error Strategy** — What happens when things fail?
5. **Data Structures** — What represents the domain?
6. **Algorithms** — Core logic identified?

Verdict: READY or BLOCKED (with specific gaps to resolve).

**When to use:** Before implementing any feature with unclear boundaries.

---

## Adversarial Commands

### `/devils-advocate`

**Assumption challenger.** Systematically questions assumptions across four dimensions.

```
/devils-advocate feature-auth
```

Challenge categories:
- **Availability** — What if services/resources are unavailable?
- **Scale** — What if 0 items? 1M items? Backpressure?
- **Timing** — What if during deployment? DST? Concurrent?
- **Trust** — What if malformed? Malicious? Unexpected?

**When to use:** After drafting a blueprint, before committing to implementation.

---

### `/overcomplicated`

**Complexity challenger.** Questions whether complexity is justified.

```
/overcomplicated feature-auth
```

Challenges:
- **Abstraction** — Do we need this layer?
- **Build vs. Use** — Does this already exist?
- **Necessity** — What's the MVP? What could be phase 2?

**When to use:** When a blueprint has multiple components or abstractions.

---

### `/edge-cases`

**Boundary explorer.** Maps specific boundaries where things break.

```
/edge-cases feature-auth
```

Probes:
- **Input boundaries** — Empty, single, limit, over-limit, malformed
- **State boundaries** — Transitions, repeats, reverses, cold starts
- **Concurrency** — Simultaneous, interrupted, stale
- **Time** — Zones, leaps, skew

**When to use:** Before finalizing implementation approach.

---

## Quality & Testing Commands

### `/tdd`

**TDD-enforced development.** Manages RED-GREEN-REFACTOR discipline with enforcement hooks.

```
/tdd [--mode advisory|strict|aggressive] [--target path]
```

Phases:
1. **SPEC** — Define what to test (acceptance criteria)
2. **RED** — Write failing tests (implementation edits blocked by hook)
3. **GREEN** — Write minimum code to pass tests
4. **REFACTOR** — Clean up while tests stay green
5. **VERIFY** — Run full suite, confirm no regressions

Enforcement modes:
- **advisory** — Warns on violations but allows (default)
- **strict** — Blocks implementation edits during RED phase
- **aggressive** — Strict + blocks non-test files in RED

**When to use:** New features that need tests, or when enforcing test-first discipline.

---

### `/quality-gate`

**Quality threshold check.** Scores implementation against quality dimensions.

```
/quality-gate [--threshold 85]
```

**When to use:** Before completing significant implementation. Blocks below-threshold work.

---

### `/spec-to-tests`

**Specification-blind test generator.** Creates tests from spec WITHOUT implementation knowledge.

```
/spec-to-tests feature-auth
```

Critical constraint: This command must NOT see implementation details. Tests derived from:
- Success criteria → Behavior tests
- Preservation contract → Contract tests
- Failure modes → Failure mode tests

Includes anti-tautology review checklist.

**When to use:** After spec is complete, before or alongside implementation.

---

## Status & Tracking Commands

### `/status [name]`

**Planning state display.** Shows detailed progress for a specific blueprint or overview.

```
/status                 # Overview of all blueprints
/status feature-auth    # Detailed view of one blueprint
```

Shows: Stage progress, artifacts created, skipped stages, time since activity.

---

### `/blueprints`

**List all in-progress blueprints.** Overview of planning state across project.

```
/blueprints
```

Shows: All active blueprints, their current stage, last activity, stale warnings.

---

### `/overrides`

**Override pattern review.** Retrospective on planning shortcuts.

```
/overrides
```

Shows: When blueprints deviated from recommendations, reasons given, outcomes (if known).

Enables learning: Were shortcuts justified, or did they cause problems?

---

### `/approve [blueprint]`

**Stage gate approval.** Explicitly approve a stage to advance.

```
/approve feature-auth
```

Options: Clean approval, approve with concerns, not ready.

**When to use:** In staged planning protocol, or when you want explicit gates.

---

### `/dashboard`

**Aggregated status view.** Shows all active work in one place.

```
/dashboard
```

Displays:
- Active blueprint (name, stage, time since update)
- Active TDD session (target, phase)
- Last checkpoint timestamp
- Delegation status (if running)
- Suggested next action based on current state

**When to use:** Resuming work, or checking progress across all active workflows.

---

### `/checkpoint`

**Manual context-save.** Captures decision rationale for session continuity.

```
/checkpoint "Chose JWT over sessions because stateless API"
```

Saves:
- Summary of current state
- Key decisions and rationale
- Next action to take when resuming
- Active blueprint/TDD context

Location: `.claude/plans/[name]/checkpoints/` (if blueprint active) or `.claude/checkpoints/`

**When to use:** Before ending a session, when context is large, or after non-obvious decisions.

---

### `/end`

**Graceful session close.** Runs Empirica postflight assessment and vault export while Claude is still in the loop, then prompts the user to `/exit`.

```
/end
```

Steps:
1. Reads active Empirica session from `.empirica/active_session`
2. Claude self-assesses current epistemic state (13 vectors)
3. Submits postflight assessment (captures learning delta)
4. Exports session artifacts to Obsidian vault (decisions, findings, blueprints, session summary)
5. Logs any final findings
6. Displays confirmation and prompts `/exit`

**Why not just `/exit`?** The `SessionEnd` hook closes the DB record and writes a vault breadcrumb, but can't do epistemic self-assessment or rich vault export (Claude is already gone). `/end` keeps Claude in the loop for meaningful postflight data and detailed vault notes with wiki-links.

**When to use:** Before every `/exit`. The session-sail hook reminds Claude to suggest it.

---

## Vault Commands

### `/vault-save`

**Manual knowledge capture.** Saves ideas, decisions, findings, or patterns to the Obsidian vault.

```
/vault-save                              # Interactive — asks type, title, content
/vault-save idea webhook retry logic     # Quick: type + title from args
/vault-save finding                      # Type only, asks for details
```

Note types: idea (→ Ideas/), decision (→ Engineering/Decisions/), finding (→ Engineering/Findings/), pattern (→ Engineering/Patterns/).

Wiki-links to existing vault notes only (no speculative links). All filenames NTFS-safe via slug sanitization.

**When to use:** When you discover something worth preserving for future sessions.

---

### `/vault-query`

**Vault search.** Searches the Obsidian vault for past decisions, patterns, findings, and session logs.

```
/vault-query authentication         # Keyword search
/vault-query --type decision api    # Filter by note type
/vault-query --project bootstrap    # Filter by project
```

Three-strategy search: frontmatter fields, content keywords, filename matching. Results ranked and deduplicated.

**When to use:** When you need context from past sessions or want to avoid re-solving a solved problem.

---

## Existing Commands

### `/start`

**Session starter.** Assesses project state and recommends next task.

```
/start
```

**When to use:** Beginning of every session.

---

### `/brainstorm`

**Structured problem analysis.** Forces analysis before jumping to solutions.

```
/brainstorm [problem description]
```

**When to use:** Complex problems, unclear requirements.

---

### `/dispatch`

**Single-task subagent dispatch.** Sends one task to a fresh subagent with clean context.

```
/dispatch "Implement login endpoint" --review
/dispatch path/to/spec.md --model haiku --lenses security,perf
/dispatch "Add endpoint" --review --plan-context feature-auth
```

Features:
- Fresh context (no session baggage)
- Optional two-stage review (spec compliance + quality)
- Review lenses (`--lenses security,perf,arch,cfn`) for additional perspectives
- Plan context (`--plan-context`) to enrich with planning intelligence
- Model selection (haiku/sonnet/opus)
- Max 3 retry attempts on review failure

**When to use:** Well-defined task that benefits from isolated execution.

---

### `/delegate`

**Smart task delegation.** Two modes: ad-hoc parallel dispatch or plan-based orchestration.

```
/delegate Explore auth system and Plan OAuth integration
/delegate --plan .claude/plans/feature-auth/spec.md --review --lenses security
/delegate --plan spec.md --review --isolate --plan-context feature-auth
```

Modes:
- **Ad-hoc:** Quick parallel delegation of independent tasks
- **Orchestrated:** Parses plan into tasks, partitions by file, dispatches in batches with approval gates

Features:
- Review lenses (`--lenses security,perf,arch,cfn`) for additional review perspectives
- Worktree isolation (`--isolate`) for independent per-task review and accept/reject
- Plan context (`--plan-context`) to enrich implementers with planning intelligence

**When to use:** Multiple independent tasks, or structured multi-task implementation from a plan.

---

### `/gpt-review`

**Multi-model adversarial review.** External perspective via GPT.

```
/gpt-review [--focus security|performance|architecture|all]
```

When used after local adversarial commands, includes their findings for blind-spot detection.

---

### `/security-checklist`

**8-point security audit.** OWASP-aligned assessment.

```
/security-checklist
```

---

### `/debug`

**Scientific debugging.** Structured 5-phase process that prevents random-change debugging.

```
/debug "Login fails after session timeout"
```

Phases:
1. **OBSERVE** — Exact error, reproduction steps, expected vs actual
2. **HYPOTHESIZE** — Generate 3+ possible causes, rank by likelihood
3. **PREDICT** — If hypothesis X is true, what ELSE should be true?
4. **EXPERIMENT** — Test ONE prediction, record result
5. **CONCLUDE** — Confirmed cause, fix, and prevention

**When to use:** Bug resists quick fixes, or you've already tried the obvious solution.

---

### `/push-safe`

**Safe push with secret scanning.** Blocks secrets, large files, build artifacts.

```
/push-safe
```

---

## Documentation Commands

### `/toolkit`

**Quick reference.** Displays all available commands organized by workflow stage.

```
/toolkit
```

---

### `/refresh-claude-md`

**Update project documentation.** Scans for drift and suggests updates.

```
/refresh-claude-md
```

---

### `/migrate-docs`

**Diataxis migration.** Restructures docs into Tutorial/How-to/Reference/Explanation.

```
/migrate-docs [path] [options]
```

---

### `/process-doc`

**Generate How-to Guides.** Creates task-oriented documentation.

```
/process-doc [topic]
```

---

## Setup Commands

### `/bootstrap-project`

**Full project setup.** Analyzes project and installs appropriate configuration.

```
/bootstrap-project
```

---

### `/check-project-setup`

**Drift detection.** Checks if setup has drifted from project state.

```
/check-project-setup
```

---

### `/setup-hooks`

**Configure formatting hooks.** Detects stack and configures PostToolUse hooks.

```
/setup-hooks
```

---

## Storage Structure

Blueprints and state are stored in `.claude/`:

```
.claude/
├── state-index.json          # Active work index (maintained by hook)
├── checkpoints/              # Global checkpoints (no active blueprint)
│   └── 20260124T100000Z.json
├── plans/
│   ├── feature-auth/
│   │   ├── state.json        # Progress tracking + execution results
│   │   ├── describe.md       # Triage output
│   │   ├── spec.md           # Specification
│   │   ├── adversarial.md    # Challenge findings
│   │   ├── tests.md          # Generated tests
│   │   └── checkpoints/      # Plan-scoped checkpoints
│   │       └── 20260124T100000Z.json
│   └── ...
├── tdd-sessions/
│   └── active.json           # Current TDD session state
├── worktrees/                # Temporary (created by --isolate, cleaned on start)
├── overrides.json            # Project-level override history
└── settings.json             # Claude Code config
```

See [docs/PLANNING-STORAGE.md](../docs/PLANNING-STORAGE.md) for schema details.

---

## Plugin Integration

### `plugin-enhancers` (reference command)

**Not user-invoked.** Read by workflow commands at plugin integration seams to determine what enhancements are available.

When Claude Code plugins are installed (detected via `~/.claude/plugins/installed_plugins.json`), workflow commands offer plugin-powered enhancements:

| Workflow | Enhancement | Plugin Required |
|----------|-------------|-----------------|
| `/blueprint` Stage 5 | Deep Dive — 6 specialized review agents | pr-review-toolkit |
| `/blueprint` Stage 5 | Multi-Model Consensus | frontend |
| `/review` Stage 5 | Deep Analysis — specialized agents in parallel | pr-review-toolkit |
| `/dispatch --lenses` | Extended lenses: `silent-failures`, `types`, `comments`, `simplify`, `test-coverage` | pr-review-toolkit |

Plugin results are **advisory** — tagged `[plugin-review]`, they don't block workflows or trigger regressions.

If no plugins are installed, all workflows behave exactly as they did before this feature was added.

---

## Stock Elements

The `templates/` directory contains stock elements installed by `/bootstrap-project`:

```
templates/
├── stock-agents/           # Specialized subagents
├── stock-commands/         # Project-specific commands
├── stock-hooks/            # Prompt-based hooks
├── vault-notes/            # Obsidian vault note templates (decision, finding, session, blueprint, idea)
├── prompts/                # Shared prompt templates (dispatch/delegate)
│   ├── implementer.md
│   ├── spec-review.md
│   ├── quality-review.md
│   ├── security-review.md
│   ├── performance-review.md
│   └── architecture-review.md
└── INSTALL.md              # Installation guide
```
