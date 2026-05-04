#!/usr/bin/env bash
# epistemic-smoke-test.sh — Post-install verification for epistemic tracking
#
# Runs a mock session lifecycle (init → preflight hook → store preflight →
# store postflight → verify pairing) against a temporary HOME.
#
# Updated for per-claude-PID marker layout (see scripts/epistemic-marker.sh).
# Uses EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE so the helper does not depend on
# walking up to a real claude process during smoke testing.
#
# Usage: bash scripts/epistemic-smoke-test.sh
# DEV-ONLY: not part of the install path.
# Requires: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TEMP_HOME=$(mktemp -d)
export HOME="$TEMP_HOME"

# Use a fake claude main PID so the helper can resolve in any test context.
# Pick a PID that's almost certainly not in /proc.
export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=987654321

pass() { echo "  ✓ $1"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ $1"; FAIL=$((FAIL + 1)); }

cleanup() {
    # Guards: non-empty, not root, end-of-options. Catalog: bash-rm-rf-with-variable.
    [ -n "$TEMP_HOME" ] && [ "$TEMP_HOME" != "/" ] && rm -rf -- "$TEMP_HOME"
}
trap cleanup EXIT

echo "=== Epistemic Tracking Smoke Test ==="
echo "Temp HOME: $TEMP_HOME"
echo "Override claude main PID: $EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE"
echo ""

# ── Guard ────────────────────────────────────────────────────
if ! command -v jq &>/dev/null; then
    echo "ERROR: jq required but not found"
    exit 1
fi

# Source helper for assertions
# shellcheck disable=SC1091
source "$REPO_ROOT/scripts/epistemic-marker.sh"

# ── 1. Init ──────────────────────────────────────────────────
echo "Phase 1: Initialization"

bash "$REPO_ROOT/scripts/epistemic-init.sh" >/dev/null 2>&1
if [ -s "$HOME/.claude/epistemic.json" ] && \
   jq -e '.schema_version == 1' "$HOME/.claude/epistemic.json" >/dev/null 2>&1; then
    pass "Init creates valid epistemic.json"
else
    fail "Init failed to create valid epistemic.json"
fi

VECTOR_COUNT=$(jq '.calibration | keys | length' "$HOME/.claude/epistemic.json" 2>/dev/null)
if [ "$VECTOR_COUNT" = "13" ]; then
    pass "All 13 vectors present in calibration"
else
    fail "Expected 13 vectors, got $VECTOR_COUNT"
fi

echo ""

# ── 2. SessionStart Hook (per-claude-PID layout) ──────────────
echo "Phase 2: SessionStart Hook"

mkdir -p "$TEMP_HOME/test-project/.git"
cd "$TEMP_HOME/test-project"
git init -q 2>/dev/null

TEST_SID="11111111-2222-4333-9444-555555555555"
echo "{\"session_id\":\"$TEST_SID\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
    | EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=$EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE \
      bash "$REPO_ROOT/hooks/epistemic-preflight.sh" 2>/dev/null

if [ -d "$HOME/.claude/.current-session" ]; then
    pass "SessionStart creates marker directory (per-claude-PID layout)"
else
    fail "SessionStart should create marker directory"
fi

MARKER_FILE="$HOME/.claude/.current-session/$EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE"
if [ -s "$MARKER_FILE" ]; then
    pass "Per-claude-PID marker file present"
else
    fail "Per-claude-PID marker file missing at $MARKER_FILE"
fi

SESSION_ID=$(epistemic_get_session_id 2>/dev/null)
if [ "$SESSION_ID" = "$TEST_SID" ]; then
    pass "Session ID matches stdin: ${SESSION_ID:0:8}..."
else
    fail "Session ID mismatch: expected $TEST_SID, got $SESSION_ID"
fi

echo ""

# ── 3. Preflight Vector Storage ──────────────────────────────
echo "Phase 3: Preflight Vector Storage"

jq --arg id "$SESSION_ID" --arg project "test-project" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '
   .sessions += [{
     id: $id, project: $project, timestamp: $ts,
     preflight: {
       engagement: 0.8, know: 0.5, do: 0.6, context: 0.7,
       clarity: 0.8, coherence: 0.7, signal: 0.6, density: 0.5,
       state: 0.6, change: 0.3, completion: 0.1, impact: 0.7,
       uncertainty: 0.4
     },
     postflight: null, deltas: null, task_summary: "", paired: false
   }] | .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ' "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
   mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"

PREFLIGHT_COUNT=$(jq --arg id "$SESSION_ID" \
    '[.sessions[] | select(.id == $id) | .preflight | keys[]] | length' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

if [ "$PREFLIGHT_COUNT" = "13" ]; then
    pass "Preflight stores all 13 vectors"
else
    fail "Expected 13 preflight vectors, got $PREFLIGHT_COUNT"
fi

echo ""

# ── 4. Postflight + Delta Computation ────────────────────────
echo "Phase 4: Postflight + Delta Computation"

jq --arg id "$SESSION_ID" \
   '
   (.sessions[] | select(.id == $id)) as $session |
   $session.preflight as $pre |
   {
     engagement: (0.85 - $pre.engagement),
     know: (0.7 - $pre.know),
     do: (0.8 - $pre.do),
     context: (0.75 - $pre.context),
     clarity: (0.85 - $pre.clarity),
     coherence: (0.75 - $pre.coherence),
     signal: (0.7 - $pre.signal),
     density: (0.65 - $pre.density),
     state: (0.75 - $pre.state),
     change: (0.6 - $pre.change),
     completion: (0.5 - $pre.completion),
     impact: (0.75 - $pre.impact),
     uncertainty: (0.2 - $pre.uncertainty)
   } as $deltas |

   .sessions = [.sessions[] |
     if .id == $id then
       .postflight = {
         engagement: 0.85, know: 0.7, do: 0.8, context: 0.75,
         clarity: 0.85, coherence: 0.75, signal: 0.7, density: 0.65,
         state: 0.75, change: 0.6, completion: 0.5, impact: 0.75,
         uncertainty: 0.2
       } |
       .deltas = $deltas |
       .paired = true |
       .task_summary = "Smoke test session"
     else . end
   ] |

   reduce ("engagement","know","do","context","clarity","coherence","signal","density","state","change","completion","impact","uncertainty") as $v (
     .;
     .calibration[$v].last_deltas = ((.calibration[$v].last_deltas + [$deltas[$v]]) | .[-50:]) |
     .calibration[$v].observation_count = ([.calibration[$v].last_deltas[] | select(. != null)] | length) |
     .calibration[$v].rolling_mean_delta = (
       [.calibration[$v].last_deltas[] | select(. != null) | tonumber] |
       if length == 0 then 0 else add / length end
     ) |
     .calibration[$v].correction = (
       .calibration[$v].rolling_mean_delta |
       if . > 0.25 then 0.25 elif . < -0.25 then -0.25 else . end
     )
   ) |
   .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ' "$HOME/.claude/epistemic.json" > "$HOME/.claude/epistemic.json.tmp" && \
   mv "$HOME/.claude/epistemic.json.tmp" "$HOME/.claude/epistemic.json"

IS_PAIRED=$(jq --arg id "$SESSION_ID" \
    '.sessions[] | select(.id == $id) | .paired' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

if [ "$IS_PAIRED" = "true" ]; then
    pass "Session paired after postflight"
else
    fail "Session should be paired, got paired=$IS_PAIRED"
fi

HAS_DELTAS=$(jq --arg id "$SESSION_ID" \
    '.sessions[] | select(.id == $id) | .deltas | length > 0' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

if [ "$HAS_DELTAS" = "true" ]; then
    pass "Deltas computed for all vectors"
else
    fail "Deltas should be present after pairing"
fi

KNOW_DELTA=$(jq --arg id "$SESSION_ID" \
    '.sessions[] | select(.id == $id) | .deltas.know' \
    "$HOME/.claude/epistemic.json" 2>/dev/null)

KNOW_CORRECT=$(echo "$KNOW_DELTA" | awk '{ print ($1 > 0.19 && $1 < 0.21) ? "true" : "false" }')
if [ "$KNOW_CORRECT" = "true" ]; then
    pass "know delta = $KNOW_DELTA (expected ~0.2)"
else
    fail "know delta = $KNOW_DELTA (expected ~0.2)"
fi

echo ""

# ── 5. Calibration State ────────────────────────────────────
echo "Phase 5: Calibration State"

OBS_COUNT=$(jq '.calibration.know.observation_count' "$HOME/.claude/epistemic.json" 2>/dev/null)
if [ "$OBS_COUNT" = "1" ]; then
    pass "Observation count incremented to 1"
else
    fail "Expected observation_count=1, got $OBS_COUNT"
fi

CORRECTION=$(jq '.calibration.know.correction' "$HOME/.claude/epistemic.json" 2>/dev/null)
IN_BOUNDS=$(echo "$CORRECTION" | awk '{ print ($1 >= -0.25 && $1 <= 0.25) ? "true" : "false" }')
if [ "$IN_BOUNDS" = "true" ]; then
    pass "Correction within ±0.25 bounds ($CORRECTION)"
else
    fail "Correction out of bounds: $CORRECTION"
fi

echo ""

# ── 6. Fail-Open Verification ───────────────────────────────
echo "Phase 6: Fail-Open Verification"

# Remove epistemic.json and verify hook still exits 0
rm -f "$HOME/.claude/epistemic.json"
echo "{\"session_id\":\"$TEST_SID\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
    | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" 2>/dev/null
if [ $? -eq 0 ]; then
    pass "SessionStart exits 0 with missing epistemic.json"
else
    fail "SessionStart should exit 0 even without epistemic.json"
fi

# 0-byte file
touch "$HOME/.claude/epistemic.json"
echo "{\"session_id\":\"$TEST_SID\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
    | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" 2>/dev/null
if [ $? -eq 0 ]; then
    pass "SessionStart exits 0 with 0-byte epistemic.json"
else
    fail "SessionStart should exit 0 with 0-byte file"
fi

# No-stdin: hook MUST still exit 0 (no marker created — by design, CF-7).
bash "$REPO_ROOT/hooks/epistemic-preflight.sh" </dev/null 2>/dev/null
if [ $? -eq 0 ]; then
    pass "SessionStart exits 0 with empty stdin (no uuidgen fallback)"
else
    fail "SessionStart should exit 0 even with empty stdin"
fi

echo ""

# ── 7. No Stale Temp Files ──────────────────────────────────
echo "Phase 7: Cleanup Verification"

if [ ! -f "$HOME/.claude/epistemic.json.tmp" ]; then
    pass "No stale .tmp files"
else
    fail "Found stale epistemic.json.tmp"
fi

# Check no stale tmpfiles in marker directory
stale_marker_tmps=$(find "$HOME/.claude/.current-session" -maxdepth 1 -name ".tmp.*" 2>/dev/null | wc -l)
if [ "$stale_marker_tmps" -eq 0 ]; then
    pass "No stale .tmp.* files in marker directory"
else
    fail "Found $stale_marker_tmps stale tmpfiles in marker directory"
fi

echo ""

# ── 8. Sweep behavior ───────────────────────────────────────
echo "Phase 8: Sweep Behavior"

# Plant a fake-PID orphan and a current-shell orphan (PID exists but comm != claude)
mkdir -p "$HOME/.claude/.current-session"
echo "SESSION_ID=fake-orphan" > "$HOME/.claude/.current-session/9999999"
echo "SESSION_ID=non-claude-pid" > "$HOME/.claude/.current-session/$$"
epistemic_sweep_orphans
if [ ! -f "$HOME/.claude/.current-session/9999999" ]; then
    pass "Sweep removed fake-PID orphan"
else
    fail "Sweep should have removed fake-PID orphan"
fi
if [ ! -f "$HOME/.claude/.current-session/$$" ]; then
    pass "Sweep removed non-claude-PID orphan (PID-reuse defense)"
else
    fail "Sweep should have removed non-claude-PID orphan"
fi
# The fake claude main PID marker should still exist after sweep
# (sweep only checks /proc for the PID — fake-PID without /proc entry is removed,
# real PID with non-claude comm is removed; "claude" comm survives.)
# Note: 987654321 is a fake PID, so it WILL be removed if sweep runs against it.
# This is correct behavior — when PID has no /proc, marker is orphaned.

echo ""

# ── 9. Parallel Isolation (AC1 + AC2) ────────────────────────
echo "Phase 9: Parallel Isolation"

# Simulate two distinct claude main PIDs writing concurrently.
# Each subshell scopes EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE so the helper
# resolves to its own fake PID, and we use unique session_ids.
SID_A="aaaaaaaa-1111-4222-8333-444444444444"
SID_B="bbbbbbbb-1111-4222-8333-444444444444"
PID_A=10001
PID_B=10002

(
    export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=$PID_A
    export EPISTEMIC_SKIP_SWEEP=1  # fake PIDs would otherwise be reaped
    echo "{\"session_id\":\"$SID_A\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
        | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" >/dev/null 2>&1
)
(
    export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=$PID_B
    export EPISTEMIC_SKIP_SWEEP=1
    echo "{\"session_id\":\"$SID_B\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
        | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" >/dev/null 2>&1
)

if [ -s "$HOME/.claude/.current-session/$PID_A" ] && [ -s "$HOME/.claude/.current-session/$PID_B" ]; then
    pass "Both per-PID markers exist (no clobber)"
else
    fail "Expected both markers to exist after parallel preflight"
fi

A_SID=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session/$PID_A" 2>/dev/null | cut -d= -f2)
B_SID=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session/$PID_B" 2>/dev/null | cut -d= -f2)
# Fail-fast: empty extraction would fall through silently otherwise.
if [ -z "$A_SID" ] || [ -z "$B_SID" ]; then
    fail "SESSION_ID extraction returned empty (A='$A_SID' B='$B_SID')"
elif [ "$A_SID" = "$SID_A" ] && [ "$B_SID" = "$SID_B" ]; then
    pass "Markers contain correct session_ids (each session sees its own)"
else
    fail "Marker contents wrong: A=$A_SID (expected $SID_A), B=$B_SID (expected $SID_B)"
fi

# AC2: Postflight reads its own marker. Simulate session A's postflight.
(
    export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=$PID_A
    # shellcheck disable=SC1091
    source "$REPO_ROOT/scripts/epistemic-marker.sh"
    READ_SID=$(epistemic_get_session_id)
    [ "$READ_SID" = "$SID_A" ] && exit 0 || exit 1
)
if [ $? -eq 0 ]; then
    pass "Session A's postflight resolves session A's session_id (not B's)"
else
    fail "Session A's postflight failed to resolve correct session_id"
fi

echo ""

# ── 10. Resume Pairing Proxy (AC3) ───────────────────────────
echo "Phase 10: Resume Pairing Proxy"

# First run: claude PID 20001 with session_id=Z. Postflight cleans marker.
# Second run: claude PID 20002 (different PID, "resumed") with same session_id=Z.
# Marker filenames differ; SESSION_ID inside is the same.
SID_RESUME="cccccccc-1111-4222-8333-444444444444"
PID_RUN1=20001
PID_RUN2=20002

(
    export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=$PID_RUN1
    export EPISTEMIC_SKIP_SWEEP=1
    echo "{\"session_id\":\"$SID_RESUME\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
        | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" >/dev/null 2>&1
)

if [ -s "$HOME/.claude/.current-session/$PID_RUN1" ]; then
    pass "Run-1 marker created"
else
    fail "Run-1 marker missing"
fi

# Simulate session ending: remove run-1 marker (postflight does this)
rm -f "$HOME/.claude/.current-session/$PID_RUN1"

# Run 2: same session_id, new claude PID, source=resume
(
    export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=$PID_RUN2
    export EPISTEMIC_SKIP_SWEEP=1
    echo "{\"session_id\":\"$SID_RESUME\",\"source\":\"resume\",\"hook_event_name\":\"SessionStart\"}" \
        | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" >/dev/null 2>&1
)

if [ -s "$HOME/.claude/.current-session/$PID_RUN2" ]; then
    pass "Run-2 marker created at new PID"
else
    fail "Run-2 marker missing"
fi

R2_SID=$(grep "^SESSION_ID=" "$HOME/.claude/.current-session/$PID_RUN2" 2>/dev/null | cut -d= -f2)
# Fail-fast: catalog bash-missing-fail-fast.
if [ -z "$R2_SID" ]; then
    fail "Run-2 SESSION_ID extraction returned empty"
elif [ "$R2_SID" = "$SID_RESUME" ]; then
    pass "Run-2 preserves session_id across resume (PID changed, identity preserved)"
else
    fail "Run-2 session_id mismatch: expected $SID_RESUME, got $R2_SID"
fi

echo ""

# ── 11. Migration (AC6) ─────────────────────────────────────
echo "Phase 11: Legacy Marker Migration"

# Reset state: remove the directory and write a legacy single-file marker
[ -n "$HOME" ] && [ "$HOME" != "/" ] && rm -rf -- "$HOME/.claude/.current-session"
LEGACY_CONTENT=$'SESSION_ID=legacy-test-session\nPROJECT=legacy-project\nSTARTED=2026-01-01T00:00:00Z'
echo "$LEGACY_CONTENT" > "$HOME/.claude/.current-session"

# Pre-check: legacy file exists as a non-directory
if [ -f "$HOME/.claude/.current-session" ] && [ ! -d "$HOME/.claude/.current-session" ]; then
    pass "Legacy single-file marker present (pre-migration)"
else
    fail "Legacy fixture setup failed"
fi

# Trigger preflight (which calls epistemic_migrate_legacy_marker)
SID_MIGRATE="dddddddd-1111-4222-8333-444444444444"
(
    export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=30001
    echo "{\"session_id\":\"$SID_MIGRATE\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
        | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" >/dev/null 2>&1
)

# Assertion: legacy file renamed with timestamp suffix
legacy_archive=$(find "$HOME/.claude" -maxdepth 1 -name ".current-session.legacy-*" 2>/dev/null | head -1)
if [ -n "$legacy_archive" ] && [ -s "$legacy_archive" ]; then
    pass "Legacy marker archived to $legacy_archive (non-destructive)"
else
    fail "Legacy archive not found after migration"
fi

# Assertion: archived content preserves original
if [ -n "$legacy_archive" ] && grep -q "SESSION_ID=legacy-test-session" "$legacy_archive" 2>/dev/null; then
    pass "Archived content preserves original session_id"
else
    fail "Archived content missing or corrupt"
fi

# Assertion: directory now exists with new marker
if [ -d "$HOME/.claude/.current-session" ] && [ -s "$HOME/.claude/.current-session/30001" ]; then
    pass "Post-migration directory + new marker created"
else
    fail "Post-migration state incorrect"
fi

# Assertion: migration is idempotent — second preflight does NOT re-archive
ARCHIVE_COUNT_BEFORE=$(find "$HOME/.claude" -maxdepth 1 -name ".current-session.legacy-*" 2>/dev/null | wc -l)
sleep 1  # ensure timestamp would differ if a new archive were created
(
    export EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE=30002
    echo "{\"session_id\":\"$SID_MIGRATE\",\"source\":\"startup\",\"hook_event_name\":\"SessionStart\"}" \
        | bash "$REPO_ROOT/hooks/epistemic-preflight.sh" >/dev/null 2>&1
)
ARCHIVE_COUNT_AFTER=$(find "$HOME/.claude" -maxdepth 1 -name ".current-session.legacy-*" 2>/dev/null | wc -l)
if [ "$ARCHIVE_COUNT_BEFORE" -eq "$ARCHIVE_COUNT_AFTER" ]; then
    pass "Migration is idempotent — no re-archive on second run"
else
    fail "Migration re-archived: $ARCHIVE_COUNT_BEFORE → $ARCHIVE_COUNT_AFTER"
fi

echo ""

# ── Summary ──────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Smoke Test: $PASS passed, $FAIL failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
