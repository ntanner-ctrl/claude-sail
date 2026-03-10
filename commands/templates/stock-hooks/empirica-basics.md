---
name: empirica-basics
description: After significant code changes, suggests logging findings via Empirica if available
hooks:
  - event: PostToolUse
    tools:
      - Write
      - Edit
---

# Empirica Finding Nudge

After making significant code changes, consider whether you learned something worth logging.

## When to Act

This nudge applies when you just made a change AND one of these is true:
- You discovered something non-obvious about the codebase (architectural pattern, hidden dependency, surprising behavior)
- You fixed a bug and the root cause was unexpected
- You tried an approach that failed and switched to a different one
- You found that documentation or comments were misleading or wrong
- You learned something about a library/framework that would help future work

## When to Skip

- Routine changes (formatting, renaming, adding boilerplate)
- Changes where nothing surprising was learned
- If you already logged this finding earlier in the session
- If Empirica is not available (no MCP server, no active session) -- just move on

## How to Log

If Empirica MCP tools are available and a session is active, use:

- **`finding_log`** -- For discoveries and insights
  - Required: `session_id`, `finding`
  - Optional: `impact`
  - Prefix finding with context: "[Insight] ...", "[Architecture] ...", "[Gotcha] ..."

- **`mistake_log`** -- For mistakes and wrong assumptions
  - Required: `session_id`, `mistake`, `why_wrong`, `prevention`

- **`deadend_log`** -- For approaches that were tried and abandoned
  - Required: `session_id`, `approach`, `why_failed`

## If Empirica Is Not Available

If the Empirica MCP server is not connected or no session is active, you have two options:

1. **Skip it** -- This is fine. The nudge is advisory.
2. **Note it in CLAUDE.md** -- If the finding is important enough, add it to the project's CLAUDE.md under a relevant section so future sessions benefit.

## What Makes a Good Finding

**Good findings** (log these):
- "The payment service retries failed charges 3 times with exponential backoff -- not documented anywhere"
- "pytest fixtures in conftest.py are session-scoped, not function-scoped -- affects test isolation"
- "The GraphQL resolver silently returns null instead of throwing on missing fields"

**Not worth logging** (skip these):
- "Added a new function to utils.py"
- "The linter requires trailing commas"
- "Python uses indentation for blocks"

## Fail-Soft

This hook is purely advisory. If logging would interrupt your flow or Empirica is unavailable, skip it entirely. The point is to build a habit of epistemic capture, not to create friction.
