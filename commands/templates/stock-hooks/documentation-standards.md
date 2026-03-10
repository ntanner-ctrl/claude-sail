---
name: documentation-standards
description: Enforces Diataxis documentation framework (Tutorial, How-to, Reference, Explanation)
hooks:
  - event: PostToolUse
    tools:
      - Write
      - Edit
    pattern: "**/docs/**/*.md|**/documentation/**/*.md|**/*.mdx"
---

# Diataxis Documentation Standards

When writing or editing documentation, classify it using the **Diataxis framework**. Every document must be exactly ONE of these four types -- mixing types produces documentation that serves no reader well.

## Type Decision

Ask: **What is the reader's goal right now?**

| Type | Reader's Goal | Opens With | Tone |
|------|--------------|------------|------|
| **Tutorial** | "I want to learn X" | "In this tutorial, you will..." | Encouraging, one path |
| **How-to Guide** | "I need to accomplish X" | "This guide shows how to..." | Direct, task-focused |
| **Reference** | "I need to look up X" | "This section documents..." | Austere, complete |
| **Explanation** | "I want to understand X" | "This explains why/how..." | Discursive, contextual |

```
Is the reader trying to...
├── Learn something new?           --> TUTORIAL
├── Accomplish a specific task?    --> HOW-TO GUIDE
├── Look up specific information?  --> REFERENCE
└── Understand why/how?            --> EXPLANATION
```

## Validate Against Type

### Tutorial Checklist
- [ ] States a clear learning objective upfront
- [ ] Follows ONE path -- no choices, no alternatives
- [ ] Every step produces a visible, verifiable result
- [ ] Ends with a working thing the reader built themselves
- [ ] Does NOT explain concepts inline (link to Explanation instead)
- [ ] Does NOT offer alternatives (pick the simplest path)

### How-to Guide Checklist
- [ ] Addresses a specific, real-world task
- [ ] Steps are numbered and actionable
- [ ] Includes verification after critical steps
- [ ] Covers failure modes, not just happy path
- [ ] Has a troubleshooting section for common errors
- [ ] Does NOT teach concepts (link to Tutorial or Explanation)

**Process categories** -- identify which applies:

| Category | Human Role | First Section |
|----------|-----------|---------------|
| **Manual** | Initiates | "Step 1: [Human action]..." |
| **Scheduled** | Monitors | "Runs automatically at [schedule]. To monitor..." |
| **Event-driven** | Responds | "Triggered when [event]. To respond..." |

### Reference Checklist
- [ ] Organized for quick lookup (alphabetical, by function, by resource type)
- [ ] Consistent structure across ALL entries (same headings, same order)
- [ ] Complete -- every parameter, option, return value documented
- [ ] Accurate -- matches the actual current behavior
- [ ] Includes brief examples (illustrative, not tutorial-length)
- [ ] Does NOT explain why (link to Explanation)
- [ ] Does NOT walk through procedures (link to How-to Guide)

### Explanation Checklist
- [ ] Clarifies a concept, decision, or design
- [ ] Provides context: why does this exist? what problem does it solve?
- [ ] Discusses alternatives and tradeoffs
- [ ] Connects to the bigger picture
- [ ] Does NOT include step-by-step procedures (link to How-to Guide)
- [ ] Does NOT serve as API documentation (link to Reference)

## Document Header

Every document should declare its type for readers and future editors:

```markdown
# [Title]

> **Type:** Tutorial | How-to Guide | Reference | Explanation
> **Last updated:** YYYY-MM-DD
> **Related:** [Links to complementary doc types for this topic]
```

## Common Anti-Patterns

| Anti-Pattern | Problem | Fix |
|-------------|---------|-----|
| Tutorial with choices | Overwhelms learners | Pick one path |
| How-to that teaches theory | Reader loses focus | Extract to Explanation, link |
| Reference with opinions | Undermines trust | State facts, move opinions to Explanation |
| Explanation with steps | Reader can't follow | Extract procedure to How-to Guide |
| One giant doc covering all four | Serves nobody well | Split into four linked documents |

## Further Reading

- https://diataxis.fr/ -- The canonical Diataxis documentation
