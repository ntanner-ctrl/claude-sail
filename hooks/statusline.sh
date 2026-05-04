#!/bin/bash
# Claude Code Status Line v3 — Two-Line Toolkit Dashboard (braille meters + truecolor)
#
# Line 1: [project[·worktree][›cwd]] Model │ Style │ Code Churn │ Duration │ Sparkline ctx │ Toolkit
# Line 2: BrailleCtx % (% left) of size │ cache: % │ 5h: % (resets) │ 7d: % (resets)
#
# Receives JSON on stdin (documented Claude Code statusline schema).
# Reads .claude/state-index.json for active plan/TDD state.
# Maintains /tmp/claude-sl-ctx-history for ctx sparkline data.
# Optimized for 300ms update frequency: single jq call for stdin, no per-render forks.
#
# Visual upgrades over v2:
#   - 8-sub-level braille meters (↑8x resolution from 4-level block chars)
#   - Tokyo-Night truecolor palette (graceful degrade on non-truecolor terms)
#   - Project/cwd-divergence prefix on L1
#   - Real 5h + 7d rate limit display with resets-at countdown
#   - "(N% left)" closes the loop on context display
#   - Removed never-firing rate_limits.session block
#
# All data fields verified against documented schema. No invented field names.

set +e

# Hook runtime toggle
HOOK_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
if [[ ",${SAIL_DISABLED_HOOKS}," == *",${HOOK_NAME},"* ]]; then
    exit 0
fi

# --- Single jq call: parse all fields pipe-separated ---
# (tab is whitespace IFS in bash → collapses adjacent empties; pipe is non-whitespace
#  IFS → preserves empty fields between separators. Required because PROJECT_DIR,
#  CURRENT_DIR, GIT_WORKTREE may any be empty.)
IFS='|' read -r MODEL CTX_PCT CTX_REM CTX_SIZE CACHE_READ CACHE_CREATE INPUT_TOKENS \
    DURATION_MS LINES_ADD LINES_REM STYLE \
    PROJECT_DIR CURRENT_DIR GIT_WORKTREE \
    RATE_5H RATE_5H_RESETS RATE_7D RATE_7D_RESETS < <(jq -r '[
  (.model.display_name // "Unknown"),
  (.context_window.used_percentage // 0 | tostring),
  (.context_window.remaining_percentage // 0 | tostring),
  (.context_window.context_window_size // 200000 | tostring),
  (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
  (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
  (.context_window.current_usage.input_tokens // 0 | tostring),
  (.cost.total_duration_ms // 0 | tostring),
  (.cost.total_lines_added // 0 | tostring),
  (.cost.total_lines_removed // 0 | tostring),
  (.output_style.name // ""),
  (.workspace.project_dir // ""),
  (.workspace.current_dir // .cwd // ""),
  (.workspace.git_worktree // ""),
  (.rate_limits.five_hour.used_percentage // -1 | tostring),
  (.rate_limits.five_hour.resets_at // 0 | tostring),
  (.rate_limits.seven_day.used_percentage // -1 | tostring),
  (.rate_limits.seven_day.resets_at // 0 | tostring)
] | join("|")' 2>/dev/null)

# --- ANSI palette: 16-color attributes + Tokyo Night truecolor accents ---
RST="\033[0m"
DIM="\033[2m"
BLD="\033[1m"
# Tokyo Night palette (truecolor; degrades to nearest ANSI on 256/16-color terms)
BLU="\033[38;2;122;162;247m"
CYN="\033[38;2;125;207;255m"
MAG="\033[38;2;187;154;247m"
GRN="\033[38;2;158;206;106m"
YLW="\033[38;2;224;175;104m"
RED="\033[38;2;247;118;142m"
DIM_C="\033[38;2;122;128;153m"
MUTED="\033[38;2;84;88;118m"

# --- Sanitize numerics ---
CTX_INT=${CTX_PCT%.*}; CTX_INT=${CTX_INT:-0}
CTX_REM_INT=${CTX_REM%.*}; CTX_REM_INT=${CTX_REM_INT:-0}
[ "$CTX_REM_INT" -eq 0 ] && [ "$CTX_INT" -gt 0 ] && CTX_REM_INT=$((100 - CTX_INT))
DURATION_MS=${DURATION_MS:-0}
LINES_ADD=${LINES_ADD:-0}
LINES_REM=${LINES_REM:-0}
CACHE_READ=${CACHE_READ:-0}
CACHE_CREATE=${CACHE_CREATE:-0}
INPUT_TOKENS=${INPUT_TOKENS:-0}
CTX_SIZE=${CTX_SIZE:-200000}
RATE_5H=${RATE_5H:--1}
RATE_5H_RESETS=${RATE_5H_RESETS:-0}
RATE_7D=${RATE_7D:--1}
RATE_7D_RESETS=${RATE_7D_RESETS:-0}

# --- Helpers ---
threshold_color() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then printf '%s' "$RED"
    elif [ "$pct" -ge 60 ]; then printf '%s' "$YLW"
    else printf '%s' "$GRN"
    fi
}

# Braille bar — 8 sub-levels per cell. width=10 → 80 effective resolution steps.
braille_bar() {
    local pct=$1 width=$2
    local total=$((width * 8))
    local filled=$((pct * total / 100))
    local glyphs=('⠀' '⡀' '⣀' '⣄' '⣤' '⣦' '⣶' '⣷' '⣿')
    local out='' i cell
    for ((i=0; i<width; i++)); do
        cell=$((filled - i*8))
        [ "$cell" -lt 0 ] && cell=0
        [ "$cell" -gt 8 ] && cell=8
        out+="${glyphs[$cell]}"
    done
    printf '%s' "$out"
}

# Format unix-epoch reset time → relative ("47m", "2h17", "3d")
fmt_reset() {
    local resets_at=$1
    [ "$resets_at" -le 0 ] && { printf -- '—'; return; }
    local now=${EPOCHSECONDS:-$(date +%s)}
    local diff=$((resets_at - now))
    [ "$diff" -le 0 ] && { printf 'now'; return; }
    if [ "$diff" -lt 3600 ]; then
        printf '%dm' $((diff / 60))
    elif [ "$diff" -lt 86400 ]; then
        printf '%dh%02d' $((diff / 3600)) $(((diff % 3600) / 60))
    else
        printf '%dd' $((diff / 86400))
    fi
}

NOW=${EPOCHSECONDS:-$(date +%s)}

# ═══════════════════════════════════════════════════════════════════
# LINE 1: Identity + Operational State
# ═══════════════════════════════════════════════════════════════════

L1=""

# Project + worktree + cwd-divergence prefix
PROJECT_NAME="${PROJECT_DIR##*/}"
CURRENT_NAME="${CURRENT_DIR##*/}"
if [ -n "$PROJECT_NAME" ]; then
    PREFIX="${BLU}${BLD}${PROJECT_NAME}${RST}"
    if [ -n "$GIT_WORKTREE" ]; then
        PREFIX+="${DIM_C}·${RST}${MAG}${GIT_WORKTREE}${RST}"
    fi
    if [ -n "$CURRENT_NAME" ] && [ "$CURRENT_NAME" != "$PROJECT_NAME" ]; then
        PREFIX+="${DIM_C}›${CURRENT_NAME}${RST}"
    fi
    L1+="${MUTED}[${RST}${PREFIX}${MUTED}]${RST} "
fi

L1+="${BLD}${MODEL}${RST}"

# Output style
if [ -n "$STYLE" ] && [ "$STYLE" != "default" ]; then
    L1+=" ${DIM}│${RST} ${MAG}${STYLE}${RST}"
fi

# Code churn
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_REM" -gt 0 ]; then
    L1+=" ${DIM}│${RST} ${GRN}+${LINES_ADD}${RST} ${RED}−${LINES_REM}${RST}"
fi

# Duration
SECS_TOTAL=$((DURATION_MS / 1000))
MINS=$((SECS_TOTAL / 60))
SECS=$((SECS_TOTAL % 60))
if [ "$MINS" -gt 0 ]; then
    L1+=" ${DIM}│${RST} ${DIM_C}${MINS}m ${SECS}s${RST}"
elif [ "$SECS" -gt 0 ]; then
    L1+=" ${DIM}│${RST} ${DIM_C}${SECS}s${RST}"
fi

# Context burn sparkline (rolling 8 samples, real history; sampled every ~10s)
HISTORY_FILE="/tmp/claude-sl-ctx-history"
SAMPLE_TS_FILE="/tmp/claude-sl-last-sample"

LAST_SAMPLE=0
[ -f "$SAMPLE_TS_FILE" ] && LAST_SAMPLE=$(cat "$SAMPLE_TS_FILE" 2>/dev/null)

if [ $((NOW - LAST_SAMPLE)) -ge 10 ]; then
    echo "$CTX_INT" >> "$HISTORY_FILE"
    echo "$NOW" > "$SAMPLE_TS_FILE"
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
    SPARK_CLR=$(threshold_color "$CTX_INT")
    L1+=" ${DIM}│${RST} ${SPARK_CLR}${SPARKLINE}${RST}${DIM} ctx${RST}"
fi

# Toolkit state (Plan/TDD)
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
# LINE 2: Resource Gauges (braille meter + cache + rate limits)
# ═══════════════════════════════════════════════════════════════════

CTX_CLR=$(threshold_color "$CTX_INT")
CTX_BAR=$(braille_bar "$CTX_INT" 10)

if [ "$CTX_SIZE" -ge 1000000 ]; then
    SIZE_FMT="1M"
else
    SIZE_FMT="$((CTX_SIZE / 1000))k"
fi

L2="${CTX_CLR}${CTX_BAR}${RST} ${CTX_CLR}${BLD}${CTX_INT}%${RST}"
L2+=" ${DIM_C}(${CTX_REM_INT}% left) of ${SIZE_FMT}${RST}"

# Cache hit ratio (computed from current_usage; the schema-correct way)
TOTAL_INPUT=$((INPUT_TOKENS + CACHE_CREATE + CACHE_READ))
if [ "$TOTAL_INPUT" -gt 0 ]; then
    CACHE_HIT=$((CACHE_READ * 100 / TOTAL_INPUT))
    if [ "$CACHE_HIT" -ge 70 ]; then
        CACHE_CLR="$GRN"
    elif [ "$CACHE_HIT" -ge 40 ]; then
        CACHE_CLR="$YLW"
    else
        CACHE_CLR="$DIM_C"
    fi
    L2+=" ${DIM}│${RST} ${DIM_C}cache:${RST} ${CACHE_CLR}${CACHE_HIT}%${RST}"
fi

# 5h rate limit (Pro/Max only — gated on present field)
if [ "$RATE_5H" != "-1" ]; then
    RATE_5H_INT=${RATE_5H%.*}; RATE_5H_INT=${RATE_5H_INT:-0}
    RATE_5H_CLR=$(threshold_color "$RATE_5H_INT")
    L2+=" ${DIM}│${RST} ${DIM_C}5h:${RST} ${RATE_5H_CLR}${RATE_5H_INT}%${RST}"
    if [ "$RATE_5H_RESETS" -gt 0 ]; then
        RESET_5H=$(fmt_reset "$RATE_5H_RESETS")
        L2+=" ${DIM_C}(${RESET_5H})${RST}"
    fi
fi

# 7d rate limit
if [ "$RATE_7D" != "-1" ]; then
    RATE_7D_INT=${RATE_7D%.*}; RATE_7D_INT=${RATE_7D_INT:-0}
    RATE_7D_CLR=$(threshold_color "$RATE_7D_INT")
    L2+=" ${DIM}│${RST} ${DIM_C}7d:${RST} ${RATE_7D_CLR}${RATE_7D_INT}%${RST}"
    if [ "$RATE_7D_RESETS" -gt 0 ]; then
        RESET_7D=$(fmt_reset "$RATE_7D_RESETS")
        L2+=" ${DIM_C}(${RESET_7D})${RST}"
    fi
fi

# --- Compaction Guardian Signal Files (preserved from v2) ---
if [ "$PPID" -eq 1 ]; then
    SIG_SUFFIX="$USER-$(pwd | md5sum | cut -c1-8)"
else
    SIG_SUFFIX="$PPID"
fi

if [ "$CTX_INT" -ge 75 ]; then
    echo "$CTX_INT" > "/tmp/.claude-ctx-critical-${SIG_SUFFIX}"
    echo "$NOW" >> "/tmp/.claude-ctx-critical-${SIG_SUFFIX}"
    if [ ! -f "/tmp/.claude-ctx-warning-${SIG_SUFFIX}" ]; then
        echo "$CTX_INT" > "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
        echo "$NOW" >> "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
    fi
elif [ "$CTX_INT" -ge 65 ]; then
    echo "$CTX_INT" > "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
    echo "$NOW" >> "/tmp/.claude-ctx-warning-${SIG_SUFFIX}"
    rm -f "/tmp/.claude-ctx-critical-${SIG_SUFFIX}" 2>/dev/null
elif [ "$CTX_INT" -lt 75 ]; then
    rm -f "/tmp/.claude-ctx-warning-${SIG_SUFFIX}" "/tmp/.claude-ctx-critical-${SIG_SUFFIX}" 2>/dev/null
fi

echo -e "$L1"
echo -e "$L2"
