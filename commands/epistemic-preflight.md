---
description: Submit preflight epistemic vectors at session start. Use after seeing the calibration context from the SessionStart hook.
---

# Epistemic Preflight

Capture your preflight self-assessment vectors and store them in `~/.claude/epistemic.json`.

## Instructions

### Step 1: Read Session Context

```bash
source ~/.claude/scripts/epistemic-marker.sh 2>/dev/null
if epistemic_session_active; then
    epistemic_get_session_id
else
    echo "NO_SESSION"
fi
```

If no session marker exists, the SessionStart hook should have created one from
its stdin JSON. If you're running this command standalone (no SessionStart fired
yet — rare), the marker can't be synthesised: SessionStart's stdin contains
Claude Code's canonical session_id, and we don't have it here. Skip the
preflight — it cannot pair correctly without the canonical ID.

### Step 2: Self-Assess

Rate each of these 13 vectors from 0.0 to 1.0 based on your CURRENT epistemic state:

| Vector | What to assess |
|--------|---------------|
| `engagement` | How aligned are you with this task? |
| `know` | How much do you know about the domain/codebase? |
| `do` | How confident are you in your ability to execute? |
| `context` | How well do you understand the surrounding context? |
| `clarity` | How clear are the requirements/goals? |
| `coherence` | How well does your approach hold together? |
| `signal` | How relevant is the available information? |
| `density` | How information-dense do you expect this work to be? |
| `state` | How well do you understand the current system state? |
| `change` | How much change do you expect to produce? |
| `completion` | How much progress do you expect to make? |
| `impact` | How impactful do you expect this work to be? |
| `uncertainty` | How much uncertainty remains? |

### Step 3: Store Vectors

Write vectors to `epistemic.json`. Use the Bash tool:

```bash
#!/usr/bin/env bash
set +e

EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"
EPISTEMIC_TMP="${EPISTEMIC_FILE}.tmp"
EPISTEMIC_BAK="${EPISTEMIC_FILE}.bak"

# Source the marker helper for per-claude-PID resolution.
source "${HOME}/.claude/scripts/epistemic-marker.sh" 2>/dev/null
if [ -z "$(type -t epistemic_get_session_id 2>/dev/null)" ]; then
    echo "ERROR: epistemic-marker.sh not found. Reinstall claude-sail." >&2
    exit 1
fi

# Read session context via helper (per-claude-PID marker).
SESSION_ID=$(epistemic_get_session_id 2>/dev/null)
PROJECT=$(epistemic_get_marker_field PROJECT 2>/dev/null)
STARTED=$(epistemic_get_marker_field STARTED 2>/dev/null)

if [ -z "$SESSION_ID" ]; then
    echo "ERROR: No session ID found. Run SessionStart hook first." >&2
    exit 1
fi

# Initialize if needed
if [ ! -s "$EPISTEMIC_FILE" ]; then
    if [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/scripts/epistemic-init.sh" ]; then
        bash "$(git rev-parse --show-toplevel 2>/dev/null)/scripts/epistemic-init.sh"
    elif [ -f "${HOME}/.claude/scripts/epistemic-init.sh" ]; then
        bash "${HOME}/.claude/scripts/epistemic-init.sh"
    else
        echo "ERROR: epistemic.json not found and init script unavailable" >&2
        exit 1
    fi
fi

# Snapshot original session count — used as a tripwire before any swap.
ORIG_SESSIONS=$(jq '.sessions | length' "$EPISTEMIC_FILE" 2>/dev/null || echo "")

# Rolling-window floor: kept here as a mirror invariant with
# epistemic-postflight (whose paired pipeline trims to .[-50:]) and with
# scripts/epistemic-safe-write.sh::epistemic_safe_swap. The preflight
# upserts a single session, so its count never drops and SESSIONS_FLOOR
# is effectively dead code in this command. It is preserved to keep the
# mirror identical — drift between this inline copy and the helper has
# bitten us before.
SESSIONS_FLOOR=50

# Validate-before-swap: only replace epistemic.json if jq output is
# non-empty, valid JSON, and didn't drop sessions below the rolling-
# window floor. Backs up the prior state to .bak on every successful
# write.
#
# Mirrors scripts/epistemic-safe-write.sh::epistemic_safe_swap. Kept
# inline so this command stays self-contained — Claude executes this
# bash block directly via the Bash tool, and a missing source would
# silently revert to the unsafe pattern.
# NOTE: reads $JQ_EXIT instead of taking $1 as an argument — when this
# command is invoked as a skill, the renderer substitutes $N positional
# patterns from the args string (e.g. $1 → "know=0.80"), corrupting the
# function body. A named global is immune to that substitution.
_safe_swap() {
    local jq_exit="$JQ_EXIT"
    if [ "$jq_exit" -ne 0 ]; then
        echo "ERROR: jq failed (exit $jq_exit). epistemic.json untouched." >&2
        rm -f "$EPISTEMIC_TMP"
        return 1
    fi
    if [ ! -s "$EPISTEMIC_TMP" ]; then
        echo "ERROR: jq produced empty output. epistemic.json untouched." >&2
        rm -f "$EPISTEMIC_TMP"
        return 1
    fi
    if ! jq -e . "$EPISTEMIC_TMP" >/dev/null 2>&1; then
        echo "ERROR: jq output is not valid JSON. epistemic.json untouched." >&2
        rm -f "$EPISTEMIC_TMP"
        return 1
    fi
    local new_count
    new_count=$(jq '.sessions | length' "$EPISTEMIC_TMP" 2>/dev/null)
    local min_allowed="$ORIG_SESSIONS"
    if [ -n "$ORIG_SESSIONS" ] && [ -n "$SESSIONS_FLOOR" ] && \
       [ "$ORIG_SESSIONS" -gt "$SESSIONS_FLOOR" ]; then
        min_allowed="$SESSIONS_FLOOR"
    fi
    if [ -n "$min_allowed" ] && [ -n "$new_count" ] && [ "$new_count" -lt "$min_allowed" ]; then
        echo "ERROR: session count below floor ($ORIG_SESSIONS → $new_count, floor $min_allowed). Refusing swap." >&2
        rm -f "$EPISTEMIC_TMP"
        return 1
    fi
    cp "$EPISTEMIC_FILE" "$EPISTEMIC_BAK" 2>/dev/null
    mv "$EPISTEMIC_TMP" "$EPISTEMIC_FILE"
}

# VECTORS — replace these values with your actual self-assessment
ENGAGEMENT={{engagement}}
KNOW={{know}}
DO={{do}}
CONTEXT={{context}}
CLARITY={{clarity}}
COHERENCE={{coherence}}
SIGNAL={{signal}}
DENSITY={{density}}
STATE={{state}}
CHANGE={{change}}
COMPLETION={{completion}}
IMPACT={{impact}}
UNCERTAINTY={{uncertainty}}

# Upsert session entry (overwrites if already exists — handles double submission)
jq --arg id "$SESSION_ID" \
   --arg project "$PROJECT" \
   --arg ts "$STARTED" \
   --argjson eng "$ENGAGEMENT" \
   --argjson kno "$KNOW" \
   --argjson do_ "$DO" \
   --argjson ctx "$CONTEXT" \
   --argjson cla "$CLARITY" \
   --argjson coh "$COHERENCE" \
   --argjson sig "$SIGNAL" \
   --argjson den "$DENSITY" \
   --argjson sta "$STATE" \
   --argjson chg "$CHANGE" \
   --argjson com "$COMPLETION" \
   --argjson imp "$IMPACT" \
   --argjson unc "$UNCERTAINTY" \
   '
   # Remove existing entry for this session (handles double submission)
   .sessions = [.sessions[] | select(.id != $id)] |
   # Add new entry
   .sessions += [{
     id: $id,
     project: $project,
     timestamp: $ts,
     preflight: {
       engagement: $eng, know: $kno, do: $do_, context: $ctx,
       clarity: $cla, coherence: $coh, signal: $sig, density: $den,
       state: $sta, change: $chg, completion: $com, impact: $imp,
       uncertainty: $unc
     },
     postflight: null,
     deltas: null,
     task_summary: "",
     paired: false
   }] |
   .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ' "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP"
JQ_EXIT=$?
_safe_swap || { echo "ERROR: Failed to write preflight vectors" >&2; exit 1; }

echo "Preflight vectors recorded for session ${SESSION_ID} (project: ${PROJECT})."
```

Replace `{{vector}}` placeholders with your actual 0.0-1.0 scores before running.

### Step 4: Confirm

Report: "Preflight vectors recorded for session {SESSION_ID}."

Store the session ID for use throughout this conversation — you'll need it for postflight.
