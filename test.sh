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

if bash -n "$SCRIPT_DIR/scripts/epistemic-marker.sh" 2>/dev/null; then
    pass "epistemic-marker.sh"
else
    fail "epistemic-marker.sh — syntax error"
fi

echo ""

# ─── 2. Shellcheck ────────────────────────────────────────────────

bold "2. Shellcheck"

if command -v shellcheck &>/dev/null; then
    for f in "$SCRIPT_DIR"/hooks/*.sh "$SCRIPT_DIR"/install.sh "$SCRIPT_DIR"/scripts/epistemic-marker.sh; do
        [ -f "$f" ] || continue
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
CMD_EXPECTED=65
AGENT_EXPECTED=12
HOOK_EXPECTED=20
HOOKIFY_EXPECTED=7
STOCK_HOOK_EXPECTED=6
STOCK_AGENT_EXPECTED=3
STOCK_CMD_EXPECTED=3
STOCK_AP_EXPECTED=4

CMD_ACTUAL=$(ls "$SCRIPT_DIR"/commands/*.md 2>/dev/null | grep -v README | wc -l)
AGENT_ACTUAL=$(ls "$SCRIPT_DIR"/agents/*.md 2>/dev/null | wc -l)
HOOK_ACTUAL=$(ls "$SCRIPT_DIR"/hooks/*.sh 2>/dev/null | wc -l)
HOOKIFY_ACTUAL=$(ls "$SCRIPT_DIR"/hookify-rules/*.local.md 2>/dev/null | wc -l)
STOCK_HOOK_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-hooks/*.md 2>/dev/null | wc -l)
STOCK_AGENT_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-agents/*.md 2>/dev/null | wc -l)
STOCK_CMD_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-commands/*.md 2>/dev/null | wc -l)
STOCK_PIPELINE_EXPECTED=4
STOCK_PIPELINE_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-pipelines/*.yaml 2>/dev/null | wc -l)
STOCK_AP_ACTUAL=$(ls "$SCRIPT_DIR"/commands/templates/stock-anti-patterns/*.md 2>/dev/null | wc -l)
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
check_count "Stock anti-patterns" "$STOCK_AP_ACTUAL" "$STOCK_AP_EXPECTED"

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

# Wizard structural section checks
WIZARD_FILES="blueprint.md prism.md clarify.md review.md test.md research.md"
WIZARD_SECTIONS="Cognitive Traps:Failure Modes|What Could Fail:Known Limitations:vault-config.sh"

wizard_ok=true
IFS=':' read -ra SECTIONS <<< "$WIZARD_SECTIONS"
for wf in $WIZARD_FILES; do
    filepath="$SCRIPT_DIR/commands/$wf"
    [ -f "$filepath" ] || { fail "Wizard file missing: $wf"; wizard_ok=false; continue; }
    for section in "${SECTIONS[@]}"; do
        if ! grep -qE "$section" "$filepath"; then
            fail "$wf — missing required wizard section: $section"
            wizard_ok=false
        fi
    done
done
if $wizard_ok; then
    pass "All wizard commands have required structural sections"
fi

# Check all wizard commands reference state management
for wizard in prism review test clarify research; do
    grep -q "wizards/" "$SCRIPT_DIR/commands/${wizard}.md" || warn "${wizard}.md missing wizard state reference"
done

# Check all wizard commands have stage progression display
for wizard in prism review test clarify research; do
    grep -q '✓' "$SCRIPT_DIR/commands/${wizard}.md" && grep -q '→' "$SCRIPT_DIR/commands/${wizard}.md" && grep -q '○' "$SCRIPT_DIR/commands/${wizard}.md" \
        || warn "${wizard}.md missing stage progression markers"
done

# Check all wizard commands have resume protocol
for wizard in prism review test clarify research; do
    grep -q 'Resume' "$SCRIPT_DIR/commands/${wizard}.md" && grep -q 'Abandon' "$SCRIPT_DIR/commands/${wizard}.md" \
        || warn "${wizard}.md missing resume/abandon protocol"
done

# /research description must NOT contain MUST or REQUIRED (tier 2.5)
if [ -f "$SCRIPT_DIR/commands/research.md" ]; then
    research_desc=$(grep "^description:" "$SCRIPT_DIR/commands/research.md" || true)
    if echo "$research_desc" | grep -qiE "MUST|REQUIRED|STOP"; then
        fail "research.md — description uses process-critical language (should be tier 2.5)"
    else
        pass "research.md — description uses correct tier 2.5 language"
    fi
else
    fail "research.md — file does not exist"
fi

# /clarify description must start with DEPRECATED:
if [ -f "$SCRIPT_DIR/commands/clarify.md" ]; then
    clarify_desc=$(grep "^description:" "$SCRIPT_DIR/commands/clarify.md" | sed 's/^description: *//;s/^"//;s/"$//' || true)
    if echo "$clarify_desc" | grep -q "^DEPRECATED:"; then
        pass "clarify.md — description starts with DEPRECATED:"
    else
        fail "clarify.md — description does not start with DEPRECATED:"
    fi
else
    fail "clarify.md — file does not exist"
fi

# Research command structural checks
if [ -f "$SCRIPT_DIR/commands/research.md" ]; then
    # Check research.md exists (explicit pass)
    pass "commands/research.md exists"

    # Topic sanitization reference
    if grep -qiE "sanitiz|slug" "$SCRIPT_DIR/commands/research.md"; then
        pass "research.md — references topic sanitization"
    else
        fail "research.md — missing topic sanitization reference (sanitiz/slug)"
    fi

    # Overwrite handling reference
    if grep -qiE "already exists|overwrite|conflict" "$SCRIPT_DIR/commands/research.md"; then
        pass "research.md — references overwrite handling"
    else
        fail "research.md — missing overwrite handling reference"
    fi

    # Multi-session handling reference
    if grep -qiE "multiple|list all" "$SCRIPT_DIR/commands/research.md"; then
        pass "research.md — references multi-session handling"
    else
        fail "research.md — missing multi-session handling reference"
    fi
else
    fail "commands/research.md does not exist"
fi

# docs/OPTIONAL-ENRICHMENT.md exists
if [ -f "$SCRIPT_DIR/docs/OPTIONAL-ENRICHMENT.md" ]; then
    pass "docs/OPTIONAL-ENRICHMENT.md exists"
else
    fail "docs/OPTIONAL-ENRICHMENT.md does not exist"
fi

# NOTE: Behavioral evals for research-pipeline (E-NEW-1 through E-NEW-4)
# are planned but require fixture files to be created separately.
# See .claude/plans/research-pipeline/tests.md for fixture specs.

# Anti-pattern catalog frontmatter validation (AC7)
ap_required="id language severity status detection_regex first_seen recent_window_days"
for entry in "$SCRIPT_DIR"/.claude/anti-patterns/*.md \
             "$SCRIPT_DIR"/commands/templates/stock-anti-patterns/*.md; do
    [ -f "$entry" ] || continue
    base=$(basename "$entry")
    [ "$base" = "SCHEMA.md" ] && continue
    rel=$(echo "$entry" | sed "s|$SCRIPT_DIR/||")

    missing=""
    for field in $ap_required; do
        # Match field at start-of-line in frontmatter; bounded by next ---
        if ! awk -v f="$field" '
            /^---$/{c++; if(c>=2)exit}
            c==1 && index($0, f":") == 1 { found=1; exit }
            END{exit found?0:1}
        ' "$entry"; then
            missing="$missing $field"
        fi
    done
    if [ -z "$missing" ]; then
        pass "$rel — frontmatter complete"
    else
        fail "$rel — missing required field(s):$missing"
    fi

    # filename must equal id field
    declared_id=$(awk '/^---$/{c++; if(c>=2)exit} c==1 && index($0,"id:")==1{
        sub(/^id:[[:space:]]*/,""); print; exit
    }' "$entry")
    expected_id="${base%.md}"
    if [ "$declared_id" = "$expected_id" ]; then
        : # already accounted for above
    else
        fail "$rel — id field '$declared_id' does not match filename '$expected_id'"
    fi
done

# AC6: stock SCHEMA.md exists and is ≤80 lines
SCHEMA_FILE="$SCRIPT_DIR/commands/templates/stock-anti-patterns/SCHEMA.md"
if [ -f "$SCHEMA_FILE" ]; then
    lines=$(wc -l < "$SCHEMA_FILE")
    if [ "$lines" -le 80 ]; then
        pass "stock SCHEMA.md exists ($lines lines, ≤80)"
    else
        fail "stock SCHEMA.md is $lines lines, expected ≤80"
    fi
    # Topic coverage (spec AC6)
    if grep -qiE "schema|frontmatter" "$SCHEMA_FILE" \
       && grep -qiE "add (a )?pattern" "$SCHEMA_FILE" \
       && grep -qiE "counter|derived" "$SCHEMA_FILE"; then
        pass "stock SCHEMA.md covers schema + add-pattern + counter topics"
    else
        fail "stock SCHEMA.md missing required topic sections"
    fi
else
    fail "stock SCHEMA.md missing"
fi

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

# AC4: All consumers must source the helper (no direct .current-session reads
# outside the helper itself + test infrastructure). Spec require ≥ 9.
helper_adoption=$(grep -rl "epistemic_get_session_id\|epistemic_marker_path\|epistemic_session_active" \
    "$SCRIPT_DIR/hooks/" "$SCRIPT_DIR/commands/" "$SCRIPT_DIR/scripts/" 2>/dev/null | wc -l)
if [ "$helper_adoption" -ge 9 ]; then
    pass "AC4: helper adopted by $helper_adoption files (>= 9 required)"
else
    fail "AC4: helper adoption only $helper_adoption files (need >= 9)"
fi

# AC4 second check: no direct .current-session reads outside the helper +
# test scripts. Excludes .bak/.md/legacy/migration/README per spec.
direct_reads=$(grep -rln '\.current-session\b' \
    "$SCRIPT_DIR/hooks/" "$SCRIPT_DIR/commands/" "$SCRIPT_DIR/scripts/" 2>/dev/null \
    | grep -v "\.bak\|legacy\|migration\|README\|\.md$" \
    | grep -v "scripts/epistemic-marker.sh\|scripts/epistemic-smoke-test.sh" || true)
if [ -z "$direct_reads" ]; then
    pass "AC4: no direct .current-session reads outside helper + test"
else
    fail "AC4: direct .current-session reads found (should use helper):"
    echo "$direct_reads" | while read -r f; do echo "       $f"; done
fi

# epistemic-marker.sh is sourced by hooks — same fail-open contract applies.
if [ -f "$SCRIPT_DIR/scripts/epistemic-marker.sh" ]; then
    if grep -E "^[[:space:]]*set -e" "$SCRIPT_DIR/scripts/epistemic-marker.sh" 2>/dev/null | grep -v "set -eo\|set -eu\|set +e" | grep -q .; then
        fail "scripts/epistemic-marker.sh contains 'set -e' (sourced by fail-open hooks)"
    else
        pass "scripts/epistemic-marker.sh has no 'set -e' (sourced by fail-open hooks)"
    fi
    if grep -q "^set +e" "$SCRIPT_DIR/scripts/epistemic-marker.sh" 2>/dev/null; then
        pass "scripts/epistemic-marker.sh has explicit 'set +e'"
    else
        warn "scripts/epistemic-marker.sh missing explicit 'set +e'"
    fi
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

    # Validate wizard state.json files if any exist
    # Note: validates JSON syntax only. Schema structure relies on Content Contracts.
    for f in "$SCRIPT_DIR"/.claude/wizards/*/state.json; do
        [ -f "$f" ] || continue
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
    [ -d "$FAKE_HOME/.claude/commands/templates/stock-anti-patterns" ] && pass "stock-anti-patterns/ installed" || fail "stock-anti-patterns/ missing"
    installed_ap=$(ls "$FAKE_HOME/.claude/commands/templates/stock-anti-patterns/"*.md 2>/dev/null | wc -l)
    check_count "Installed stock anti-patterns" "$installed_ap" "$STOCK_AP_EXPECTED"

    # Check hooks are executable
    non_exec=$(find "$FAKE_HOME/.claude/hooks" -name "*.sh" ! -executable 2>/dev/null | wc -l)
    if [ "$non_exec" -eq 0 ]; then
        pass "All hooks are executable"
    else
        fail "$non_exec hooks not executable"
    fi

    # Verify epistemic-marker.sh helper landed and is sourceable.
    if [ -f "$FAKE_HOME/.claude/scripts/epistemic-marker.sh" ]; then
        pass "scripts/epistemic-marker.sh installed"
        if (
            set +e
            source "$FAKE_HOME/.claude/scripts/epistemic-marker.sh" 2>/dev/null
            type epistemic_get_session_id >/dev/null 2>&1 \
              && type epistemic_marker_path >/dev/null 2>&1 \
              && type epistemic_session_active >/dev/null 2>&1 \
              && type epistemic_sweep_orphans >/dev/null 2>&1 \
              && type epistemic_write_marker >/dev/null 2>&1 \
              && type epistemic_claude_main_pid >/dev/null 2>&1
        ); then
            pass "epistemic-marker.sh exposes all 6 required functions"
        else
            fail "epistemic-marker.sh missing one or more required functions"
        fi
    else
        fail "scripts/epistemic-marker.sh missing from install"
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

# ─── 8.5 Epistemic Marker End-to-End ──────────────────────────────

bold "8.5 Epistemic Marker End-to-End"

if [ -f "$SCRIPT_DIR/scripts/epistemic-smoke-test.sh" ] && command -v jq &>/dev/null; then
    smoke_exit=0
    smoke_output=$(bash "$SCRIPT_DIR/scripts/epistemic-smoke-test.sh" 2>&1) || smoke_exit=$?
    smoke_summary=$(echo "$smoke_output" | grep -E "Smoke Test: [0-9]+ passed, [0-9]+ failed")
    if [ "$smoke_exit" -ne 0 ]; then
        fail "Epistemic smoke test failed"
        echo "$smoke_output" | tail -30
    else
        pass "$smoke_summary"
    fi
else
    if ! [ -f "$SCRIPT_DIR/scripts/epistemic-smoke-test.sh" ]; then
        warn "scripts/epistemic-smoke-test.sh not found — skipping"
    elif ! command -v jq &>/dev/null; then
        warn "jq not installed — skipping epistemic smoke test"
    fi
fi

echo ""

# ─── 9. Anti-Pattern Sweep Live Tests ────────────────────────────

bold "9. Anti-Pattern Sweep Live Behavior"

# Relax strict mode inside this section — fixture commands are allowed
# to return non-zero (e.g. grep finding no match) without halting the run.
set +eo pipefail

if [ -f "$SCRIPT_DIR/scripts/anti-pattern-sweep.sh" ] && command -v jq &>/dev/null; then
    AP_TMP=$(mktemp -d)
    # Materialize a minimal toolkit-shaped repo with the catalog
    git init -q "$AP_TMP" 2>/dev/null
    mkdir -p "$AP_TMP/.claude/anti-patterns" "$AP_TMP/scripts" "$AP_TMP/src"
    cp "$SCRIPT_DIR/.claude/anti-patterns/"*.md "$AP_TMP/.claude/anti-patterns/" 2>/dev/null
    cp "$SCRIPT_DIR/scripts/anti-pattern-sweep.sh" "$AP_TMP/scripts/"

    # Drop a known-bad fixture into a non-excluded source path
    cat > "$AP_TMP/src/sample.sh" <<'EOF'
#!/usr/bin/env bash
jq '.' input.json > "$TMP" && mv "$TMP" "$FILE"
EOF
    ( cd "$AP_TMP" && git add -A && git commit -q -m seed 2>/dev/null )

    # AC2 — sweep detects fixture_bad
    ( cd "$AP_TMP" && bash scripts/anti-pattern-sweep.sh --full ) >/dev/null 2>&1
    if [ -f "$AP_TMP/.claude/anti-patterns/.events.jsonl" ] \
       && grep -F '"id":"bash-unsafe-atomic-write"' "$AP_TMP/.claude/anti-patterns/.events.jsonl" \
            | grep -F '"file":"src/sample.sh"' >/dev/null; then
        pass "AC2: sweep records detection event for fixture_bad"
    else
        fail "AC2: no detection event for known fixture_bad"
    fi

    # AC11 — heartbeat written
    if [ -f "$AP_TMP/.claude/anti-patterns/.last-sweep.json" ] \
       && jq -e '.timestamp and .events_appended != null and .duration_ms != null and .mode' \
            "$AP_TMP/.claude/anti-patterns/.last-sweep.json" >/dev/null 2>&1; then
        pass "AC11: heartbeat written with required fields"
    else
        fail "AC11: heartbeat missing or incomplete"
    fi

    # AC3 — idempotency: counters identical across two runs
    snap1=$(for f in "$AP_TMP/.claude/anti-patterns/"*.md; do
        [ "$(basename "$f")" = "SCHEMA.md" ] && continue
        id=$(basename "$f" .md)
        th=$(awk '/^---$/{c++; if(c>=2)exit} c==1 && /^total_hits:/{sub(/^[^:]+:[ \t]*/,""); print; exit}' "$f")
        echo "$id $th"
    done | sort)
    ( cd "$AP_TMP" && bash scripts/anti-pattern-sweep.sh --full ) >/dev/null 2>&1
    snap2=$(for f in "$AP_TMP/.claude/anti-patterns/"*.md; do
        [ "$(basename "$f")" = "SCHEMA.md" ] && continue
        id=$(basename "$f" .md)
        th=$(awk '/^---$/{c++; if(c>=2)exit} c==1 && /^total_hits:/{sub(/^[^:]+:[ \t]*/,""); print; exit}' "$f")
        echo "$id $th"
    done | sort)
    if [ "$snap1" = "$snap2" ]; then
        pass "AC3: sweep is idempotent (counters stable across runs)"
    else
        fail "AC3: counters changed between sweeps"
    fi

    # AC13 — dedup by (id, file, line)
    sample_evt=$(tail -1 "$AP_TMP/.claude/anti-patterns/.events.jsonl")
    sample_id=$(echo "$sample_evt" | jq -r .id)
    before=$(awk '/^---$/{c++; if(c>=2)exit} c==1 && /^total_hits:/{sub(/^[^:]+:[ \t]*/,""); print; exit}' \
        "$AP_TMP/.claude/anti-patterns/$sample_id.md")
    echo "$sample_evt" | jq -c '.ts = (now | todateiso8601)' \
        >> "$AP_TMP/.claude/anti-patterns/.events.jsonl"
    ( cd "$AP_TMP" && bash scripts/anti-pattern-sweep.sh --full ) >/dev/null 2>&1
    after=$(awk '/^---$/{c++; if(c>=2)exit} c==1 && /^total_hits:/{sub(/^[^:]+:[ \t]*/,""); print; exit}' \
        "$AP_TMP/.claude/anti-patterns/$sample_id.md")
    if [ "$before" = "$after" ]; then
        pass "AC13: counter regen dedupes by (id, file, line)"
    else
        fail "AC13: counter changed on duplicate event ($before → $after)"
    fi

    # AC9 — fail-open without vault
    rm -f "$AP_TMP/.claude/anti-patterns/.events.jsonl" "$AP_TMP/.claude/anti-patterns/.last-sweep.json"
    if (cd "$AP_TMP" && unset VAULT_ENABLED VAULT_PATH; bash scripts/anti-pattern-sweep.sh --full) >/dev/null 2>&1 \
       && [ -f "$AP_TMP/.claude/anti-patterns/.events.jsonl" ]; then
        pass "AC9: sweep succeeds without vault"
    else
        fail "AC9: sweep failed when vault unavailable"
    fi

    # AC8 — corrupted regex doesn't break sweep (fail-open)
    sed -i.bak "s/^detection_regex:.*/detection_regex: '['/" \
        "$AP_TMP/.claude/anti-patterns/bash-unsafe-atomic-write.md" 2>/dev/null
    rc=0
    (cd "$AP_TMP" && bash scripts/anti-pattern-sweep.sh --session) >/dev/null 2>&1 || rc=$?
    if [ "$rc" -eq 0 ]; then
        pass "AC8: sweep exits 0 on corrupted regex (fail-open)"
    else
        fail "AC8: sweep returned $rc on corrupted regex (expected 0)"
    fi

    # Cleanup
    rm -rf "$AP_TMP"

    # AC14 form-1: hook emits valid additionalContext JSON on matching content
    if [ -f "$SCRIPT_DIR/hooks/anti-pattern-write-check.sh" ]; then
        AP_HOOK_TMP=$(mktemp -d)
        mkdir -p "$AP_HOOK_TMP/.claude/anti-patterns"
        cp "$SCRIPT_DIR/.claude/anti-patterns/"*.md "$AP_HOOK_TMP/.claude/anti-patterns/"
        ( cd "$AP_HOOK_TMP" && git init -q )
        fixture=$(awk '/^fixture_bad: \|$/{flag=1;next}/^[a-z_]+:/{flag=0}flag' \
            "$SCRIPT_DIR/.claude/anti-patterns/bash-unsafe-atomic-write.md")
        mock_input=$(jq -nc --arg c "$fixture" --arg p "src/test.sh" \
            '{tool_input: {content: $c, file_path: $p}}')
        stdout=$(cd "$AP_HOOK_TMP" && echo "$mock_input" | \
            bash "$SCRIPT_DIR/hooks/anti-pattern-write-check.sh" 2>/dev/null)
        if echo "$stdout" \
            | jq -e '.hookSpecificOutput.permissionDecision == "allow" and
                     (.hookSpecificOutput.additionalContext | test("Catalog:[[:space:]]*bash-unsafe-atomic-write"))' \
            >/dev/null 2>&1; then
            pass "AC14 form-1: hook emits additionalContext with Catalog citation"
        else
            fail "AC14 form-1: hook output missing or malformed: $stdout"
        fi
        rm -rf "$AP_HOOK_TMP"
    else
        warn "anti-pattern-write-check.sh not found, skipping AC14 form-1"
    fi
else
    warn "Anti-pattern sweep tests skipped (script or jq missing)"
fi

# Restore strict mode for the summary
set -eo pipefail

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
