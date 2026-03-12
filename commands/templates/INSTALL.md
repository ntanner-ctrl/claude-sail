# Claude Sail Installation

## Quick Install (Recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-sail/main/install.sh | bash
```

Or if you prefer to inspect first:

```bash
curl -fsSL https://raw.githubusercontent.com/ntanner-ctrl/claude-sail/main/install.sh -o install.sh
cat install.sh  # Review it
bash install.sh
```

## What Gets Installed

```
~/.claude/
├── commands/              # 47 slash commands
│   ├── bootstrap-project.md     # Full project setup
│   ├── check-project-setup.md   # Light drift detection
│   ├── blueprint.md             # Planning workflow
│   └── templates/               # Stock element templates (12 total)
│       ├── stock-hooks/    (6)  # Prompt-based hooks for target projects
│       ├── stock-agents/   (3)  # Agents for target projects
│       └── stock-commands/ (3)  # Commands for target projects
├── agents/                # 6 review agents
├── hooks/                 # 18 shell hooks
└── plugins/local/
    └── sail-toolkit/      # Session-start drift detection
```

## Manual Installation

1. Clone the repo:
   ```bash
   git clone https://github.com/ntanner-ctrl/claude-sail.git
   cd claude-sail
   ```

2. Run the installer:
   ```bash
   ./install.sh
   ```

## Usage

After installation, in any project:

```bash
# First time setup
/bootstrap-project

# Quick check anytime
/check-project-setup

# Update documentation only
/refresh-claude-md

# See all available commands
/toolkit
```

## Upgrading from claude-bootstrap

The installer automatically cleans up old bootstrap-toolkit files. Existing project manifests (`.claude/bootstrap-manifest.json`) are still read for backward compatibility — new manifests are written as `.claude/sail-manifest.json`.

## Uninstall

```bash
rm -rf ~/.claude/commands/ ~/.claude/agents/ ~/.claude/hooks/
rm -rf ~/.claude/plugins/local/sail-toolkit/
```
