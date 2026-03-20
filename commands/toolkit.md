---
description: Use when you need to find the right command for a situation. Lists all available commands with their trigger conditions.
---

# Toolkit

Display a quick reference of all available commands, organized by workflow stage.

## Output

Present this reference card:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        CLAUDE SAIL TOOLKIT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

WORKFLOW WIZARDS (guided paths)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /blueprint [name]  Full planning workflow — walks through all stages
  /review [name]     Adversarial review workflow — challenge a blueprint
  /test [name]       Testing workflow — spec to tests to verification

START HERE
━━━━━━━━━━
  /start             Assess state, recommend next task
  /describe-change   Triage — determines planning depth
  /toolkit           You are here

PLANNING (before you build)
━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /spec-change       Full change specification template
  /spec-agent        Define a new agent
  /spec-hook         Define a new hook
  /preflight         Pre-flight checklist (quick safety check)
  /brainstorm        Open-ended problem exploration
  /decision          Record a non-obvious decision
  /requirements-discovery   Extract validated requirements

ADVERSARIAL (challenge your blueprint)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /devils-advocate   What assumptions might be wrong?
  /overcomplicated   Is this overcomplicated?
  /edge-cases        Probe boundaries and limits
  /gpt-review        External model review (different perspective)

TESTING (verify before ship)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /spec-to-tests     Generate tests from spec (spec-blind)
  /security-checklist   8-point OWASP-style audit

EXECUTION (when you build)
━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /delegate          Hand off to specialized sub-agent
  /push-safe         Safe git push with secret scanning
  /freeze [dir]      Lock directories from edits
  /unfreeze [dir]    Unlock frozen directories
  /budget            Session turn awareness and thresholds
  /audit             Review hook block history

LEARNING (improve over time)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  /log-error         Interview yourself after mistakes
  /log-success       Capture what went right and why
  /evolve            Synthesize patterns into workflow rules
  /retro             Retrospective across recent sessions

DOCUMENTATION
━━━━━━━━━━━━━
  /refresh-claude-md Update project CLAUDE.md
  /migrate-docs      Migrate to Diataxis framework
  /process-doc       Generate How-to Guides

SETUP & STATUS
━━━━━━━━━━━━━━
  /bootstrap-project Initialize project with toolkit
  /check-project-setup   Verify configuration
  /assess-project    Generate CLAUDE.md only
  /setup-hooks       Configure formatting hooks
  /status            Current blueprint workflow state
  /blueprints        List all in-progress blueprints
  /overrides         Review override patterns

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Don't know where to start? Run /describe-change
  Want guided help? Run /blueprint [name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Contextual Additions

If `.claude/plans/` exists and contains in-progress blueprints, append:

```
ACTIVE BLUEPRINTS
━━━━━━━━━━━━
  [name]    Stage [N]/7    Last: [time ago]
  ...

  Resume with: /blueprint [name]
```

## Notes

- This is a display-only command
- No arguments required
- Updates automatically as new commands are added
