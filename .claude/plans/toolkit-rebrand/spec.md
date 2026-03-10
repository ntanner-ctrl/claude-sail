# Change Specification: toolkit-rebrand

## Summary

Rename claude-bootstrap to claude-sail, rebuild `/bootstrap-project` with modern toolkit awareness (Empirica, vault, plugins), refresh stock elements, and update all documentation to reflect the project's evolved identity as a comprehensive Claude Code extensibility toolkit.

## What Changes

### Files/Components Touched

#### Layer 1: Identity & Infrastructure (Rename)

| File | Nature of Change |
|------|------------------|
| `install.sh` | Modify — new repo URL, banner, output text, plugin paths |
| `hooks/session-bootstrap.sh` | Rename to `hooks/session-sail.sh` + update content |
| `plugins/bootstrap-toolkit/` | Rename to `plugins/sail-toolkit/` |
| `plugins/sail-toolkit/.claude-plugin/plugin.json` | Modify — new name, description |
| `plugins/sail-toolkit/scripts/check-setup-quiet.sh` | Modify — update references |
| `plugins/sail-toolkit/hooks/hooks.json` | Modify — update script path refs |
| `settings-example.json` | Modify — update hook and plugin paths |
| `.claude/settings.local.json` | Modify — update hook and plugin paths |
| `.claude/bootstrap-manifest.json` | Rename to `.claude/sail-manifest.json` |

#### Layer 2: Core Command Rebuild

| File | Nature of Change |
|------|------------------|
| `commands/bootstrap-project.md` | Major rewrite — 8 new phases, modern CLAUDE.md template |
| `commands/check-project-setup.md` | Modify — align with new bootstrap output, dual manifest detection |
| `commands/start.md` | Minor modify — update project identity references |
| `commands/assess-project.md` | Modify — update deprecation notice to reference new project name |

#### Layer 3: Stock Element Refresh

| File | Nature of Change |
|------|------------------|
| `commands/templates/stock-hooks/test-coverage-reminder.md` | Modify — refresh content |
| `commands/templates/stock-hooks/security-warning.md` | Modify — refresh content |
| `commands/templates/stock-hooks/interface-validation.md` | Modify — refresh content |
| `commands/templates/stock-hooks/documentation-standards.md` | Modify — refresh content |
| `commands/templates/stock-hooks/empirica-basics.md` | Add — simplified Empirica finding capture |
| `commands/templates/stock-hooks/compaction-safety.md` | Add — lightweight compaction guardian |
| `commands/templates/stock-agents/troubleshooter.md` | Modify — refresh |
| `commands/templates/stock-agents/code-reviewer.md` | Modify — refresh |
| `commands/templates/stock-agents/architecture-explainer.md` | Modify — refresh |
| `commands/templates/stock-commands/test-all.md` | Modify — refresh |
| `commands/templates/stock-commands/health-check.md` | Modify — refresh |
| `commands/templates/stock-commands/scaffold.md` | Modify — refresh |
| `commands/templates/INSTALL.md` | Modify — update references and element catalog |

#### Layer 4: Documentation

| File | Nature of Change |
|------|------------------|
| `README.md` | Major rewrite — new identity, narrative, counts |
| `GETTING_STARTED.md` | Major rewrite — modern tutorial for full toolkit |
| `commands/README.md` | Modify — update command catalog references |
| `docs/SECURITY.md` | Modify — update hook references |
| `docs/PLANNING-STORAGE.md` | Modify — update manifest references |
| `docs/ENFORCEMENT-PATTERNS.md` | Minor — update example references |
| `.claude/CLAUDE.md` | Modify — update project identity, architecture section |

#### Layer 5: Cross-Cutting Reference Updates

| File | Nature of Change |
|------|------------------|
| ~30 command files | Minor — grep/replace stale "bootstrap" references where they refer to the project (NOT the verb) |
| `.claude/plans/*/` | Low priority — update planning doc refs where convenient |

### External Dependencies

- [x] None — this is a pure shell/markdown toolkit with no package dependencies

### Database/State Changes

- [x] State format changes:
  - `.claude/bootstrap-manifest.json` → `.claude/sail-manifest.json` in target projects
  - Migration logic: commands that read manifest check BOTH filenames, prefer new name
  - On write, always use new name
  - Old file is NOT deleted (user may have it in .gitignore or committed)

## Preservation Contract (What Must NOT Change)

### Behavior that must survive:
- `install.sh` works via both `curl | bash` (remote) and `./install.sh` (local clone)
- All 48 commands remain functional after rename
- All 23 hooks remain functional (exit code behavior preserved)
- All 6 agents remain functional
- `/bootstrap-project` command name is PRESERVED (the verb "bootstrap" is fine; the project identity changes)
- Manifest tracking: re-runs detect customized elements and don't overwrite
- Tarball-based self-maintaining installer pattern (no file list to update)
- Fail-open hook pattern (set +e, exit codes 0/1/2)
- Plugin session-start drift check fires silently when setup is clean

### Interfaces that must remain stable:
- Hook exit code contract (0=allow, 1=user error, 2=block with feedback)
- State.json schema (blueprint v2)
- Manifest.json schema (work-graph, planning storage)
- All command YAML frontmatter descriptions (enforcement tiers unchanged)

### Performance bounds that must hold:
- `install.sh` completes in <30 seconds on reasonable connection
- Session-start hook completes in <5 seconds
- `/bootstrap-project` analysis phase completes in <60 seconds for typical projects

## Design: Rebuilt /bootstrap-project

The command gets 8 phases (up from 6). Phases 1-2 are modernized versions of the existing phases. Phases 3-5 are new. Phases 6-8 map to old phases 3-6.

### Phase 1: Project Analysis (MODERNIZE existing)

Keep existing logic (structure scan, language/framework detection, maturity scoring). Add:

- **Plugin detection**: Read `~/.claude/plugins/installed_plugins.json` if exists. Keys are scoped as `name@registry` (e.g., `pr-review-toolkit@claude-code-plugins`). Match by prefix: strip the `@registry` suffix before comparing against known plugin names. Record which plugins are available. This informs Phase 5 recommendations.
- **Vault detection**: Source `~/.claude/hooks/vault-config.sh`. Record `VAULT_ENABLED` and `VAULT_PATH`. This informs Phase 4.
- **Empirica detection**: Check if `empirica` CLI is available (`which empirica 2>/dev/null`). Record availability. This informs Phase 3.
- **Existing sail-manifest.json check**: Read `.claude/sail-manifest.json` OR `.claude/bootstrap-manifest.json` (backward compat). Record previous bootstrap state.

### Phase 2: CLAUDE.md Generation (MODERNIZE existing)

Keep existing exploration/gap-analysis flow. Modernize the CLAUDE.md template:

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

### Phase 3: Empirica Initialization (NEW)

Only runs if Empirica CLI was detected in Phase 1.

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

If Empirica is NOT detected:
```
Empirica integration:
  ✗ CLI not found (optional — install via: pipx install empirica)

  Empirica tracks confidence and learning across sessions.
  The toolkit works fine without it.
```

### Phase 4: Vault Configuration (NEW)

Only runs if vault config was detected in Phase 1.

1. Source `~/.claude/hooks/vault-config.sh`
2. If `VAULT_ENABLED=1` and `VAULT_PATH` is set and accessible:
   ```
   Obsidian vault integration:
     ✓ Vault found at: [VAULT_PATH]
     ✓ Writable

   The vault captures findings, decisions, and patterns across sessions.
   Use /vault-save to store knowledge, /vault-query to retrieve it.
   ```
3. If vault config doesn't exist or vault path is inaccessible:
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

### Phase 5: Plugin Recommendation (NEW)

Based on project type detected in Phase 1, recommend relevant plugins:

| Project Type | Recommended Plugins |
|-------------|-------------------|
| Any | `pr-review-toolkit` (code review agents) |
| React/Vue/Next | `frontend` (UI dev workflow) |
| Any with tests | `testing-suite` (test generation) |
| Any with deployment | `security-pro` (security audit) |
| Any complex | `superpowers` (structured planning skills) |

Present as:
```
Plugin recommendations based on your project:
  [✓ installed] pr-review-toolkit — 6 specialized review agents
  [  available ] frontend — UI development workflow with design validation
  [  available ] testing-suite — Test generation and coverage analysis

Plugins are optional. Install via their respective repos.
```

### Phase 6: Stock Element Selection (MODERNIZE existing Phase 3)

Keep existing maturity-based selection logic. **Preserve the maturity scoring rubric verbatim from current bootstrap-project.md Phase 1** — do not redefine the scoring scale or signals. The rubric is the source of truth for Phase 6 conditional installation. Expand the available elements:

**Universal hooks (all projects):**
- `test-coverage-reminder.md` (existing, refreshed)
- `security-warning.md` (existing, refreshed)
- `compaction-safety.md` (NEW — lightweight compaction awareness)

**Conditional hooks:**
- `empirica-basics.md` (NEW — only if Empirica detected, simplified finding capture)
- `documentation-standards.md` (existing — only if docs/ directory exists)
- `interface-validation.md` (existing — only if consistent module patterns detected)

**Universal agents (all projects):**
- `troubleshooter.md` (existing, refreshed)
- `code-reviewer.md` (existing, refreshed)

**Conditional agents:**
- `architecture-explainer.md` (existing — only if maturity >= 4)

**Commands (growing/mature only):**
- `test-all.md` (existing, refreshed)
- `health-check.md` (existing, refreshed)
- `scaffold.md` (existing — only if maturity >= 5)

### Phase 7: Installation (KEEP existing Phase 4, update manifest name)

Same logic as current Phase 4, but:
- Write `.claude/sail-manifest.json` instead of `bootstrap-manifest.json`
- If old `bootstrap-manifest.json` exists, read it for upgrade tracking
- Add `"upgraded_from": "bootstrap-manifest"` field if migrating

### Phase 8: Summary Report (MODERNIZE existing Phase 6)

Updated output format:
```
## Setup Complete

### Project Profile
- **Type:** [detected types]
- **Maturity:** [level] (score: N/10)
- **Integrations:** Empirica [✓/✗] │ Vault [✓/✗] │ Plugins [N installed]

### What Was Installed
[organized by category with counts]

### Recommendations
[prioritized: Immediate / Soon / Eventually]

### Next Steps
1. Review generated CLAUDE.md and refine
2. Run /start at the beginning of your next session
3. Run /toolkit to see all available commands
4. Try /blueprint [name] for your next non-trivial change
```

## Design: New Stock Elements

### New Stock Hook — compaction-safety.md

A simplified version of the toolkit's `compaction-guardian.sh`, designed as a prompt-based hook (not shell) for target projects:

```yaml
hooks:
  - event: PreToolUse
    tools: [Write, Edit, Bash]
```

Purpose: When context window is getting large, remind Claude to save important state before compaction occurs. Lightweight — just a behavioral nudge, not the full guardian. Scoped to Write/Edit/Bash (tools that indicate significant context change) rather than `["*"]` to avoid firing on every Read/Glob/Grep call.

### New Stock Hook — empirica-basics.md

```yaml
hooks:
  - event: PostToolUse
    tools: [Write, Edit]
```

Purpose: After significant code changes, remind to log findings via Empirica if a session is active. Only installed when Empirica is detected. Fail-soft — if no session active, does nothing.

## Design: Final Stock Element Counts (After Refresh)

| Category | Count | Elements |
|----------|-------|----------|
| Stock hooks | 6 | test-coverage-reminder, security-warning, compaction-safety, empirica-basics, documentation-standards, interface-validation |
| Stock agents | 3 | troubleshooter, code-reviewer, architecture-explainer |
| Stock commands | 3 | test-all, health-check, scaffold |
| **Total stock elements** | **12** | |

These counts must match README.md, GETTING_STARTED.md, and INSTALL.md after implementation.

## Design: Naming Decisions

| Old Name | New Name | Rationale |
|----------|----------|-----------|
| `claude-bootstrap` (repo) | `claude-sail` | Done — project identity |
| `/bootstrap-project` (command) | `/bootstrap-project` | KEEP — "bootstrap" as a verb is correct |
| `session-bootstrap.sh` (hook) | `session-sail.sh` | Hook represents the project, not the verb |
| `bootstrap-toolkit` (plugin) | `sail-toolkit` | Plugin represents the project |
| `bootstrap-manifest.json` (data) | `sail-manifest.json` | Data file represents the project. Backward compat: read both, write new. |
| `claude_bootstrap_hook` (instance ID) | `claude_sail_hook` | Empirica instance identifier |
| "bootstrap" in prose | Context-dependent | Replace when it means the project name. Keep when it means the action of bootstrapping. |

## Design: README Narrative

The README shifts from "here's how to bootstrap your project" to:

> **Claude Sail** — Structured workflows, safety guardrails, and planning discipline for Claude Code.
>
> *A sail doesn't cross an ocean alone.*

Key sections:
1. What is this? (toolkit identity, not bootstrapper identity)
2. Quick Start (install + first commands)
3. What's Included (commands, hooks, agents, planning — the full picture)
4. For New Projects (/bootstrap-project as ONE feature)
5. For Existing Workflows (the planning/review/safety commands)
6. Architecture
7. Contributing / License

## Design: GETTING_STARTED.md Narrative

Rewritten as a proper Diataxis tutorial:

1. Install the toolkit
2. Set up your first project (`/bootstrap-project`)
3. Your first session (`/start`)
4. Your first planned change (`/describe-change` → `/blueprint`)
5. Daily workflow (the commands you'll actually use)
6. Going further (Empirica, vault, plugins)

This covers the full on-ramp, not just the setup step.

## Success Criteria

| Criterion | How to Verify |
|-----------|---------------|
| `install.sh` works from new GitHub URL | `curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-sail/main/install.sh \| bash` succeeds |
| `install.sh` works from local clone | `cd claude-sail && ./install.sh` succeeds |
| No stale "claude-bootstrap" repo references | `grep -r "claude-bootstrap" --include="*.md" --include="*.sh" --include="*.json" \| grep -v ".git/" \| grep -v "_OLD/" \| grep -v ".claude/plans/" \| grep -v "bootstrap-manifest"` returns 0 results. NOTE: run AFTER all work units complete, not mid-implementation. |
| Bootstrap-project runs successfully on a test project | Run `/bootstrap-project` in a sample project, verify CLAUDE.md + manifest + stock elements created |
| Backward compat: old manifest detected | Create `.claude/bootstrap-manifest.json` in test project, run `/bootstrap-project`, verify it reads old manifest |
| Stock elements are current | Compare stock element content to modern toolkit equivalents, verify they reflect current patterns |
| README accurately describes project scope | Command count, hook count, agent count all match reality |
| GETTING_STARTED tutorial is end-to-end walkable | Follow every step in a fresh environment |
| Plugin renamed and functional | `~/.claude/plugins/local/sail-toolkit/` exists after install, session-start check fires |
| Hook renamed and functional | `~/.claude/hooks/session-sail.sh` exists after install, fires on SessionStart |

## Failure Modes

| What Could Fail | Detection Method | Recovery Action |
|-----------------|------------------|-----------------|
| Old raw.githubusercontent.com install URL | 404 on curl (raw URLs do NOT redirect after repo rename, only github.com web URLs do) | Update GETTING_STARTED.md and README.md with new URL. Old users must update their bookmarked install command manually. |
| Old github.com repo URL in browser | User sees old name | GitHub web UI redirect handles this automatically |
| Existing projects have bootstrap-manifest.json | check-project-setup can't find manifest | Dual-read logic: check both filenames |
| User's settings.json still references session-bootstrap.sh | Hook doesn't fire on session start | install.sh output explicitly lists what to update in settings.json |
| User's settings.json still references bootstrap-toolkit plugin path | Plugin session-start check doesn't fire | install.sh output must list BOTH the hook path AND plugin path changes. Also detect if old `~/.claude/plugins/local/bootstrap-toolkit/` directory exists and warn explicitly. |
| Stock element hash mismatch on upgrade | Manifest shows customized=true for unchanged files | Recalculate hash on fresh install |
| Plugin not detected after rename | Session start check silent | install.sh verifies plugin.json is valid after copy |

## Rollback Plan

1. `git revert` the implementation commits
2. Rename GitHub repo back to `claude-bootstrap` (Settings → Rename)
3. `git remote set-url origin` back to old URL
4. Re-run `install.sh` to restore old file names to `~/.claude/`
5. Manually clean up stale renamed files: `rm ~/.claude/hooks/session-sail.sh && rm -rf ~/.claude/plugins/local/sail-toolkit/`
6. No data migration needed — old manifest name still works

## Dependencies (Preconditions)

- [x] GitHub repo renamed to claude-sail (DONE)
- [x] Git remote updated locally (DONE)
- [ ] Current main branch is clean (verified at session start)
- [ ] No other active branches that would conflict

## Open Questions

1. **Should we rename the `_OLD/bootstrap-toolkit/` archive?** — Probably not, it's gitignored and historical. But noting it.
2. **Planning docs in `.claude/plans/*/`** — These reference "bootstrap" heavily but they're internal planning artifacts. Update opportunistically or leave as historical? Recommend: leave as historical, they document the journey.
3. **The hookify rules** — Do any of the 7 hookify rules reference "bootstrap"? Need to check during implementation.

## Senior Review Simulation

- **They'd probably ask about:** "What happens to users who installed the old version? Is the upgrade path clean?" — Answer: GitHub redirects handle URL, dual manifest reading handles data, install.sh overwrites handle files. The main gap is settings.json hook paths, which install.sh explicitly calls out.
- **The non-obvious risk is:** The session-bootstrap.sh → session-sail.sh rename means anyone with the old hook path in their settings.json will silently lose the session-start functionality until they update. We should make install.sh LOUDLY flag this.
- **The standard approach I might be missing:** Some projects use a version migration script that detects old installs and auto-patches settings.json. We could add this to install.sh but it's risky to auto-edit user config. Better to detect and warn.
- **What bites first-timers:** Forgetting to update settings.json after reinstalling. The hook paths are hardcoded there and install.sh can't auto-update them. The install output MUST be unmissable.

## Work Units

| ID | Description | Files | Dependencies | Complexity |
|----|-------------|-------|-------------|------------|
| W1 | Rename infrastructure files (hook, plugin dir) | `hooks/session-bootstrap.sh` → `session-sail.sh`, `plugins/bootstrap-toolkit/` → `plugins/sail-toolkit/`. NOTE: `.claude/bootstrap-manifest.json` is NOT renamed here — it lives in target projects, not this repo. Manifest name change is handled by runtime dual-read logic in W4/W5. Also update session hook content: change `INSTANCE_ID`, output text ("claude-sail" not "claude-bootstrap"), and add one-shot migration to copy old instance file if it exists. | None | Small |
| W2 | Update install.sh (URLs, banner, paths, output) | `install.sh` — CRITICAL items: (1) `REPO_DIR` variable must change from `claude-bootstrap-main` to `claude-sail-main` (tarball extraction directory); (2) `REPO_URL` default must change to new GitHub URL; (3) `TARBALL_URL` must change; (4) All `mkdir -p` calls referencing `bootstrap-toolkit` must change to `sail-toolkit`; (5) `chmod +x` glob must change from `bootstrap-toolkit/scripts/*.sh` to `sail-toolkit/scripts/*.sh`; (6) Banner and output messages updated | W1 (needs new filenames) | Medium |
| W3 | Update settings-example.json and .claude/settings.local.json | `settings-example.json`, `.claude/settings.local.json` | W1 (needs new filenames) | Small |
| W4 | Rebuild bootstrap-project.md (all 8 phases) | `commands/bootstrap-project.md` | None | Large |
| W5 | Update check-project-setup.md (dual manifest, new references) | `commands/check-project-setup.md` | W4 (needs to know new manifest name) | Medium |
| W6 | Refresh existing stock elements (4 hooks, 3 agents, 3 commands) | `commands/templates/stock-*/*.md` | None | Medium |
| W7 | Create new stock elements (compaction-safety, empirica-basics) | `commands/templates/stock-hooks/` | None | Medium |
| W8 | Update INSTALL.md template | `commands/templates/INSTALL.md` | W6, W7 (needs final stock element list) | Small |
| W9 | Rewrite README.md | `README.md` | W4 (needs to know new feature set) | Medium |
| W10 | Rewrite GETTING_STARTED.md | `GETTING_STARTED.md` | W9 (needs consistent narrative) | Large |
| W11 | Cross-cutting reference update | Use targeted grep patterns to find project-name references (NOT verb uses): `grep -rn "claude-bootstrap\|bootstrap-toolkit\|bootstrap_hook\|bootstrap-manifest\|bootstrap\.sh" --include="*.md" --include="*.sh" --include="*.json"`. Exclude `.git/`, `_OLD/`, `.claude/plans/`. Each replacement must be manually reviewed — do NOT bulk sed. The word "bootstrap" as a verb (e.g., "bootstrap your project", "/bootstrap-project") is KEPT. | W1, W2, W4 (needs final names settled) | Medium |
| W12 | Update docs/*.md (SECURITY, PLANNING-STORAGE, ENFORCEMENT) | `docs/*.md` | W1 (needs new filenames) | Small |
| W13 | Update .claude/CLAUDE.md (project identity) | `.claude/CLAUDE.md` | W4, W9 (needs final architecture description) | Small |
| W14 | Update commands/README.md (catalog) | `commands/README.md` | W4, W6, W7 (needs final command/element list) | Small |
| W15 | Update assess-project.md deprecation notice | `commands/assess-project.md` | None | Trivial |
| W16 | Update start.md identity references | `commands/start.md` | None | Trivial |
| W17 | Update plugin internals (plugin.json, check-setup-quiet.sh, hooks.json) | `plugins/sail-toolkit/` | W1 (after directory rename) | Small |

---

Specification complete. Next steps:
  - Challenge assumptions → Stage 3 (debate mode)
  - Probe boundaries → Stage 4
  - Generate tests → Stage 6
  - Ready to build → Stage 7
