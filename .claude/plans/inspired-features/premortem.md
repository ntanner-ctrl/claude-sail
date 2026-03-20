# Pre-Mortem: inspired-features

## Premise
These 7 features were implemented and shipped in v0.10.0 two weeks ago. Something went wrong.

## Most Likely Failure
**Existing users who upgraded didn't get `freeze-guard.sh` wired into their `settings.json`.** The install script copies files but doesn't modify an existing `settings.json`. Users who ran `/freeze` believed their directories were locked, but the hook wasn't firing. The freeze feature provided no actual protection.

## Contributing Factors
1. **No upgrade migration path.** `install.sh` copies files but doesn't diff against existing settings.json to suggest new hook additions. First-time installs work; upgrades are silent.
2. **`audit-log.sh` naming confusion.** It lives in `hooks/` but isn't a hook — it's a sourced utility. Users may accidentally wire it into settings.json, where it fails silently (no exit codes).
3. **Per-project budget data silently scopes `/retro`.** Cross-project retrospectives aren't possible without manually specifying project paths.
4. **Baseline false security.** Despite honest documentation, "baseline: true" in frontmatter creates an expectation gap with users who read YAML but not docs.

## Early Warning Signs Missed
- No test for "upgrade from v0.9.0 to v0.10.0" in test.sh
- No naming convention distinguishing utility files from wireable hooks
- No settings.json diff tool

## Recommendations

| # | Recommendation | Status |
|---|---|---|
| 1 | Add settings.json upgrade detection to install.sh — warn about new hooks | NEW |
| 2 | Rename `audit-log.sh` to `_audit-log.sh` or move to `hooks/lib/` | NEW |
| 3 | Add upgrade testing to test.sh (install v0.9.0, upgrade to v0.10.0) | NEW |
| 4 | Document settings.json changes needed on upgrade in release notes | NEW |
