# Describe: toolkit-rebrand

## Change Summary

Rename claude-bootstrap to claude-sail and restructure the project from a bootstrapping tool identity to a comprehensive Claude Code extensibility toolkit. Rebuild the bootstrap command for modern toolkit awareness, modernize stock elements, and update all documentation.

## Motivation

The project has evolved from a simple project setup wizard into a 100+ file workflow engine with epistemic tracking (Empirica), knowledge synthesis (Obsidian vault), multi-stage adversarial planning, and plugin-aware review workflows. The name and on-ramp no longer reflect what the project is.

## Steps (20 discrete actions)

### Identity & Infrastructure
1. ~~Rename GitHub repo~~ (DONE: github.com/ntanner-ctrl/claude-sail)
2. Update install.sh — new repo URL, banner text, output messaging
3. Update README.md — new identity, narrative, project description, counts
4. Rewrite GETTING_STARTED.md — fresh tutorial reflecting modern toolkit scope

### Core Command Rebuild
5a. Modernize CLAUDE.md template in bootstrap-project.md (add Empirica/vault/plugin sections)
5b. Add Empirica initialization phase to bootstrap-project.md
5c. Add vault configuration phase to bootstrap-project.md
5d. Add plugin detection/recommendation phase to bootstrap-project.md
5e. Expand stock element selection logic in bootstrap-project.md
5f. Update bootstrap-project.md summary report format
6. Update check-project-setup.md — align drift detection with modernized bootstrap
7. Update start.md — reference new project identity where needed

### Stock Element Refresh
8a. Audit existing stock elements for staleness
8b. Create new stock hooks from modern toolkit
8c. Create new stock agents
8d. Update existing stock elements

### Cleanup & Alignment
9. Update assess-project.md deprecation notice
10. Grep and update all internal "bootstrap" references across commands, hooks, docs
11. Rename plugins/bootstrap-toolkit/ directory and references
12. Update settings-example.json path references
13. Update docs/*.md — architecture, security, planning storage docs
14. Update .claude/CLAUDE.md — project identity section
15. Update commands/README.md — command catalog

## Risk Flags
- [x] User-facing behavior change (install URL, command behavior, stock elements)
  - Mitigated: GitHub redirects, ~/.claude/ overwrite on reinstall

## Triage Result

**Steps:** 20 discrete actions
**Risk flags:** 1 (user-facing behavior change, mitigated)
**Execution preference:** Auto
**Recommended path:** Full
**Challenge mode:** Debate (default)
