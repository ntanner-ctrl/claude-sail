#!/bin/bash
# Worktree Cleanup - SessionStart Hook
# Removes any leftover worktrees from previous delegate --isolate sessions.
#
# Worktrees are created by /delegate --isolate and should be cleaned up
# after accept/reject. This hook catches orphaned worktrees from crashes
# or interrupted sessions.
#
# Installation: Add to ~/.claude/settings.json SessionStart hooks
set +e

WORKTREE_DIR=".claude/worktrees"

# Only act if worktree directory exists
[ -d "$WORKTREE_DIR" ] || exit 0

# Check for any remaining worktrees
orphans=$(ls -d "$WORKTREE_DIR"/*/ 2>/dev/null)
[ -z "$orphans" ] && exit 0

# Remove orphaned worktrees
count=0
for wt in "$WORKTREE_DIR"/*/; do
    [ -d "$wt" ] || continue
    wt_name=$(basename "$wt")
    git worktree remove "$WORKTREE_DIR/$wt_name" --force 2>/dev/null || rm -rf "$wt"
    count=$((count + 1))
done

if [ "$count" -gt 0 ]; then
    echo "Cleaned up $count orphaned worktree(s) from previous delegate --isolate session."
fi

# Remove empty worktree directory
rmdir "$WORKTREE_DIR" 2>/dev/null || true

exit 0
