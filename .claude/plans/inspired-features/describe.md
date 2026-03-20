# Describe: inspired-features

## Change Summary

Add 7 new features to claude-sail inspired by external projects (gstack, everything-claude-code, sidjua). These features strengthen the toolkit's safety model, add observability, and close the learning loop.

## Features

### 1. Hook Runtime Toggles
**Source:** everything-claude-code (`ECC_HOOK_PROFILE`, `ECC_DISABLED_HOOKS`)
- Add `SAIL_DISABLED_HOOKS` env var check to all 17 shell hooks
- Hook checks its own filename against comma-separated disable list
- Document in CLAUDE.md and README

### 2. Budget/Cost Awareness
**Source:** sidjua (per-task budget enforcement)
- SessionEnd hook logs token usage to `.claude/budget.jsonl`
- `/budget` command to view spend history and set soft limits
- PreToolUse hook warns when approaching budget (advisory, not blocking)

### 3. Baseline Rules That Can't Be Weakened
**Source:** sidjua (10 mandatory baseline protection rules)
- Add `baseline: true` frontmatter field to select hookify rules
- Hookify plugin checks baseline flag before allowing disable
- Mark security-critical existing rules as baseline (exfiltration, force-push, etc.)

### 4. Retrospective Command (`/retro`)
**Source:** gstack (`/retro` — commit history + velocity analysis)
- Analyzes git log, session logs, and command usage patterns
- Produces structured retro output (what worked, what didn't, velocity)
- Template for vault export

### 5. `/freeze` Directory Locking
**Source:** gstack (`/freeze`/`/unfreeze`)
- `/freeze` writes locked directories to `.claude/frozen-dirs.json`
- `/unfreeze` removes locks
- PreToolUse hook blocks Write/Edit to frozen directories

### 6. Instinct → Skill Evolution (`/evolve`)
**Source:** everything-claude-code (instinct-based learning → skill evolution)
- `/evolve` reads `.claude/log-error.jsonl` and `.claude/log-success.jsonl`
- Clusters recurring patterns
- Proposes hookify rules or CLAUDE.md additions
- Promotion workflow: pattern → finding → rule

### 7. Audit Trail for Hook Blocks
**Source:** sidjua (compliance auditing)
- Hooks that exit 2 append to `.claude/audit.jsonl` with timestamp, hook name, reason
- `/audit` command reviews log with summary stats (most-blocked, trends)
- Shared logging function for all hooks

## Discrete Steps (18 total)

1a. Add env var checks to 17 shell hooks
1b. Document env vars in CLAUDE.md and README
2a. Create SessionEnd hook for budget logging
2b. Create `/budget` command
2c. Create PreToolUse budget warning hook
3a. Add `baseline: true` frontmatter to select hookify rules
3b. Modify hookify plugin to check baseline flag
3c. Mark existing rules as baseline
4a. Create `commands/retro.md`
4b. Create retro vault note template
5a. Create `commands/freeze.md`
5b. Create `commands/unfreeze.md`
5c. Create PreToolUse freeze hook
6a. Create `commands/evolve.md`
6b. Implement pattern clustering logic
6c. Create promotion workflow
7a. Add audit logging to hooks that exit 2
7b. Create `commands/audit.md`
7c. Add summary stats to audit command

## Triage Result

**Steps:** 18 discrete actions
**Risk flags:** User-facing behavior change, Security-sensitive operations
**Execution preference:** Speed (parallel)
**Recommended path:** Full — Complete planning protocol
**Challenge mode:** Family (generational debate)
