# Pre-Mortem: research-pipeline

## Premise
This plan was implemented two weeks ago. It failed.

## Most Likely Failure
Feature shipped correctly but adoption was near zero — soft nudge was too quiet, users never built research-first habit. This is an expected tradeoff of tier 2.5 enforcement, not a deployment failure.

## Contributing Factors

### PM-1: test.sh validates syntax but not behavior [NEW]
WU9 says "update tests" but only specifies count checks and deprecation lint. No behavioral eval fixtures to verify blueprint actually reads research briefs or that coverage manifest routes correctly.

**Direction:** Add behavioral eval fixtures to `evals/evals.json` for:
- Blueprint detects research brief and adjusts pre-stage
- Blueprint proceeds normally without research brief
- Deprecated /clarify shows redirect message

### PM-2: Blueprint.md multi-section edit risk [COVERED]
1600+ line file, 4 non-adjacent sections modified. Risk of inconsistency during implementation.

**Mitigated by:** Work graph sequencing (WU4 → WU5/WU6), separate commits, manifest recovery.

### PM-3: Clarify wizard state in target projects [COVERED]
Active sessions from before upgrade create confusion on deprecated /clarify invocation.

**Mitigated by:** §6.3 handles active session prompt. install.sh doesn't modify target project state by design.

### PM-4: Vault Research/ directory not created before first write [NEW]
Spec says brief goes to `Engineering/Research/YYYY-MM-DD-[topic].md` but doesn't specify directory creation. Same gap as vault-data-pipeline blueprint (Elder Council analogy).

**Direction:** Add to §1.7 Storage or §3 Synthesize: "Ensure `Engineering/Research/` directory exists before vault write (mkdir -p equivalent via vault MCP)."

## Pre-Mortem Overlap Assessment
- 2 COVERED / 4 total = 50% overlap with prior stages
- premortem_overlap: moderate (prior rounds caught design failures; pre-mortem caught deployment gaps)
