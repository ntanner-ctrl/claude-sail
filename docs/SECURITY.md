# Security Architecture

How Claude Sail implements defense-in-depth security for AI-assisted development.

---

## The Problem

Claude Code is powerful, but power without guardrails leads to accidents:
- Committing secrets to git
- Running `rm -rf` in the wrong directory
- Force-pushing to main
- Editing production config files

These aren't malicious—they're the mistakes everyone makes eventually. The question is whether you catch them before or after they cause damage.

---

## Defense-in-Depth Model

Claude Sail implements three security layers, each with different characteristics:

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: Shell Hooks (PreToolUse) - Deterministic blocking     │
│  dangerous-commands.sh, secret-scanner.sh                       │
│  → Executes BEFORE Claude runs commands                         │
│  → Binary: allow or block                                       │
│  → Cannot be talked around                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: Hookify Rules - Prompt-based warnings/blocks          │
│  *.local.md files with YAML rules                               │
│  → Claude-readable explanations                                 │
│  → Can warn OR block                                            │
│  → Claude understands why and can suggest alternatives          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 3: CLAUDE.md - Behavioral guidance (suggestions)         │
│  → Read by Claude at session start                              │
│  → Influences behavior but doesn't enforce                      │
│  → Can be ignored under pressure                                │
└─────────────────────────────────────────────────────────────────┘
```

### Why Three Layers?

| Layer | Strength | Weakness |
|-------|----------|----------|
| Shell Hooks | Deterministic, can't be bypassed | Binary, no nuance |
| Hookify Rules | Claude understands context | Can potentially be argued around |
| CLAUDE.md | Flexible, contextual | Suggestions only |

The layers complement each other: shell hooks catch catastrophic mistakes, hookify rules handle nuanced situations, and CLAUDE.md guides general behavior.

---

## Layer 1: Shell Hooks

Shell scripts that execute before or after Claude's tool use. Located in `hooks/`.

### Exit Code Convention

| Code | Meaning | Claude Sees |
|------|---------|-------------|
| `0` | Allow operation | Nothing (proceeds silently) |
| `1` | User-facing error | Error message shown to user |
| `2` | Block with feedback | stderr sent TO CLAUDE as context |

**Exit code 2 is the key insight**: It blocks the operation AND sends your explanation back to Claude, so it understands *why* and can suggest alternatives.

```bash
# Example: Blocking with explanation
if [[ "$cmd" =~ chmod\ 777 ]]; then
    echo "Blocked: chmod 777 creates security vulnerability." >&2
    echo "Use specific permissions like 755 instead." >&2
    exit 2  # Block AND inform Claude
fi
```

### Included Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `session-sail.sh` | SessionStart | Inject command awareness, auto-create Empirica session, and active work state |
| `worktree-cleanup.sh` | SessionStart | Clean orphaned worktrees |
| `dangerous-commands.sh` | PreToolUse (Bash) | Block catastrophic commands |
| `secret-scanner.sh` | PreToolUse (Bash) | Scan for secrets before commits |
| `protect-claude-md.sh` | PreToolUse (Edit\|Write) | Block CLAUDE.md edits (approval file bypass for /bootstrap-project) |
| `tdd-guardian.sh` | PreToolUse (Edit\|Write) | Block impl edits during TDD RED phase |
| `empirica-session-guard.sh` | PreToolUse (mcp__empirica__session_create) | Block duplicate Empirica sessions (redirect to preflight) |
| `after-edit.sh` | PostToolUse (Edit\|Write) | Auto-format files after edits |
| `cfn-lint-check.sh` | PostToolUse (Edit\|Write) | Auto-lint CloudFormation templates (fail-open) |
| `state-index-update.sh` | PostToolUse (Edit\|Write) | Maintain active work state index |
| `blueprint-stage-gate.sh` | PostToolUse (Edit\|Write) | Check Empirica data before stage transitions (advisory) |
| `statusline.sh` | StatusLine | Model, cost, context, active blueprint/TDD state |
| `notify.sh` | Notification | Desktop alerts |

### Fail-Open Pattern

All hooks use fail-open: if the hook itself breaks, operations continue.

```bash
# Fail-open pattern
set +e  # Don't exit on error
# ... hook logic ...
# Only exit non-zero if EXPLICITLY blocking
```

**Why fail-open?** Hook bugs shouldn't halt legitimate work. The security check only activates when functioning correctly.

| Scenario | Fail-Closed | Fail-Open |
|----------|-------------|-----------|
| Hook has bug | All work blocked | Work continues, security gap |
| jq not installed | Nothing works | Proceeds without check |

For personal/dev environments, fail-open makes sense. For production deploys, consider fail-closed.

### Surgical vs Blanket Blocking

Don't block `rm -rf` entirely—that breaks legitimate operations like `rm -rf node_modules`. Instead, block specific dangerous targets:

```bash
# Bad: Blanket blocking
[[ "$cmd" =~ rm\ -rf ]] && exit 2

# Good: Surgical blocking
[[ "$cmd" =~ rm\ -rf\ / ]] && exit 2      # root
[[ "$cmd" =~ rm\ -rf\ ~ ]] && exit 2      # home
[[ "$cmd" =~ rm\ -rf\ /home ]] && exit 2  # all users
# rm -rf node_modules is fine
```

---

## Layer 2: Hookify Rules

YAML-based rules in `*.local.md` files. Claude reads these and understands the context.

### Included Rules

| Rule | Action | What It Blocks |
|------|--------|----------------|
| `surgical-rm` | block | `rm -rf /`, `~`, `..`, `/home` (allows safe targets) |
| `force-push-protection` | block | Force push to main/master/production/release/develop |
| `chmod-777` | block | World-writable permissions |
| `remote-exec-protection` | block | `curl \| bash` and similar patterns |
| `disk-ops-protection` | block | Direct disk writes (`dd of=/dev/*`, `mkfs`) |
| `exfiltration-protection` | block | Network transfers of sensitive files |
| `env-exposure-protection` | warn | Reading `.env` files (warns but allows) |

### Block vs Warn

- **block**: Operation prevented entirely
- **warn**: Claude sees warning, can proceed if justified

Use `warn` for things that are sometimes legitimate (like reading `.env` for debugging) and `block` for things that are never okay (like `chmod 777`).

### Installation

```bash
cp hookify-rules/*.local.md ~/.claude/
```

Hookify reads `*.local.md` files automatically from `~/.claude/`.

---

## Layer 3: CLAUDE.md

Project-specific guidance that Claude reads at session start. Not enforcement—just context.

CLAUDE.md tells Claude:
- Your project's conventions
- What patterns to follow (and avoid)
- How to run tests, builds, deploys
- What's sensitive and should be handled carefully

Because it's suggestions rather than enforcement, Claude can deviate when appropriate. This flexibility is a feature for general guidance but a weakness for security-critical rules—which is why Layers 1 and 2 exist.

---

## Configuration

### settings.json

Add hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "matcher": "", "hooks": [
      { "type": "command", "command": "~/.claude/hooks/session-sail.sh" },
      { "type": "command", "command": "~/.claude/hooks/worktree-cleanup.sh" }
    ]}],
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/dangerous-commands.sh" },
        { "type": "command", "command": "~/.claude/hooks/secret-scanner.sh" }
      ]},
      { "matcher": "Edit|Write", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/protect-claude-md.sh" },
        { "type": "command", "command": "~/.claude/hooks/tdd-guardian.sh" }
      ]},
      { "matcher": "mcp__empirica__session_create", "hooks": [
        { "type": "command", "command": "~/.claude/hooks/empirica-session-guard.sh" }
      ]}
    ],
    "PostToolUse": [{ "matcher": "Edit|Write", "hooks": [
      { "type": "command", "command": "~/.claude/hooks/after-edit.sh" },
      { "type": "command", "command": "~/.claude/hooks/cfn-lint-check.sh", "timeout": 30 },
      { "type": "command", "command": "~/.claude/hooks/state-index-update.sh" },
      { "type": "command", "command": "~/.claude/hooks/blueprint-stage-gate.sh" }
    ]}],
    "Notification": [{ "matcher": "*", "hooks": [
      { "type": "command", "command": "~/.claude/hooks/notify.sh" }
    ]}]
  }
}
```

See `settings-example.json` for complete configuration including status line.

---

## Timeout Pattern

Quality checks (linting, formatting) should have timeouts to prevent hanging:

```bash
TIMEOUT=30

if timeout "$TIMEOUT" npm run lint 2>/dev/null; then
    echo "Lint passed"
elif [[ $? -eq 124 ]]; then
    echo "Lint timed out - skipping"
else
    echo "Lint failed"
fi
```

Exit code 124 specifically means "timeout killed the process."

### Recommended Timeouts

| Check Type | Timeout | Rationale |
|------------|---------|-----------|
| Formatters | 10s | Should be fast |
| Linters | 30s | May need more time |
| Type checkers | 60s | Complex projects need time |
| Tests | Don't use in hooks | Run separately |

---

## Further Reading

- `hooks/HOOK-PATTERNS-RESEARCH.md` - Detailed research on patterns
- [TheDecipherist/claude-code-mastery](https://github.com/TheDecipherist/claude-code-mastery) - Source of many patterns
- [Anthropic MCP Documentation](https://docs.anthropic.com/claude-code) - Official Claude Code docs

---

## Philosophy

> "CLAUDE.md rules are suggestions. Hooks are enforcement."

Every hook in this toolkit exists because someone made that mistake. The goal isn't to restrict Claude—it's to catch the mistakes that happen at 3 AM when you're tired and just want to ship.

Safety by default. Flexibility when needed. Enforcement where it matters.
