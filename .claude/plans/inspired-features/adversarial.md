# Adversarial Findings: inspired-features

## Family Round 1

### Synthesis (Mother)

Three blocking issues affect multiple features:
1. `/log-error` and `/log-success` write markdown files to directories, not JSONL — breaks `/retro` AND `/evolve`
2. `$CLAUDE_PROJECT_DIR` doesn't exist in hook environment — breaks all audit logging
3. Baseline acceptance criteria overclaim enforcement that doesn't exist

### Analysis (Father)

**Confidence: Spec is 70% ready. Architecture sound, five required fixes.**

Required changes:
1. Remove JSONL assumptions from Features 4 & 6; read `.claude/error-logs/*.md` and `.claude/success-logs/*.md`
2. Replace `$CLAUDE_PROJECT_DIR` with `git rev-parse --show-toplevel 2>/dev/null || pwd`
3. Add no-op fallback + post-source guard for `audit-log.sh` dependency
4. Rewrite baseline acceptance criteria to "convention signal, not enforcement"; remove `SAIL_BASELINE_OVERRIDE`
5. Fix command count: "5 new" → "6 new"

Recommended changes:
6. `/evolve` writes to `~/.claude/hookify-rules/` with project-namespaced filenames + human confirmation
7. Budget: rename `set` to `threshold`; cap displayed precision
8. Hook toggles: warn that `.bashrc` export breaks session-scope guarantee

### Historical Review (Elder Council)

| Vault Source | Lesson | Relevance |
|---|---|---|
| source-of-truth-drift | Every phantom data format assumption is a future silent failure | Validates fixing JSONL assumption + baseline honesty |
| shell-correctness-traps | Silent failures under set +e are the common hook signature | Validates fixing $CLAUDE_PROJECT_DIR |
| posttooluse-cant-capture-prose | Hooks cannot access what they need | Validates budget NOT using hooks |
| build-native-epistemic-tracking | Simpler plumbing wins | Validates reading existing markdown vs inventing JSONL |
| documentation-coupling | Ghost references from claiming non-existent behavior | Warns against baseline overclaiming |
| claude-md-context-budget | Every CLAUDE.md line costs context | Budget awareness section must be minimal |
| poison-pill-prevention | No-op fallback before source | Strengthens audit-log.sh pattern |

**Elder Verdict:** CONVERGED
**Confidence:** 0.85
**Carry Forward:** None — all blocking issues have clear, historically-validated fixes.

---

## Consolidated Findings (ordered by severity)

| ID | Finding | Severity | Convergence | Status |
|----|---------|----------|-------------|--------|
| F1 | `/retro` and `/evolve` assume JSONL format that doesn't exist — log commands write markdown files | critical | both-agreed | needs-spec-update |
| F2 | `$CLAUDE_PROJECT_DIR` doesn't exist in hook environment — audit log writes to wrong directory | critical | both-agreed | needs-spec-update |
| F3 | Baseline acceptance criteria claim enforcement that hookify plugin doesn't implement | high | both-agreed | needs-spec-update |
| F4 | `SAIL_BASELINE_OVERRIDE` is an escape hatch for a lock that doesn't exist — security theater | high | both-agreed | needs-new-section |
| F5 | `audit-log.sh` source failure is silent — audit system fails without indication | medium | both-agreed | needs-spec-update |
| F6 | `/evolve` hookify rule write path is ambiguous (project-local vs global) | medium | both-agreed | needs-spec-update |
| F7 | Budget "set" verb implies enforcement; turn-count heuristic can be 10-50x off | medium | both-agreed | needs-spec-update |
| F8 | Command count says "5 new" but lists 6 items | low | both-agreed | needs-spec-update |
| F9 | Hook toggle `.bashrc` export breaks session-scope guarantee | low | newly-identified | needs-new-section |
| F10 | CLAUDE.md budget awareness section has real context cost — keep minimal | low | newly-identified | needs-spec-update |

## Edge Case Findings (Stage 4 — Family Round 1)

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| B19 | `command_snippet` with quotes → invalid JSON via printf — use jq --arg | critical | needs-spec-update |
| B13 | Freeze: relative vs absolute path mismatch → freeze bypassed | critical | needs-spec-update |
| B16 | Freeze: trailing slash mismatch → unfreeze silently does nothing | high | needs-spec-update |
| B27 | Freeze: jq absent → freeze silently bypassed — document as optional dep | high | needs-spec-update |
| B25 | All timestamps must standardize on UTC with Z suffix | high | needs-spec-update |
| B22 | WSL2 CRLF in session_id — add tr -d '\r' | medium | needs-spec-update |
| B1 | Whitespace in SAIL_DISABLED_HOOKS → hook not disabled | medium | implementation-note |
| B18 | Crash leaves frozen dirs — warn at session start | medium | implementation-note |
| B10 | /retro --days filtering inconsistent — need frontmatter dates in logs | medium | implementation-note |

**Elder addition:** jq-as-dependency contradicts no-dependency constraint — resolve as "optional enhancement" (graceful degradation without jq).

**Elder Verdict:** CONVERGED (confidence: 0.90)

## Pre-Mortem Findings (Stage 4.5)

| ID | Finding | Severity | Status |
|----|---------|----------|--------|
| PM1 | Existing users' settings.json won't have freeze-guard.sh wired — freeze provides no protection on upgrade | high | NEW |
| PM2 | audit-log.sh in hooks/ dir is confusable with wireable hooks — naming convention needed | medium | NEW |
| PM3 | No upgrade testing in test.sh — first-install tested but not v0.9→v0.10 upgrade path | medium | NEW |
| PM4 | Settings.json changes on upgrade need explicit documentation | medium | NEW |
