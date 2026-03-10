# Getting Started with Claude Sail

In this tutorial, you will install Claude Sail, bootstrap a real project, and explore the key commands that structure your Claude Code workflow.

By the end, you'll have a project wired up with documentation, hooks, agents, and commands — all tailored to your codebase.

## Prerequisites

You need **Claude Code** installed and working:

```bash
claude --version
```

If not installed, visit: https://docs.anthropic.com/claude-code

You also need **curl** (available on most systems) and a terminal (macOS Terminal, Linux shell, or Windows WSL).

## Step 1: Install Claude Sail

Run the one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-sail/main/install.sh | bash
```

This downloads the toolkit and copies it to `~/.claude/` — the directory Claude Code reads from on every session. No package managers, no build steps.

If you prefer to inspect the script first:

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-sail/main/install.sh -o install.sh
cat install.sh
bash install.sh
```

Verify the install worked:

```bash
ls ~/.claude/commands/bootstrap-project.md
```

If the file exists, you're good.

## Step 2: Bootstrap your project

Navigate to any project you're working on and start Claude Code:

```bash
cd /path/to/your/project
claude
```

Then type:

```
/bootstrap-project
```

Sail analyzes your project — languages, structure, maturity — and installs appropriate tooling. It runs through six phases: project analysis, CLAUDE.md generation, stock element selection, installation, manifest creation, and recommendations.

When it finishes, your project has a `.claude/` directory with everything it set up.

## Step 3: Explore what got created

After bootstrapping, your project now contains:

```
your-project/
├── .claude/
│   ├── CLAUDE.md                    # Project docs Claude reads every session
│   ├── bootstrap-manifest.json      # Tracks what was installed
│   ├── hooks/                       # Automated reminders and guardrails
│   └── agents/                      # Specialized assistants
├── src/
└── ... your project files
```

**CLAUDE.md** is the most important file. It documents your project's conventions, build commands, test commands, and architecture so Claude has context from the start of every session.

**bootstrap-manifest.json** tracks what Sail installed, including content hashes. This means re-running `/bootstrap-project` later won't overwrite your customizations — it knows what you've changed.

**Hooks** run automatically during your session (e.g., reminding you about test coverage after editing source files). **Agents** are specialized assistants Claude can delegate to (e.g., a troubleshooter or code reviewer).

## Step 4: Try key commands

Start a new Claude Code session in your bootstrapped project and try these:

### /start

```
/start
```

This orients you at the beginning of a session. It reads your project state, checks for pending work, and recommends what to do next. Use it at the start of every session.

### /toolkit

```
/toolkit
```

This is your command reference. It lists every available command grouped by category — planning, review, testing, execution, and more. When you're not sure which command to use, start here.

### /blueprint

```
/blueprint my-feature
```

This is the structured planning workflow. For any non-trivial change, `/blueprint` walks you through describing the change, writing a spec, adversarial review, implementation, and verification. It creates artifacts in `.claude/plans/my-feature/` and tracks progress.

You don't need to use `/blueprint` for small changes — it's for work that benefits from a plan.

## Step 5: Understand the toolkit layers

Sail installs tooling at two levels:

| Level | Location | Purpose |
|-------|----------|---------|
| **Global** | `~/.claude/` | Toolkit commands, agents, hooks, and rules available in every project |
| **Project** | `your-project/.claude/` | Project-specific docs, hooks, and agents created by `/bootstrap-project` |

Global components are the toolkit itself. Project components are tailored artifacts that `/bootstrap-project` generates for each project.

## Optional integrations

Sail works standalone, but it can integrate with other tools if you have them:

- **Empirica** — Epistemic tracking (what you know, what you learned, what went wrong). If the Empirica MCP server is available, blueprint workflows automatically log findings and track confidence.
- **Obsidian Vault** — Knowledge management. If an Obsidian MCP server is connected, Sail can read and write vault notes during planning and review stages.
- **Plugins** — Claude Code plugins (like `pr-review-toolkit`, `security-pro`, `frontend`) automatically enhance review stages when detected. No configuration needed.

None of these are required. All workflows function without them.

## Next steps

You now have a bootstrapped project with structured workflows. Here are useful things to try:

- Run `/describe-change` before your next code change to triage its complexity
- Run `/check-project-setup` to verify your project's setup is healthy
- Edit `.claude/CLAUDE.md` in your project to refine the conventions Claude follows
- Run `/toolkit` anytime to discover commands you haven't tried yet

For issues or questions: https://github.com/ntanner-ctrl/claude-sail/issues
