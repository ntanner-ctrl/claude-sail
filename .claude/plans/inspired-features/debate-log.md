# Family Debate Log: inspired-features

## Round 1

### Child-Defend (Generation 1)

**7 defended positions:**

1. **Env var hook toggles** — Self-cleaning by design (die with the shell), no persistent state leak. Alternative of config file toggles risks forgotten disables. The guard block is idempotent and adds no file I/O.

2. **Heuristic turn-count budget** — Honest about technical constraint (hooks can't see tokens). Turn count is proportional, directionally correct. Advisory-only preserves user agency. Append-only JSONL is crash-resilient.

3. **Baseline-as-convention** — Right posture when you don't own a dependency. The field serves immediate documentation purpose even before enforcement. `SAIL_BASELINE_OVERRIDE=1` with audit logging is a mature tradeoff.

4. **`/retro` reads from heterogeneous sources** — Unix philosophy: don't own data that already exists. Graceful degradation means it works with whatever's available. Creates a data flywheel — each feature's output becomes retro input.

5. **Shell hook enforcement for `/freeze`** — Deterministic enforcement vs behavioral guidance. Core defense-in-depth lesson: CLAUDE.md can be argued around, hooks cannot. The reason field makes block messages actionable.

6. **Claude-as-pattern-detector in `/evolve`** — Right division of labor. Natural language clustering is what LLMs do well. Gets better as Claude improves. Avoids forcing rigid taxonomy onto log entries.

7. **Shared `audit-log.sh`** — DRY for a domain where inconsistency has real costs. One place for JSON schema, fail-open contract, and session ID lookup. Prevents schema drift across hooks.

---

### Child-Assert (Generation 1)

**8 challenges identified:**

1. **`/retro` assumes JSONL log files that don't exist** — HIGH confidence. `/log-error` writes markdown to `.claude/error-logs/`, not JSONL. `/log-success` writes to `.claude/success-logs/`. The data sources `/retro` depends on aren't there. Learning loop breaks silently.

2. **Baseline rules deliver appearance of enforcement without enforcement** — HIGH confidence. Hookify plugin doesn't read `baseline: true`. Acceptance criteria treat this as a guardrail when it's just documentation. Force-push protection could still be disabled.

3. **`audit-log.sh` uses `$CLAUDE_PROJECT_DIR` which doesn't exist** — HIGH confidence. No existing hook uses this variable. Fallback to `.` writes audit log to wrong directory. `/audit` finds nothing.

4. **Shared `source` pattern fails silently on missing file** — MEDIUM confidence. If `audit-log.sh` isn't installed, `source` fails silently under `set +e`, `audit_block` calls become "command not found" — also silent. Audit system fails without any indication.

5. **`BASH_SOURCE[0]` hook name extraction** — LOW confidence. Works correctly given existing `#!/bin/bash` shebangs.

6. **`/evolve` hookify rule write path is ambiguous** — MEDIUM confidence. `hookify-rules/` is relative — writes to project dir (wrong) or `~/.claude/` (global scope affects all projects). Neither is obviously correct.

7. **Budget turn-count heuristic can be off by 10-50x** — MEDIUM confidence. Subagent-heavy sessions consume vastly more tokens than turn count suggests. Soft limit has no mechanism to actually limit.

8. **Command count arithmetic says "5 new" but lists 6** — HIGH confidence. Factual error: budget, retro, freeze, unfreeze, evolve, audit = 6. Final number (61) is correct but the "5 new" label is wrong.

---

### Mother — Strength Synthesizer (Generation 2)

**Summary Map:**

| Feature | Defender Strength | Challenger Strength | Priority |
|---|---|---|---|
| Hook Toggles | Design is correct | Non-issue surfaced | Ship as-is |
| Budget | Honest heuristic framing | UX labeling misleads | Rename to "awareness", not "limit" |
| Baseline | Right posture for unowned deps | Acceptance criteria overclaim | Rewrite criteria to match reality |
| Retro | Graceful degradation design | Data sources don't exist as specified | Fix log format before implementing |
| Freeze | Hook > behavioral guidance | (No challenge) | Ship as-is; verify tool input field names |
| Evolve | LLM as pattern detector | Write path ambiguous; same log format gap | Decide write scope; fix log format first |
| Audit | DRY shared function | Env var + silent source failures | Fix two specific bugs before shipping |
| Count math | (N/A) | "5 new" should be "6 new" | Fix label; note audit-log.sh in test.sh |

**Three blocking issues that affect multiple features:**
1. `/log-error` and `/log-success` write markdown files to directories, not JSONL — breaks `/retro` AND `/evolve`
2. `$CLAUDE_PROJECT_DIR` doesn't exist in hook environment — breaks all audit logging
3. Baseline acceptance criteria overclaim enforcement that doesn't exist

**Key synthesis points:**
- Budget: rename from "limit" to "awareness" throughout — labeling is the issue, not the design
- Baseline: rewrite acceptance criteria to match what actually ships (convention, not enforcement)
- Audit: replace `$CLAUDE_PROJECT_DIR` with `git rev-parse --show-toplevel 2>/dev/null || pwd`; add guard after `source` call
- Evolve: decide if hookify rules are project-local or global, document the scope explicitly
- Freeze: verify `tool_input.file_path` field name against actual Claude Code tool schemas

---

### Father — Weakness Analyst & Guide (Generation 2)

**Confidence assessment: Spec is 70% ready.**

**Architecture is sound throughout. No features need to be dropped.**

**Required changes (must fix before implementation):**

1. **Features 4 & 6 data sources** — Remove JSONL assumptions; read from `.claude/error-logs/*.md` and `.claude/success-logs/*.md` instead. Claude can parse markdown directly — this actually simplifies the implementation.

2. **`audit-log.sh` project dir** — Replace `$CLAUDE_PROJECT_DIR` with `git rev-parse --show-toplevel 2>/dev/null || pwd` (established pattern in existing hooks).

3. **Audit source dependency** — Add post-source guard or inline `audit_block` to eliminate silent-failure risk.

4. **Baseline acceptance criteria** — Rewrite to be honest: "convention signal, not enforcement." Remove `SAIL_BASELINE_OVERRIDE` or label as "reserved for future enforcement" — documenting an escape hatch for a lock that doesn't exist is security theater.

5. **Command count label** — "5 new" → "6 new" (factual error).

**Recommended changes (improve quality but not blocking):**

6. **`/evolve` write path** — Define explicit scope: `~/.claude/hookify-rules/` with project-namespaced filenames (e.g., `hookify.[project].[pattern].local.md`).

7. **Budget subcommand verb** — Rename `set` to `threshold` or add explicit advisory warning. Cap precision to avoid false confidence (~50 turns, not 47).

8. **Hook toggle profile note** — Warn that `.bashrc` export breaks session-scope guarantee.

**What should stay unchanged:**
- Env var toggle design
- Shell hook enforcement for `/freeze`
- Claude-as-pattern-detector for `/evolve`
- Shared `audit-log.sh` DRY pattern
- Append-only JSONL for budget and audit
- Maturation tier alignment with `/promote-finding`

**Unresolved tension:** `/evolve` global-vs-local scope needs a decision, not just a direction.

---

### Elder Council (Generation 3)

**Vault research:** 7 relevant historical analogies found across Findings, Decisions, and Patterns.

**Key historical validations:**
- `source-of-truth-drift` pattern directly validates fixing the JSONL assumption and baseline overclaiming
- `shell-correctness-traps` pattern validates fixing `$CLAUDE_PROJECT_DIR` (silent wrong-directory writes)
- `posttooluse-cant-capture-prose` finding validates Feature 2's decision NOT to use hooks for budget
- `build-native-epistemic-tracking` decision validates "simpler plumbing wins" philosophy
- `documentation-coupling` finding warns against claiming behavior that doesn't exist (baseline)
- `claude-md-context-budget` finding warns that CLAUDE.md additions have real context cost

**Elder-specific strengthening:**
- Audit `source` pattern should use no-op fallback: `audit_block() { :; }` before `source`, so missing file produces harmless no-op rather than undefined command

**Father review — all 8 changes accepted:**
1. Read markdown files (STRONG support)
2. `git rev-parse --show-toplevel` (STRONG support — 3 hooks already use it)
3. Post-source guard (STRONG support, strengthened with no-op pattern)
4. Rewrite baseline criteria, remove `SAIL_BASELINE_OVERRIDE` (STRONG support)
5. Count label fix (NEUTRAL — trivial)
6. `/evolve` project-namespaced filenames (MILD WARNING — add human confirmation)
7. Budget naming (SUPPORTED)
8. Hook toggle .bashrc warning (NEUTRAL)

**VERDICT: CONVERGED** (confidence: 0.85)
No historical red flags remain. Architecture follows validated patterns.

---

## Round 1 — Edge Cases (Stage 4)

### Child-Defend (Edge Cases)

**12 defended boundary positions.** Key findings:
- Comma pattern matching handles malformed input correctly (double commas, trailing commas)
- `BASH_SOURCE[0]` empty → fail-open (hook runs normally)
- Fail-open architecture naturally protects most missing-file scenarios
- JSON injection in audit snippets is tolerable because sources are constants and JSONL line independence limits blast radius
- No-op fallback pattern correctly handles missing `audit-log.sh`
- Budget heuristic divergence is honestly labeled — correct response is transparency, not false precision

**Two genuine gaps acknowledged as acceptable:**
- `.bashrc` export persistence — documentation is proportionate mitigation
- JSON injection in audit snippets — tolerable given constant sources

### Child-Assert (Edge Cases)

**27 boundary challenges.** Top 12 by confidence:

| ID | Feature | Issue | Confidence |
|----|---------|-------|-----------|
| B19 | Audit | `command_snippet` with quotes → invalid JSON → audit.jsonl unreadable | HIGH |
| B13 | Freeze | Relative vs. absolute path mismatch → freeze bypassed | HIGH |
| B16 | Freeze | Trailing slash mismatch → unfreeze silently does nothing | HIGH |
| B18 | Freeze | Crash leaves frozen dirs → blocks next session with no warning | HIGH |
| B25 | Cross-cutting | Mixed UTC vs. local timestamps → wrong --days filtering | HIGH |
| B1 | Toggle | Whitespace in env var → hook not disabled | HIGH |
| B10 | Retro | --days filtering inconsistent across data sources | HIGH |
| B11 | Retro | Filesystem mtime reset on restore → misleading retro window | HIGH |
| B22 | Audit | WSL2 CRLF in .current-session → \r in session_id | HIGH (WSL2) |
| B27 | Freeze | jq absent → freeze silently bypassed | HIGH |
| B4 | Budget | Concurrent /end calls → partial JSONL line | HIGH |
| B3 | Toggle | Export persistence outlives session intention | HIGH |

**Three architecture-level findings requiring spec language:**
1. B13: Freeze guard must resolve both paths to absolute before comparison
2. B19: Audit log must use jq for JSON construction, not printf
3. B25: All timestamps must standardize on UTC with Z suffix
