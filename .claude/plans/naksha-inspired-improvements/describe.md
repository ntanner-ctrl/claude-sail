# Describe: Naksha-Inspired Improvements

## Summary

Add three new capabilities to claude-sail, inspired by analysis of naksha-studio (github.com/Adityaraj0421/naksha-studio). These strengthen the core toolkit without adding domain knowledge.

## Features

### Feature 1: `/sail-doctor` — Runtime Self-Diagnostic
Runtime health check command that validates installed state inside a Claude session. Checks file counts, hook wiring in settings.json, MCP availability, settings drift, and target project health. Optional `--fix` flag provides remediation guidance.

### Feature 2: `/pipeline` — Declarative Workflow Chains
YAML-defined multi-step workflow orchestration. Subcommands: `list`, `show <name>`, `run <name>`. Pipelines live in `.claude/pipelines/*.yaml`. Context passes between steps via `pass-output-as` directives. Configurable error handling (`on-error: stop`).

### Feature 3: Behavioral Evals
Fixture-based testing of command reasoning. Structured eval entries (`evals/evals.json`) with prompts and assertions. Reference output fixtures in `evals/fixtures/`. Shell script validates fixtures against keyword/structural thresholds. Integrated into `test.sh`.

## Steps (14 discrete actions)

### /sail-doctor (4 steps)
1. Create `commands/sail-doctor.md` — command definition
2. Create `scripts/sail-doctor-checks.sh` — deterministic shell checks
3. Update `test.sh` — structural tests for new command/script
4. Update `README.md` and `commands/README.md`

### /pipeline (5 steps)
5. Create `commands/pipeline.md` — command definition with subcommands
6. Create example pipelines in `commands/templates/stock-pipelines/`
7. Update `bootstrap-project.md` — pipeline awareness for target projects
8. Update `test.sh` — YAML validation and structural tests
9. Update `README.md` and `commands/README.md`

### Behavioral Evals (5 steps)
10. Create `evals/evals.json` — structured eval entries
11. Create `evals/fixtures/` — reference output files
12. Create `scripts/behavioral-smoke.sh` — fixture validation script
13. Integrate into `test.sh` — add eval test category
14. Update `README.md`

## Risk Assessment

- **Risk flags:** User-facing behavior change (3 new commands)
- **No destructive risk** — additive only
- **Convention compliance critical** — must match existing command/hook/test patterns

## Triage

- **Path:** Full
- **Execution preference:** Auto
- **Parallelization potential:** High — 3 features are independent, shared touchpoints only at test.sh and README.md updates
