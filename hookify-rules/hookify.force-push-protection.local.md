---
name: force-push-protection
enabled: true
event: bash
pattern: git\s+push\s+.*(-f|--force).*\s+(main|master|production|release|develop)
action: block
baseline: true
---

**BLOCKED: Force push to protected branch**

Force pushing to `main`, `master`, `production`, `release`, or `develop` can:
- Destroy commit history for the entire team
- Break CI/CD pipelines
- Cause data loss that's difficult to recover

**Safe alternatives:**
- Create a new branch and PR instead
- Use `git revert` to undo changes safely
- If you MUST force push, do it to a feature branch first

If this is intentional (you own the repo solo), temporarily disable this rule.
