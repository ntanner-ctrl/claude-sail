---
description: Use when project setup may have drifted or new components are available. Detects gaps between current and recommended configuration.
argument-hint: --quiet for minimal output, --verbose for full analysis, --fix to auto-update
allowed-tools:
  - Read
  - Glob
  - Bash
  - Grep
---

# Project Setup Check

Lightweight drift detection for Claude Code extensibility. Designed to run quickly and suggest updates without blocking your workflow.

## Arguments

- `--quiet` or `-q`: Only output if action is needed
- `--verbose` or `-v`: Show detailed analysis
- `--fix`: Auto-update CLAUDE.md with detected changes (use with caution)

## Quick Checks (< 30 seconds)

Perform these fast checks first:

### 1. Existence Checks

```
Does .claude/ directory exist?
├── YES → Check for manifest
└── NO → SUGGEST: Run /bootstrap-project

Does CLAUDE.md exist? (check .claude/CLAUDE.md then ./CLAUDE.md)
├── YES → Continue to drift detection
└── NO → SUGGEST: Run /bootstrap-project

Does .claude/sail-manifest.json OR .claude/bootstrap-manifest.json exist?
├── YES → Use it for tracking (prefer sail-manifest.json, fall back to bootstrap-manifest.json)
└── NO → This may be a manually configured project
```

### 2. Staleness Check

If manifest exists, check:
- How long since last bootstrap? (>30 days = suggest review)
- Has project structure changed significantly?

## Drift Detection

If quick checks pass, perform light drift detection:

### A. CLAUDE.md Accuracy

Sample 2-3 commands from CLAUDE.md's Quick Reference and verify they still work:

```bash
# Extract commands from CLAUDE.md (look for code blocks after "Build:", "Test:", etc.)
# Test each with --help or --version to verify it exists
```

**Indicators of drift:**
- Commands fail or don't exist
- Paths referenced don't exist
- Dependencies listed are wrong

### B. Structural Changes

Compare current structure to what CLAUDE.md documents:

```bash
# List top-level directories
ls -d */ 2>/dev/null | sort

# Compare to what's documented
# Look for new directories not mentioned in Architecture/Structure sections
```

**Indicators of drift:**
- New top-level directories (>2 new since CLAUDE.md written)
- Missing directories that are documented
- New major config files (docker-compose, terraform, etc.)

### C. Dependency Changes

Quick check for new dependencies:

```bash
# Python
diff <(grep -E "^[a-z]" requirements.txt 2>/dev/null | wc -l) <(echo "documented_count")

# Node
jq '.dependencies | length' package.json 2>/dev/null
```

**Indicators of drift:**
- >10 new dependencies since last check
- Major framework additions

### D. Stock Element Health

If bootstrap manifest exists:
- Are all stock elements still present?
- Have any been modified (hash changed)?
- Are there newer versions available?

## Escalation Triggers

Recommend running full `/bootstrap-project` when:

1. **No setup exists**: Missing .claude/ or CLAUDE.md
2. **Major structural changes**: 3+ new top-level directories
3. **Framework changes**: New language or framework detected
4. **Stale setup**: >60 days since last full bootstrap
5. **Broken commands**: >30% of documented commands fail

## Output Formats

### Quiet Mode (--quiet)

Only output if action needed:
```
[setup-check] 2 issues found. Run /check-project-setup for details.
```

Or nothing if all good.

### Normal Mode

```
## Project Setup Check

**Status:** [OK / NEEDS ATTENTION / NEEDS BOOTSTRAP]
**Last bootstrapped:** 15 days ago

### Quick Checks
✓ .claude/ directory exists
✓ CLAUDE.md present (2,847 chars)
✓ Bootstrap manifest found

### Drift Detection
✓ Build command works: `npm run build`
✓ Test command works: `npm test`
⚠ New directory not documented: `infrastructure/`
⚠ 5 new dependencies since last check

### Suggestions
1. Add `infrastructure/` to Architecture section of CLAUDE.md
2. Consider running /refresh-claude-md to update dependency documentation

Run `/bootstrap-project` for a full setup refresh.
```

### Verbose Mode (--verbose)

Add detailed information:
```
### Detailed Analysis

#### Structure Comparison
Documented directories: src/, tests/, docs/
Current directories: src/, tests/, docs/, infrastructure/, scripts/

New (undocumented):
- infrastructure/ (contains terraform files - likely IaC)
- scripts/ (contains shell scripts - utility scripts)

#### Dependency Analysis
requirements.txt: 23 packages (+5 since manifest)
New packages: boto3, pydantic, httpx, rich, typer

#### Stock Element Status
| Element | Status | Modified |
|---------|--------|----------|
| hooks/test-coverage-reminder.md | Present | No |
| hooks/security-warning.md | Present | Yes (customized) |
| agents/troubleshooter.md | Present | No |
```

## Integration with Session Start

This command is designed to be called by the session start hook with `--quiet` flag. When called this way:

1. Run only the fastest checks (existence, staleness)
2. Output a single-line suggestion if needed
3. Exit silently if everything looks good

The user can then run without --quiet for full details.

## Comparison with Related Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/check-project-setup` | Quick drift detection | Session start, quick validation |
| `/refresh-claude-md` | Update CLAUDE.md content | When documentation is stale |
| `/bootstrap-project` | Full setup/re-setup | New projects, major changes |

---

$ARGUMENTS
