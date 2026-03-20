# Prior Art: inspired-features

## Research Already Completed

This blueprint's features were directly sourced from prior art research conducted at session start. Three projects were analyzed:

### 1. gstack (stackr.to)
- **Relevance:** `/retro`, `/freeze`/`/unfreeze`, graduated safety modes
- **Adaptation:** Taking the retrospective concept and directory locking, adapting to claude-sail's hook-based architecture
- **License/Access:** Proprietary (stackr.to platform)

### 2. everything-claude-code (GitHub, 90k stars)
- **Relevance:** `ECC_DISABLED_HOOKS`, `ECC_HOOK_PROFILE`, instinct-based learning → skill evolution
- **Adaptation:** Hook toggle env vars (simplified to single `SAIL_DISABLED_HOOKS`), evolve concept adapted to our log-error/log-success pipeline
- **License:** MIT

### 3. sidjua (GitHub)
- **Relevance:** Pre-action enforcement pipeline, baseline rules, budget enforcement, compliance auditing
- **Adaptation:** Baseline hookify rules, budget tracking (simplified — advisory not blocking), audit trail for hook blocks
- **License:** Open source

## Recommendation: ADAPT

All 7 features have direct prior art. We are adapting proven concepts to claude-sail's architecture (pure bash/markdown, hook-based, no runtime dependencies).

No existing library can be directly adopted — these projects have different architectures (Node.js, platform-specific). The adaptation is in the *concepts*, not the code.
