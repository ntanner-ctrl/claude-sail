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
#
# Optional: set EPISTEMIC_SESSIONS_FLOOR alongside EPISTEMIC_ORIG_SESSIONS
# to permit intentional rolling-window trims (e.g. `.sessions = .[-50:]`).
# When ORIG > FLOOR, drops down to FLOOR are allowed; drops below FLOOR
# are still refused. When ORIG <= FLOOR, behavior is unchanged (any drop
# is refused — the strict tripwire). When FLOOR is unset, behavior is
# also unchanged (strict tripwire) — this preserves backward compatibility
# with callers that never trim.

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
    # Use ${VAR:-} so the helper is safe to source into a `set -u` caller
    # (e.g. scripts/epistemic-smoke-test.sh). Callers who don't set
    # EPISTEMIC_ORIG_SESSIONS or EPISTEMIC_SESSIONS_FLOOR get empty strings,
    # not unbound-variable errors.
    if [ -n "${EPISTEMIC_ORIG_SESSIONS:-}" ]; then
        local new_count
        new_count=$(jq '.sessions | length' "$tmp" 2>/dev/null)
        local min_allowed="$EPISTEMIC_ORIG_SESSIONS"
        if [ -n "${EPISTEMIC_SESSIONS_FLOOR:-}" ] && \
           [ "$EPISTEMIC_ORIG_SESSIONS" -gt "$EPISTEMIC_SESSIONS_FLOOR" ]; then
            min_allowed="$EPISTEMIC_SESSIONS_FLOOR"
        fi
        if [ -n "$new_count" ] && [ "$new_count" -lt "$min_allowed" ]; then
            echo "epistemic_safe_swap: session count below floor ($EPISTEMIC_ORIG_SESSIONS → $new_count, floor $min_allowed). Refusing swap." >&2
            rm -f "$tmp"
            return 1
        fi
    fi

    cp "$file" "${file}.bak" 2>/dev/null
    mv "$tmp" "$file"
}
