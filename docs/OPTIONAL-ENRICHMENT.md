# Optional-Enrichment Pattern

How workflows in claude-sail share artifacts without creating hard dependencies.

---

## The Problem: Workflow Coupling

Structured workflows produce useful artifacts. Other workflows could benefit from those artifacts. The naive approach — making Workflow B require Workflow A's output — creates rigid coupling: users must run workflows in a fixed order, and a missing or corrupt artifact blocks progress entirely.

Claude-sail needs the opposite: workflows that are better together but fully functional alone.

---

## The Pattern

Optional enrichment is a design convention for inter-workflow communication. Workflow B consumes Workflow A's output when available, but works fine without it. The consumer adapts its behavior based on what it finds — it never demands what it cannot find.

The flow has four states:

```
Detection → Validation → Enrichment (artifact present and valid)
                       → Fallback   (artifact absent or invalid)
```

### Detection

The consumer checks for an artifact at a predictable, convention-based path. No discovery protocol, no registry, no runtime coordination. The path is derived from shared naming conventions (e.g., `.claude/plans/[name]/research.md`).

### Validation

If an artifact exists, the consumer validates its format before reading it. Validation is lightweight: check that YAML frontmatter is parseable and that required fields are present. This is a structural check, not a quality judgment.

### Enrichment

When the artifact is present and valid, the consumer adjusts its behavior. This might mean skipping redundant steps, pre-populating context, or changing which questions it asks the user. The enrichment is specific to the consumer — the producer does not dictate how its output is used.

### Fallback

When the artifact is absent, corrupt, or partially invalid, the consumer proceeds with its default behavior. This is the critical constraint: **the fallback path must be fully functional.** A user who has never heard of the producer workflow must have an identical experience to what existed before the enrichment seam was added.

---

## Fail-Open Guarantee

The pattern enforces a strict fail-open contract:

| Condition | Behavior |
|-----------|----------|
| Artifact missing | Proceed normally, soft nudge shown once |
| Artifact corrupt (unparseable YAML) | Log warning, proceed normally |
| Artifact partially valid (some fields missing) | Consume valid fields, ignore invalid ones |
| Artifact present and valid | Enrich behavior based on contents |

Nothing in the "absent or invalid" column blocks the consumer workflow. This is not a preference — it is the defining constraint of the pattern. If a consumer cannot function without the artifact, it is not optional enrichment; it is a dependency, and it should be modeled as one.

### Soft Nudge

When an artifact is absent, the consumer displays a one-time suggestion:

```
/research wasn't run for this topic. Consider running it first
for richer context. Proceeding with standard behavior.
```

Soft nudge rules:
- Displayed once per workflow invocation (not per stage)
- Never blocks progress
- Never repeats if the user has seen it this session
- Phrased as a suggestion, not a warning

---

## First Instance: Research to Blueprint

The first optional-enrichment seam in claude-sail connects `/research` (producer) and `/blueprint` (consumer).

| Aspect | Detail |
|--------|--------|
| **Producer** | `/research` |
| **Artifact** | `.claude/plans/[name]/research.md` |
| **Format** | YAML frontmatter with `coverage` block + markdown body |
| **Consumer** | `/blueprint` |
| **Enrichment** | Blueprint reads the research brief's coverage manifest to skip redundant pre-stage suggestions and the prior-art gate |
| **Fallback** | Blueprint runs its full pre-stage and all gates, identical to pre-research behavior |

Detection uses two strategies:
1. Direct path match: `.claude/plans/[blueprint-name]/research.md`
2. `linked_blueprint` field search: scan research briefs for a matching `linked_blueprint` value

The research brief's YAML `coverage` block drives per-field conditional behavior — a quick-mode research that only ran prior-art will skip only the prior-art gate, while brainstorm and requirements suggestions remain active.

---

## Convention for Future Seams

Any command can adopt optional enrichment. To claim compliance, the command's documentation must specify six items:

### Compliance Checklist

1. **Producer**: which workflow creates the artifact
2. **Artifact path**: predictable, convention-based location (no dynamic discovery)
3. **Artifact format**: YAML frontmatter with structured metadata + markdown body
4. **Consumer**: which workflow reads the artifact
5. **Enrichment behavior**: what changes when the artifact is present
6. **Fallback behavior**: what happens when the artifact is absent (must be fully functional without it)

All six items must be documented. If fallback behavior is not explicitly described, the seam is not compliant — the whole point is that absence is a first-class state.

---

## Enforcement

This pattern is enforced socially and through documentation, not structurally. No hook validates that a consumer handles missing artifacts gracefully. No test checks that enrichment is truly optional.

The reason is pragmatic: claude-sail has no runtime code. Commands are markdown files interpreted by Claude. The "enforcement" is Claude reading this document and the compliance checklist in each command's spec, then behaving accordingly. This is consistent with how claude-sail enforces other behavioral patterns — through clear documentation and convention rather than programmatic guards.

If a future version of claude-sail adds behavioral evals (test fixtures that verify Claude's behavior), optional-enrichment compliance would be a natural candidate: test that `/blueprint` works identically with and without a research brief present.

---

## Design Rationale

### Why Not Make It Required?

If `/research` were a prerequisite for `/blueprint`, every blueprint would require a research phase — even trivial ones. The overhead would push users to skip the entire planning workflow rather than engage with a lighter version of it. Optional enrichment preserves the graduated approach: users can plan without researching, but research makes planning better.

### Why YAML Frontmatter?

The artifact format uses YAML frontmatter + markdown body because:
- Frontmatter is machine-readable (coverage booleans, gate scores) for routing decisions
- The markdown body is human-readable for context
- This is already the standard format for claude-sail commands, agents, and briefs
- No additional parsing infrastructure is needed

### Why Convention-Based Paths?

Artifacts live at predictable paths derived from shared naming conventions rather than a registry or discovery mechanism. This keeps the pattern dependency-free — a consumer only needs to know the convention to find the artifact. No coordination protocol, no shared state, no race conditions.
