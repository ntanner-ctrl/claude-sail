---
description: Use when Claude Sail may have drifted, hooks aren't firing, or after re-installing. Validates toolkit integrity and suggests fixes.
argument-hint: --fix to show remediation steps, --quiet for pass/fail only
allowed-tools:
  - Read
  - Glob
  - Bash
  - Grep
---

# Sail Doctor — Toolkit Health Report

Diagnose the health of the claude-sail installation across 6 categories. Run sequentially. Aggregate results into a final status report.

## Flags

- `--fix`: After each failing check, show commented-out remediation commands with a safety warning header.
- `--quiet`: Suppress passing checks; show failures and warnings only. Summary always shown.
- `--quiet --fix`: Failures + fixes shown, passes suppressed. Summary always shown.

## Self-Bootstrap Check (run FIRST, before any category)

Use the Bash tool:

```bash
ls ~/.claude/.sail-counts.json 2>/dev/null && echo "EXISTS" || echo "MISSING"
```

If missing, display:

```
⚠  Install artifact missing (~/.claude/.sail-counts.json).
   Run `bash install.sh` to regenerate.
   File count verification will be skipped.
```

Continue with remaining categories — do not stop.

---

## Category 1: File Count Verification

Read `~/.claude/.sail-counts.json` using the Read tool.

**Schema:**
```json
{"commands": N, "agents": N, "hooks": N, "hookify_rules": N, "stock_total": N, "stock_pipelines": N}
```

If the file is absent (caught in self-bootstrap check): mark as **SKIP** with warning shown above.

If the file is present but JSON is malformed: mark as **FAILURE**.
```
✗ ~/.sail-counts.json is corrupt — re-run install.sh to regenerate.
```

If valid, count actual installed files using the Bash tool:

```bash
echo "commands=$(ls ~/.claude/commands/*.md 2>/dev/null | wc -l)"
echo "agents=$(ls ~/.claude/agents/*.md 2>/dev/null | wc -l)"
echo "hooks=$(ls ~/.claude/hooks/*.sh 2>/dev/null | wc -l)"
echo "hookify_rules=$(ls ~/.claude/hookify-rules/*.local.md 2>/dev/null | wc -l)"
echo "stock_total=$(ls ~/.claude/commands/templates/stock-*/* 2>/dev/null | wc -l)"
```

Compare each field. For any mismatch, report the delta:

```
✗ commands: expected 51, found 49  (delta: -2)
```

Overall result for this category:
- All match → **PASS**
- Any mismatch → **FAILURE**

If `--fix` is set and there are failures, show:

```
  ⚠  Review these suggestions before running — they may overwrite customizations.
  # Re-run the installer to restore missing files:
  # bash ~/path/to/claude-sail/install.sh
```

---

## Category 2: Hook Wiring Validation

Read `~/.claude/settings.json` using the Read tool. If absent, try `~/.claude/settings.local.json`. If neither exists:

```
✗ No settings.json found at ~/.claude/settings.json or ~/.claude/settings.local.json.
  Hook wiring cannot be verified.
```

Mark as **FAILURE** and skip to Category 3.

If the file exists but is malformed JSON:

```
✗ settings.json is malformed. Fix JSON syntax before hooks will fire.
```

Mark as **FAILURE** and skip to Category 3.

**Expected hook .sh files** (from settings-example.json):

```
~/.claude/hooks/session-sail.sh
~/.claude/hooks/worktree-cleanup.sh
~/.claude/hooks/notify.sh
~/.claude/hooks/after-edit.sh
~/.claude/hooks/cfn-lint-check.sh
~/.claude/hooks/state-index-update.sh
~/.claude/hooks/blueprint-stage-gate.sh
~/.claude/hooks/failure-escalation.sh
~/.claude/hooks/empirica-insight-capture.sh
~/.claude/hooks/empirica-preflight-capture.sh
~/.claude/hooks/empirica-postflight-capture.sh
~/.claude/hooks/dangerous-commands.sh
~/.claude/hooks/secret-scanner.sh
~/.claude/hooks/protect-claude-md.sh
~/.claude/hooks/tdd-guardian.sh
~/.claude/hooks/session-end-vault.sh
~/.claude/hooks/session-end-cleanup.sh
```

For each hook path, scan the user's settings.json to determine if a matching `"command"` entry exists. Use Grep:

```bash
grep -c "hook-filename.sh" ~/.claude/settings.json 2>/dev/null
```

Also verify the file exists and is executable:

```bash
test -x ~/.claude/hooks/hook-filename.sh && echo "OK" || echo "NOT_EXECUTABLE"
```

Tally: N wired out of 17 expected.

Report each missing or non-executable hook individually:
```
  ✗ session-sail.sh — not wired in settings.json
  ✗ notify.sh — file not executable (chmod +x ~/.claude/hooks/notify.sh)
```

Overall:
- All 17 wired and executable → **PASS**
- Any missing or non-executable → **FAILURE**

Report: `N/17 expected hooks wired`

If `--fix` is set and there are failures:

```
  ⚠  Review these suggestions before running — they may overwrite customizations.
  # To wire missing hooks, copy settings-example.json from the claude-sail repo
  # into ~/.claude/settings.json (back up your current settings first):
  # cp ~/.claude/settings.json ~/.claude/settings.json.bak
  # cp ~/path/to/claude-sail/settings-example.json ~/.claude/settings.json
  #
  # To make a single hook executable:
  # chmod +x ~/.claude/hooks/<hook-name>.sh
```

---

## Category 3: Settings Drift Detection

Check at the EVENT-TYPE KEY level only. Do NOT check individual hook entries, matchers, or timeouts. Do NOT flag user additions.

**Expected event-type keys** (from settings-example.json):
```
SessionStart
Notification
PostToolUse
PreToolUse
SessionEnd
```

Read the user's settings.json (already read in Category 2 — reuse if available). Check whether each event-type key exists as a top-level key under `"hooks"`.

For each missing key:
```
  ⚠ Event type "SessionEnd" not present in settings.json hooks
```

Overall:
- All 5 event-type keys present → **PASS**
- Any missing → **WARNING** (not FAILURE — user may have intentionally omitted)

If `--fix` is set and there are warnings:

```
  ⚠  Review these suggestions before running — they may overwrite customizations.
  # Add missing event-type sections to ~/.claude/settings.json.
  # Reference: settings-example.json in the claude-sail repo.
  # Missing: SessionEnd
```

---

## Category 4: MCP Server Availability (INFORMATIONAL)

This category NEVER affects overall status. Always labeled as "informational."

### Empirica

Attempt to call `mcp__empirica__system_status`. If the tool does not exist in the session, report "not available." If it succeeds, report "connected."

### Context7

Attempt `mcp__context7__resolve-library-id` with query "react". If the tool does not exist in the session, report "not available." If it returns a result (even no match), report "connected."

### Obsidian

Use the Bash tool:

```bash
timeout 5 bash -c 'source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo $VAULT_ENABLED' 2>/dev/null
```

If output is `1`, report "connected." If output is empty or `0`, report "not configured." If the command times out, report "timeout."

Report: `N/3 connected (informational)`

---

## Category 5: Target Project Health

### Self-Exclusion Check

First, determine if the current working directory should be skipped.

Use the Bash tool:

```bash
echo "PWD=$PWD"
echo "HOME=$HOME"
test -f "$PWD/install.sh" && test -f "$PWD/commands/bootstrap-project.md" && echo "IS_SAIL_REPO=1" || echo "IS_SAIL_REPO=0"
```

Skip with note if:
- `PWD` matches `$HOME/.claude`, OR
- `IS_SAIL_REPO=1` (claude-sail source repo detected)

```
  — Skipped (running inside claude-sail source repo — no target project to check)
```

### Project Checks (if not skipped)

**A. CLAUDE.md presence**

```bash
test -f "$PWD/.claude/CLAUDE.md" && echo "EXISTS" || echo "MISSING"
```

If missing: **WARNING** — "No .claude/CLAUDE.md found. Run /bootstrap-project."

**B. Manifest presence**

```bash
test -f "$PWD/.claude/sail-manifest.json" && echo "EXISTS" || test -f "$PWD/.claude/bootstrap-manifest.json" && echo "EXISTS (legacy)" || echo "MISSING"
```

If missing: **WARNING** — "No sail manifest found. Project may not have been bootstrapped."

**C. Orphaned plans**

```bash
for d in "$PWD/.claude/plans"/*/; do
  [ -d "$d" ] && ! [ -f "${d}state.json" ] && echo "ORPHAN: $d"
done
```

For each directory found without a `state.json`, report:
```
  ⚠ Orphaned plan directory: .claude/plans/my-plan/ (no state.json)
```

Overall for this category:
- No issues → **PASS**
- Warnings only → **WARNING**
- (No failure conditions — project issues are advisory)

If `--fix` is set and there are warnings:

```
  ⚠  Review these suggestions before running — they may overwrite customizations.
  # Bootstrap this project:
  # Run /bootstrap-project in a Claude Code session here
  #
  # Clean up orphaned plan directories manually:
  # rm -rf .claude/plans/<orphaned-dir>/
```

---

## Category 6: Version Alignment

**Read installed version:**

```bash
cat ~/.claude/.sail-version 2>/dev/null || echo "MISSING"
```

**Detect if in claude-sail repo:**

```bash
test -f "$PWD/VERSION" && test -f "$PWD/install.sh" && cat "$PWD/VERSION" || echo "NOT_IN_REPO"
```

Logic:
- If `~/.claude/.sail-version` is missing → **SKIP**: "Installed version unknown (.sail-version not found)"
- If not in claude-sail repo → **SKIP**: "Not in claude-sail repo — cannot compare versions"
- If both present: compare values
  - Match → **PASS**: "Installed version matches repo (v1.2.3)"
  - Mismatch → **WARNING**: "Installed: v1.2.2 / Repo: v1.2.3 — run install.sh to update"

If `--fix` is set and version is behind:

```
  ⚠  Review these suggestions before running — they may overwrite customizations.
  # Update your install from the repo:
  # bash install.sh
```

---

## Status Aggregation

Collect results from all categories. Use the following status levels:

| Symbol | Level |
|--------|-------|
| ✓ | PASS |
| ⚠ | WARNING |
| ✗ | FAILURE |
| — | SKIPPED |

**Overall status** is determined by the WORST result across Categories 1, 2, 3, 5, and 6 only. Category 4 is always informational and never affects overall status.

| Worst result | Overall status |
|---|---|
| All PASS (or SKIP) | HEALTHY |
| WARNING only | NEEDS ATTENTION |
| Any FAILURE | UNHEALTHY |

---

## Summary Output

Always display the summary block at the end, regardless of `--quiet`.

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SAIL DOCTOR │ Toolkit Health Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. File Counts        ✓ All match
  2. Hook Wiring        ✗ 2 hooks not wired
  3. Settings Drift     ⚠ 1 event type missing
  4. MCP Availability   ✓ 2/3 connected (informational)
  5. Target Project     ✓ Healthy
  6. Version            — Skipped (not in repo)

  Status: NEEDS ATTENTION — 1 failure, 1 warning

  Run /sail-doctor --fix for remediation steps.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Adjust the status line to reflect actual findings:
- `Status: HEALTHY — all checks passed`
- `Status: NEEDS ATTENTION — N warning(s)`
- `Status: UNHEALTHY — N failure(s), M warning(s)`

If `--fix` was NOT used and there are any failures or warnings, append:
```
  Run /sail-doctor --fix for remediation steps.
```

If `--quiet` is in effect, the category lines for passing checks are omitted from the summary but always present for failures and warnings.

---

$ARGUMENTS
