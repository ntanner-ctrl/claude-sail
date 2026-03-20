# Claude Sail

Structured workflows, safety guardrails, and planning discipline for Claude Code. A human-AI collaborative discipline toolkit.

## Quick Reference

- **Run tests:** `bash test.sh` (~67 checks: syntax, counts, lint, JSON, install dry-run, behavioral evals)
- **Install locally:** `bash install.sh` (copies to `~/.claude/`)
- **Verify install:** `ls ~/.claude/commands/blueprint.md`
- **Run from repo:** `cd /path/to/project && claude` then `/bootstrap-project`

## Architecture Overview

This repo is a **distribution package** — not a runtime app. `install.sh` copies files to `~/.claude/` where Claude Code discovers them. The repo itself is the source of truth; `~/.claude/` is the install target.

```
claude-sail/
├── commands/          # 61 slash commands (*.md with YAML frontmatter, includes plugin-enhancers reference)
│   ├── templates/     # Stock elements installed by /bootstrap-project into target projects
│   │   ├── stock-hooks/      # 6 prompt-based hooks for target projects
│   │   ├── stock-agents/     # 3 agents for target projects
│   │   ├── stock-commands/   # 3 commands for target projects
│   │   ├── stock-pipelines/  # 3 YAML pipeline templates for target projects
│   │   ├── vault-notes/      # Obsidian vault note templates
│   │   ├── prompts/          # Shared prompt templates (dispatch/delegate review lenses)
│   │   └── documentation/    # Diataxis doc templates
│   └── *.md           # The actual toolkit commands
├── agents/            # 6 review agents (spec, quality, security, performance, architecture, CloudFormation)
├── hooks/             # 19 shell files: 18 hooks + 1 utility (_audit-log.sh) for SessionStart, PreToolUse, PostToolUse, SessionEnd, etc.
├── hookify-rules/     # 7 YAML-based safety rules (*.local.md)
├── plugins/           # Session-start plugin (sail-toolkit)
├── evals/             # Behavioral eval fixtures (evals.json) — used by test.sh Category 8
├── scripts/           # Utility scripts (not hooks) — may use strict error modes (behavioral-smoke.sh)
├── ops-starter-kit/   # Domain extension example for infrastructure teams
├── docs/              # Architecture explanations (Diataxis: explanation type)
├── plans/             # Legacy planning directory (pre-.claude/ era)
├── _OLD/              # Archived iterations (gitignored)
├── VERSION            # Current toolkit version (semver)
├── install.sh         # Installer — copies everything to ~/.claude/
├── settings-example.json  # Full settings.json template for users
├── GETTING_STARTED.md     # Tutorial for new users
└── README.md              # Project overview and quick start
```

### Key Distinction: Source vs Target

| Directory | Lives in... | Purpose |
|-----------|-------------|---------|
| `commands/*.md` | This repo → `~/.claude/commands/` | Toolkit commands (user runs these) |
| `commands/templates/stock-*` | This repo → `~/.claude/commands/templates/` | Elements `/bootstrap-project` installs into TARGET projects |
| `commands/templates/stock-pipelines/` | This repo → `~/.claude/commands/templates/stock-pipelines/` | YAML pipeline templates for target projects (copy-if-not-exists) |
| `agents/*.md` | This repo → `~/.claude/agents/` | Global review agents |
| `hooks/*.sh` | This repo → `~/.claude/hooks/` | Shell hooks wired via settings.json |
| `scripts/*.sh` | This repo only (not installed) | Utility scripts — CAN use strict error modes (not hooks) |
| `evals/evals.json` | This repo only (not installed) | Behavioral eval fixtures for test.sh Category 8 |

## Key Conventions

### Command Authoring

Commands are Markdown files with YAML frontmatter. The `description` field is critical — it determines when Claude invokes the command.

**Enforcement Tiers** (see `docs/ENFORCEMENT-PATTERNS.md`):

| Tier | Opens With | Use For |
|------|-----------|---------|
| Safety-Critical | `STOP. You MUST...` | Irreversible actions (push, deploy) |
| Process-Critical | `You MUST use this for...` | Planning, specs, testing |
| Adversarial | `REQUIRED after...` | Review stages |
| Specification | `You MUST create this before...` | Agent/hook specs |
| Utility | `Use when...` | Tools, setup, docs |
| Deprecated | `DEPRECATED: Use X instead.` | Superseded commands |

**Rules:**
- Description = trigger condition ONLY (never summarize the workflow)
- No escape hatches (`consider`, `might`, `optionally` are forbidden)
- Use ALL-CAPS quantifiers: `ANY`, `ALWAYS`, `BEFORE`, `AFTER`
- State consequences for MUST-level commands

### Agent Authoring

Agents use YAML frontmatter with `name`, `description`, `tools` fields. Each agent has a narrow mandate — the "Stay in your lane" pattern. See `agents/spec-reviewer.md` for the canonical example.

### Hook Authoring (Shell)

All hooks follow the **fail-open** pattern:
- Exit 0: Allow (proceed silently)
- Exit 1: User-facing error
- Exit 2: Block with feedback TO Claude (stderr)
- Use `set +e` — hook bugs must not halt work
- Include timeouts for external tool calls

### Hook Runtime Toggles

Set `SAIL_DISABLED_HOOKS` to temporarily disable specific hooks:

```bash
SAIL_DISABLED_HOOKS=secret-scanner,tdd-guardian claude
```

Comma-separated hook names (without path or `.sh` extension). Unset = all hooks active.

**Warning:** If exported in `.bashrc`/`.zshrc`, the disable persists across ALL sessions.

### Baseline Hookify Rules

Four hookify rules are marked `baseline: true` — security-critical protections:
- `force-push-protection`, `exfiltration-protection`, `disk-ops-protection`, `chmod-777`

**Current effect: convention signal only.** The hookify plugin does not currently enforce this field. Enforcement requires upstream hookify plugin changes.

### Pipeline YAML Format

Pipeline files in `commands/templates/stock-pipelines/` define reusable workflows. Required fields:
- `name:` — Pipeline identifier (matches filename without extension)
- `description:` — What this pipeline does
- `steps:` — Ordered list of commands to run
- `on-error:` — Behavior on step failure (`stop`, `continue`, or `rollback`)

Stock pipelines are copied with **copy-if-not-exists** semantics — user customizations are preserved on reinstall. The `/pipeline` command discovers pipelines from `.claude/pipelines/` in the target project.

### scripts/ vs hooks/ Convention

`hooks/*.sh` files are Claude Code hooks — they MUST follow the fail-open pattern (no `set -e`, use `set +e`, exit 0/1/2 only). `scripts/*.sh` files are standalone utilities not wired as hooks — they CAN use strict error modes (`set -euo pipefail`) and are called explicitly rather than triggered by Claude Code events. `behavioral-smoke.sh` is the canonical example.

### Planning Storage

Blueprints store artifacts in `.claude/plans/<name>/`:
- `state.json` — Progress tracking (v2 schema with debate, confidence, regression)
- `manifest.json` — Token-dense recovery format (~5-10x cheaper than reading all markdown)
- `describe.md`, `spec.md`, `adversarial.md`, etc. — Stage artifacts

See `docs/PLANNING-STORAGE.md` for full schemas.

## Key Patterns

### Installer Self-Maintenance

`install.sh` uses tarball extraction (not a file list) so new files are automatically included:
```bash
curl -fsSL "$TARBALL_URL" | tar xz -C "$TEMP_DIR"
```
When adding new commands/agents/hooks, they're picked up by the installer automatically — no manifest update needed.

### Defense-in-Depth Security

Three layers (see `docs/SECURITY.md`):
1. **Shell hooks** (PreToolUse) — deterministic, can't be argued around
2. **Hookify rules** (*.local.md) — Claude-readable, can warn or block
3. **CLAUDE.md** (target projects) — behavioral guidance, suggestions only

### Blueprint Challenge Modes

Default: **debate** (3-round sequential chain). See `docs/BLUEPRINT-MODES.md`:
- Vanilla: single perspective
- Debate: Challenger → Defender → Judge (escalating depth)
- Team: 3 concurrent agents (experimental, requires flag)

## Common Tasks

### Adding a new command
1. Create `commands/<name>.md` with YAML frontmatter
2. Choose the correct enforcement tier for `description`
3. Validate: `grep -n "^description:" commands/<name>.md` — verify trigger-only language
4. Test: `bash install.sh` then start a new Claude Code session
5. Update `commands/README.md` — add entry to appropriate category table
6. Update `README.md` — add to "Commands at a Glance" if it's a primary command

### Adding a new agent
1. Create `agents/<name>.md` with YAML frontmatter (`name`, `description`, `tools`)
2. Define narrow mandate (what it does AND what it explicitly does NOT do)
3. Test: `bash install.sh`, verify agent appears in session
4. Update `install.sh` output message if agent count changes
5. Update `README.md` agent count

### Adding a new shell hook
1. Create `hooks/<name>.sh` — follow fail-open pattern
2. Add appropriate exit code handling (0/1/2)
3. Update `settings-example.json` with the hook wiring
4. Update `install.sh` output to list the new hook
5. Update `docs/SECURITY.md` hook table

### Adding stock elements (for target projects)
Stock elements go in `commands/templates/stock-{hooks,agents,commands}/`. These are what `/bootstrap-project` copies into user projects — they're NOT used by this toolkit itself.

## Testing

Run `bash test.sh` for automated verification (~67 checks across 8 categories):

```bash
bash test.sh
```

**What it checks:**
1. **Shell syntax** — `bash -n` on all hooks, install.sh, and scripts/behavioral-smoke.sh
2. **Shellcheck** — lint warnings (graceful skip if not installed)
3. **File counts** — commands, agents, hooks, hookify rules, stock elements, stock pipelines vs README claims
4. **Enforcement lint** — no escape-hatch language in descriptions, required frontmatter, stock pipeline required fields
5. **Hook conventions** — no `set -e`, no `eval`, `set +e` presence
6. **JSON validation** — settings-example.json, plugin.json, plan state files
7. **Install dry run** — runs install.sh in a temp `$HOME`, verifies all files land correctly
8. **Behavioral evals** — runs `scripts/behavioral-smoke.sh` against `evals/evals.json` fixtures (skipped if `jq` absent)

**Manual verification** (not covered by test.sh):
- **Hook test:** Start a Claude Code session in any project and verify hooks fire
- **Remote install:** `curl -fsSL <tarball_url> | bash` path (test.sh only tests local install)

## Important Context

- **No package manager** — this is a pure shell/markdown toolkit. No node, no pip, no build step.
- **_OLD/ is gitignored** — contains previous iterations for reference, not part of the distribution.
- **.claude/ directory in this repo** — contains planning artifacts for the toolkit's own development. Not part of the install.
- **install.sh has two paths** — local (if run from cloned repo) and remote (if piped via curl). Both must work.
- **Epistemic tracking** — The blueprint workflow integrates with native epistemic tracking (`~/.claude/epistemic.json`). Session IDs are stored in `state.json`.

## Do Not

- Do NOT add workflow summaries to command `description` fields — Claude will improvise instead of invoking
- Do NOT use escape-hatch language (`consider`, `might`, `optionally`) in MUST-tier commands
- Do NOT add `set -e` to hooks — it breaks the fail-open pattern
- Do NOT modify stock templates (`commands/templates/`) thinking they affect this toolkit — they affect TARGET projects
- Do NOT add dependencies — this toolkit must work with just bash and curl
- Do NOT forget to update both `README.md` AND `commands/README.md` when adding commands — they have independent tables
