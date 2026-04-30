---
description: Submit postflight epistemic vectors at session end. Computes deltas, updates calibration, generates behavioral feedback. Called automatically by /end.
---

# Epistemic Postflight

Capture postflight self-assessment, compute deltas against preflight, update calibration state, and generate behavioral feedback for future sessions.

## Instructions

### Step 1: Read Session Context

```bash
cat ~/.claude/.current-session 2>/dev/null || echo "NO_SESSION"
```

If no session marker exists or `SESSION_ID` is empty, the write step
in Step 3 will refuse to run. Inspect `~/.claude/.current-session` or
re-run `/epistemic-preflight` first to create one. (Silently proceeding
with an empty session ID once corrupted `epistemic.json` — see the
2026-04-30 data-loss event.)

### Step 2: Self-Assess (Postflight)

Rate each of these 13 vectors from 0.0 to 1.0 based on your CURRENT epistemic state — where you are NOW, after the session's work:

| Vector | What to assess |
|--------|---------------|
| `engagement` | How deeply did you engage with the task? |
| `know` | How much do you NOW know about the domain? |
| `do` | How much practical ability did you gain? |
| `context` | How well do you understand the project context NOW? |
| `clarity` | How clear is your understanding NOW? |
| `coherence` | How well does everything fit together NOW? |
| `signal` | How strong was the signal-to-noise ratio? |
| `density` | How information-dense was the work? |
| `state` | How well do you know the current state of things? |
| `change` | How much changed from your initial understanding? |
| `completion` | How complete is the work? |
| `impact` | How impactful was the session? |
| `uncertainty` | How much uncertainty remains? |

**Be honest.** The value of postflight is in the delta between preflight and postflight. Inflated scores corrupt the calibration data.

### Step 3: Compute Deltas and Update Calibration

Write postflight vectors, compute deltas, and update calibration. Use the Bash tool:

```bash
#!/usr/bin/env bash
set +e

EPISTEMIC_FILE="${HOME}/.claude/epistemic.json"
EPISTEMIC_TMP="${EPISTEMIC_FILE}.tmp"
EPISTEMIC_BAK="${EPISTEMIC_FILE}.bak"
SESSION_FILE="${HOME}/.claude/.current-session"

# Read session context (strip CR for CRLF-tolerant marker files)
SESSION_ID=$(grep "^SESSION_ID=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2 | tr -d '\r')
PROJECT=$(grep "^PROJECT=" "$SESSION_FILE" 2>/dev/null | cut -d= -f2 | tr -d '\r')

# Fail-fast on empty SESSION_ID. Proceeding without a session ID once
# corrupted epistemic.json (data-loss event 2026-04-30) — refuse instead
# of silently falling through to the standalone branch.
if [ -z "$SESSION_ID" ]; then
    echo "ERROR: SESSION_ID is empty in ${SESSION_FILE} — refusing to write postflight." >&2
    echo "Inspect ~/.claude/.current-session or re-run /epistemic-preflight first." >&2
    exit 1
fi

if [ ! -s "$EPISTEMIC_FILE" ]; then
    echo "ERROR: epistemic.json missing or empty. Cannot store postflight." >&2
    exit 1
fi

# Snapshot original session count — used as a tripwire before any swap.
ORIG_SESSIONS=$(jq '.sessions | length' "$EPISTEMIC_FILE" 2>/dev/null || echo "")

# Validate-before-swap: only replace epistemic.json if jq output is
# non-empty, valid JSON, and didn't lose sessions. Backs up the prior
# state to .bak on every successful write.
#
# Call as:   jq ... > "$EPISTEMIC_TMP"; _safe_swap $? || exit 1
_safe_swap() {
    local jq_exit=$1
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
    if [ -n "$ORIG_SESSIONS" ] && [ -n "$new_count" ] && [ "$new_count" -lt "$ORIG_SESSIONS" ]; then
        echo "ERROR: session count would drop ($ORIG_SESSIONS → $new_count). Refusing swap." >&2
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
TASK_SUMMARY="{{task_summary}}"

# Check for matching preflight (strict session_id match — NOT "latest unpaired")
HAS_PREFLIGHT="false"
if [ -n "$SESSION_ID" ]; then
    HAS_PREFLIGHT=$(jq --arg id "$SESSION_ID" \
        '[.sessions[] | select(.id == $id and .preflight != null)] | length > 0' \
        "$EPISTEMIC_FILE" 2>/dev/null)
fi

if [ "$HAS_PREFLIGHT" != "true" ]; then
    echo "Note: No preflight found for session ${SESSION_ID}."
    echo "Postflight stored but not paired. No delta computation."

    # Store as standalone unpaired entry
    jq --arg id "${SESSION_ID:-standalone-$(date +%s)}" \
       --arg project "${PROJECT:-unknown}" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg summary "$TASK_SUMMARY" \
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
       # Check if session exists (may have been created by hook without preflight)
       if [.sessions[] | select(.id == $id)] | length > 0 then
         .sessions = [.sessions[] |
           if .id == $id then
             .postflight = {
               engagement: $eng, know: $kno, do: $do_, context: $ctx,
               clarity: $cla, coherence: $coh, signal: $sig, density: $den,
               state: $sta, change: $chg, completion: $com, impact: $imp,
               uncertainty: $unc
             } | .task_summary = $summary
           else . end]
       else
         .sessions += [{
           id: $id, project: $project, timestamp: $ts,
           preflight: null,
           postflight: {
             engagement: $eng, know: $kno, do: $do_, context: $ctx,
             clarity: $cla, coherence: $coh, signal: $sig, density: $den,
             state: $sta, change: $chg, completion: $com, impact: $imp,
             uncertainty: $unc
           },
           deltas: null, task_summary: $summary, paired: false
         }]
       end |
       .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
       ' "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP"
    _safe_swap $? || exit 1

    exit 0
fi

# ── Paired session: compute deltas and update calibration ────

jq --arg id "$SESSION_ID" \
   --arg summary "$TASK_SUMMARY" \
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
   # Build postflight object
   ($eng) as $post_engagement |
   ($kno) as $post_know |
   ($do_) as $post_do |
   ($ctx) as $post_context |
   ($cla) as $post_clarity |
   ($coh) as $post_coherence |
   ($sig) as $post_signal |
   ($den) as $post_density |
   ($sta) as $post_state |
   ($chg) as $post_change |
   ($com) as $post_completion |
   ($imp) as $post_impact |
   ($unc) as $post_uncertainty |

   # Find the matching session and extract preflight
   (.sessions[] | select(.id == $id)) as $session |
   $session.preflight as $pre |

   # Compute deltas (postflight - preflight)
   {
     engagement: ($post_engagement - $pre.engagement),
     know: ($post_know - $pre.know),
     do: ($post_do - $pre.do),
     context: ($post_context - $pre.context),
     clarity: ($post_clarity - $pre.clarity),
     coherence: ($post_coherence - $pre.coherence),
     signal: ($post_signal - $pre.signal),
     density: ($post_density - $pre.density),
     state: ($post_state - $pre.state),
     change: ($post_change - $pre.change),
     completion: ($post_completion - $pre.completion),
     impact: ($post_impact - $pre.impact),
     uncertainty: ($post_uncertainty - $pre.uncertainty)
   } as $deltas |

   # Update the session entry
   .sessions = [.sessions[] |
     if .id == $id then
       .postflight = {
         engagement: $post_engagement, know: $post_know, do: $post_do,
         context: $post_context, clarity: $post_clarity, coherence: $post_coherence,
         signal: $post_signal, density: $post_density, state: $post_state,
         change: $post_change, completion: $post_completion, impact: $post_impact,
         uncertainty: $post_uncertainty
       } |
       .deltas = $deltas |
       .task_summary = $summary |
       .paired = true
     else . end
   ] |

   # Update calibration for each vector
   # Append delta to last_deltas (cap at 50), recompute rolling mean and correction
   .calibration.engagement.last_deltas = ((.calibration.engagement.last_deltas + [$deltas.engagement]) | .[-50:]) |
   .calibration.know.last_deltas = ((.calibration.know.last_deltas + [$deltas.know]) | .[-50:]) |
   .calibration.do.last_deltas = ((.calibration.do.last_deltas + [$deltas.do]) | .[-50:]) |
   .calibration.context.last_deltas = ((.calibration.context.last_deltas + [$deltas.context]) | .[-50:]) |
   .calibration.clarity.last_deltas = ((.calibration.clarity.last_deltas + [$deltas.clarity]) | .[-50:]) |
   .calibration.coherence.last_deltas = ((.calibration.coherence.last_deltas + [$deltas.coherence]) | .[-50:]) |
   .calibration.signal.last_deltas = ((.calibration.signal.last_deltas + [$deltas.signal]) | .[-50:]) |
   .calibration.density.last_deltas = ((.calibration.density.last_deltas + [$deltas.density]) | .[-50:]) |
   .calibration.state.last_deltas = ((.calibration.state.last_deltas + [$deltas.state]) | .[-50:]) |
   .calibration.change.last_deltas = ((.calibration.change.last_deltas + [$deltas.change]) | .[-50:]) |
   .calibration.completion.last_deltas = ((.calibration.completion.last_deltas + [$deltas.completion]) | .[-50:]) |
   .calibration.impact.last_deltas = ((.calibration.impact.last_deltas + [$deltas.impact]) | .[-50:]) |
   .calibration.uncertainty.last_deltas = ((.calibration.uncertainty.last_deltas + [$deltas.uncertainty]) | .[-50:]) |

   # Recompute rolling means and corrections for all vectors (null-safe)
   reduce ("engagement","know","do","context","clarity","coherence","signal","density","state","change","completion","impact","uncertainty") as $v (
     .;
     .calibration[$v].observation_count = ([.calibration[$v].last_deltas[] | select(. != null)] | length) |
     .calibration[$v].rolling_mean_delta = (
       [.calibration[$v].last_deltas[] | select(. != null) | tonumber] |
       if length == 0 then 0 else add / length end
     ) |
     .calibration[$v].correction = (
       .calibration[$v].rolling_mean_delta |
       if . > 0.25 then 0.25
       elif . < -0.25 then -0.25
       else . end
     ) |
     .calibration[$v].last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ) |

   # Trim sessions to rolling window of 50
   .sessions = (.sessions | .[-50:]) |

   .last_updated = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
   ' "$EPISTEMIC_FILE" > "$EPISTEMIC_TMP"
_safe_swap $? || { echo "ERROR: Failed to compute deltas" >&2; exit 1; }

# Report deltas
echo "Postflight recorded and paired for session ${SESSION_ID}."
echo ""
echo "Deltas (postflight - preflight):"
jq --arg id "$SESSION_ID" '
  .sessions[] | select(.id == $id) | .deltas |
  to_entries[] | "\(.key): \(if .value > 0 then "+\(.value)" else "\(.value)" end)"
' "$EPISTEMIC_FILE" 2>/dev/null | while read -r line; do
    echo "  $line" | tr -d '"'
done
echo ""
echo "Calibration updated."
```

Replace `{{vector}}` placeholders with your actual 0.0-1.0 scores and `{{task_summary}}` with a 2-3 sentence summary of all work completed this session.

### Step 4: Generate Behavioral Feedback

After updating calibration, regenerate behavioral instructions for future sessions:

```bash
# Source and run feedback generation
SCRIPT_DIR="$(git rev-parse --show-toplevel 2>/dev/null)/scripts"
if [ -f "$SCRIPT_DIR/epistemic-feedback.sh" ]; then
    source "$SCRIPT_DIR/epistemic-feedback.sh"
    epistemic_generate_feedback
elif [ -f "${HOME}/.claude/scripts/epistemic-feedback.sh" ]; then
    source "${HOME}/.claude/scripts/epistemic-feedback.sh"
    epistemic_generate_feedback
fi
```

### Step 5: Report Summary

Present a summary:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  POSTFLIGHT COMPLETE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Session:     {SESSION_ID}
  Project:     {PROJECT}
  Paired:      {yes/no}

  Top deltas:
    {vector}: {+/-delta} ({direction})
    {vector}: {+/-delta} ({direction})
    {vector}: {+/-delta} ({direction})

  Calibration: Updated ({N} total paired sessions)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Step 6: Cleanup Session Marker

```bash
rm -f ~/.claude/.current-session 2>/dev/null
```
