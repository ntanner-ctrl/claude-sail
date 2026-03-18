## Sail Doctor — Running Checks

### Category 1: File Counts

Comparing installed files against `.sail-counts.json` baseline...

- commands: 51/51 ✓
- agents: 6/6 ✓
- hooks: 18/18 ✓
- hookify_rules: 7/7 ✓
- stock_total: 12/12 ✓

Result: **PASS**

---

### Category 2: Hook Wiring

Scanning `~/.claude/settings.json` for hook entries...

All 17 expected hooks are wired and executable.

Result: **PASS** — 17/17 hooks wired

---

### Category 3: Settings Drift

Checking for required event-type keys in settings.json...

All 5 event-type keys present: SessionStart, Notification, PostToolUse, PreToolUse, SessionEnd.

Result: **PASS**

---

### Category 4: MCP Availability (informational)

- Empirica: connected
- Context7: connected
- Obsidian: connected

Result: 3/3 connected (informational)

---

### Category 5: Target Project

- `.claude/CLAUDE.md` present ✓
- `sail-manifest.json` present ✓
- No orphaned plan directories found ✓

Result: **PASS**

---

### Category 6: Version Alignment

Installed version: v1.4.0 — matches repo version.

Result: **PASS**

---

## Summary

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  SAIL DOCTOR │ Toolkit Health Report
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. File Counts        ✓ All match
  2. Hook Wiring        ✓ 17/17 hooks wired
  3. Settings Drift     ✓ All event types present
  4. MCP Availability   ✓ 3/3 connected (informational)
  5. Target Project     ✓ Healthy
  6. Version            ✓ v1.4.0 (matches repo)

  Status: HEALTHY — all checks passed

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
