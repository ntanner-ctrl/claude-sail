# Test Plan: inspired-features

Tests to add to `test.sh` after implementation. These are spec-blind — derived from acceptance criteria, not implementation details.

## Category: File Counts (existing category, updated values)

```bash
# Command count: 55 → 61 (6 new: budget, retro, freeze, unfreeze, evolve, audit)
EXPECTED_COMMANDS=61

# Hook count: 17 → 18 (1 new: freeze-guard.sh)
EXPECTED_HOOKS=18

# Hookify rules: 7 (unchanged)
EXPECTED_HOOKIFY=7
```

## Category: Hook Runtime Toggles (Feature 1)

```bash
# T1.1: All hooks have SAIL_DISABLED_HOOKS guard
for hook in hooks/*.sh; do
    if [[ "$(basename "$hook")" == "_"* ]]; then continue; fi  # skip utility files
    grep -q "SAIL_DISABLED_HOOKS" "$hook" || fail "Hook $hook missing SAIL_DISABLED_HOOKS guard"
done

# T1.2: Guard block uses correct pattern (basename + comma-delimited match)
for hook in hooks/*.sh; do
    if [[ "$(basename "$hook")" == "_"* ]]; then continue; fi
    grep -q 'HOOK_NAME=.*basename.*BASH_SOURCE' "$hook" || fail "Hook $hook missing HOOK_NAME extraction"
done
```

## Category: Baseline Rules (Feature 3)

```bash
# T3.1: Expected hookify rules have baseline: true
for rule in hookify.force-push-protection hookify.exfiltration-protection hookify.disk-ops-protection hookify.chmod-777; do
    grep -q "baseline: true" "hookify-rules/${rule}.local.md" || fail "Rule $rule missing baseline: true"
done

# T3.2: Non-baseline rules do NOT have baseline: true
for rule in hookify.surgical-rm hookify.remote-exec-protection hookify.env-exposure-protection; do
    if grep -q "baseline: true" "hookify-rules/${rule}.local.md" 2>/dev/null; then
        fail "Rule $rule should NOT have baseline: true"
    fi
done
```

## Category: New Commands Exist (Features 2, 4, 5, 6, 7)

```bash
# T-CMD: All 6 new commands exist with required frontmatter
for cmd in budget retro freeze unfreeze evolve audit; do
    [[ -f "commands/${cmd}.md" ]] || fail "Missing command: ${cmd}.md"
    head -5 "commands/${cmd}.md" | grep -q "^description:" || fail "Command ${cmd}.md missing description frontmatter"
done
```

## Category: Freeze Feature (Feature 5)

```bash
# T5.1: freeze-guard.sh exists and follows hook conventions
[[ -f "hooks/freeze-guard.sh" ]] || fail "Missing freeze-guard.sh"
grep -q "set +e" "hooks/freeze-guard.sh" || fail "freeze-guard.sh missing set +e"
grep -q "exit 0" "hooks/freeze-guard.sh" || fail "freeze-guard.sh missing exit 0 (fail-open)"
! grep -q "set -e" "hooks/freeze-guard.sh" || fail "freeze-guard.sh has set -e (forbidden in hooks)"

# T5.2: freeze-guard.sh is wired in settings-example.json
grep -q "freeze-guard.sh" "settings-example.json" || fail "freeze-guard.sh not wired in settings-example.json"

# T5.3: freeze-guard.sh normalizes paths (absolute comparison)
grep -q "rev-parse\|realpath\|readlink" "hooks/freeze-guard.sh" || fail "freeze-guard.sh missing path normalization"
```

## Category: Audit Trail (Feature 7)

```bash
# T7.1: audit-log.sh utility exists (underscore prefix per pre-mortem PM2)
[[ -f "hooks/_audit-log.sh" ]] || [[ -f "hooks/audit-log.sh" ]] || fail "Missing audit-log.sh utility"

# T7.2: audit-log.sh uses jq for JSON construction (or has jq fallback)
audit_file=$(ls hooks/*audit-log.sh 2>/dev/null | head -1)
if [[ -n "$audit_file" ]]; then
    grep -q "jq" "$audit_file" || fail "audit-log.sh should use jq for safe JSON construction"
fi

# T7.3: audit-log.sh uses git rev-parse for project root (not $CLAUDE_PROJECT_DIR)
if [[ -n "$audit_file" ]]; then
    grep -q "git rev-parse" "$audit_file" || fail "audit-log.sh should use git rev-parse, not \$CLAUDE_PROJECT_DIR"
    ! grep -q "CLAUDE_PROJECT_DIR" "$audit_file" || fail "audit-log.sh should not use \$CLAUDE_PROJECT_DIR"
fi

# T7.4: audit-log.sh uses UTC timestamps
if [[ -n "$audit_file" ]]; then
    grep -q 'date -u' "$audit_file" || fail "audit-log.sh should use UTC timestamps (date -u)"
fi

# T7.5: Blocking hooks source audit-log.sh (or define no-op fallback)
for hook in dangerous-commands secret-scanner protect-claude-md tdd-guardian freeze-guard; do
    if [[ -f "hooks/${hook}.sh" ]]; then
        grep -q "audit_block\|audit-log" "hooks/${hook}.sh" || fail "Hook ${hook}.sh should integrate with audit logging"
    fi
done

# T7.6: WSL2 CRLF handling in session_id extraction
if [[ -n "$audit_file" ]]; then
    grep -q "tr.*-d.*\\\\r\|tr -d '\\\\r'" "$audit_file" || fail "audit-log.sh should strip \\r for WSL2 compatibility"
fi
```

## Category: Vault Templates (Feature 4)

```bash
# T4.1: Retro vault template exists
[[ -f "commands/templates/vault-notes/retro.md" ]] || fail "Missing retro vault note template"
```

## Category: Settings Example (Cross-cutting)

```bash
# T-SET: settings-example.json is valid JSON (existing check, just verify still passes)
jq empty settings-example.json 2>/dev/null || fail "settings-example.json is invalid JSON"
```

## Category: Enforcement Lint (Cross-cutting)

```bash
# T-LINT: New commands follow enforcement tier conventions
# budget, retro, audit = Utility tier ("Use when...")
# freeze = Safety tier (should block edits)
# evolve = Utility tier ("Use when...")
for cmd in budget retro audit evolve; do
    desc=$(grep "^description:" "commands/${cmd}.md" | head -1)
    echo "$desc" | grep -qi "use when\|use after\|use to" || fail "Command ${cmd}.md description should use Utility tier language"
done
```

## Manual Verification Checklist

These cannot be automated in test.sh — require a Claude Code session:

- [ ] `SAIL_DISABLED_HOOKS=dangerous-commands claude` → dangerous-commands hook does not fire
- [ ] `/freeze src/auth` → writes to `.claude/frozen-dirs.json` with absolute path
- [ ] Edit a file in `src/auth/` → blocked with feedback message
- [ ] `/unfreeze src/auth` → removes the entry
- [ ] `/budget` → displays session history (or "no data" gracefully)
- [ ] `/budget threshold 50` → writes to `.claude/budget-config.json`
- [ ] `/retro` → produces structured output from available data sources
- [ ] `/retro --days 1` → filters to last 24 hours
- [ ] `/evolve` → reads error/success logs, groups patterns
- [ ] `/audit` → displays audit entries (or "no entries" gracefully)
- [ ] `/audit --hook dangerous-commands` → filters by hook name
- [ ] Hook block (e.g., `rm -rf /`) → produces entry in `.claude/audit.jsonl`
