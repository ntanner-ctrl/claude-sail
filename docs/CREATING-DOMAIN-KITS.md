# How to Create a Domain Kit

Create specialized Claude Code extensions for your field or workflow.

---

## Prerequisites

- Claude Code installed and working
- Familiarity with the Claude Sail toolkit structure
- A domain with recurring patterns worth encoding

---

## Step 1: Copy the Template

Use the Ops Starter Kit as your starting point:

```bash
cp -r ops-starter-kit my-domain-kit
cd my-domain-kit
```

You now have this structure:

```
my-domain-kit/
├── agents/              # Specialized subagents
├── commands/            # Slash commands
├── hooks/               # Safety guards
├── install.sh           # Installation script
└── README.md            # Documentation
```

---

## Step 2: Identify Your Domain's Patterns

Before writing anything, answer these questions:

### What mistakes happen repeatedly?
These become **hooks**.

| Domain | Common Mistakes |
|--------|-----------------|
| Data Engineering | Dropping production tables, unvalidated schemas |
| Frontend | Committing API keys, breaking accessibility |
| ML Ops | Training on test data, overwriting models |
| Security | Weak hashing, missing input validation |

### What complex tasks need guidance?
These become **agents**.

| Domain | Complex Tasks |
|--------|---------------|
| Data Engineering | Pipeline debugging, schema migrations |
| Frontend | Performance audits, accessibility reviews |
| ML Ops | Experiment comparison, model validation |
| Security | Vulnerability assessment, compliance audit |

### What workflows should be one command?
These become **commands**.

| Domain | Workflow Commands |
|--------|-------------------|
| Data Engineering | `/validate-pipeline`, `/schema-diff` |
| Frontend | `/lighthouse-audit`, `/bundle-analyze` |
| ML Ops | `/experiment-log`, `/model-compare` |
| Security | `/owasp-check`, `/dependency-audit` |

---

## Step 3: Create Your Hooks

Hooks are safety guards that run before or after Claude's actions.

### Hook Template

Create `hooks/your-hook.md`:

```markdown
# Your Hook Name

Brief description of what this hook catches.

## Trigger

- **Event**: PreToolUse | PostToolUse
- **Matcher**: Which tools trigger this (e.g., "Bash", "Edit|Write")

## What It Checks

1. First condition to check
2. Second condition to check

## Hook Configuration

\`\`\`json
{
  "hooks": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Check if this command [your criteria]. If it violates [rule], respond with BLOCK and explain why. Otherwise, respond with ALLOW."
        }
      ]
    }
  ]
}
\`\`\`
```

### Example: Data Engineering Hook

`hooks/production-table-safety.md`:

```markdown
# Production Table Safety

Prevents accidental DROP, TRUNCATE, or DELETE on production tables.

## Trigger

- **Event**: PreToolUse
- **Matcher**: Bash

## What It Checks

1. SQL commands that modify production tables
2. Missing WHERE clauses on DELETE/UPDATE
3. DROP TABLE without explicit confirmation

## Hook Configuration

\`\`\`json
{
  "hooks": [
    {
      "matcher": "Bash",
      "hooks": [
        {
          "type": "prompt",
          "prompt": "Check if this command contains DROP TABLE, TRUNCATE, or DELETE without WHERE clause targeting production tables. Production indicators: 'prod', 'production', 'live' in table/database name. If detected, respond with BLOCK: [reason]. Otherwise ALLOW."
        }
      ]
    }
  ]
}
\`\`\`
```

---

## Step 4: Create Your Agents

Agents are specialized assistants for complex, multi-step tasks.

### Agent Template

Create `agents/your-agent.md`:

```yaml
---
name: your-agent-name
description: One-line description for agent selection
model: sonnet
tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Your Agent Name

## Role

What this agent does and when to use it.

## Methodology

### Phase 1: Assessment
1. First step
2. Second step

### Phase 2: Analysis
1. First step
2. Second step

### Phase 3: Output
What the agent produces.

## Constraints

- What the agent should NOT do
- Boundaries and limitations
```

### Example: ML Ops Agent

`agents/experiment-analyzer.md`:

```yaml
---
name: experiment-analyzer
description: Compare ML experiments and recommend next steps
model: sonnet
tools:
  - Bash
  - Read
  - Grep
  - Glob
---

# Experiment Analyzer

## Role

Systematic comparison of ML experiments to identify the best performing configuration and recommend next experiments.

## Methodology

### Phase 1: Gather Metrics
1. Find all experiment logs/configs
2. Extract key metrics (loss, accuracy, F1, etc.)
3. Identify hyperparameters used

### Phase 2: Compare
1. Build comparison table
2. Identify trends (what improves results?)
3. Find anomalies (surprising results)

### Phase 3: Recommend
1. Best configuration so far
2. Suggested next experiments
3. Potential issues to investigate

## Constraints

- Do not modify experiment files
- Do not re-run experiments without explicit request
- Present findings objectively, let human decide
```

---

## Step 5: Create Your Commands

Commands are shortcuts for common workflows.

### Command Template

Create `commands/your-command.md`:

```yaml
---
description: One-line description
arguments:
  - name: arg1
    description: What this argument does
    required: true
---

# Your Command

## Purpose

What this command accomplishes.

## Steps

1. First action
2. Second action
3. Output format

## Example Usage

\`\`\`
/your-command example-arg

Expected output...
\`\`\`
```

### Example: Data Engineering Command

`commands/validate-pipeline.md`:

```yaml
---
description: Validate data pipeline configuration and dependencies
arguments:
  - name: pipeline
    description: Pipeline name or path to validate
    required: false
---

# Validate Pipeline

## Purpose

Pre-flight check for data pipelines before deployment.

## Steps

1. **Parse Configuration**
   - Read pipeline config (Airflow DAG, dbt project, etc.)
   - Identify sources, transformations, destinations

2. **Check Connections**
   - Verify source credentials exist (don't expose values)
   - Check destination permissions

3. **Validate Schema**
   - Compare expected vs actual schemas
   - Flag breaking changes

4. **Dependency Check**
   - Ensure required packages available
   - Check version compatibility

## Output

Produce a validation report:

\`\`\`
## Pipeline Validation: [name]

✅ Configuration: Valid
✅ Connections: 3/3 accessible
⚠️ Schema: 1 breaking change detected
✅ Dependencies: All satisfied

### Issues
| Severity | Issue | Location |
|----------|-------|----------|
| Warning | Column 'user_id' type changed INT→VARCHAR | transform_users |
\`\`\`
```

---

## Step 6: Write the README

Document your kit so others can use it. Follow the Ops Starter Kit pattern:

1. **What's Included** - Tables of hooks, commands, agents
2. **Usage Examples** - Show real workflows
3. **Philosophy** - Why these choices were made
4. **Customization** - How to extend

---

## Step 7: Create the Installer

Update `install.sh` to copy your files to the right locations:

```bash
#!/bin/bash
set -e

CLAUDE_DIR="${HOME}/.claude"

echo "Installing My Domain Kit..."

# Create directories
mkdir -p "$CLAUDE_DIR/hooks"
mkdir -p "$CLAUDE_DIR/commands"
mkdir -p "$CLAUDE_DIR/agents"

# Copy hooks
cp hooks/*.md "$CLAUDE_DIR/hooks/"

# Copy commands
cp commands/*.md "$CLAUDE_DIR/commands/"

# Copy agents
cp agents/*.md "$CLAUDE_DIR/agents/"

echo "✓ Installation complete!"
echo ""
echo "Available commands:"
for cmd in commands/*.md; do
    name=$(basename "$cmd" .md)
    echo "  /$name"
done
```

---

## Domain Kit Ideas

| Domain | Focus Areas |
|--------|-------------|
| **Frontend** | Accessibility, performance, component patterns, bundle size |
| **Data Engineering** | Pipeline safety, schema validation, data quality |
| **ML Ops** | Experiment tracking, model versioning, training safety |
| **Security** | Vulnerability scanning, compliance, audit logging |
| **Mobile** | Platform-specific patterns, app store compliance |
| **Game Dev** | Asset management, performance profiling, build pipelines |
| **Embedded** | Memory safety, hardware constraints, firmware updates |

---

## Testing Your Kit

Before sharing:

1. **Install fresh**: Uninstall, reinstall, verify everything works
2. **Test hooks**: Deliberately trigger each hook to confirm it catches what it should
3. **Test agents**: Run each agent on a realistic task
4. **Test commands**: Run each command with various inputs
5. **Documentation**: Follow your own README as a new user would

---

## Contributing Back

If your domain kit would help others:

1. Fork the claude-sail repo
2. Add your kit as a new directory
3. Update the main README to list it
4. Open a PR

The more specialized kits exist, the more useful the bootstrap ecosystem becomes.
