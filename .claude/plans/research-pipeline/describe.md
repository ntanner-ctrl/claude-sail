# Describe: research-pipeline

## What is Changing

A two-part change that splits the investigation concern from the planning concern in claude-sail's workflow portfolio:

### Part 1: New `/research` Command
A structured investigation workflow that formalizes the ad-hoc research phase before blueprinting. Progressive structure: freeform findings → synthesis brief. Vault-first storage. Clean handoff artifact for downstream consumers.

### Part 2: Blueprint Restructure (Heavy)
Refocus blueprint's `describe` stage on solution scoping. Refocus ambiguity gate on solution clarity. Migrate prior-art gate to research. Establish conditional stage inclusion: blueprint's pre-stage investigative steps (brainstorm, prior-art, requirements-discovery) are skipped when a research brief is present, run when absent.

### Part 3: Establish Optional-Enrichment Pattern
A reusable design convention for inter-workflow communication: "check for artifact → enrich if present → proceed normally if absent." First instance at the research→blueprint seam, designed as template for future seams.

### Part 4: Deprecate `/clarify`
Research absorbs 3 of 4 clarify sub-steps (brainstorm, prior-art, requirements-discovery). Design-check remains standalone in blueprint. No orphaned clarification concern remains.

## Steps

1. Design the `/research` command — stages, state management, vault integration, synthesis format
2. Design the research brief artifact format — structured enough for consumers to determine coverage
3. Design the optional-enrichment pattern — reusable convention for inter-workflow consumption
4. Design parameterized ambiguity gate — base gate concept with problem-clarity and solution-clarity rubrics
5. Refactor blueprint's describe stage — solution scoping focus, consumes research brief when present
6. Migrate prior-art gate from blueprint to research
7. Implement conditional stage inclusion in blueprint — skip investigative steps when research brief present
8. Deprecate `/clarify` — soft deprecation with redirect message
9. Update `/clarify` wizard state management to handle deprecation gracefully
10. Update tests — test.sh count changes, new command validation, deprecation check
11. Update README/docs — command counts, architecture docs, lifecycle coverage map

## Risk Scan

- [x] User-facing behavior change — blueprint's describe stage changes behavior, /clarify deprecated
- All other risk categories: no

## Path Determination

| Steps | Risk Flags | Path |
|-------|------------|------|
| 11    | 1          | **Full** |

Full path: new command + restructure of most complex existing command + new cross-cutting pattern + deprecation.

## Decisions Made During Describe

1. **Heavy unburdening** — blueprint's describe refocused on solution scoping, not just "add research and leave blueprint alone"
2. **Optional enrichment, not dependency** — blueprint works without research output, enhanced with it
3. **Conditional stage inclusion** — blueprint skips brainstorm/prior-art/requirements when research brief present
4. **Design-check stays with blueprint** — it's implementation readiness, not problem investigation
5. **Deprecate /clarify (option C)** — cleanest separation; research + design-check cover all clarification concerns
6. **Parameterized ambiguity gate** — same mechanism, different rubrics for research vs blueprint
7. **Research brief as coverage manifest** — structured enough that consumers know which sub-steps were run

## Soft Nudge Design (Agreed)
When blueprint starts without a research brief:
- Soft nudge: "For complex investigations, consider `/research` first"
- Then proceed normally with pre-stage suggestions (brainstorm, prior-art, requirements)
- NOT a gate, NOT enforcement — awareness only
