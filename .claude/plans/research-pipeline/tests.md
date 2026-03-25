# Test Specifications: research-pipeline

Generated spec-blind from the specification and adversarial findings. These tests should be added to test.sh and evals.json during WU9.

---

## Category 3: File Count Changes

```
CMD_EXPECTED: 64 → 65 (+1: research.md added, clarify.md stays as deprecated)
```

No other counts change. No new agents, hooks, or stock elements.

---

## Category 4: Enforcement Lint — New Checks

### T1: /research description uses tier 2.5 language (NOT MUST)
```
Test: grep "^description:" commands/research.md
Assert: does NOT contain "MUST"
Assert: does NOT contain "REQUIRED"
Assert: does NOT contain "STOP"
Rationale: F1 — enforcement tier dropped to tier 2.5 per vault precedent
```

### T2: /clarify description starts with DEPRECATED
```
Test: grep "^description:" commands/clarify.md
Assert: starts with "DEPRECATED:"
Rationale: §6 — soft deprecation
```

### T3: /research has required frontmatter fields
```
Test: grep in commands/research.md
Assert: has "description:" field
Assert: has "arguments:" field
Assert: arguments include "topic" with required: true
Rationale: §1.3
```

### T4: /research is in wizard commands list
```
Test: research.md should be added to WIZARD_FILES check
Assert: research.md contains "State Management" or "wizards/" reference
Assert: research.md contains stage progression markers (✓, →, ○)
Rationale: §1.6 — research is a stateful wizard
```

---

## Category 4 Extension: Structural Checks

### T5: Research brief format validation
```
Test: Validate that the spec defines a research brief with YAML frontmatter containing:
  - topic (string)
  - date (YYYY-MM-DD)
  - mode (quick|standard|deep)
  - coverage (object with boolean fields)
  - linked_blueprint (string or null)
  - gate_score (number)
Assert: The research command references all these fields
Rationale: §2.2 + F2 (linked_blueprint)
```

### T6: Coverage block does NOT contain design_check field
```
Test: grep "design_check" in commands/research.md coverage block definition
Assert: NOT present
Rationale: F4 dead-field removal — design_check always false, removed
```

### T7: Blueprint references optional-enrichment pattern
```
Test: grep "research.md" OR "research brief" in commands/blueprint.md
Assert: at least 2 references (pre-stage detection + describe enrichment)
Rationale: §5.1-5.2 — blueprint must detect and consume research brief
```

### T8: Blueprint no longer has MUST prior-art gate
```
Test: Check blueprint.md for prior-art gate section
Assert: prior-art gate is conditional on research brief absence, not unconditional
Note: This is a content check, not just a presence check — harder to automate
Rationale: §5.4
```

---

## Category 8: Behavioral Evals (evals.json fixtures)

### E-NEW-1: Research brief detection in blueprint (brief present)
```json
{
  "id": "research-enrichment-present",
  "name": "blueprint-detects-research-brief",
  "command": "blueprint",
  "scenario": "Blueprint invoked with research.md present in plan directory. Coverage has prior_art: true, brainstorm: true, requirements: true.",
  "fixture": "fixtures/blueprint-with-research-brief.md",
  "assertions": [
    {
      "type": "contains",
      "value": "Research brief detected",
      "description": "Should acknowledge research brief"
    },
    {
      "type": "contains-any",
      "values": ["coverage", "Coverage"],
      "description": "Should display coverage from brief"
    },
    {
      "type": "not-contains",
      "value": "/brainstorm",
      "description": "Should NOT suggest brainstorm (covered by research)"
    }
  ]
}
```

### E-NEW-2: Research brief absent in blueprint (soft nudge)
```json
{
  "id": "research-enrichment-absent",
  "name": "blueprint-without-research-brief",
  "command": "blueprint",
  "scenario": "Blueprint invoked without research.md. No prior research.",
  "fixture": "fixtures/blueprint-without-research-brief.md",
  "assertions": [
    {
      "type": "contains-any",
      "values": ["/research", "research"],
      "description": "Should suggest /research as an option"
    },
    {
      "type": "contains",
      "value": "/brainstorm",
      "description": "Should still suggest brainstorm (no research coverage)"
    }
  ]
}
```

### E-NEW-3: Deprecated /clarify redirect
```json
{
  "id": "clarify-deprecated",
  "name": "clarify-shows-deprecation",
  "command": "clarify",
  "scenario": "User invokes /clarify. Should see deprecation message with redirect to /research and /design-check.",
  "fixture": "fixtures/clarify-deprecated.md",
  "assertions": [
    {
      "type": "contains",
      "value": "DEPRECATED",
      "description": "Should show deprecation notice"
    },
    {
      "type": "contains",
      "value": "/research",
      "description": "Should redirect to /research"
    },
    {
      "type": "contains",
      "value": "/design-check",
      "description": "Should redirect to /design-check"
    },
    {
      "type": "contains",
      "value": "/brainstorm",
      "description": "Should mention /brainstorm as lightweight option"
    }
  ]
}
```

### E-NEW-4: Research completion shows coverage manifest
```json
{
  "id": "research-completion-coverage",
  "name": "research-shows-coverage-on-complete",
  "command": "research",
  "scenario": "Research completes standard mode. Completion screen should show coverage manifest and next steps.",
  "fixture": "fixtures/research-complete-standard.md",
  "assertions": [
    {
      "type": "contains-any",
      "values": ["brainstorm ✓", "brainstorm: true", "brainstorm ✓"],
      "description": "Coverage shows brainstorm completed"
    },
    {
      "type": "contains-any",
      "values": ["prior-art ✓", "prior_art: true", "prior-art ✓"],
      "description": "Coverage shows prior-art completed"
    },
    {
      "type": "contains",
      "value": "/blueprint",
      "description": "Should suggest blueprint as next step"
    }
  ]
}
```

---

## Edge Case Tests (from Stage 4 findings)

### T-EDGE-1: Topic sanitization
```
Test: research.md command body references topic sanitization
Assert: contains "sanitiz" OR "slug" OR "[a-z0-9" in storage section
Rationale: E1 (B-I-2) — special chars break paths
```

### T-EDGE-2: Overwrite confirmation
```
Test: research.md command body references existing brief detection
Assert: contains "already exists" OR "overwrite" OR "conflict"
Rationale: E2 (B-IN-2) — re-run overwrites silently
```

### T-EDGE-3: Multi-session listing
```
Test: research.md state management references multiple sessions
Assert: contains "multiple" OR "list all" OR "select which"
Rationale: E3 (B-S-2) — wrong session resumed
```

### T-EDGE-4: Staleness warning
```
Test: research.md state management references session age threshold
Assert: contains "stale" OR "48" OR "days old"
Rationale: F5 / B-T-3 — deep mode resume without staleness check
```

---

## Documentation Checks

### T-DOC-1: docs/OPTIONAL-ENRICHMENT.md exists
```
Test: [ -f docs/OPTIONAL-ENRICHMENT.md ]
Assert: file exists
Rationale: WU3 — pattern documentation
```

### T-DOC-2: OPTIONAL-ENRICHMENT.md contains checklist
```
Test: grep "checklist" OR "compliance" in docs/OPTIONAL-ENRICHMENT.md
Assert: contains compliance check pattern
Rationale: Elder Council — enforcement is social, checklist makes it auditable
```

---

## Summary

| Category | New Checks | Description |
|----------|-----------|-------------|
| Cat 3 (Counts) | 1 | CMD_EXPECTED 64→65 |
| Cat 4 (Lint) | 8 | Tier check, deprecation, frontmatter, structural |
| Cat 8 (Evals) | 4 | Behavioral fixtures for enrichment, deprecation, coverage |
| Edge cases | 4 | Sanitization, overwrite, multi-session, staleness |
| Docs | 2 | OPTIONAL-ENRICHMENT.md existence + content |
| **Total** | **19** | |

Expected test.sh total: ~75 → ~94 checks (net +19)
