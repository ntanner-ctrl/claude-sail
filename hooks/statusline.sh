#!/bin/bash
# Claude Code Status Line v2 - Two-Line Toolkit Dashboard
#
# Line 1: Model │ Style │ Code Churn │ Duration │ Context Burn Sparkline │ Toolkit State
# Line 2: Context Bar (checkerboard transition) + % of window │ Cache Hit │ Sub Usage (future)
#
# Receives JSON on stdin: model, cost, context_window, output_style, rate_limits, etc.
# Reads .claude/state-index.json for active plan/TDD state
# Maintains /tmp/claude-sl-ctx-history for sparkline data
#
# Optimized for 300ms update frequency: single jq call for stdin, minimal forks

set +e

# Hook runtime toggle — skip if disabled via env var
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# --- Parse all input fields in one jq call (tab-separated) ---
IFS=$'\t' read -r MODEL CTX_PCT CTX_SIZE CACHE_READ CACHE_CREATE INPUT_TOKENS \
    DURATION_MS LINES_ADD LINES_REM STYLE RATE_SESSION < <(jq -r '[
  (.model.display_name // "Unknown"),
  (.context_window.used_percentage // 0 | tostring),
  (.context_window.context_window_size // 200000 | tostring),
  (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
  (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
  (.context_window.current_usage.input_tokens // 0 | tostring),
  (.cost.total_duration_ms // 0 | tostring),
  (.cost.total_lines_added // 0 | tostring),
  (.cost.total_lines_removed // 0 | tostring),
  (.output_style.name // ""),
  (.rate_limits.session.used_percentage // -1 | tostring)
] | join("\t")' 2>/dev/null)

# --- ANSI palette ---
RST="\033[0m"
DIM="\033[2m"
BLD="\033[1m"
CYN="\033[36m"
GRN="\033[32m"
YLW="\033[33m"
RED="\033[31m"
MAG="\033[35m"

# --- Sanitize numerics ---
CTX_INT=${CTX_PCT%.*}; CTX_INT=${CTX_INT:-0}
DURATION_MS=${DURATION_MS:-0}
LINES_ADD=${LINES_ADD:-0}
LINES_REM=${LINES_REM:-0}
CACHE_READ=${CACHE_READ:-0}
CACHE_CREATE=${CACHE_CREATE:-0}
INPUT_TOKENS=${INPUT_TOKENS:-0}
CTX_SIZE=${CTX_SIZE:-200000}
RATE_SESSION=${RATE_SESSION:--1}

# ═══════════════════════════════════════════════════════════════════
# LINE 1: Operational State
# ═══════════════════════════════════════════════════════════════════

L1="${BLD}${MODEL}${RST}"

# Output style (skip if default or empty)
if [ -n "$STYLE" ] && [ "$STYLE" != "default" ]; then
    L1+=" ${DIM}│${RST} ${MAG}${STYLE}${RST}"
fi

# Code churn (+lines / -lines)
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_REM" -gt 0 ]; then
    L1+=" ${DIM}│${RST} ${GRN}+${LINES_ADD}${RST} ${RED}−${LINES_REM}${RST}"
fi

# Session duration
SECS_TOTAL=$((DURATION_MS / 1000))
MINS=$((SECS_TOTAL / 60))
SECS=$((SECS_TOTAL % 60))
if [ "$MINS" -gt 0 ]; then
    L1+=" ${DIM}│${RST} ${DIM}${MINS}m ${SECS}s${RST}"
elif [ "$SECS" -gt 0 ]; then
    L1+=" ${DIM}│${RST} ${DIM}${SECS}s${RST}"
fi

# Context burn sparkline (rolling 8 samples, recorded every ~10s)
HISTORY_FILE="/tmp/claude-sl-ctx-history"
SAMPLE_TS_FILE="/tmp/claude-sl-last-sample"

NOW=${EPOCHSECONDS:-$(date +%s)}
LAST_SAMPLE=0
[ -f "$SAMPLE_TS_FILE" ] && LAST_SAMPLE=$(cat "$SAMPLE_TS_FILE" 2>/dev/null)

if [ $((NOW - LAST_SAMPLE)) -ge 10 ]; then
    echo "$CTX_INT" >> "$HISTORY_FILE"
    echo "$NOW" > "$SAMPLE_TS_FILE"
    # Keep only last 8 samples
    if [ -f "$HISTORY_FILE" ]; then
        tail -8 "$HISTORY_FILE" > "${HISTORY_FILE}.tmp" 2>/dev/null && \
            mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE" 2>/dev/null
    fi
fi

SPARK_CHARS=(▁ ▂ ▃ ▄ ▅ ▆ ▇ █)
SPARKLINE=""
if [ -f "$HISTORY_FILE" ]; then
    while IFS= read -r val; do
        val=${val:-0}
        idx=$((val * 7 / 100))
        [ "$idx" -gt 7 ] && idx=7
        [ "$idx" -lt 0 ] && idx=0
        SPARKLINE+="${SPARK_CHARS[$idx]}"
    done < "$HISTORY_FILE"
fi

if [ -n "$SPARKLINE" ]; then
    if [ "$CTX_INT" -ge 80 ]; then
        SPARK_CLR="$RED"
    elif [ "$CTX_INT" -ge 60 ]; then
        SPARK_CLR="$YLW"
    else
        SPARK_CLR="$GRN"
    fi
    L1+=" ${DIM}│${RST} ${SPARK_CLR}${SPARKLINE}${RST}${DIM} ctx${RST}"
fi

# Toolkit state (plan/TDD) from state-index
STATE_FILE=".claude/state-index.json"
if [ -f "$STATE_FILE" ]; then
    IFS=$'\t' read -r PLAN STAGE TDD_PHASE < <(jq -r '[
      (.active_plan // ""),
      (.active_plan_stage // "" | tostring),
      (.active_tdd_phase // "")
    ] | join("\t")' "$STATE_FILE" 2>/dev/null)

    TOOLKIT=""
    if [ -n "$PLAN" ]; then
        TOOLKIT="${CYN}Plan: ${PLAN}"
        [ -n "$STAGE" ] && TOOLKIT+=" [${STAGE}]"
        TOOLKIT+="${RST}"
    fi
    if [ -n "$TDD_PHASE" ]; then
        [ -n "$TOOLKIT" ] && TOOLKIT+=" "
        case "$TDD_PHASE" in
            RED)   TDD_CLR="$RED" ;;
            GREEN) TDD_CLR="$GRN" ;;
            *)     TDD_CLR="$YLW" ;;
        esac
        TOOLKIT+="${TDD_CLR}TDD: ${TDD_PHASE}${RST}"
    fi
    [ -n "$TOOLKIT" ] && L1+=" ${DIM}│${RST} ${TOOLKIT}"
fi

# ═══════════════════════════════════════════════════════════════════
# LINE 2: Resource Gauges
# ═══════════════════════════════════════════════════════════════════

# Context bar (10 chars with checkerboard transition)
FILLED=$((CTX_INT / 10))
REMAINDER=$((CTX_INT % 10))

BAR=""
for ((i=0; i<FILLED; i++)); do BAR+="█"; done

# Transition cell: ▒ for low fill, ▓ for high fill within the cell
if [ "$REMAINDER" -gt 0 ]; then
    if [ "$REMAINDER" -ge 5 ]; then
        BAR+="▓"
    else
        BAR+="▒"
    fi
    EMPTY=$((9 - FILLED))
else
    EMPTY=$((10 - FILLED))
fi
[ "$EMPTY" -lt 0 ] && EMPTY=0
for ((i=0; i<EMPTY; i++)); do BAR+="░"; done

# Color context by usage threshold
if [ "$CTX_INT" -ge 80 ]; then
    CTX_CLR="$RED"
elif [ "$CTX_INT" -ge 60 ]; then
    CTX_CLR="$YLW"
else
    CTX_CLR="$GRN"
fi

# Format context window size (200k or 1M)
if [ "$CTX_SIZE" -ge 1000000 ]; then
    SIZE_FMT="1M"
else
    SIZE_FMT="$((CTX_SIZE / 1000))k"
fi

L2="${CTX_CLR}${BAR} ${CTX_INT}%${RST} ${DIM}of ${SIZE_FMT}${RST}"

# Cache hit ratio
TOTAL_INPUT=$((INPUT_TOKENS + CACHE_CREATE + CACHE_READ))
if [ "$TOTAL_INPUT" -gt 0 ]; then
    CACHE_HIT=$((CACHE_READ * 100 / TOTAL_INPUT))
    if [ "$CACHE_HIT" -ge 70 ]; then
        CACHE_CLR="$GRN"
    elif [ "$CACHE_HIT" -ge 40 ]; then
        CACHE_CLR="$YLW"
    else
        CACHE_CLR="$DIM"
    fi
    L2+=" ${DIM}│${RST} ${DIM}cache:${RST} ${CACHE_CLR}${CACHE_HIT}%${RST}"
fi

# Subscription usage (future-proofed — lights up when rate_limits ships)
if [ "$RATE_SESSION" != "-1" ]; then
    if [ "$RATE_SESSION" -ge 80 ]; then
        RATE_CLR="$RED"
    elif [ "$RATE_SESSION" -ge 60 ]; then
        RATE_CLR="$YLW"
    else
        RATE_CLR="$GRN"
    fi
    L2+=" ${DIM}│${RST} ${DIM}sub:${RST} ${RATE_CLR}${RATE_SESSION}%${RST}"
fi

# --- Compaction Guardian Signal Files ---
# Determine session-scoped path
if [ "$PPID" -eq 1 ]; then
    SIG_SUFFIX="$USER-$(pwd | md5sum | cut -c1-8)"
else
    SIG_SUFFIX="$PPID"
fi

if [ "$CTX_INT" -ge 75 ]; then
    echo "$CTX_INT" > "/tmp/.claude-ctx-critical-${SIG_SUFFIX}"
    echo "$(date +%s)" >> "/tmp/.claude-ctx-critical-${SIG_SUFFIX}"
    # Also write warning if not already there
    if [ ! -f "/tmp/.claude-ctx-warning-${SIG_SUFFIX}" ]; then
        echo "$CTX_INT" > "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
        echo "$(date +%s)" >> "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
    fi
elif [ "$CTX_INT" -ge 65 ]; then
    echo "$CTX_INT" > "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
    echo "$(date +%s)" >> "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
    # Remove critical if context dropped below 75
    rm -f "/tmp/.claude-ctx-critical-${SIG_SUFFIX}" 2>/dev/null
elif [ "$CTX_INT" -lt 75 ]; then
    # Cleanup when context drops below thresholds
    rm -f "/tmp/.claude-ctx-warning-${SIG_SUFFIX}" "/tmp/.claude-ctx-critical-${SIG_SUFFIX}" 2>/dev/null
fi

echo -e "$L1"
echo -e "$L2"
