#!/bin/bash
#
# Claude Sail — Automated Verification Suite
# Validates distribution integrity: counts, syntax, conventions, install
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PASS=0
FAIL=0
WARN=0

green() { echo -e "\033[0;32m$1\033[0m"; }
red()   { echo -e "\033[0;31m$1\033[0m"; }
yellow(){ echo -e "\033[1;33m$1\033[0m"; }
bold()  { echo -e "\033[1m$1\033[0m"; }

pass() { PASS=$((PASS + 1)); echo "  $(green "✓") $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  $(red "✗") $1"; }
warn() { WARN=$((WARN + 1)); echo "  $(yellow "⚠") $1"; }

# ─── 1. Shell Syntax ──────────────────────────────────────────────

bold "1. Shell Syntax (bash -n)"

for f in "$SCRIPT_DIR"/hooks/*.sh; do
    name=$(basename "$f")
    if bash -n "$f" 2>/dev/null; then
        pass "$name"
    else
        fail "$name — syntax error"
    fi
done

if bash -n "$SCRIPT_DIR/install.sh" 2>/dev/null; then
    pass "install.sh"
else
    fail "install.sh — syntax error"
fi

if bash -n "$SCRIPT_DIR/scripts/behavioral-smoke.sh" 2>/dev/null; then
    pass "behavioral-smoke.sh"
else
    fail "behavioral-smoke.sh — syntax error"
fi

echo ""

# ─── 2. Shellcheck ────────────────────────────────────────────────

bold "2. Shellcheck"

if command -v shellcheck &>/dev/null; then
    for f in "$SCRIPT_DIR"/hooks/*.sh "$SCRIPT_DIR"/install.sh; do
        name=$(basename "$f")
        if shellcheck -S warning "$f" >/dev/null 2>&1; then
            pass "$name"
        else
            issues=$(shellcheck -S warning "$f" 2>&1 | grep -c "^In " || true)
            warn "$name — $issues warning(s)"
        fi
    done
else
    warn "shellcheck not installed — skipping (install: apt install shellcheck)"
fi

echo ""

# ─── 3. File Count Verification ───────────────────────────────────

bold "3. File Counts (vs README claims)"

# Expected counts from README.md
CMD_EXPECTED=62
AGENT_EXPECTED=6
HOOK_EXPECTED=19
HOOKIFY_EXPECTED=7
STOCK_HOOK_EXPECTED=6
STOCK_AGENT_EXPECTED=3
STOCK_CMD_EXPECTED=3

CMD_ACTUAL=$(ls "$SCRIPT_DIR"/commands/*.md 2>/dev/null | grep -v README | wc -l)
AGENT_ACTUAL=$(ls "$SCRIPT_DIR"/agents/*.md 2>/dev/null | wc -l)
HOOK_ACTUAL=$(ls "$SCRIPT_DIR"/hooks/*.sh 2>/dev/null | wc -l)
HOOKIFY_ACTUAL=$(ls "$SCRIPT_DIR"/hookify-rules/*.local.md 2>/dev/null | wc -l)
STOCK_HOOK_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-hooks/*.md 2>/dev/null | wc -l)
STOCK_AGENT_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-agents/*.md 2>/dev/null | wc -l)
STOCK_CMD_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-commands/*.md 2>/dev/null | wc -l)
STOCK_PIPELINE_EXPECTED=4
STOCK_PIPELINE_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-pipelines/*.yaml 2>/dev/null | wc -l)
STOCK_TOTAL=$((STOCK_HOOK_ACTUAL + STOCK_AGENT_ACTUAL + STOCK_CMD_ACTUAL))

check_count() {
    local label=$1 actual=$2 expected=$3
    if [ "$actual" -eq "$expected" ]; then
        pass "$label: $actual (expected $expected)"
    else
        fail "$label: $actual (expected $expected)"
    fi
}

check_count "Commands" "$CMD_ACTUAL" "$CMD_EXPECTED"
check_count "Agents" "$AGENT_ACTUAL" "$AGENT_EXPECTED"
check_count "Shell hooks" "$HOOK_ACTUAL" "$HOOK_EXPECTED"
check_count "Hookify rules" "$HOOKIFY_ACTUAL" "$HOOKIFY_EXPECTED"
check_count "Stock hooks" "$STOCK_HOOK_ACTUAL" "$STOCK_HOOK_EXPECTED"
check_count "Stock agents" "$STOCK_AGENT_ACTUAL" "$STOCK_AGENT_EXPECTED"
check_count "Stock commands" "$STOCK_CMD_ACTUAL" "$STOCK_CMD_EXPECTED"
check_count "Stock total" "$STOCK_TOTAL" 12
check_count "Stock pipelines" "$STOCK_PIPELINE_ACTUAL" "$STOCK_PIPELINE_EXPECTED"

echo ""

# ─── 4. Enforcement Lint ──────────────────────────────────────────

bold "4. Enforcement Lint"

# No escape-hatch language in command descriptions
escape_matches=$(grep -rn "^description:.*\(consider\|might\|optionally\)" "$SCRIPT_DIR"/commands/ 2>/dev/null || true)
if [ -z "$escape_matches" ]; then
    pass "No escape-hatch language in descriptions"
else
    fail "Escape-hatch language found:"
    echo "$escape_matches" | while read -r line; do echo "       $line"; done
fi

# All commands have description field
for f in "$SCRIPT_DIR"/commands/*.md; do
    name=$(basename "$f")
    [ "$name" = "README.md" ] && continue
    if grep -q "^description:" "$f"; then
        : # silent pass
    else
        fail "$name — missing description field"
    fi
done
pass "All commands have description field"

# All agents have required frontmatter
for f in "$SCRIPT_DIR"/agents/*.md; do
    name=$(basename "$f")
    missing=""
    grep -q "^name:" "$f" || missing="name "
    grep -q "^description:" "$f" || missing="${missing}description "
    grep -q "^tools:" "$f" || missing="${missing}tools"
    if [ -z "$missing" ]; then
        pass "$name — frontmatter complete"
    else
        fail "$name — missing: $missing"
    fi
done

# Stock pipeline required fields
for f in "$SCRIPT_DIR"/commands/templates/stock-pipelines/*.yaml; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    if grep -q '^name:' "$f" && grep -q '^description:' "$f" && grep -q '^steps:' "$f" && grep -q '^on-error:' "$f"; then
        pass "$name — required fields present"
    else
        fail "$name — missing required fields"
    fi
done

echo ""

# ─── 5. Hook Conventions ─────────────────────────────────────────

bold "5. Hook Conventions"

# No set -e in hooks (fail-open pattern)
set_e_hooks=$(grep -l "set -e" "$SCRIPT_DIR"/hooks/*.sh 2>/dev/null | grep -v "set -eo\|set -eu\|set +e" || true)
if [ -z "$set_e_hooks" ]; then
    pass "No 'set -e' in hooks (fail-open respected)"
else
    fail "Hooks with 'set -e' (violates fail-open):"
    echo "$set_e_hooks" | while read -r f; do echo "       $(basename "$f")"; done
fi

# Check for set +e in hooks (expected in most)
hooks_with_set_plus_e=$(grep -l "set +e" "$SCRIPT_DIR"/hooks/*.sh 2>/dev/null | wc -l)
if [ "$hooks_with_set_plus_e" -ge 10 ]; then
    pass "$hooks_with_set_plus_e/$HOOK_ACTUAL hooks have explicit 'set +e'"
else
    warn "Only $hooks_with_set_plus_e/$HOOK_ACTUAL hooks have explicit 'set +e'"
fi

# No eval in hooks (injection risk)
eval_hooks=$(grep -l "eval " "$SCRIPT_DIR"/hooks/*.sh 2>/dev/null || true)
if [ -z "$eval_hooks" ]; then
    pass "No 'eval' usage in hooks"
else
    fail "Hooks using 'eval' (injection risk):"
    echo "$eval_hooks" | while read -r f; do echo "       $(basename "$f")"; done
fi

echo ""

# ─── 6. JSON Validation ──────────────────────────────────────────

bold "6. JSON Validation"

if command -v jq &>/dev/null; then
    for f in "$SCRIPT_DIR"/settings-example.json \
             "$SCRIPT_DIR"/plugins/sail-toolkit/.claude-plugin/plugin.json; do
        name=$(echo "$f" | sed "s|$SCRIPT_DIR/||")
        if [ -f "$f" ]; then
            if jq empty "$f" 2>/dev/null; then
                pass "$name"
            else
                fail "$name — invalid JSON"
            fi
        else
            warn "$name — file not found"
        fi
    done

    # Check any other JSON files in .claude/plans/
    for f in $(find "$SCRIPT_DIR/.claude" -name "*.json" -type f 2>/dev/null | head -10); do
        name=$(echo "$f" | sed "s|$SCRIPT_DIR/||")
        if jq empty "$f" 2>/dev/null; then
            pass "$name"
        else
            fail "$name — invalid JSON"
        fi
    done
else
    warn "jq not installed — skipping JSON validation"
fi

echo ""

# ─── 7. Install Dry Run ──────────────────────────────────────────

bold "7. Install Dry Run (temp directory)"

FAKE_HOME=$(mktemp -d)
export HOME="$FAKE_HOME"

if bash "$SCRIPT_DIR/install.sh" >/dev/null 2>&1; then
    # Verify key files landed
    [ -d "$FAKE_HOME/.claude/commands" ] && pass "commands/ created" || fail "commands/ missing"
    [ -d "$FAKE_HOME/.claude/agents" ] && pass "agents/ created" || fail "agents/ missing"
    [ -d "$FAKE_HOME/.claude/hooks" ] && pass "hooks/ created" || fail "hooks/ missing"

    installed_cmds=$(ls "$FAKE_HOME/.claude/commands/"*.md 2>/dev/null | grep -v README | wc -l)
    installed_agents=$(ls "$FAKE_HOME/.claude/agents/"*.md 2>/dev/null | wc -l)
    installed_hooks=$(ls "$FAKE_HOME/.claude/hooks/"*.sh 2>/dev/null | grep -v "vault-config.sh" | wc -l)

    check_count "Installed commands" "$installed_cmds" "$CMD_EXPECTED"
    check_count "Installed agents" "$installed_agents" "$AGENT_EXPECTED"
    check_count "Installed hooks" "$installed_hooks" "$HOOK_EXPECTED"

    # Check stock elements
    [ -d "$FAKE_HOME/.claude/commands/templates/stock-hooks" ] && pass "stock-hooks/ installed" || fail "stock-hooks/ missing"
    [ -d "$FAKE_HOME/.claude/commands/templates/stock-agents" ] && pass "stock-agents/ installed" || fail "stock-agents/ missing"
    [ -d "$FAKE_HOME/.claude/commands/templates/stock-commands" ] && pass "stock-commands/ installed" || fail "stock-commands/ missing"

    # Check hooks are executable
    non_exec=$(find "$FAKE_HOME/.claude/hooks" -name "*.sh" ! -executable 2>/dev/null | wc -l)
    if [ "$non_exec" -eq 0 ]; then
        pass "All hooks are executable"
    else
        fail "$non_exec hooks not executable"
    fi
else
    fail "install.sh exited with error"
fi

rm -rf "$FAKE_HOME"

echo ""

# ─── 8. Behavioral Evals ────────────────────────────────────────

bold "8. Behavioral Evals"

if [ -f "$SCRIPT_DIR/evals/evals.json" ] && command -v jq &>/dev/null; then
    if [ -f "$SCRIPT_DIR/scripts/behavioral-smoke.sh" ]; then
        eval_exit=0
        eval_output=$(bash "$SCRIPT_DIR/scripts/behavioral-smoke.sh" 2>&1) || eval_exit=$?
        echo "$eval_output"
        if [ "$eval_exit" -ne 0 ]; then
            fail "Behavioral evals: fixtures failed"
        else
            pass "Behavioral evals: all fixtures passed"
        fi
    else
        warn "scripts/behavioral-smoke.sh not found"
    fi
else
    if ! [ -f "$SCRIPT_DIR/evals/evals.json" ]; then
        warn "evals/evals.json not found — skipping behavioral evals"
    elif ! command -v jq &>/dev/null; then
        warn "jq not installed — skipping behavioral evals"
    fi
fi

echo ""

# ─── Summary ──────────────────────────────────────────────────────

bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  $(green "$PASS passed")  $(red "$FAIL failed")  $(yellow "$WARN warnings")"
bold "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$FAIL" -gt 0 ]; then
    echo ""
    red "  Some checks failed. Fix before release."
    exit 1
fi

if [ "$WARN" -gt 0 ]; then
    echo ""
    yellow "  Passed with warnings."
    exit 0
fi

echo ""
green "  All checks passed."
exit 0
