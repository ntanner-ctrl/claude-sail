# Verification Tests: family-debate-and-rename

## Track A: Rename Verification

### T1: No residual references
```bash
grep -r "simplify-this" commands/ README.md GETTING_STARTED.md .claude/bootstrap-manifest.json
# Expected: 0 matches
```

### T2: New file exists with correct content
```bash
test -f commands/overcomplicated.md && echo "EXISTS"
grep "^# Overcomplicated" commands/overcomplicated.md
grep "^description:" commands/overcomplicated.md | grep -v "consider\|might\|optionally"
# Expected: EXISTS, title match, no escape hatches
```

### T3: Cross-references updated
```bash
grep "/overcomplicated" commands/devils-advocate.md commands/edge-cases.md commands/review.md commands/toolkit.md
# Expected: matches in all 4 files
```

### T4: README tables updated
```bash
grep "overcomplicated" README.md commands/README.md
# Expected: matches in both files
```

### T5: Bootstrap manifest updated
```bash
grep "overcomplicated" .claude/bootstrap-manifest.json
grep "simplify-this" .claude/bootstrap-manifest.json
# Expected: first matches, second does not
```

## Track B: Family Mode Verification

### T6: Challenge mode option registered
```bash
grep "family" commands/blueprint.md | head -5
# Expected: --challenge=family appears in mode selection, YAML frontmatter
```

### T7: Family mode section exists
```bash
grep "### Family Mode" commands/blueprint.md
# Expected: section header found
```

### T8: All 5 agent prompts defined
```bash
grep -c "Child-Defend\|Child-Assert\|Mother.*Strength\|Father.*Weakness\|Elder Council" commands/blueprint.md
# Expected: ≥5 matches (one per agent role)
```

### T9: Loop control specified
```bash
grep "Maximum rounds: 3" commands/blueprint.md
grep "Per-agent timeout: 3" commands/blueprint.md
grep "CONVERGED\|CONTINUE" commands/blueprint.md | head -3
# Expected: all present
```

### T10: Hardening sections present
```bash
grep "Elder Output Processing\|Asymmetric Child Output\|Empty Carry-Forward Guard\|Incremental Output Persistence" commands/blueprint.md
# Expected: all 4 section headers found
```

### T11: /overcomplicated wired into blueprint
```bash
grep "Post-Challenge.*Complexity\|/overcomplicated" commands/blueprint.md
# Expected: post-challenge section referencing /overcomplicated
```

### T12: /simplify wired into blueprint completion
```bash
grep "/simplify" commands/blueprint.md | grep -i "post-implementation\|completion"
# Expected: /simplify in post-implementation options
```

## Structural Verification

### T13: Command count unchanged (rename, not add)
```bash
ls commands/*.md | grep -v README | wc -l
# Expected: 46 (same as before — renamed, not added)
```

### T14: Install test
```bash
bash install.sh 2>&1 | tail -5
# Expected: successful copy, no errors
```

### T15: Enforcement lint
```bash
grep -rn "^description:.*\(consider\|might\|optionally\)" commands/
# Expected: 0 matches
```
