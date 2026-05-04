# Recovery Instructions for `/end` of This Session

**This session experienced live marker clobber during planning.** The marker at `~/.claude/.current-session` no longer matches this session's actual session_id.

## DO NOT

- Read `~/.claude/.current-session` for SESSION_ID at `/end` time — it has been clobbered by a parallel session.
- Run the standard `/epistemic-postflight` flow without overriding SESSION_ID — it will write postflight to the wrong session.

## DO

1. **Use the snapshot file** at `.claude/plans/epistemic-session-race/preflight-snapshot-original-*.json` to recover the preflight values.
2. **Override SESSION_ID** to `c2bbe8ed-727b-435c-a93b-932585a6eef1` when running postflight Bash.
3. **Do not touch** marker entry `b30dce80-f289-4620-b337-f9045b574487` — that belongs to a parallel session.

## Marker Timeline (forensic)

| Time | Event | Marker State |
|------|-------|--------------|
| 17:04:24Z | This session SessionStart | `c2bbe8ed-...` (correct) |
| ~17:08:43Z | Parallel session SessionStart | clobbered to `b30dce80-...` |
| 17:11:37Z | Discovery during planning | `b30dce80-...` (still wrong) |
