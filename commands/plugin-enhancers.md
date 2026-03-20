---
description: Use when a workflow command reaches a plugin integration seam. Maps installed plugins to workflow enhancement options.
allowed-tools:
  - Read
---

# Plugin Enhancers — Registry & Detection Protocol

Reference command for plugin-to-workflow integration. Workflow commands (blueprint, review, dispatch) read this file at their plugin integration seams to determine what enhancements are available.

> **Users do not invoke this command directly.** It is read by other workflow commands at decision points.

---

## Section 1: Detection Protocol

All commands MUST use this exact protocol. No ad-hoc detection.

```
PLUGIN DETECTION PROTOCOL

Step 1: Read ~/.claude/plugins/installed_plugins.json
  - If file doesn't exist → no plugins installed, skip all enhancements
  - If file exists but read takes >3 seconds → abort detection, skip all enhancements
  - If JSON parsing fails → log "[PLUGIN] installed_plugins.json parse failed: <error>; skipping all enhancements", skip all enhancements

Step 2: Extract plugin names from the "plugins" object keys
  - Key format: "<plugin-name>@<marketplace-name>"
  - Extract the plugin name: everything BEFORE the first "@"
  - Match EXACTLY on the extracted prefix (not substring)
    Example: "pr-review-toolkit" matches "pr-review-toolkit@claude-code-plugins"
             "pr-review" does NOT match "pr-review-toolkit@claude-code-plugins"

Step 3: For each plugin needed at this seam, check if its extracted name exists
  - If detected → offer its capabilities (see slot mapping below)
  - If NOT detected → silently skip (no error, no warning, no log)
  - If detected but not in this registry → log "[PLUGIN] <name> installed but not in registry; skipping"

TIMEOUT: 3 seconds for file read. FALLBACK: Skip all enhancements.
```

**If this file (plugin-enhancers.md) does not exist:** Skip all plugin integration. Do not error. Workflow commands MUST check for this file's existence before attempting to read it.

---

## Section 2: Capability Slots

Abstract capabilities that plugins can fill at workflow seams:

| Slot | What It Provides | Phase | Used At |
|------|-----------------|-------|---------|
| `review:specialized` | Specialized review agents (multi-lens) | **Phase 1** | `/review`, `/dispatch`, Blueprint Stage 5 |
| `review:multi-model` | Multi-model consensus review | **Phase 1** | `/review`, Blueprint Stage 5 |
| `review:cross-platform` | Cross-platform adversarial (Claude+GPT) | existing | Blueprint Stage 5 (already `/gpt-review`) |
| `review:security-deep` | Deep security audit beyond standard lens | **Phase 1** | `/dispatch`, `/security-checklist`, Blueprint Stage 5, `/quality-gate` |
| `review:performance-deep` | Deep performance profiling beyond standard lens | **Phase 1** | `/dispatch`, `/quality-gate`, Blueprint Stage 5 |
| `review:code-quality` | Code review from additional perspectives | **Phase 1** | `/review`, `/dispatch`, Blueprint Stage 5 |
| `investigate:deep` | Deep code investigation and architecture tracing | Phase 2 | `/debug`, `/describe-change` |
| `execute:frontend` | Frontend-guided implementation | Phase 2 | Blueprint Stage 7, `/describe-change` |
| `execute:backend` | Backend-guided implementation | Phase 2 | Blueprint Stage 7, `/describe-change` |
| `execute:feature` | Technology-agnostic guided dev | Phase 2 | Blueprint Stage 7, `/describe-change` |
| `test:quality` | Test engineering and quality analysis | Phase 2 | `/test` Stage 3, `/tdd`, `/quality-gate` |
| `search:semantic` | Semantic code search | Phase 3 | `/bootstrap-project` setup |
| `iterate:loop` | Self-referential iteration loops | Phase 2 | Blueprint Stage 7 |

---

## Section 3: Plugin-to-Slot Mapping

### pr-review-toolkit (Phase 1)

**Fills:** `review:specialized`
**Tested with:** v1.0.0 (claude-code-plugins marketplace)
**Detection:** Check installed_plugins.json for key with prefix "pr-review-toolkit"

**Agents:**
- `pr-review-toolkit:silent-failure-hunter` — Identifies silent failures, inadequate error handling, inappropriate fallbacks
- `pr-review-toolkit:type-design-analyzer` — Analyzes type design for encapsulation, invariant expression, usefulness
- `pr-review-toolkit:pr-test-analyzer` — Reviews test coverage quality and completeness
- `pr-review-toolkit:comment-analyzer` — Checks comment accuracy, completeness, maintainability
- `pr-review-toolkit:code-simplifier` — Identifies simplification opportunities
- `pr-review-toolkit:code-reviewer` — Reviews for bugs, logic errors, security, code quality, conventions

**Invocation:**
```
Task(
  subagent_type: "pr-review-toolkit:<agent-name>",
  prompt: "<review context + file paths>"
)
```

Each agent receives: file paths to review + context summary.
Results: markdown format, advisory only.

**Dispatch rules:**
- Fast-fail probe: Before dispatching all 6 agents, dispatch ONE agent with a 10-second timeout.
  If the probe fails, skip remaining agents. Log: "[PLUGIN] pr-review-toolkit probe failed; skipping all agents"
- After probe succeeds: dispatch remaining agents in parallel (5-minute timeout per agent).
- Results: max 2000 tokens per agent. If exceeded, truncate and append `[truncated]`.

**If agent dispatch fails:**
  Log: `[PLUGIN] pr-review-toolkit:<agent> dispatch failed: <error>`
  User message: `Note: <agent> unavailable (dispatch failed), skipping.`
  Action: Skip this agent, continue with remaining agents.

**If agent times out:**
  Log: `[PLUGIN] pr-review-toolkit:<agent> timeout: 5m exceeded`
  User message: `Note: <agent> unavailable (timeout after 5min), skipping.`
  Action: Kill agent, continue with remaining agents.

### frontend (Phase 1 — review only)

**Fills:** `review:multi-model`
**Tested with:** v9271e6b66d4a (mag-claude-plugins marketplace)
**Detection:** Check installed_plugins.json for key with prefix "frontend"

**Phase 1 agents (review only):**
- `frontend:reviewer` — Senior code review against simplicity, AEI docs, OWASP, production-readiness

**Invocation:** Same pattern as pr-review-toolkit.

### security-pro (Phase 1 — review only)

**Fills:** `review:security-deep`
**Tested with:** claude-code-templates marketplace
**Detection:** Check installed_plugins.json for key with prefix "security-pro"

**Phase 1 agents (review only):**
- `security-pro:security-auditor` — Deep security review: vulnerabilities, authentication gaps, OWASP compliance, encryption

**Invocation:** Same pattern as pr-review-toolkit.

**Phase 2 agents (operational — not active):**
- `security-pro:penetration-tester` — Penetration testing and exploitation
- `security-pro:compliance-specialist` — Regulatory compliance assessment
- `security-pro:incident-responder` — Production incident handling

**Workflow seams (Phase 1):**
- `/dispatch --lenses deep-security` — Enhanced security lens
- `/security-checklist` — Deep audit augmentation
- `/quality-gate` — Security category (20 points) enhanced assessment
- Blueprint Stage 5 — Security-focused review option

### performance-optimizer (Phase 1 — review only)

**Fills:** `review:performance-deep`
**Tested with:** claude-code-templates marketplace
**Detection:** Check installed_plugins.json for key with prefix "performance-optimizer"

**Phase 1 agents (review only):**
- `performance-optimizer:performance-engineer` — Performance profiling, bottleneck identification, caching strategies, query optimization

**Invocation:** Same pattern as pr-review-toolkit.

**Phase 2 agents (operational — not active):**
- `performance-optimizer:load-testing-specialist` — Load testing scenarios and capacity analysis

**Workflow seams (Phase 1):**
- `/dispatch --lenses deep-perf` — Enhanced performance lens
- `/quality-gate` — Performance category (10 points) enhanced assessment
- Blueprint Stage 5 — Performance-focused review option

### superpowers (Phase 1 — review only)

**Fills:** `review:code-quality`
**Tested with:** v4.2.0 (claude-plugins-official marketplace)
**Detection:** Check installed_plugins.json for key with prefix "superpowers"

**Phase 1 agents (review only):**
- `superpowers:code-reviewer` — Methodology-based code review against project guidelines and best practices

**Invocation:** Same pattern as pr-review-toolkit.

**Note:** superpowers also provides 14+ methodology skills (brainstorming, systematic-debugging, test-driven-development, etc.) which are Phase 2 candidates for deeper workflow integration. Phase 1 uses only the code-reviewer agent.

**Workflow seams (Phase 1):**
- `/review` — Additional code review perspective
- `/dispatch --review` — Enhanced review pipeline
- `/dispatch --lenses methodology` — Methodology-based review lens
- Blueprint Stage 5 — Additional reviewer option

### feature-dev (Phase 1 — review; Phase 2 — execution)

**Fills:** `review:code-quality` (Phase 1), `execute:feature` (Phase 2)
**Tested with:** v1.0.0 (claude-code-plugins marketplace)
**Detection:** Check installed_plugins.json for key with prefix "feature-dev"

**Phase 1 agents (review only):**
- `feature-dev:code-reviewer` — Convention-focused code review with confidence-based filtering

**Invocation:** Same pattern as pr-review-toolkit.

**Phase 2 agents (execution — not active):**
- `feature-dev:code-architect` — Feature architecture design from existing codebase patterns
- `feature-dev:code-explorer` — Deep codebase analysis tracing execution paths

**Workflow seams (Phase 1):**
- `/review` — Convention-focused review perspective
- `/dispatch --review` — Enhanced review pipeline
- `/dispatch --lenses conventions` — Convention-based review lens
- Blueprint Stage 5 — Additional reviewer option

### Plugins Registered for Future Phases

### code-analysis (Phase 2 — investigation)

**Fills:** `investigate:deep`
**Tested with:** v9271e6b66d4a (mag-claude-plugins marketplace)
**Detection:** Check installed_plugins.json for key with prefix "code-analysis"

**Phase 2 agents:**
- `code-analysis:detective` — Deep code investigation, architecture tracing, usage pattern discovery, bug tracking

**Workflow seams (Wired):**
- `/debug` Phase 2 (HYPOTHESIZE) — Deep investigation to generate/validate hypotheses
- `/describe-change` — Automated codebase analysis for step decomposition
- Blueprint Stage 7 — Pre-implementation codebase understanding
- `/delegate` — Architecture-aware exploration tasks

### testing-suite (Phase 2 — test quality)

**Fills:** `test:quality`
**Tested with:** claude-code-templates marketplace
**Detection:** Check installed_plugins.json for key with prefix "testing-suite"

**Phase 2 agents:**
- `testing-suite:test-engineer` — Test automation, coverage analysis, CI/CD testing, quality engineering

**Workflow seams (Wired):**
- `/test` Stage 3 (Verify) — Enhanced tautology detection and coverage analysis
- `/tdd` REFACTOR phase — Test quality improvement
- `/quality-gate` — Tests category (20 points) enhanced assessment
- Blueprint Stage 6 (Test) — Enhanced test generation

### ralph-wiggum (Wired — verification loops)

**Fills:** `iterate:loop`
**Detection:** Check installed_plugins.json for key with prefix "ralph-wiggum"

**Workflow seams (Wired):**
- `/blueprint` Stage 7 (Execute) — Verification checkpoints during long implementations

### commit-commands (Wired — commit workflow)

**Fills:** `commit:workflow`
**Detection:** Check installed_plugins.json for key with prefix "commit-commands"

**Workflow seams (Wired):**
- `/push-safe` — Streamlined commit workflow before pushing

### git-workflow (Wired — branch management)

**Fills:** `branch:lifecycle`
**Detection:** Check installed_plugins.json for key with prefix "git-workflow"

**Workflow seams (Wired):**
- `/blueprint` Stage 7 (Execute) — Git Flow feature/finish lifecycle for implementation branches

### hookify (Wired — mistake prevention)

**Fills:** `prevent:hooks`
**Detection:** Check installed_plugins.json for key with prefix "hookify"

**Workflow seams (Wired):**
- `/debug` Integration — Create prevention hooks for recurring mistakes

### documentation-generator (Wired — docs maintenance)

**Fills:** `docs:update`
**Detection:** Check installed_plugins.json for key with prefix "documentation-generator"

**Workflow seams (Wired):**
- `/end` Integration — Update docs before closing session

### agentdev (Wired — agent development)

**Fills:** `develop:agents`
**Detection:** Check installed_plugins.json for key with prefix "agentdev"

**Workflow seams (Wired):**
- `/spec-agent` — Full-cycle multi-model agent creation after spec

### plugin-dev (Wired — plugin development)

**Fills:** `develop:plugins`
**Detection:** Check installed_plugins.json for key with prefix "plugin-dev"

**Workflow seams (Wired):**
- `/spec-agent` — Guided plugin workflow after agent spec

### devops-automation (Wired — infrastructure)

**Fills:** `infra:architect`
**Detection:** Check installed_plugins.json for key with prefix "devops-automation"

**Workflow seams (Wired):**
- `/security-checklist` Integration — Infrastructure security posture review

### project-management-suite (Wired — planning)

**Fills:** `plan:strategy`
**Detection:** Check installed_plugins.json for key with prefix "project-management-suite"

**Workflow seams (Wired):**
- `/start` — Product strategy and roadmap when project context suggests planning

### Other Plugins Noted for Future Phases

| Plugin | Slot | Phase | Marketplace |
|--------|------|-------|-------------|
| bun | `execute:backend` | Phase 2 | mag-claude-plugins |

These entries are documented for planning. Phase 2+ integration seams are NOT active.

---

## Section 4: Graceful Degradation Rules

1. **Plugin not installed:** Slot not offered. No error, no warning, no log.
2. **Plugin installed but agent dispatch fails:** Log failure, skip agent, continue workflow. Show user: `Note: [agent] unavailable (dispatch failed), skipping.`
3. **Plugin returns oversized output (>2000 tokens):** Truncate to 2000 tokens, append `[truncated — full output available via direct plugin invocation]`.
4. **Multiple plugins fill same slot:** Offer all as options, ordered alphabetically by plugin name.
5. **Detection file missing or unparseable:** Skip all enhancements. Log: `[PLUGIN] installed_plugins.json not found or corrupted; skipping plugin detection`
6. **Detection exceeds 3-second timeout:** Abort, proceed without enhancements.
7. **Circuit breaker — 3 consecutive failures from same plugin:** Abort remaining agents for that plugin. Log: `[PLUGIN] Circuit breaker: 3 consecutive failures from <plugin>; skipping remaining agents` Show user: `Plugin enhancements temporarily disabled due to repeated failures.` Circuit breaker is session-scoped — resets automatically when a new session begins.

---

## Section 5: Plugin Results Format

All plugin results MUST be formatted as:

```markdown
### [plugin-review] <plugin-name>: <agent-name>

**Findings:**
- [severity: high] Description of finding (file:line)
- [severity: medium] Description of finding (file:line)

**Summary:** N findings (N high, N medium, N low)
```

**Size limit:** Max 2000 tokens per agent result. Truncate with `[truncated]` note if exceeded.

**Tag:** `[plugin-review]` enables filtering. Plugin results are distinguished from debate chain findings:
- Debate chain findings CAN trigger regressions
- Plugin review findings CANNOT trigger regressions

**"Advisory" semantics:** Plugin results are surfaced to the user for awareness. They are appended to the relevant output (adversarial.md, review summary, dispatch report). They do NOT block workflow progression. They do NOT affect confidence scoring. They do NOT trigger regression logic. The user may act on them or ignore them.

---

## Section 6: Logging Protocol

### Responsibility
The **workflow command** that invokes the plugin is responsible for logging. Never rely on the plugin to log its own failure.

### Format
```
[PLUGIN] <plugin-name>:<agent-name> <event>: <detail>
```

### Events
```
[PLUGIN] Detection: found <plugin>@<version>
[PLUGIN] <plugin>:<agent> dispatched
[PLUGIN] <plugin>:<agent> completed: <tokens> tokens
[PLUGIN] <plugin>:<agent> timeout: 5m exceeded
[PLUGIN] <plugin>:<agent> dispatch failed: <error>
[PLUGIN] <plugin>:<agent> failed: <reason>
[PLUGIN] <plugin> probe failed; skipping all agents
[PLUGIN] Circuit breaker: 3 consecutive failures from <plugin>; skipping remaining agents
[PLUGIN] installed_plugins.json not found or corrupted; skipping plugin detection
[PLUGIN] <name> installed but not in registry; skipping
```

### Destinations
1. **Epistemic tracking** (if session active): append to `.epistemic/insights.jsonl` — dead-ends for failures, findings for successful plugin insights
2. **User-facing**: One-line note in workflow output
3. **If epistemic tracking unavailable**: Stderr only (fail-open, no file creation)

### What's NOT logged
- Successful detection (silent — reduces noise)
- Plugin results content (already in output files)
- Per-token metrics (out of scope for Phase 1)

---

## Section 7: Dispatch Lenses for /dispatch

When `/dispatch` runs with `--lenses`, these additional lenses are available from installed plugins:

**pr-review-toolkit lenses:**

| Lens Name | Agent | Requires Plugin |
|-----------|-------|-----------------|
| `silent-failures` | pr-review-toolkit:silent-failure-hunter | pr-review-toolkit |
| `types` | pr-review-toolkit:type-design-analyzer | pr-review-toolkit |
| `comments` | pr-review-toolkit:comment-analyzer | pr-review-toolkit |
| `simplify` | pr-review-toolkit:code-simplifier | pr-review-toolkit |
| `test-coverage` | pr-review-toolkit:pr-test-analyzer | pr-review-toolkit |

**Additional plugin lenses:**

| Lens Name | Agent | Requires Plugin | Complements |
|-----------|-------|-----------------|-------------|
| `deep-security` | security-pro:security-auditor | security-pro | Standard `security` lens |
| `deep-perf` | performance-optimizer:performance-engineer | performance-optimizer | Standard `perf` lens |
| `methodology` | superpowers:code-reviewer | superpowers | Standard quality review |
| `conventions` | feature-dev:code-reviewer | feature-dev | Standard quality review |

**Lens complementarity:** The `deep-security` and `deep-perf` lenses are more thorough than the standard `security` and `perf` lenses (which use built-in agents). Users can run both: `--lenses security,deep-security` for maximum coverage. The standard lens provides a quick scan; the plugin lens provides a deep audit.

If a user requests an extended lens and the required plugin is not installed:
```
Lens '<name>' requires <plugin> plugin (not installed).
Proceeding with standard lenses only.
```

---

## Phase 1 Scope Reminder

This file documents the full vision but only the following are active:
- **Detection protocol** (Section 1) — active
- **Slots:** `review:specialized`, `review:multi-model`, `review:security-deep`, `review:performance-deep`, `review:code-quality` — active
- **Plugins (Phase 1):** pr-review-toolkit, frontend, security-pro, performance-optimizer, superpowers, feature-dev (review agents only) — active
- **Dispatch lenses** (Section 7) — all 9 extended lenses active
- **Phase 2+ plugins:** code-analysis, testing-suite — documented, NOT active
- **Phase 2+ agents:** execution/investigation agents from Phase 1 plugins — documented, NOT active
