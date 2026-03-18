# Prior Art Report: Naksha-Inspired Improvements

## Problem
Three features for claude-sail (bash/markdown Claude Code toolkit): runtime self-diagnostic, YAML pipeline orchestration, behavioral evals.

## Stack
Bash, Markdown, YAML — no package manager, no build step

## Candidates

### Feature 1: /sail-doctor

| Candidate | Fit | Maturity | Integration | Risk | Notes |
|-----------|-----|----------|-------------|------|-------|
| `claude doctor` (built-in) | Medium | High | N/A | Low | Checks system install, not plugin-specific state |
| naksha-studio `/naksha-doctor` | High | Medium | Low | Low | Direct inspiration; not adoptable (different domain) |

**Verdict:** Build. Built-in `/doctor` doesn't validate plugin install integrity, hook wiring, or toolkit settings drift.

### Feature 2: /pipeline

| Candidate | Fit | Maturity | Integration | Risk | Notes |
|-----------|-----|----------|-------------|------|-------|
| claude-pipeline | Low | Medium | Low | Low | Hardcoded bash scripts, not declarative YAML |
| Claude-Code-Workflow | Low | Low | Low | Medium | Heavyweight JSON-driven framework, overkill |
| naksha-studio `/pipeline` | High | Medium | Low | Low | Direct inspiration; simple YAML schema to replicate |

**Verdict:** Build. No existing tool provides simple YAML pipeline definitions for chaining Claude Code slash commands.

### Feature 3: Behavioral Evals

| Candidate | Fit | Maturity | Integration | Risk | Notes |
|-----------|-----|----------|-------------|------|-------|
| promptfoo | Medium | High | Low | Medium | Requires Node.js (violates no-dep constraint), tests live LLM calls |
| naksha-studio `behavioral-smoke.sh` | High | Medium | Low | Low | Bash-native fixture testing; exact pattern to replicate |
| TracePact | Low | Low | Low | Medium | Runtime behavioral testing, not fixture-based |

**Verdict:** Build. Promptfoo is closest but requires Node.js and tests live calls. We need bash-native fixture validation.

## Overall Recommendation: BUILD (informed by Naksha patterns)

All three features occupy a niche: bash-native, no-dependency, Claude Code plugin-specific. No existing solution is adoptable.

### Patterns Worth Borrowing
- Naksha YAML pipeline schema: `steps`, `pass-output-as`, `on-error`
- Naksha fixture smoke tests: keyword grep + structural thresholds
- Naksha doctor: plugin-specific diagnostics with `--fix` flag
- Promptfoo assertion taxonomy: `contains`, `regex`, `min-length` types

### Key Discovery
Claude Code has a built-in `claude doctor` / `/doctor` that checks system-level health. Our `/sail-doctor` must be positioned as **toolkit health** (claude-sail install integrity) not system health, to avoid confusion and redundancy.
