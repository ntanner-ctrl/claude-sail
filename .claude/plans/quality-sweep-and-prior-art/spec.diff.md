# Specification Revision History

## Revision 0 (initial)
- Created: 2026-03-13
- Sections: Deliverable 1 (/prior-art), Deliverable 2 (/quality-sweep), Deliverable 3 (Blueprint Wiring), Work Units, Acceptance Criteria
- Work Units: 6

## Revision 0 → Revision 1
- Trigger: Debate judge verdict REGRESS — 2 critical, 4 high findings
- Date: 2026-03-13

### Changes

| Finding | Severity | Change |
|---------|----------|--------|
| F1 | critical | Narrowed `/prior-art` description from "ANY new implementation approach" to "custom solution to a problem that might already be solved by an existing library" |
| F3 | critical | Removed `fix=auto` mode entirely. Only `prompt` (default) and `report-only` remain. |
| F2 | high | Added agent interface contract — orchestrator parses free-form output, defaults unrated findings to medium severity |
| F5 | high | Expanded dependency heuristic — same file OR same function/export = sequential. Cross-file logical deps flagged for user judgment. |
| F6 | high | Added git checkpoint before fix dispatch (`git stash create`). Added rollback offer on regression cap hit. Added rationale for cap of 2. |
| F8 | high | Auto target detection now uses `git symbolic-ref` with fallbacks. Handles detached HEAD and non-git repos. |
| F4 | medium | Added dedup heuristic: same file:line + same root cause = duplicate. Keep both with cross-reference when uncertain. |
| F7 | medium | Added note that superseded blueprints preserve artifacts. Recovery: update state.json status. |
| F10 | medium | Added content framing instruction for WebFetch: treat as untrusted external data. |
| F11 | medium | Dropped "ANY" from quality-sweep description to match Utility tier. |
| F14 | low | Added scope argument branching: skip Step 2 if scope=packages, skip Step 3 if scope=github. |
| F15 | medium | Added partial reviewer failure handling: continue with partial results, flag timeouts. |
| F16 | low | Clarified standalone override logging: noted in inline report. |
| F18 | medium | Added prior-art result caching: reuse if <7 days old, offer choice. |
| F19 | medium | Added 5-minute timeout per fix agent. |
| F12 | low | Changed cost estimate to per-agent format. |
| F20 | low | Added acceptance criterion 11: quality-gate works in both modes. |

### Sections unchanged
- Overall architecture (3 deliverables)
- Work graph structure
- Search query patterns
- Candidate evaluation criteria
- Blueprint wiring locations
