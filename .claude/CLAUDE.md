# Claude Sail

Structured workflows, safety guardrails, and planning discipline for Claude Code. A human-AI collaborative discipline toolkit.

## Quick Reference

- **Test install locally:** `bash install.sh` (copies to `~/.claude/`)
- **Verify install:** `ls ~/.claude/commands/blueprint.md`
- **Count commands:** `ls commands/*.md | grep -v README | wc -l` (expect 47)
- **Count agents:** `ls agents/*.md | wc -l` (expect 6)
- **Count hooks:** `ls hooks/*.sh | wc -l` (expect 18)
- **Lint enforcement:** `grep -rn "^description:.*\(consider\|might\|optionally\)" commands/` (expect 0 matches)
- **Run from repo:** `cd /path/to/project && claude` then `/bootstrap-project`

## Architecture Overview

This repo is a **distribution package** — not a runtime app. `install.sh` copies files to `~/.claude/` where Claude Code discovers them. The repo itself is the source of truth; `~/.claude/` is the install target.

```
claude-sail/
├── commands/          # 47 slash commands (*.md with YAML frontmatter, includes plugin-enhancers reference)
│   ├── templates/     # Stock elements installed by /bootstrap-project into target projects
│   │   ├── stock-hooks/      # 6 prompt-based hooks for target projects
│   │   ├── stock-agents/     # 3 agents for target projects
│   │   ├── stock-commands/   # 3 commands for target projects
│   │   ├── vault-notes/      # Obsidian vault note templates
│   │   ├── prompts/          # Shared prompt templates (dispatch/delegate review lenses)
│   │   └── documentation/    # Diataxis doc templates
│   └── *.md           # The actual toolkit commands
├── agents/            # 6 review agents (spec, quality, security, performance, architecture, CloudFormation)
├── hooks/             # 18 shell hooks (*.sh) for SessionStart, PreToolUse, PostToolUse, SessionEnd, etc.
├── hookify-rules/     # 7 YAML-based safety rules (*.local.md)
├── plugins/           # Session-start plugin (sail-toolkit)
├── ops-starter-kit/   # Domain extension example for infrastructure teams
├── docs/              # Architecture explanations (Diataxis: explanation type)
├── plans/             # Legacy planning directory (pre-.claude/ era)
├── _OLD/              # Archived iterations (gitignored)
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
| `agents/*.md` | This repo → `~/.claude/agents/` | Global review agents |
| `hooks/*.sh` | This repo → `~/.claude/hooks/` | Shell hooks wired via settings.json |

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

No automated test suite. Verification is manual:
- **Install test:** `bash install.sh` and verify files copied correctly
- **Command count:** `ls commands/*.md | grep -v README | wc -l` should match README claims
- **Enforcement lint:** `grep -rn "^description:.*\(consider\|might\|optionally\)" commands/` should return nothing
- **Hook test:** Start a Claude Code session in any project and verify hooks fire

## Important Context

- **No package manager** — this is a pure shell/markdown toolkit. No node, no pip, no build step.
- **_OLD/ is gitignored** — contains previous iterations for reference, not part of the distribution.
- **.claude/ directory in this repo** — contains planning artifacts for the toolkit's own development. Not part of the install.
- **install.sh has two paths** — local (if run from cloned repo) and remote (if piped via curl). Both must work.
- **Empirica integration** — The blueprint workflow integrates with Empirica MCP for epistemic tracking. Session IDs are stored in `state.json`.

## Do Not

- Do NOT add workflow summaries to command `description` fields — Claude will improvise instead of invoking
- Do NOT use escape-hatch language (`consider`, `might`, `optionally`) in MUST-tier commands
- Do NOT add `set -e` to hooks — it breaks the fail-open pattern
- Do NOT modify stock templates (`commands/templates/`) thinking they affect this toolkit — they affect TARGET projects
- Do NOT add dependencies — this toolkit must work with just bash and curl
- Do NOT forget to update both `README.md` AND `commands/README.md` when adding commands — they have independent tables
