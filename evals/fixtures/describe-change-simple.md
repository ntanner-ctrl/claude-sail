## Triage Result

**Change:** Update button hover color in global stylesheet
**Steps:** 2 discrete actions
**Risk flags:** None
**Execution preference:** Simplicity

**Recommended path:** Light — `/preflight`, then execute

---

## Step Breakdown

1. Open `src/styles/global.css`
2. Change `.btn:hover` background-color from `#0066cc` to `#0052a3`

Both steps are mechanical CSS edits with no logic changes. No tests required. No external contracts affected.

---

## Assessment

This is a single-file cosmetic change with a 1-3 step count and zero risk flags. No database, authentication, deletion, or external API surface is touched. The Light path is appropriate — run `/preflight` to confirm scope, then execute directly.

Next steps:
  - Light path → `/preflight` then execute
