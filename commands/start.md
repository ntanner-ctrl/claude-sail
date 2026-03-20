---
description: Use at the START of any session to orient. Assesses project state and recommends the optimal next action.
---

# Where to Begin

Quickly assess project state and recommend the optimal next task.

## Instructions

1. **Check active work** (first):
   - If `.claude/state-index.json` exists, read it for active plans/TDD/checkpoints
   - If active work exists, show `/dashboard`-style summary before git assessment
   - If a checkpoint exists, surface its `next_action` as the recommended task

2. **Query vault for prior knowledge** (fail-soft — skip if vault unavailable):
   - Use the Bash tool to source vault config:
     ```bash
     source ~/.claude/hooks/vault-config.sh 2>/dev/null && echo "VAULT_ENABLED=$VAULT_ENABLED" && echo "VAULT_PATH=$VAULT_PATH"
     ```
   - If vault is available (`VAULT_ENABLED=1` and `VAULT_PATH` is set):
     - Get project name from git repo basename: `basename $(git rev-parse --show-toplevel 2>/dev/null)`
     - Use Grep tool to search `$VAULT_PATH` for `"^project: PROJECT_NAME"` in `*.md` files
     - Focus on `Engineering/Findings/` and `Engineering/Decisions/` directories
     - For up to 5 most recent matches, read frontmatter to extract:
       - `epistemic_confidence` scores if present
       - `epistemic_status` values (flag any marked `stale` or `contradicted`)
       - Brief summary of the finding/decision
     - Present vault context summary (see output format below)
   - If vault is unavailable, note: "No vault configured — skipping prior knowledge lookup"
   - If vault is available but no matches found, note: "No prior vault knowledge for this project"
   - If an epistemic session is active (`~/.claude/.current-session` exists), suggest submitting preflight with vault context:
     ```
     Epistemic session active. Submit /epistemic-preflight now with prior vault context:
       - N findings (M high-confidence, K need verification)
       - P decisions
     ```

3. **Check epistemic calibration** (fail-soft — skip if unavailable):
   - Check for epistemic data:
     ```bash
     cat ~/.claude/.current-session 2>/dev/null || echo "NO_SESSION"
     jq -r '.calibration | to_entries[] | select((.value.observation_count >= 5) and ((.value.correction > 0.05) or (.value.correction < -0.05))) | "\(.key): correction \(.value.correction) — \(.value.behavioral_instruction)"' ~/.claude/epistemic.json 2>/dev/null || echo "NO_CALIBRATION"
     ```
   - If calibration data exists, note any corrections (e.g., "You tend to overestimate `know` — read more files before rating high")
   - The SessionStart hook already injects calibration context, but `/start` provides a second chance to review it
   - If no epistemic data available, skip silently

4. **Assess current state** (in parallel):
   - `git status` - Check for uncommitted changes
   - `git log -3 --oneline` - Review recent commits
   - Check for existing to-do list items
   - Scan for TODO/FIXME comments in recently modified files

5. **Identify what's pending**:
   - Uncommitted work in progress
   - Failed tests or build issues
   - Open to-do items from previous sessions
   - Obvious next steps from recent commits

6. **Recommend the optimal next task**:
   - State the single most impactful thing to work on
   - Explain briefly why this is the priority
   - Estimate complexity (quick fix vs. significant work)

7. **Offer alternatives**:
   - If the recommendation doesn't fit, list 2-3 other options

## Output Format

```
## Current State
[Brief summary of git status, recent work]

## Prior Vault Knowledge
[If vault available and matches found:]
  Found N findings, P decisions for PROJECT_NAME:
  - [Finding title] (confidence: 0.X) [STALE if applicable]
  - [Decision title] (confidence: 0.X)
  ...
  Preflight suggestion: Submit with context above.
[If vault unavailable: "No vault configured — skipped"]
[If no matches: "No prior vault knowledge for this project"]

## Cross-Project Insights
[If epistemic tracking available and global findings found:]
  Calibration: [adjustment summary, e.g., "you overestimate change by 10%"]
  From other projects:
  - [Finding summary] (project: X, impact: 0.Y)
  ...
[If no epistemic data or no relevant findings: omit section]

## Recommended Next Task
**[Task description]**
Why: [1-2 sentence rationale]
Complexity: [Quick/Medium/Significant]

## Alternatives
- [Option 2]
- [Option 3]
[If vault context was displayed above:]
- Search deeper: /vault-query [topic]
- Full command index: /toolkit
[If .claude/frozen-dirs.json exists and is non-empty:]
- ⚠️ N directories frozen from a previous session. Run /unfreeze --all to clear.
[If .claude/budget-config.json exists:]
- Budget awareness target: ~N turns (/budget to review)
[If .claude/error-logs/ or .claude/success-logs/ has 5+ files:]
- Consider running /evolve to synthesize patterns from logged errors/successes
[If .claude/budget.jsonl has 5+ entries:]
- Consider running /retro for a retrospective on recent sessions
```

---

$ARGUMENTS
