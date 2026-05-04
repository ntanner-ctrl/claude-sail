#!/usr/bin/env bash
# epistemic-marker.sh — shared helper for per-claude-PID session markers
#
# Replaces the single-file ~/.claude/.current-session marker with a
# directory of per-claude-process markers, eliminating the cross-session
# clobber that occurred when two parallel claude sessions both fired
# their SessionStart hooks against the same global path.
#
# Layout:
#   ~/.claude/.current-session/         (directory)
#     <claude_pid>                      (one file per active claude main process)
#         SESSION_ID=<uuid-from-stdin-json>
#         PROJECT=<project-name>
#         STARTED=<ISO-8601 UTC>
#         CLAUDE_PID=<self-validation>
#
# Discovery scaffolding: claude main PID is found by walking the process
# tree (/proc/$PID/status PPid line) until a process with comm=claude is
# reached. Bash-tool context: bash → claude (~2 hops). Hook context:
# bash → sh → claude (~3 hops). Bounded at 15 hops.
#
# Identity vs scaffolding:
#   - Marker FILENAME is the claude main PID — discovery scaffolding only.
#   - Marker CONTENT (SESSION_ID) is Claude Code's own session UUID from
#     the SessionStart hook's stdin JSON. This is the canonical identity
#     used to key entries in epistemic.json.
#
# Hook stdin: read by epistemic-preflight.sh ONLY. Other consumers (other
# hooks, command bash blocks) MUST read session_id from the marker file
# via epistemic_get_session_id. Stdin is a stream; only the first reader
# wins.
#
# Fail-open: every function exits 0 on error; callers treat missing
# results as "no active session." This file uses explicit `set +e`.
#
# Sourced by:
#   - hooks/epistemic-preflight.sh, hooks/epistemic-postflight.sh
#   - hooks/_audit-log.sh
#   - commands/{epistemic-preflight,epistemic-postflight,end,start,
#       collect-insights,vault-curate}.md (bash blocks)

set +e

# ── Constants ───────────────────────────────────────────────────────
EPISTEMIC_MARKER_DIR="${HOME}/.claude/.current-session"
EPISTEMIC_LEGACY_FILE="${HOME}/.claude/.current-session"  # same path; type-disambiguated at runtime
EPISTEMIC_MAX_HOPS=15
EPISTEMIC_UUID_REGEX='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

# ── epistemic_claude_main_pid ──────────────────────────────────────
# Walk the process tree upward from $$ until comm=claude is found.
# Caches result in EPISTEMIC_CLAUDE_MAIN_PID for the current shell.
#
# Override: set EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE in the environment to
# force a specific PID (used by eval fixtures to simulate parallel
# sessions).
#
# Output: PID (stdout) on success; empty + non-zero exit on failure.
epistemic_claude_main_pid() {
    if [ -n "${EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE:-}" ]; then
        printf '%s' "$EPISTEMIC_CLAUDE_MAIN_PID_OVERRIDE"
        return 0
    fi
    if [ -n "${EPISTEMIC_CLAUDE_MAIN_PID:-}" ]; then
        printf '%s' "$EPISTEMIC_CLAUDE_MAIN_PID"
        return 0
    fi
    if [ ! -d /proc ]; then
        # Non-Linux: fall back to direct PPID. Caller has already been
        # warned by the SessionStart hook (FM3) that isolation is degraded.
        local fallback_pid="${PPID:-}"
        if [ -n "$fallback_pid" ]; then
            EPISTEMIC_CLAUDE_MAIN_PID="$fallback_pid"
            export EPISTEMIC_CLAUDE_MAIN_PID
            printf '%s' "$fallback_pid"
            return 0
        fi
        return 1
    fi

    local pid="$$"
    local hops=0
    local name ppid
    while [ "$hops" -lt "$EPISTEMIC_MAX_HOPS" ]; do
        # /proc/<pid>/status format is line-oriented "Key:\tvalue".
        # Robust against comm names containing spaces or parens (which
        # would break /proc/<pid>/stat field-4 parsing — see E1).
        if [ ! -r "/proc/$pid/status" ]; then
            return 1
        fi
        name=$(awk -F'\t' '$1=="Name:"{print $2; exit}' "/proc/$pid/status" 2>/dev/null)
        if [ "$name" = "claude" ]; then
            EPISTEMIC_CLAUDE_MAIN_PID="$pid"
            export EPISTEMIC_CLAUDE_MAIN_PID
            printf '%s' "$pid"
            return 0
        fi
        ppid=$(awk -F'\t' '$1=="PPid:"{print $2; exit}' "/proc/$pid/status" 2>/dev/null)
        if [ -z "$ppid" ] || [ "$ppid" -le 1 ] 2>/dev/null; then
            # Reached init or kernel boundary — claude not in ancestor
            # chain. Guard against PPid=0 from kernel threads (E9).
            return 1
        fi
        pid="$ppid"
        hops=$((hops + 1))
    done
    # Exhausted hop budget without finding claude
    return 1
}

# ── epistemic_marker_path ──────────────────────────────────────────
# Returns the marker file path for the current claude main PID (or the
# PID passed as $1, used by sweep). Empty + non-zero exit if PID unresolvable.
epistemic_marker_path() {
    local pid="${1:-}"
    if [ -z "$pid" ]; then
        pid=$(epistemic_claude_main_pid)
        [ -z "$pid" ] && return 1
    fi
    printf '%s/%s' "$EPISTEMIC_MARKER_DIR" "$pid"
}

# ── epistemic_session_active ───────────────────────────────────────
# Returns 0 if a marker exists for the current claude main process,
# non-zero otherwise. Use this in place of `[ -f ~/.claude/.current-session ]`.
epistemic_session_active() {
    local path
    path=$(epistemic_marker_path) || return 1
    [ -s "$path" ]
}

# ── epistemic_get_session_id ───────────────────────────────────────
# Reads SESSION_ID from the current claude main process's marker.
# Strips CR for CRLF tolerance. Empty stdout + non-zero exit on miss.
epistemic_get_session_id() {
    local path
    path=$(epistemic_marker_path) || return 1
    [ -s "$path" ] || return 1
    grep "^SESSION_ID=" "$path" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'
}

# ── epistemic_sweep_orphans ────────────────────────────────────────
# Two-condition sweep: remove marker files whose PID either no longer
# exists OR points at a process whose comm is not "claude" (PID-reuse
# defense). Skips silently on non-Linux (no /proc).
#
# Set EPISTEMIC_SKIP_SWEEP=1 to disable. TEST-ONLY: parallel-isolation
# evals use fake PIDs that do not exist in /proc, so the sweep would
# remove them. Sweep itself is verified in Phase 8 of the smoke test.
epistemic_sweep_orphans() {
    [ "${EPISTEMIC_SKIP_SWEEP:-0}" = "1" ] && return 0
    [ -d "$EPISTEMIC_MARKER_DIR" ] || return 0
    [ -d /proc ] || return 0  # non-Linux: cannot validate, leave markers
    local f base name
    for f in "$EPISTEMIC_MARKER_DIR"/*; do
        [ -e "$f" ] || continue  # glob no-match safety
        base=$(basename -- "$f")
        # Only numeric PID-named files; skip anything else (e.g. tmpfiles)
        case "$base" in
            ''|*[!0-9]*) continue ;;
        esac
        if [ ! -d "/proc/$base" ]; then
            rm -f -- "$f" 2>/dev/null
            continue
        fi
        name=$(awk -F'\t' '$1=="Name:"{print $2; exit}' "/proc/$base/status" 2>/dev/null)
        if [ "$name" != "claude" ]; then
            rm -f -- "$f" 2>/dev/null
        fi
    done
}

# ── epistemic_write_marker ─────────────────────────────────────────
# Atomic write of marker contents.
# Args:  $1 = session_id (UUID), $2 = project name, $3 = ISO timestamp
# Returns 0 on success, non-zero on any validation/write failure.
# Validates session_id against UUID regex (E6) before writing.
# Tmpfile is created in the marker directory to avoid EXDEV on mv (E2).
epistemic_write_marker() {
    local session_id="$1" project="$2" started="$3"
    if [ -z "$session_id" ]; then
        echo "[epistemic-marker] write_marker: empty session_id, skipping" >&2
        return 1
    fi
    if ! [[ "$session_id" =~ $EPISTEMIC_UUID_REGEX ]]; then
        echo "[epistemic-marker] write_marker: session_id is not a UUID ('$session_id'), skipping" >&2
        return 1
    fi
    local pid
    pid=$(epistemic_claude_main_pid)
    if [ -z "$pid" ]; then
        echo "[epistemic-marker] write_marker: claude main PID unresolvable, skipping" >&2
        return 1
    fi
    mkdir -p -- "$EPISTEMIC_MARKER_DIR" 2>/dev/null
    if [ ! -d "$EPISTEMIC_MARKER_DIR" ]; then
        echo "[epistemic-marker] write_marker: marker dir creation failed at $EPISTEMIC_MARKER_DIR" >&2
        return 1
    fi
    local marker_path="$EPISTEMIC_MARKER_DIR/$pid"
    local tmpfile
    tmpfile=$(mktemp -p "$EPISTEMIC_MARKER_DIR" ".tmp.XXXXXX" 2>/dev/null)
    if [ -z "$tmpfile" ]; then
        echo "[epistemic-marker] write_marker: mktemp failed, skipping" >&2
        return 1
    fi
    {
        printf 'SESSION_ID=%s\n' "$session_id"
        printf 'PROJECT=%s\n'    "$project"
        printf 'STARTED=%s\n'    "$started"
        printf 'CLAUDE_PID=%s\n' "$pid"
    } > "$tmpfile" 2>/dev/null
    if [ ! -s "$tmpfile" ]; then
        rm -f -- "$tmpfile" 2>/dev/null
        echo "[epistemic-marker] write_marker: tmpfile write failed" >&2
        return 1
    fi
    mv -f -- "$tmpfile" "$marker_path" 2>/dev/null
    if [ ! -s "$marker_path" ]; then
        rm -f -- "$tmpfile" 2>/dev/null
        echo "[epistemic-marker] write_marker: rename failed" >&2
        return 1
    fi
    return 0
}

# ── epistemic_get_marker_field ─────────────────────────────────────
# Read an arbitrary K=V field from current marker (used by E3 to
# preserve STARTED across resume).
# Args: $1 = field name (e.g. STARTED)
epistemic_get_marker_field() {
    local field="$1"
    [ -z "$field" ] && return 1
    local path
    path=$(epistemic_marker_path) || return 1
    [ -s "$path" ] || return 1
    grep "^${field}=" "$path" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r'
}

# ── epistemic_migrate_legacy_marker ────────────────────────────────
# If ~/.claude/.current-session exists as a non-directory, atomically
# rename it to .legacy-<TS> so the directory can be created.
# Race-safe: ENOENT from `mv` is treated as success (peer migrated).
epistemic_migrate_legacy_marker() {
    if [ -e "$EPISTEMIC_LEGACY_FILE" ] && [ ! -d "$EPISTEMIC_LEGACY_FILE" ]; then
        local ts
        ts=$(date -u +%Y%m%dT%H%M%SZ 2>/dev/null || date +%s)
        local legacy_archive="${EPISTEMIC_LEGACY_FILE}.legacy-${ts}"
        mv -- "$EPISTEMIC_LEGACY_FILE" "$legacy_archive" 2>/dev/null
        # ENOENT (peer renamed first) = success; mkdir below is idempotent.
    fi
    mkdir -p -- "$EPISTEMIC_MARKER_DIR" 2>/dev/null
}
