# Adversarial Findings: family-debate-and-rename

## Devil's Advocate Review (Stage 3)

### Assumptions Identified

1. Anthropic's `/simplify` skill will remain stable and available
2. Obsidian MCP will be available when Elder Council agent runs
3. Five sequential agents per round will complete within 10 minutes
4. Vault contains enough historical content to be useful
5. Subagents can be invoked with specific model tiers (sonnet/opus)
6. Family mode produces genuinely different outputs than debate mode
7. `/overcomplicated` post-challenge won't create bloat-then-trim cycles
8. All `/simplify-this` references have been identified
9. Command rename won't break external user workflows
10. Family loop converges in ≤3 rounds
11. Elder Council JSON output will be reliably parseable
12. Mother/Father produce genuinely distinct analysis

### Gap Summary

| # | Challenge | Impact | Recommendation | Status |
|---|-----------|--------|----------------|--------|
| 1 | Per-agent timeout not specified | Medium | Add 3-min per-agent timeout | NEEDS SPEC UPDATE |
| 2 | Elder JSON parse failure no fallback | High | Mirror debate mode's JSON fallback chain | NEEDS SPEC UPDATE |
| 3 | Vault query flooding (too many matches) | Medium | Limit to 5 most relevant results | NEEDS SPEC UPDATE |
| 4 | No quality gate on Mother's synthesis | Low | Accept — Father filters naturally | ACCEPTABLE RISK |
| 5 | `/simplify` external dependency | Low | Add "skip if unavailable" note | NEEDS SPEC UPDATE |
| 6 | Mid-round compaction loses outputs | Medium | Write each agent output incrementally to debate-log.md | NEEDS SPEC UPDATE |
| 7 | No "zero vault results" behavior | Low | Add explicit prompt line | NEEDS SPEC UPDATE |
| 8 | Model ID stability | Low | Already uses tier names — acceptable | ACCEPTABLE RISK |
| 9 | Missed references | Low | Grep verification at implementation | IMPLEMENTATION NOTE |

### Verdict

**Address gaps** — 3 medium-impact + 1 high-impact issue need spec updates.
Architecture is fundamentally sound; these are hardening issues.

### Spec Updates Applied (Revision 1, in-place)

1. **Per-agent timeout** — Added 3-minute per-agent cutoff to Hard Limits (§3.4)
2. **Elder JSON fallback** — Added Elder Output Processing section with parse → keyword → default chain (§3.3.5)
3. **Vault query limits** — Added "limit each query to 5 most relevant results" + zero-results behavior (§3.3.5)
4. **Incremental output persistence** — Added section on writing agent output to debate-log.md immediately (§3.4)
5. **`/simplify` availability** — Added fallback note: skip silently if plugin unavailable (§5.2)
6. **Zero vault results** — Added explicit "No historical precedent found" behavior (§3.3.5)

All 6 NEEDS SPEC UPDATE items resolved. 2 ACCEPTABLE RISK items noted. 1 IMPLEMENTATION NOTE for grep verification.

## Edge Case Analysis (Stage 4)

### Edge Cases Found

| # | Edge Case | Risk | Status |
|---|-----------|------|--------|
| 1 | family_progress not reset between stages | M | FIXED — added stage field + explicit reset language |
| 2 | One child times out, Mother gets asymmetric input | M | FIXED — added Asymmetric Child Output section |
| 3 | Elder vault queries return stale results | L | ACCEPTABLE — Elder judges relevance naturally |
| 4 | /overcomplicated contradicts Father's direction | L | ACCEPTABLE — both advisory, user decides |
| 5 | Rename misses a reference | L | IMPLEMENTATION NOTE — grep verification |
| 6 | Short spec produces shallow debate | L | ACCEPTABLE — gated to Full path |
| 7 | Elder CONTINUE with empty carry_forward | M | FIXED — added Empty Carry-Forward Guard |

### Spec Updates Applied

1. **Asymmetric Child Output** — Mother plays devil's advocate when one child missing (§3.4)
2. **Empty Carry-Forward Guard** — CONTINUE without context treated as CONVERGED (§3.4)
3. **Stage-scoped family_progress** — Added `stage` field, explicit fresh-init per stage (§3.4)

### Verdict

**Well-bounded** — 3 medium-risk edge cases addressed. Remaining are low-risk with acceptable mitigations.
