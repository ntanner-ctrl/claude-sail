## Sail Doctor — Running Checks

### Category 1: File Counts

Comparing installed files against `.sail-counts.json` baseline...

- commands: 51/51 ✓
- agents: 6/6 ✓
- hooks: 16/18 ✗ — delta: -2
- hookify_rules: 7/7 ✓
- stock_total: 12/12 ✓

2 hooks are missing from the installation.

Result: **FAILURE**

---

### Category 2: Hook Wiring

Scanning `~/.claude/settings.json` for hook entries...

Checking each expected hook...

  ✗ tdd-guardian.sh — not wired in settings.json
  ✗ session-end-vault.sh — not wired in settings.json
  ✓ session-sail.sh — wired and executable
  ✓ dangerous-commands.sh — wired and executable
  ✓ secret-scanner.sh — wired and executable

15/17 hooks wired. 2 hooks missing from settings.json.

Result: **FAILURE** — 2 hooks not wired

---

### Category 3: Settings Drift

Checking for required event-type keys in settings.json...

  ⚠ Event type "SessionEnd" not present in settings.json hooks

Result: **WARNING**

---

### Category 4: MCP Availability (informational)

- Empirica: connected
- Context7: not available
- Obsidian: not configured

Result: 1/3 connected (informational)

---

### Category 5: Target Project

- `.claude/CLAUDE.md` present ✓
- `sail-manifest.json` present ✓
- No orphaned plan directories found ✓

Result: **PASS**

---

### Category 6: Version Alignment

Not in claude-sail repo — cannot compare versions.

Result: **SKIP**

---

## Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SAIL DOCTOR │ Toolkit Health Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. File Counts        ✗ 2 hooks missing (delta: -2)
  2. Hook Wiring        ✗ 2 hooks not wired in settings.json
  3. Settings Drift     ⚠ SessionEnd event type missing
  4. MCP Availability   — 1/3 connected (informational)
  5. Target Project     ✓ Healthy
  6. Version            — Skipped (not in repo)

  Status: NEEDS ATTENTION — 2 failures, 1 warning

  Run /sail-doctor --fix for remediation steps.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
