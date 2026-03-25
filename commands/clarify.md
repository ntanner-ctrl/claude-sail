---
description: "DEPRECATED: Use /research for investigation or /design-check for implementation readiness"
arguments:
  - name: topic
    description: What needs clarification (problem, feature, or area of uncertainty)
    required: false
---

## Cognitive Traps

This command is deprecated. If you're reading this, you should be using a different command.

| Rationalization | Why It's Wrong |
|----------------|---------------|
| "I'll just use /clarify since I remember it" | /clarify has been replaced by purpose-specific workflows that do each job better. |

# Clarify (Deprecated)

This command has been superseded by purpose-specific workflows.

## What to Use Instead

Not sure which you need? Use this guide:

```
┌─────────────────────────────────────────────────┐
│ Problem space unclear?     → /research [topic]  │
│   (brainstorm + prior-art + requirements)       │
│   For complex or unfamiliar problem domains     │
│                                                 │
│ Quick question, low stakes? → /brainstorm       │
│   (lightweight problem analysis, 5-10 min)      │
│                                                 │
│ Solution unclear?          → /blueprint [topic]  │
│   (solution-clarity gate catches this)          │
│                                                 │
│ Ready to build?            → /design-check      │
│   (architecture, interfaces, error strategy)    │
└─────────────────────────────────────────────────┘
```

The clarification concerns `/clarify` addressed are now handled by these workflows:

| Concern | Old Path | New Path |
|---------|----------|----------|
| Multiple viable approaches | /clarify → brainstorm step | /research (standard mode) or /brainstorm directly |
| Requirements unclear | /clarify → requirements step | /research (standard mode) or /requirements-discovery directly |
| Prior art unknown | /clarify → prior-art step | /research (any mode) or /prior-art directly |
| Implementation boundaries fuzzy | /clarify → design-check step | /design-check directly |

## Vault Awareness

```bash
source ~/.claude/hooks/vault-config.sh 2>/dev/null
```

If vault is available and the user chooses to complete an active session, vault integration works as before. If vault is unavailable, skip silently (fail-open).

## Active Session Handling

If you have an active `/clarify` wizard session (`.claude/wizards/clarify-*/state.json`):

1. Check for active sessions: `glob .claude/wizards/clarify-*/state.json`
2. If found, display:
   ```
   You have an active /clarify session for [topic] from [session age].

     [1] Complete the existing session (runs remaining steps)
     [2] Abandon session and use /research [topic] instead
     [3] Abandon session and use /design-check [topic] instead
   ```
3. If not found: display this deprecation message.

No auto-migration of clarify state to research state — they are different workflows with different structures.

## Failure Modes

| What Could Fail | Detection | Recovery |
|-----------------|-----------|----------|
| User invokes /clarify out of habit | Command executes | Deprecation redirect shown with decision table |
| Active clarify session found | State file exists | User prompted to complete or abandon |
| Orphaned clarify sessions accumulate | State files > 7 days old | Standard wizard cleanup applies (archive after 7 days) |

## Known Limitations

- **Wizard state not migrated** — Active /clarify sessions cannot be converted to /research sessions. They must be completed under the old workflow or abandoned.
- **Skills/hooks referencing /clarify** — Any external references to `/clarify` in CLAUDE.md files, hooks, or muscle memory will need manual updating.

## Integration

- **Replaced by:** `/research` (investigation), `/design-check` (implementation readiness), `/brainstorm` (lightweight analysis)
- **Formerly called by:** `/blueprint` pre-stage (now suggests `/research` instead)
