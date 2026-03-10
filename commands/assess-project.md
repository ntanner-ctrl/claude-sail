---
description: "DEPRECATED: Use /bootstrap-project instead. This command is superseded — bootstrap-project includes all assessment functionality plus extensibility setup."
---

# Project Assessment & CLAUDE.md Generator

> **Note:** This command has been superseded by `/bootstrap-project` (part of the Claude Sail toolkit), which includes all the functionality of `/assess-project` plus automatic installation of stock hooks, agents, and commands tailored to your project type, with optional Empirica, vault, and plugin integration.
>
> - Use `/bootstrap-project` for comprehensive project setup (CLAUDE.md + extensibility + integrations)
> - Use `/assess-project` if you only want CLAUDE.md generation without any installation
> - Use `/check-project-setup` for quick drift detection after initial setup
>
> This command remains available for users who prefer documentation-only assessment.

---

Think hard about this project before responding. Do not write any code or make any changes yet.

## Phase 1: Exploration

First, thoroughly explore this project:

1. **Structure Analysis**
   - Read the root directory structure (2-3 levels deep)
   - Identify the primary language(s) and framework(s)
   - Note the build system, package manager, and dependency files
   - Find existing configuration files (.env.example, docker-compose, CI configs, etc.)

2. **Conventions Detection**
   - Sample 3-5 representative source files to identify coding patterns
   - Check for existing linting/formatting configs (eslint, prettier, black, ruff, etc.)
   - Look for test files and identify testing framework(s) and patterns
   - Note naming conventions (files, functions, classes, variables)

3. **Documentation Audit**
   - Read any existing README, CONTRIBUTING, or architectural docs
   - Check for existing CLAUDE.md and note what's there vs. missing
   - Identify undocumented but important patterns I discovered in code

4. **Workflow Discovery**
   - Find available scripts (package.json scripts, Makefile targets, shell scripts)
   - Identify how to: build, test, lint, run locally, deploy
   - Note any multi-service or monorepo patterns

## Phase 2: Gap Analysis

Based on exploration, identify:

1. **What I repeatedly need to rediscover** — patterns that should be documented so I don't waste tokens re-learning them each session

2. **Ambiguities that slow me down** — places where I'd have to guess or ask clarifying questions

3. **Error-prone areas** — complex modules, tricky configurations, or non-obvious dependencies where I'm likely to make mistakes without guidance

4. **Workflow friction** — manual steps that could be automated with hooks or commands

## Phase 3: Recommendations

Provide a structured report with:

### A. CLAUDE.md Content Recommendations

Generate a proposed CLAUDE.md (or updates to existing) that includes:

```markdown
# [Project Name]

## Quick Reference
- Build: [command]
- Test: [command]  
- Lint: [command]
- Run locally: [command]

## Architecture Overview
[2-3 sentences on structure and key patterns]

## Key Conventions
- [Naming conventions]
- [File organization patterns]
- [Import/module patterns]

## Important Context
- [Non-obvious dependencies or requirements]
- [Things that look wrong but are intentional]
- [Areas requiring extra care]

## Common Tasks
- [How to add a new X]
- [How to modify Y]
- [Testing expectations]

## Do Not
- [Anti-patterns specific to this project]
- [Files/areas to avoid modifying without discussion]
```

### B. Suggested Subagents

Based on project complexity, recommend whether custom subagents would help and for what:
- Only suggest if the project genuinely benefits (don't recommend for simple projects)
- Include draft agent descriptions if recommending

### C. Suggested Hooks

Recommend hooks if the project would benefit:
- PostToolUse hooks for auto-formatting or linting
- PreCommit hooks for validation
- Include example configuration

### D. Suggested Slash Commands

Recommend project-specific commands for repetitive workflows:
- Include draft command files if recommending

### E. MCP Integrations

Note if the project would benefit from MCP servers:
- Database access for data-heavy projects
- GitHub for PR-heavy workflows
- Slack/Jira for team coordination
- Only suggest if genuinely useful

## Phase 4: Priority Ranking

Rank all recommendations by impact:
1. **Immediate** — will improve the next session significantly
2. **Soon** — worth setting up this week
3. **Eventually** — nice to have as project matures

## Output Format

Structure your response as:
1. Brief project summary (what this is, tech stack, complexity assessment)
2. Key findings from exploration
3. The recommendations above
4. A ready-to-use CLAUDE.md block I can copy directly

---

$ARGUMENTS
