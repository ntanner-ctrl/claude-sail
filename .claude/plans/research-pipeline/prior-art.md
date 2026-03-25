# Prior Art: research-pipeline

## Search Summary

Searched for: structured research/investigation workflows in AI coding tools, pre-planning phases separate from implementation planning.

## Closest Match: ARIS (Auto-Research-In-Sleep)

- **Source**: https://github.com/wanshuiyin/Auto-claude-code-research-in-sleep
- **What it is**: Markdown-only research skills for autonomous ML research (literature survey → idea generation → experimentation → paper writing)
- **Recognition**: Accepted at AAAI 2026
- **Relevance**: Validates that markdown-only research workflows work. Different domain (academic ML) and architecture (autonomous overnight execution vs interactive human-in-the-loop).

### Key Differences
1. Domain-specific (ML papers) vs general software investigation
2. Autonomous execution vs interactive human-in-the-loop
3. Self-contained workflow vs handoff to downstream planning pipeline
4. No optional-enrichment pattern — skills are standalone

### Useful Lessons
- Single-file markdown skills as portable units (we already do this)
- Progressive structure works well for research workflows
- Cross-model review adds value during investigation

## Other Tools Surveyed

| Tool | Research Phase? | Notes |
|------|----------------|-------|
| Cursor | No formalized phase | Ad-hoc context feeding |
| Windsurf | No formalized phase | AI-native but no workflow separation |
| Aider | No formalized phase | Git-integrated but no pre-planning |
| GitHub Copilot | No formalized phase | Inline assistance only |
| Addy Osmani's workflow | Informal | Uses LLM as "research assistant" but unstructured |

## Recommendation

**BUILD** — No existing solution addresses structured investigation → synthesis brief → optional enrichment of a planning workflow. The gap we're filling doesn't exist in any surveyed tool.
