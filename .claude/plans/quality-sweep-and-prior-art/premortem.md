# Pre-Mortem: quality-sweep-and-prior-art

## Premise

These commands were released two weeks ago and failed. This is the post-mortem.

## Most Likely Single Cause of Failure

No file-existence acceptance criteria. The spec produced behavioral tests but never verified the files were actually created at the expected paths. For a toolkit where "deployment" is file copying, existence is the foundational precondition.

## Contributing Factors

1. **blueprint.md insertion not verifiable** — Prose insertion into 1500+ line file with no searchable landmark
2. **Emoji/text severity mismatch** — Reviewer agents use emoji markers, quality-sweep parses text keywords. Fallback silently defaults everything to medium.
3. **WebSearch as core dependency** — Gate skips when WebSearch unavailable, which may be common in restricted environments
4. **Utility tier means skip under pressure** — Intentional design choice, but means quality-sweep adoption depends on habit formation

## Findings

| ID | Finding | Classification | Severity | Action Taken |
|----|---------|---------------|----------|--------------|
| PM-1 | No file-existence acceptance criteria | NEW | HIGH | Added criteria 12-15 to spec |
| PM-2 | Blueprint.md insertion not grep-verifiable | NEW | MEDIUM | Added criteria 14-15 to spec |
| PM-3 | Emoji/text severity mismatch unresolved by F2 fix | COVERED (insufficient) | MEDIUM | Updated agent interface contract with multi-format parsing |
| PM-4 | WebSearch unavailability = gate always skips | NEW | MEDIUM | Noted for implementation — consider vault fallback |
| PM-5 | Utility tier = routinely skipped | NEW | LOW | Monitor adoption, elevate if needed |
