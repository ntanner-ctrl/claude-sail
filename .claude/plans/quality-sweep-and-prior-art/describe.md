# Describe: quality-sweep-and-prior-art

## Change Summary

Add two new standalone commands (`/prior-art` and `/quality-sweep`) to claude-sail, plus wire them into the blueprint workflow.

- `/prior-art` — Searches GitHub repos and package registries for existing solutions. Reports findings with build-vs-adopt recommendation. Gated in blueprint DEFINE (must complete before Stage 2).
- `/quality-sweep` — Post-implementation metaworkflow. Orchestrates existing reviewer agents (spec, quality, security, performance, architecture) in a sweep → triage → fix cycle. Suggested at blueprint Stage 7 completion.

## Discrete Steps

1. Create `commands/prior-art.md` — standalone reference-first research command
2. Create `commands/quality-sweep.md` — standalone post-implementation review orchestrator
3. Modify `commands/blueprint.md` — gate `/prior-art` in Stage 1 (DEFINE), between describe and Stage 2
4. Modify `commands/blueprint.md` — suggest `/quality-sweep` in Stage 7 completion section
5. Update `commands/README.md` — add entries for both new commands
6. Update `README.md` — add commands to "Commands at a Glance", update count 47 → 49

## Risk Flags

- [x] User-facing behavior change — new gate in blueprint DEFINE affects all future blueprints

## Triage

- **Steps:** 6
- **Risk flags:** 1
- **Path:** Full
- **Execution preference:** Auto

## Context

- Brainstormed in conversation: reference-first inspired by godmode, quality sweep inspired by desloppify
- Vault finding supports concept: `Engineering/Findings/2026-02-20-blueprint-post-implementation-validation.md` — post-implementation adversarial review catches different things than spec review
- Existing reviewer agents (5): spec-reviewer, quality-reviewer, security-reviewer, performance-reviewer, architecture-reviewer
- Existing quality infrastructure: `/quality-gate` (scoring rubric), `/review` (adversarial analysis)
- No new dependencies required — pure markdown commands
