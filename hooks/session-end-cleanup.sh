#!/usr/bin/env bash
# session-end-cleanup.sh — Removes signal files created during the session
#
# Cleans up: failure counter, debug reset, and session start timestamp.

set +e

# Determine session-scoped suffix (same logic as failure-escalation hook)
if [ "$PPID" -eq 1 ]; then
    SIG_SUFFIX="$USER-$(pwd | md5sum | cut -c1-8)"
else
    SIG_SUFFIX="$PPID"
fi

rm -f "/tmp/.claude-fail-count-${SIG_SUFFIX}" \
      "/tmp/.claude-debug-reset-${SIG_SUFFIX}" \
      "/tmp/.claude-session-start-$(id -u)" \
      2>/dev/null

exit 0
