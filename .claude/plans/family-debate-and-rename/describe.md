# Describe: family-debate-and-rename

## Change Summary

Two related changes to the claude-bootstrap toolkit:

1. **Rename `/simplify-this` → `/overcomplicated`** — Same complexity-challenge workflow, new name that avoids collision with Anthropic's built-in `/simplify` skill and better describes the trigger ("this feels overcomplicated").

2. **Add "family" challenge mode to `/blueprint`** — A six-role generational debate architecture:
   - **Children** (parallel): Child-Defend and Child-Assert receive the spec with opposing mandates
   - **Parents** (serial): Mother synthesizes strengths from both, Father finds weaknesses and refines the spec
   - **Elders** (serial/combined): Query Obsidian vault for historical analogies, validate against past project experience, issue convergence verdict
   - Loop continues until elders declare convergence or cap is reached

3. **Wire `/overcomplicated` into blueprint adversarial phase** — Add as a step in Stage 3 (Challenge) after the debate.

4. **Wire Anthropic's `/simplify` into blueprint completion** — Suggest as a post-implementation cleanup step at Stage 7.

## Discrete Steps

### Track A: Rename (mechanical, parallelizable)
1. Rename `commands/simplify-this.md` → `commands/overcomplicated.md`
2. Update internal content of renamed file (headers, self-references)
3. Update cross-references in `commands/devils-advocate.md`
4. Update cross-references in `commands/edge-cases.md`
5. Update cross-references in `commands/review.md`
6. Update cross-references in `commands/toolkit.md`
7. Update `commands/README.md` (table entry + example)
8. Update `README.md` (adversarial category table + pipeline diagram)
9. Update `GETTING_STARTED.md` (uninstall cleanup line)

### Track B: Family challenge mode (creative, sequential)
10. Wire `/overcomplicated` into `commands/blueprint.md` adversarial phase
11. Design family debate protocol (6 roles with personas)
12. Define convergence/stop conditions for the family loop
13. Define Obsidian vault query integration for Elder agents
14. Write family challenge mode specification into `commands/blueprint.md`
15. Wire Anthropic's `/simplify` as post-implementation suggestion
16. Update blueprint challenge mode selection to include `--challenge=family`

## Risk Assessment

- **User-facing behavior change**: Command rename affects muscle memory and any external documentation that references `/simplify-this`. Mitigated by: clear rename, no functional change, install.sh auto-updates.
- **Blueprint modification risk**: Changing the primary planning workflow's challenge modes. Mitigated by: family mode is additive (new option), doesn't modify existing debate/vanilla/team modes.
- **Vault dependency**: Elder agents depend on Obsidian MCP being available. Mitigated by: graceful degradation (if vault unavailable, elders skip historical queries and operate on current-spec-only analysis).

## Triage

- **Steps:** 16
- **Risk flags:** User-facing behavior change
- **Execution preference:** Auto
- **Recommended path:** Full
- **Date:** 2026-03-03
