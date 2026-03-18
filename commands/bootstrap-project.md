---
description: Use when setting up ANY new project for claude-sail. Creates CLAUDE.md, detects integrations, installs hooks, agents, and commands matched to your stack.
argument-hint: --force to overwrite existing, --skip-claude-md to keep existing docs, --type python|node|docker
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - Task
---

# Project Bootstrap

Complete claude-sail extensibility setup for any project. This command:
1. Analyzes your project structure, type, maturity, and integrations
2. Generates comprehensive CLAUDE.md documentation
3. Initializes detected integrations (Empirica, Vault, Plugins)
4. Installs appropriate stock hooks, agents, and commands
5. Tracks what's installed for future updates

Think hard before making changes. Take time to understand the project first.

## Arguments

- `--force`: Overwrite existing stock elements (respects customizations by default)
- `--skip-claude-md`: Don't generate/update CLAUDE.md (keep existing)
- `--skip-stock`: Don't install stock elements (documentation only)
- `--type <type>`: Force project type (python, node, rust, go, docker, monorepo)
- `--minimal`: Install only essential elements (hooks only, no agents/commands)

---

# PHASE 1: Project Analysis

## 1.1 Structure Scan

Read the root directory structure (2-3 levels deep):

```
Questions to answer:
- What is the project root layout?
- What are the main source directories?
- What configuration files exist?
- Is there an existing .claude/ directory?
```

## 1.2 Language & Framework Detection

Identify primary technologies:

| Indicator | Language/Framework | Project Type |
|-----------|-------------------|--------------|
| `pyproject.toml`, `setup.py`, `requirements.txt` | Python | python |
| `package.json` | Node.js | node |
| `package.json` + `react` dep | React | react |
| `package.json` + `vue` dep | Vue | vue |
| `package.json` + `next` dep | Next.js | nextjs |
| `Cargo.toml` | Rust | rust |
| `go.mod` | Go | go |
| `Dockerfile`, `docker-compose.yml` | Docker | docker |
| `*.tf`, `terraform/` | Terraform | terraform |
| `serverless.yml` | Serverless | serverless |
| Multiple `package.json` or `pyproject.toml` | Monorepo | monorepo |

Record all detected types (a project can be multiple: python + docker + terraform).

## 1.3 Maturity Assessment

Score the project 0-10 based on these signals:

### Nascent Signals (lower score)
- [ ] <10 source files (-2)
- [ ] <5 git commits (-2)
- [ ] No test directory (-1)
- [ ] No CI/CD config (-1)
- [ ] No documentation beyond README (-1)

### Mature Signals (higher score)
- [ ] >50 source files (+2)
- [ ] >100 git commits (+1)
- [ ] Multiple test directories (+1)
- [ ] CI/CD configuration present (+1)
- [ ] Existing .claude/ directory with content (+2)
- [ ] Custom commands/hooks/agents defined (+2)
- [ ] Comprehensive README/docs (+1)

**Maturity Levels:**
- **Nascent** (0-3): New project, install full starter kit
- **Growing** (4-6): Established patterns, selective installation
- **Mature** (7-10): Complex project, suggest rather than install

## 1.4 Plugin Detection

Read `~/.claude/plugins/installed_plugins.json` if it exists. Keys are scoped as `name@registry` (e.g., `pr-review-toolkit@claude-code-plugins`). Match by prefix: strip the `@registry` suffix before comparing against known plugin names. Record which plugins are available for Phase 5 recommendations.

## 1.5 Vault Detection

Source `~/.claude/hooks/vault-config.sh` if it exists:
```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

Record `VAULT_ENABLED` and `VAULT_PATH`. This informs Phase 4.

## 1.6 Empirica Detection

Check if the `empirica` CLI is available:
```bash
which empirica 2>/dev/null
```

Record availability. This informs Phase 3.

## 1.7 Existing Setup Audit

Check for existing manifest — read `.claude/sail-manifest.json` OR `.claude/bootstrap-manifest.json` (backward compat, prefer new name):

1. Read manifest if present
2. List existing hooks, agents, commands
3. Identify which are stock vs custom (via manifest or heuristics)
4. Check for customizations (hash comparison if manifest exists)

---

# PHASE 2: CLAUDE.md Generation

Use the assess-project methodology to generate comprehensive documentation.

## 2.1 Exploration

### Structure Analysis
- Read root directory structure (2-3 levels)
- Identify primary language(s) and framework(s)
- Note build system, package manager, dependencies
- Find configuration files (.env.example, docker-compose, CI configs)

### Conventions Detection
- Sample 3-5 representative source files
- Check for linting/formatting configs
- Identify testing framework(s) and patterns
- Note naming conventions (files, functions, classes)

### Documentation Audit
- Read existing README, CONTRIBUTING, architectural docs
- Check for existing CLAUDE.md
- Identify undocumented but important patterns

### Workflow Discovery
- Find available scripts (package.json, Makefile, shell scripts)
- Identify how to: build, test, lint, run locally, deploy
- Note multi-service or monorepo patterns

## 2.2 Gap Analysis

Identify:
1. What would need to be rediscovered each session?
2. What ambiguities would slow down development?
3. What areas are error-prone without guidance?
4. What manual steps could be automated?

## 2.3 Generate CLAUDE.md

Create or update `.claude/CLAUDE.md` with:

```markdown
# [Project Name]

[One sentence description]

## Quick Reference
- Build: `[command]`
- Test: `[command]`
- Lint: `[command]`
- Run locally: `[command]`

## Architecture Overview
[2-3 sentences]

## Project Structure
[key directories with descriptions]

## Key Conventions
[naming, file org, import patterns, code style]

## Key Patterns
[documented with code examples]

## Important Context
[non-obvious deps, intentional oddities, extra-care areas]

## Common Tasks
### How to add a new [X]
### How to modify [Y]

## Testing
[framework, location, conventions]

## Integrations
[IF Empirica detected]
### Empirica (Epistemic Tracking)
- Session tracking is available for this project
- Use `finding_log` to capture discoveries during work
- Use `mistake_log` to record errors for future prevention
- Submit preflight/postflight assessments at session boundaries

[IF Vault detected]
### Obsidian Vault
- Knowledge vault is connected at: [VAULT_PATH]
- Use `/vault-save` to capture findings, decisions, and patterns
- Use `/vault-query` to search prior knowledge before starting work

[IF plugins detected]
### Available Plugins
- [plugin-name]: [brief description of what it adds]

## Do Not
[anti-patterns, protected files, common mistakes]
```

---

# PHASE 3: Empirica Initialization

Only runs if Empirica CLI was detected in Phase 1.

## 3.1 If Empirica IS detected

1. Check if `.empirica/` directory exists in project root
2. If not, create it: `mkdir -p .empirica`
3. Check if project is registered with Empirica:
   ```bash
   empirica project-bootstrap --output json 2>/dev/null
   ```
4. If registration fails or returns error, log and continue (fail-soft)
5. Present to user:
   ```
   Empirica integration:
     ✓ CLI available
     [✓/✗] Project registered

   Empirica enables epistemic tracking — it helps you (and Claude)
   measure what you know vs. what you think you know across sessions.

   This is optional but recommended. See /toolkit for Empirica commands.
   ```

## 3.2 If Empirica is NOT detected

Present to user:
```
Empirica integration:
  ✗ CLI not found (optional — install via: pipx install empirica)

  Empirica tracks confidence and learning across sessions.
  The toolkit works fine without it.
```

---

# PHASE 4: Vault Configuration

Only runs if vault config was detected in Phase 1.

## 4.1 If Vault IS configured and accessible

1. Source `~/.claude/hooks/vault-config.sh`
2. If `VAULT_ENABLED=1` and `VAULT_PATH` is set and accessible:
   ```
   Obsidian vault integration:
     ✓ Vault found at: [VAULT_PATH]
     ✓ Writable

   The vault captures findings, decisions, and patterns across sessions.
   Use /vault-save to store knowledge, /vault-query to retrieve it.
   ```

## 4.2 If Vault is NOT configured or inaccessible

Present to user:
```
Obsidian vault integration:
  ✗ No vault configured

To connect an Obsidian vault:
  1. Create ~/.claude/hooks/vault-config.sh with:
     VAULT_ENABLED=1
     VAULT_PATH="/path/to/your/vault"
  2. Re-run /bootstrap-project

This is optional. The toolkit works fine without a vault.
```

---

# PHASE 5: Plugin Recommendation

Based on project type detected in Phase 1, recommend relevant plugins.

## 5.1 Recommendation Matrix

| Project Type | Recommended Plugins |
|-------------|-------------------|
| Any | `pr-review-toolkit` (code review agents) |
| React/Vue/Next | `frontend` (UI dev workflow) |
| Any with tests | `testing-suite` (test generation) |
| Any with deployment | `security-pro` (security audit) |
| Any complex | `superpowers` (structured planning skills) |

## 5.2 Detection Logic

For each recommended plugin, check if it was detected in Phase 1's plugin scan. Use prefix matching: a key like `pr-review-toolkit@claude-code-plugins` matches plugin name `pr-review-toolkit`.

## 5.3 Present Recommendations

```
Plugin recommendations based on your project:
  [✓ installed] pr-review-toolkit — 6 specialized review agents
  [  available ] frontend — UI development workflow with design validation
  [  available ] testing-suite — Test generation and coverage analysis

Plugins are optional. Install via their respective repos.
```

---

# PHASE 6: Stock Element Selection

Based on maturity and project type, select appropriate elements.

## 6.1 Selection Logic

```
IF maturity = nascent (0-3):
    Install ALL universal hooks
    Install troubleshooter + code-reviewer agents
    Skip commands (no established workflows yet)

ELIF maturity = growing (4-6):
    Install universal hooks IF NOT already present
    Install project-type-specific elements
    Suggest commands for detected workflows

ELSE maturity = mature (7-10):
    Only install explicitly requested elements
    Suggest rather than auto-install
    Focus on filling gaps in existing setup
```

## 6.2 Universal Hooks (All Projects)

- `test-coverage-reminder.md` - Remind about tests when editing source
- `security-warning.md` - Warn when editing sensitive files
- `compaction-safety.md` - Lightweight compaction awareness for context window management

## 6.3 Conditional Hooks

- `empirica-basics.md` - Simplified finding capture (only if Empirica detected in Phase 1)
- `documentation-standards.md` - Documentation quality reminders (only if `docs/` directory exists)
- `interface-validation.md` - Module pattern consistency (only if consistent module patterns detected)

## 6.4 Universal Agents (All Projects)

- `troubleshooter.md` - Systematic issue diagnosis
- `code-reviewer.md` - Code review with confidence scoring

## 6.5 Conditional Agents

- `architecture-explainer.md` - Architectural context and guidance (only if maturity >= 4)

## 6.6 Commands (Growing/Mature Only)

- `test-all.md` - Unified test runner
- `health-check.md` - Project health assessment
- `scaffold.md` - Code scaffolding (only if maturity >= 5)

---

# PHASE 7: Installation

## 7.1 Create Directory Structure

```bash
mkdir -p .claude/hooks .claude/agents .claude/commands .claude/pipelines
```

The `.claude/pipelines/` directory is where project-local pipeline YAML files live. It starts empty — add custom workflow pipelines here as the project grows.

## 7.2 Copy Stock Elements

For each selected element:

1. Read template from `~/.claude/commands/templates/stock-{type}/{name}.md`
2. Apply any project-specific customizations:
   - Update file patterns to match project structure
   - Adjust tool references to match project
3. Write to `.claude/{type}/{name}.md`
4. Compute SHA-256 hash for tracking

## 7.3 Create/Update Manifest

Create `.claude/sail-manifest.json`:

```json
{
  "version": "1.0.0",
  "bootstrapped_at": "2026-01-08T12:00:00Z",
  "project_type": ["python", "docker"],
  "maturity_score": 5,
  "upgraded_from": "bootstrap-manifest",
  "stock_elements": {
    "hooks/test-coverage-reminder.md": {
      "source_version": "1.0.0",
      "installed_hash": "sha256:abc123...",
      "customized": false
    },
    "hooks/security-warning.md": {
      "source_version": "1.0.0",
      "installed_hash": "sha256:def456...",
      "customized": false
    },
    "hooks/compaction-safety.md": {
      "source_version": "1.0.0",
      "installed_hash": "sha256:jkl012...",
      "customized": false
    },
    "agents/troubleshooter.md": {
      "source_version": "1.0.0",
      "installed_hash": "sha256:ghi789...",
      "customized": false
    }
  },
  "custom_elements": [
    "hooks/custom-validation.md",
    "agents/domain-expert.md"
  ]
}
```

Note: The `"upgraded_from": "bootstrap-manifest"` field is included ONLY when migrating from an existing `.claude/bootstrap-manifest.json`. Omit it for fresh installs.

## 7.4 Handle Re-runs

When bootstrap has already run:

1. Read existing manifest (check `.claude/sail-manifest.json` first, fall back to `.claude/bootstrap-manifest.json`)
2. For each stock element:
   - Compute current file hash
   - Compare to `installed_hash` in manifest
   - If different: Mark as customized, DO NOT overwrite (unless --force)
   - If same: Safe to update if newer template available
3. Preserve custom elements (not in stock list)
4. Update manifest with new timestamp
5. If migrating from `bootstrap-manifest.json`, write new `sail-manifest.json` with `"upgraded_from": "bootstrap-manifest"` field

---

# PHASE 8: Summary Report

Output a complete summary:

```markdown
## Setup Complete

### Project Profile
- **Type:** [detected types]
- **Maturity:** [level] (score: N/10)
- **Integrations:** Empirica [✓/✗] │ Vault [✓/✗] │ Plugins [N installed]

### What Was Installed
[organized by category with counts]

#### CLAUDE.md
Created `.claude/CLAUDE.md` with:
- Quick Reference
- Architecture Overview
- Key Patterns
- Common Tasks
- Integrations (if any detected)

#### Hooks ([count])
- [list installed hooks with descriptions]

#### Agents ([count])
- [list installed agents with descriptions]

#### Commands ([count])
- [list installed commands with descriptions, or note why skipped]

### Recommendations
[prioritized: Immediate / Soon / Eventually]

### Directories Created
- `.claude/CLAUDE.md` — project documentation
- `.claude/hooks/` — project-local hooks
- `.claude/agents/` — project-local agents
- `.claude/commands/` — project-local commands
- `.claude/pipelines/` — add custom workflow YAML files here

### Next Steps
1. Review generated CLAUDE.md and refine
2. Run /start at the beginning of your next session
3. Run /toolkit to see all available commands
4. Try /blueprint [name] for your next non-trivial change
5. Run /pipeline list to see available workflow pipelines
```

---

# Templates Location

Stock element templates are stored at:
```
~/.claude/commands/templates/
├── stock-hooks/
│   ├── test-coverage-reminder.md
│   ├── security-warning.md
│   ├── compaction-safety.md
│   ├── empirica-basics.md
│   ├── documentation-standards.md
│   └── interface-validation.md
├── stock-agents/
│   ├── troubleshooter.md
│   ├── code-reviewer.md
│   └── architecture-explainer.md
├── stock-commands/
│   ├── test-all.md
│   ├── health-check.md
│   └── scaffold.md
└── stock-pipelines/
    ├── ship-feature.yaml
    ├── quality-check.yaml
    └── quick-fix.yaml
```

---

$ARGUMENTS
