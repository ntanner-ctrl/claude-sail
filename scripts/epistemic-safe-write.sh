#!/usr/bin/env bash
# epistemic-safe-write.sh — atomic write helper for epistemic.json
#
# Sourced by hooks/epistemic-preflight.sh (and any other site that updates
# epistemic.json) to gate the tmp→file swap on multiple validity checks.
#
# Background: the original `jq ... > "$TMP" && mv "$TMP" "$FILE"` pattern
# trusts jq's exit code as a sole gate. jq can exit 0 with empty stdout
# (e.g., filter into `empty`, partial buffering after an error), in which
# case `mv` runs and the file is silently wiped. The 2026-04-30 incident
# erased a 91KB epistemic.json (26 paired sessions) this way.
#
# Usage:
#   source ~/.claude/scripts/epistemic-safe-write.sh
#   epistemic_safe_swap <epistemic_file> <tmp_file> <jq_exit_code>
#
# Returns 0 on successful swap, 1 on any validation failure (and removes
# the tmp file). On success, the prior file is copied to <epistemic_file>.bak.
#
# Optional: set EPISTEMIC_ORIG_SESSIONS before calling to enable the
# session-count tripwire. If the new file has fewer sessions than the
# original, the swap is refused.

epistemic_safe_swap() {
    local file="$1"
    local tmp="$2"
    local jq_exit="$3"

    if [ -z "$file" ] || [ -z "$tmp" ] || [ -z "$jq_exit" ]; then
        echo "epistemic_safe_swap: missing arguments (need file, tmp, jq_exit)" >&2
        return 1
    fi

    if [ "$jq_exit" -ne 0 ]; then
        echo "epistemic_safe_swap: jq failed (exit $jq_exit). $file untouched." >&2
        rm -f "$tmp"
        return 1
    fi
    if [ ! -s "$tmp" ]; then
        echo "epistemic_safe_swap: jq produced empty output. $file untouched." >&2
        rm -f "$tmp"
        return 1
    fi
    if ! jq -e . "$tmp" >/dev/null 2>&1; then
        echo "epistemic_safe_swap: jq output is not valid JSON. $file untouched." >&2
        rm -f "$tmp"
        return 1
    fi
    if [ -n "$EPISTEMIC_ORIG_SESSIONS" ]; then
        local new_count
        new_count=$(jq '.sessions | length' "$tmp" 2>/dev/null)
        if [ -n "$new_count" ] && [ "$new_count" -lt "$EPISTEMIC_ORIG_SESSIONS" ]; then
            echo "epistemic_safe_swap: session count would drop ($EPISTEMIC_ORIG_SESSIONS → $new_count). Refusing swap." >&2
            rm -f "$tmp"
            return 1
        fi
    fi

    cp "$file" "${file}.bak" 2>/dev/null
    mv "$tmp" "$file"
}
