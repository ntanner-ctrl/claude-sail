# Claude Sail

> Structured workflows, safety guardrails, and planning discipline for Claude Code.

A sail doesn't cross an ocean alone — Claude Sail is the human-AI collaborative discipline toolkit for Claude Code.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-sail/main/install.sh | bash
```

Then in any project:

```bash
cd /your/project
claude
/bootstrap-project
```

**New to this?** See the [Getting Started Guide](GETTING_STARTED.md).

---

## What's Included

| Component | Purpose |
|-----------|---------|
| [**Commands**](commands/README.md) | 65 workflow commands for planning, review, testing, execution, vault integration + plugin integration |
| [**Agents**](agents/) | 12 agents: 6 specialized review agents + 6 paradigm lens agents for `/prism` |
| [**Planning Infrastructure**](docs/PLANNING-STORAGE.md) | Staged planning with triage, specs, and adversarial challenge |
| [**Wizard State**](docs/WIZARD-STATE.md) | Persistent state for workflow wizards — resume-on-compaction, content contracts, vault checkpoints |
| [**Shell Hooks**](hooks/) | 19 shell files (18 hooks + 1 audit utility) for safety, session lifecycle, epistemic tracking, toolkit hardening |
| [**Hookify Rules**](hookify-rules/) | 7 YAML-based security rules |
| [**Stock Elements**](commands/templates/) | 12 stock elements (6 hooks, 3 agents, 3 commands) installed into target projects |
| [**Ops Starter Kit**](ops-starter-kit/) | Domain-specific extensions for infrastructure work |

### Commands at a Glance

| Category | Commands |
|----------|----------|
| **Start Here** | `/start`, `/describe-change`, `/toolkit` |
| **Workflow Wizards** | `/blueprint`, `/prism`, `/clarify` (deprecated), `/review`, `/test` |
| **Planning** | `/spec-change`, `/spec-agent`, `/spec-hook`, `/preflight`, `/brainstorm`, `/decision`, `/design-check`, `/requirements-discovery`, `/prior-art`, `/research` |
| **Adversarial** | `/devils-advocate`, `/overcomplicated`, `/edge-cases`, `/gpt-review` |
| **Quality** | `/tdd`, `/quality-gate`, `/quality-sweep`, `/spec-to-tests`, `/security-checklist`, `/debug` |
| **Learning** | `/log-error`, `/log-success` |
| **Execution** | `/dispatch`, `/delegate`, `/checkpoint`, `/end`, `/push-safe` |
| **Vault** | `/vault-save`, `/vault-query`, `/vault-curate`, `/collect-insights`, `/promote-finding` |
| **Status** | `/status`, `/blueprints`, `/overrides`, `/approve`, `/dashboard` |
| **Setup** | `/bootstrap-project`, `/check-project-setup`, `/setup-hooks`, `/sail-doctor` |
| **Pipelines** | `/pipeline` |
| **Docs** | `/refresh-claude-md`, `/migrate-docs`, `/process-doc` |

See [commands/README.md](commands/README.md) for full reference.

---

## Planning Infrastructure

The toolkit includes comprehensive planning infrastructure to catch the "unearned confidence" problem—moving faster than your understanding of consequences.

### The Triage Gateway

Every change starts with `/describe-change`, which determines planning depth:

| Steps | Risk Flags | Path |
|-------|------------|------|
| 1-3   | None       | **Light** — `/preflight`, then execute |
| 1-3   | Any        | **Standard** — `/spec-change` required |
| 4-7   | Any        | **Full** — Complete planning protocol |

### The `/blueprint` Wizard

Guided workflow through all stages with four challenge modes:

```
/blueprint feature-auth                     # family mode (default)
/blueprint feature-auth --challenge=vanilla # single-agent (original)
/blueprint feature-auth --challenge=debate  # sequential debate chain
/blueprint feature-auth --challenge=team    # agent teams (experimental)

Stage 1: Describe     → Triage the change
Stage 2: Specify      → Full specification + work graph
Stage 3: Challenge    → Debate / vanilla / family / agent team
Stage 4: Edge Cases   → Debate / vanilla / family / agent team
Stage 4.5: Pre-Mortem → Operational failure exercise (optional)
Stage 5: Review       → External perspective (optional)
Stage 6: Test         → Spec-blind test generation
Stage 7: Execute      → Implementation (with manifest handoff + work graph)
```

Features feedback loops (max 3 regressions), HALT state recovery, token-dense
manifest storage, native epistemic tracking (calibration + behavioral feedback), and work graph parallelization.

See [docs/BLUEPRINT-MODES.md](docs/BLUEPRINT-MODES.md) for challenge mode details.

> **Q: Why is the command `/blueprint` but files are in `.claude/plans/`?**
> A: The command was renamed from `/plan` to `/blueprint` to avoid collision with
> Claude Code's native plan mode. The storage directory was intentionally kept as
> `.claude/plans/` for backward compatibility — it stores general planning state,
> not just blueprints.

### Adversarial Pipeline

Local-first challenge, then external validation:

```
┌─────────────────────────────────────────────────────────────┐
│                    LOCAL ADVERSARIAL LAYER                  │
│  /devils-advocate  →  /overcomplicated  →  /edge-cases     │
└─────────────────────────────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────┐
│                   EXTERNAL REVIEW LAYER                     │
│                      /gpt-review                            │
│   Receives local findings, finds blind spots               │
└─────────────────────────────────────────────────────────────┘
```

### Review Lenses

Opt-in additional review perspectives via `--lenses`:

```bash
/dispatch "Add login endpoint" --review --lenses security,perf,arch
```

| Lens | Agent | Focus |
|------|-------|-------|
| `security` | security-reviewer | OWASP top 10, injection, auth gaps |
| `perf` | performance-reviewer | N+1 queries, blocking I/O, allocations |
| `arch` | architecture-reviewer | Layer violations, circular deps, cohesion |
| `cfn` | cloudformation-reviewer | Tagging, naming, security posture, CF best practices |

**Extended lenses** (require plugins — availability depends on what's installed):

| Lens | Agent | Plugin | Focus |
|------|-------|--------|-------|
| `silent-failures` | pr-review-toolkit:silent-failure-hunter | pr-review-toolkit | Silent failures, inadequate error handling |
| `types` | pr-review-toolkit:type-design-analyzer | pr-review-toolkit | Type design, encapsulation, invariants |
| `comments` | pr-review-toolkit:comment-analyzer | pr-review-toolkit | Comment accuracy, completeness |
| `simplify` | pr-review-toolkit:code-simplifier | pr-review-toolkit | Simplification opportunities |
| `test-coverage` | pr-review-toolkit:pr-test-analyzer | pr-review-toolkit | Test coverage quality, gaps |
| `deep-security` | security-pro:security-auditor | security-pro | Deep vulnerability assessment, OWASP compliance |
| `deep-perf` | performance-optimizer:performance-engineer | performance-optimizer | Bottleneck ID, caching, query optimization |
| `methodology` | superpowers:code-reviewer | superpowers | Methodology-based code review |
| `conventions` | feature-dev:code-reviewer | feature-dev | Convention-focused review |

Extended lenses are available when their required plugin is installed. If missing, a clear message is shown and other lenses proceed normally.

All lenses run after the standard spec + quality review and are advisory (don't block).

### Worktree Isolation

For parallel delegation with independent review:

```bash
/delegate --plan spec.md --review --isolate
```

Each agent works in its own git worktree. After completion, review and accept/reject each task's changes independently.

### Pipelines

Reusable YAML-defined workflows that chain multiple commands together. Stock pipelines are installed into target projects by `/bootstrap-project` and can be customized per project.

```bash
/pipeline ship-feature      # Run a named pipeline
/pipeline list              # List available pipelines
```

Pipeline YAML files live in `commands/templates/stock-pipelines/` (source) and `.claude/pipelines/` (project-local). Each pipeline defines `name`, `description`, `steps`, and `on-error` behavior. See [commands/README.md](commands/README.md) for details.

---

## Plugin Integration

If you have Claude Code plugins installed, Claude Sail workflows automatically detect them and offer plugin-powered enhancements at review stages.

**How it works:**
1. Workflow commands read `~/.claude/plugins/installed_plugins.json` (maintained by Claude Code)
2. If a recognized plugin is installed, additional options appear at workflow decision points
3. If no plugins are installed, everything works exactly as before — zero overhead

**Phase 1** (current): Review integration with 6 plugins. Adds specialized review agents to `/blueprint` Stage 5, `/review` Stage 5, and `/dispatch --lenses`:

| Plugin | Review Agent | Lens |
|--------|-------------|------|
| pr-review-toolkit | 6 specialized agents | `silent-failures`, `types`, `comments`, `simplify`, `test-coverage` |
| security-pro | security-auditor | `deep-security` |
| performance-optimizer | performance-engineer | `deep-perf` |
| superpowers | code-reviewer | `methodology` |
| feature-dev | code-reviewer | `conventions` |
| frontend | reviewer | (Blueprint Stage 5 only) |

**Phase 2** (planned): Investigation and execution integration with code-analysis and testing-suite.

Plugin results are advisory — tagged `[plugin-review]`, they don't block workflows or trigger regressions. See `commands/plugin-enhancers.md` for the full registry.

---

## Obsidian Vault Integration

Bidirectional knowledge bridge between Claude Code sessions and an Obsidian vault:

```
SESSION LIFECYCLE                          OBSIDIAN VAULT
═══════════════                           ══════════════

SessionStart:
  session-sail.sh ─────────────────────→ Reads recent vault notes
                                          (titles injected into context)
During Session:
  /vault-query ────────────────────────→ Search vault for past knowledge
  /vault-save  ────────────────────────→ Capture ideas, findings, patterns

/end Command:
  Vault export ────────────────────────→ Decisions, Findings, Blueprints,
                                          Session summary (with wiki-links)
SessionEnd (safety net):
  session-end-vault.sh ────────────────→ Minimal breadcrumb if /end skipped
```

**Setup:** Copy `~/.claude/hooks/vault-config.sh.example` to `vault-config.sh` and set `VAULT_PATH` to your Obsidian vault location. All vault features gracefully skip when the vault is unavailable.

---

## Defense-in-Depth Security

Three layers of protection:

```
Layer 1: Shell Hooks      → Deterministic blocking (can't be bypassed)
Layer 2: Hookify Rules    → Claude-aware warnings/blocks
Layer 3: CLAUDE.md        → Behavioral guidance (suggestions)
```

See [docs/SECURITY.md](docs/SECURITY.md) for architecture details.

### Shell Hooks

| Hook | Purpose |
|------|---------|
| `session-sail.sh` | **Inject command awareness, active work state, and epistemic context at session start** |
| `state-index-update.sh` | Maintain `.claude/state-index.json` when blueprint/TDD state changes |
| `blueprint-stage-gate.sh` | Block blueprint stage transitions when required data is missing |
| `epistemic-preflight.sh` | Generate calibration feedback and session marker at session start |
| `epistemic-postflight.sh` | Compute deltas and update calibration at session end |
| `worktree-cleanup.sh` | Clean orphaned worktrees from interrupted `--isolate` sessions |
| `protect-claude-md.sh` | Block accidental CLAUDE.md modifications |
| `tdd-guardian.sh` | Block implementation edits during TDD RED phase |
| `dangerous-commands.sh` | Block `rm -rf /`, `chmod 777`, force push to main |
| `secret-scanner.sh` | Scan for API keys before commits |
| `cfn-lint-check.sh` | Auto-lint CloudFormation templates after edit (fail-open) |
| `after-edit.sh` | Auto-format files |
| `statusline.sh` | Toolkit-aware status line (model, cost, context, active work) |
| `notify.sh` | Desktop notifications |
| `session-end-vault.sh` | Safety-net vault export when `/end` not used |
| `failure-escalation.sh` | Track repeated failures and escalate when threshold exceeded |
| `session-end-cleanup.sh` | Clean up signal files and temporary state at session end |

### Hookify Rules

| Rule | What It Blocks |
|------|----------------|
| `surgical-rm` | `rm -rf /`, `~`, `/home` (allows safe targets) |
| `force-push-protection` | Force push to protected branches |
| `chmod-777` | World-writable permissions |
| `remote-exec-protection` | `curl \| bash` patterns |
| `disk-ops-protection` | `dd of=/dev/*`, `mkfs` |
| `exfiltration-protection` | Network transfers of sensitive files |
| `env-exposure-protection` | Reading `.env` files (warns) |

---

## Installation Options

### Full Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-sail/main/install.sh | bash
```

### Components Only

```bash
# Clone and pick what you need
git clone https://github.com/ntanner-ctrl/claude-sail.git
cd claude-sail

# Shell hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Hookify rules
cp hookify-rules/*.local.md ~/.claude/

# Commands
cp commands/*.md ~/.claude/commands/
```

### Configuration

Merge into `~/.claude/settings.json`. Minimal example (safety hooks only):

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/dangerous-commands.sh" },
        { "type": "command", "command": "~/.claude/hooks/secret-scanner.sh" }
      ]
    }]
  }
}
```

See `settings-example.json` for complete configuration with all hooks and status line.

#### Temporarily Disabling Hooks

Set `SAIL_DISABLED_HOOKS` to disable specific hooks for a single session:

```bash
SAIL_DISABLED_HOOKS=secret-scanner,tdd-guardian claude
```

Comma-separated hook names (without path or `.sh` extension). Unset = all hooks active. Avoid exporting this in `.bashrc`/`.zshrc` — it will persist across all sessions.

---

## Creating Domain Kits

The [Ops Starter Kit](ops-starter-kit/) demonstrates how to create specialized extensions. Use it as a template:

```bash
cp -r ops-starter-kit my-domain-kit
```

Ideas: Frontend, Data Engineering, ML Ops, Security, Mobile, Game Dev

See [docs/CREATING-DOMAIN-KITS.md](docs/CREATING-DOMAIN-KITS.md) for the full guide.

---

## Project Philosophy

### Context is Everything

Claude Code is powerful, but without project context it's guessing at your conventions, architecture, and workflows. Claude Sail provides that context.

### Safety by Default

Every hook exists because someone made that mistake. The goal isn't to restrict Claude—it's to catch the 3 AM mistakes before they cause damage.

### Plan Before You Build

Speed without understanding leads to confident mistakes. The planning infrastructure forces understanding to catch up with speed before execution proceeds.

### Evolve, Don't Prescribe

Claude Sail adapts to project maturity:
- **Nascent** → Full starter kit
- **Growing** → Selective additions
- **Mature** → Suggestions only

---

## Documentation

**Behavioral Evals:** `test.sh` includes Category 8 — behavioral smoke tests that run `scripts/behavioral-smoke.sh` against `evals/evals.json` fixtures to verify command dispatch behavior. Skipped gracefully if `jq` is not installed.

| Document | Type | Purpose |
|----------|------|---------|
| [GETTING_STARTED.md](GETTING_STARTED.md) | Tutorial | Step-by-step first-time setup |
| [commands/README.md](commands/README.md) | Reference | All commands documented |
| [docs/SECURITY.md](docs/SECURITY.md) | Explanation | Defense-in-depth architecture |
| [docs/ENFORCEMENT-PATTERNS.md](docs/ENFORCEMENT-PATTERNS.md) | Reference | Command description enforcement tiers |
| [docs/PLANNING-STORAGE.md](docs/PLANNING-STORAGE.md) | Reference | Planning state and storage schemas (v2) |
| [docs/WIZARD-STATE.md](docs/WIZARD-STATE.md) | Reference | Wizard workflow state schema and content contracts |
| [docs/BLUEPRINT-MODES.md](docs/BLUEPRINT-MODES.md) | Explanation | Challenge mode comparison (vanilla, debate, family, team) |
| [docs/CREATING-DOMAIN-KITS.md](docs/CREATING-DOMAIN-KITS.md) | How-to | Build your own domain kit |
| [ops-starter-kit/README.md](ops-starter-kit/README.md) | Reference | Ops-specific extensions |

---

## Acknowledgments

Built with patterns and inspiration from:

- **[TheDecipherist/claude-code-mastery](https://github.com/TheDecipherist/claude-code-mastery)** - Shell hook patterns, exit code conventions, security research
- **[bmad-code-org/BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)** - Agent orchestration patterns
- **[barkain/claude-code-workflow-orchestration](https://github.com/barkain/claude-code-workflow-orchestration)** - Enforcement-via-hook pattern
- **[Priivacy-ai/spec-kitty](https://github.com/Priivacy-ai/spec-kitty)** - Git worktree isolation for parallel agents
- **[ryanthedev/code-foundations](https://github.com/ryanthedev/code-foundations)** - Code Complete SE skills (debug, design-check)
- **[cowwoc/claude-code-cat](https://github.com/cowwoc/claude-code-cat)** - Multi-perspective review lenses
- **[Nubaeon/empirica](https://github.com/Nubaeon/empirica)** - Original epistemic self-assessment framework (inspired claude-sail's native tracking system)

---

## Contributing

Found a useful hook? Built a great agent? PRs welcome!

## License

MIT - Use it, modify it, share it.

---

*Built by [@flawlesscowboy0](https://reddit.com/u/flawlesscowboy0) after one too many 3 AM mistakes.*
