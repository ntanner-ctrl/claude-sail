# Adversarial Findings: toolkit-rebrand

## Challenge Stage (Debate Mode — 3 rounds)

### Round 1: Challenger
17 findings (2 critical, 4 high, 5 medium, 6 low)

### Round 2: Defender
11 confirmed valid, 5 overstated, 1 false, 6 new findings identified

### Round 3: Judge Verdict
**REGRESS** — 2 critical findings require spec update

---

## Consolidated Findings (Judge-rated)

### Critical (spec updated)

| ID | Finding | Resolution |
|----|---------|------------|
| F1 | Tarball extracts to `claude-sail-main/` but install.sh hardcodes `claude-bootstrap-main/`. Remote install breaks immediately. | **FIXED in spec rev 2:** W2 now explicitly lists `REPO_DIR` variable rename as critical item. |
| M1 | `chmod +x` in install.sh targets `bootstrap-toolkit/scripts/*.sh` — after rename the glob matches nothing. Plugin scripts silently non-executable. | **FIXED in spec rev 2:** W2 now explicitly lists chmod glob update as critical item. |

### High (spec updated)

| ID | Finding | Resolution |
|----|---------|------------|
| F3 | Plugin detection uses bare names but `installed_plugins.json` keys are scoped (`name@registry`). Detection never matches. | **FIXED in spec rev 2:** Phase 1 plugin detection now specifies prefix-match after stripping `@registry` suffix. |
| F6 | W11 grep/replace across ~30 files is underspecified. Risk of corrupting verb uses of "bootstrap". | **FIXED in spec rev 2:** W11 now has explicit grep patterns, exclusion list, and mandatory manual review requirement. |
| M2 | `REPO_URL` variable default in install.sh still embeds old repo name. Dead link in install output. | **FIXED in spec rev 2:** W2 explicitly lists `REPO_URL` default as a required update. |

### Medium (spec updated)

| ID | Finding | Resolution |
|----|---------|------------|
| F7 | `raw.githubusercontent.com` URLs don't redirect after repo rename. Old install commands 404. | **FIXED in spec rev 2:** Failure Modes table corrected — no longer claims GitHub redirect handles raw URLs. |
| F9 | Maturity scoring rubric exists only in current file. W4 rewrite could lose it. | **FIXED in spec rev 2:** Phase 6 now says "preserve maturity scoring rubric verbatim." |
| F10 | `compaction-safety.md` fires on `tools:["*"]` — too noisy. | **FIXED in spec rev 2:** Scoped to `[Write, Edit, Bash]` only. |
| F11 | Plugin directory rename not in Failure Modes table. | **FIXED in spec rev 2:** Added plugin path change to Failure Modes with detection and warning. |
| M4 | Session hook stdout still says "claude-bootstrap" in injection text. | **FIXED in spec rev 2:** W1 now explicitly includes content update for session hook output text. |

### Low (spec updated where applicable)

| ID | Finding | Status |
|----|---------|--------|
| F2 | Empirica instance ID rename — overstated by challenger. Graceful degradation confirmed. W1 adds one-shot migration copy. | Addressed in W1 update |
| F4 | `source` on vault-config.sh — legitimate general concern but consistent with existing patterns. | Noted, not blocking |
| F5 | Dual-manifest conflict — "prefer new name" IS the resolution rule. | Already in spec |
| F15 | W1 listed manifest as file to rename — it's in target projects. | **FIXED:** W1 clarified, manifest removed from file list |
| F16 | Stock element counts unspecified. | **FIXED:** Added "Final Stock Element Counts" section |
| F17 | Rollback doesn't clean stale files. | **FIXED:** Added cleanup step to rollback plan |
| M3 | `mkdir` calls hardcode old plugin name — creates stale empty dirs. | **FIXED:** Covered by W2 explicit mkdir update |
| M5 | Toolkit's own manifest trips success grep. | **FIXED:** Success criterion grep now excludes `bootstrap-manifest` |

### Not Issues

| ID | Finding | Why |
|----|---------|-----|
| F8 | `empirica project-bootstrap` doesn't exist | FALSE — confirmed in CLI help |
| F12 | Success grep false positives mid-run | Testing workflow error, not spec defect |
| F13 | empirica-basics can't be fail-soft as prompt hook | Overstated — prompt hooks ARE fail-soft by design |
| F14 | VAULT_PATH with spaces in CLAUDE.md | Display-only, benign |
| M6 | Local install detector fragile | Noted for future, not this change |
