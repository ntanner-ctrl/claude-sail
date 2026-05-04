# Planning Storage Structure

How Claude Sail stores planning state and artifacts.

> **Note:** The storage directory is `.claude/plans/` (not `.claude/blueprints/`).
> This is intentional — the directory stores both blueprint artifacts and general
> planning state. The `/blueprint` command name reflects the structured design
> methodology; the storage path reflects the content type.

---

## Directory Structure

```
.claude/
├── plans/                      # Per-change planning artifacts
│   ├── feature-x/
│   │   ├── state.json          # Progress tracking + blueprint v2 metadata
│   │   ├── manifest.json       # Token-dense summary (recovery format)
│   │   ├── describe.md         # Triage output
│   │   ├── spec.md             # Full specification
│   │   ├── adversarial.md      # Challenge + edge case findings
│   │   ├── premortem.md        # Pre-mortem analysis (operational focus)
│   │   ├── debate-log.md       # Raw debate transcript (debug artifact)
│   │   ├── work-graph.json     # Parallelization dependency graph
│   │   ├── spec.diff.md        # Revision history (on regression)
│   │   ├── preflight.md        # Pre-flight checklist
│   │   ├── research.md         # Pre-planning research output (from /research)
│   │   └── tests.md            # Generated test specs
│   └── bugfix-y/
│       └── ...
├── state-index.json            # Lightweight "what's active?" index
├── overrides.json              # Project-level override history
└── settings.json               # Existing Claude Code config
```

---

## state.json Schema (v2)

Tracks progress through the blueprint workflow. Blueprint v2 extends the original
schema with challenge mode, confidence scoring, epistemic tracking integration, and regression tracking.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["name", "created", "recommended_path", "current_stage", "stages"],
  "properties": {
    "name": {
      "type": "string",
      "description": "Blueprint identifier (matches directory name)"
    },
    "blueprint_version": {
      "type": "integer",
      "default": 2,
      "description": "Schema version. Missing = pre-v2 plan (auto-migrated on resume)"
    },
    "created": {
      "type": "string",
      "format": "date-time"
    },
    "updated": {
      "type": "string",
      "format": "date-time"
    },
    "recommended_path": {
      "type": "string",
      "enum": ["light", "standard", "full"]
    },
    "chosen_path": {
      "type": "string",
      "enum": ["light", "standard", "full"]
    },
    "current_stage": {
      "type": "string",
      "enum": ["describe", "specify", "challenge", "edge_cases", "premortem", "review", "test", "execute", "debrief"],
      "description": "Stage name string. Note: this was documented as integer in pre-v3 schema but has always been stored as a string in practice."
    },
    "challenge_mode": {
      "type": "string",
      "enum": ["vanilla", "debate", "family", "team"],
      "default": "family",
      "description": "Set once at creation, locked for blueprint lifecycle. Changed from debate to family in v3."
    },
    "execution_preference": {
      "type": "string",
      "enum": ["speed", "simplicity", "auto"],
      "default": "auto",
      "description": "Advisory preference for parallelization (from triage)"
    },
    "revision": {
      "type": "integer",
      "default": 1,
      "description": "Spec revision number (increments on regression)"
    },
    "epistemic_session_id": {
      "type": ["string", "null"],
      "description": "Epistemic session ID resolved via epistemic_get_session_id (reads per-claude-PID marker under ~/.claude/.current-session/; one file per active claude process, session_id stored inside)"
    },
    "epistemic_preflight_complete": {
      "type": "boolean",
      "default": false
    },
    "epistemic_session_note": {
      "type": "string",
      "description": "Notes about session continuity (e.g., continuation session)"
    },
    "manifest_stale": {
      "type": "boolean",
      "default": false,
      "description": "Set true on manifest write failure. Blocks stage progression."
    },
    "work_graph_stale": {
      "type": "boolean",
      "default": false,
      "description": "Set true on regression to Stage 2. Blocks Stage 7."
    },
    "stages": {
      "type": "object",
      "properties": {
        "describe": { "$ref": "#/$defs/stage" },
        "specify": { "$ref": "#/$defs/stage" },
        "challenge": { "$ref": "#/$defs/stage_with_debate" },
        "edge_cases": { "$ref": "#/$defs/stage_with_debate" },
        "premortem": { "$ref": "#/$defs/stage" },
        "review": { "$ref": "#/$defs/stage" },
        "test": { "$ref": "#/$defs/stage" },
        "execute": { "$ref": "#/$defs/stage" },
        "debrief": { "$ref": "#/$defs/stage_debrief" }
      }
    },
    "parent": {
      "type": ["object", "null"],
      "description": "Parent blueprint reference (set by /link-blueprint)",
      "properties": {
        "blueprint": { "type": "string", "description": "Parent blueprint name" },
        "unit_id": { "type": ["string", "null"], "description": "Work unit ID from parent's spec" }
      }
    },
    "meta_units": {
      "type": "object",
      "description": "Sub-blueprint tracking map (set by /link-blueprint). Keys are child blueprint names.",
      "additionalProperties": {
        "type": "object",
        "properties": {
          "unit_id": { "type": ["string", "null"] },
          "status": { "type": "string", "enum": ["not_started", "in_progress", "complete"] },
          "linked_at": { "type": "string", "format": "date-time" },
          "discoveries": { "type": "array", "items": { "type": "string" } },
          "ship_commit": { "type": ["string", "null"] }
        }
      }
    },
    "completed": {
      "type": "boolean",
      "default": false,
      "description": "Blueprint completion flag. INVARIANT: only valid when stages.execute.status === 'complete' AND stages.debrief.status === 'complete'. Any other write path is a schema violation."
    },
    "completed_at": {
      "type": ["string", "null"],
      "format": "date-time"
    },
    "skipped": {
      "type": "array",
      "items": { "type": "string" },
      "description": "Stage names that were skipped"
    },
    "regression_log": {
      "type": "array",
      "items": { "$ref": "#/$defs/regression_entry" },
      "maxItems": 3,
      "description": "Max 3 regressions per blueprint"
    },
    "user_overrides": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "finding": { "type": "string" },
          "original": { "type": "string" },
          "override": { "type": "string" },
          "timestamp": { "type": "string", "format": "date-time" }
        }
      }
    },
    "family_progress": {
      "type": "object",
      "description": "Tracks family mode round progress (family challenge mode only)",
      "properties": {
        "stage": { "type": "string", "enum": ["challenge", "edge_cases"] },
        "round": { "type": "integer", "minimum": 1, "maximum": 3 },
        "agents_completed": {
          "type": "array",
          "items": { "type": "string", "enum": ["child_defend", "child_assert", "mother", "father", "elder"] }
        },
        "current_agent": { "type": "string" },
        "rounds_total": { "type": "integer" },
        "elder_verdicts": {
          "type": "array",
          "items": { "type": "string", "enum": ["CONVERGED", "CONTINUE"] }
        }
      }
    },
    "notes": {
      "type": "string"
    }
  },
  "$defs": {
    "stage": {
      "type": "object",
      "properties": {
        "status": {
          "type": "string",
          "enum": ["pending", "in_progress", "complete", "skipped", "blocked", "halted", "needs_revalidation", "blocked_pending_resolution"]
        },
        "started": { "type": "string", "format": "date-time" },
        "completed": { "type": "string", "format": "date-time" },
        "skippable": { "type": "boolean", "default": false },
        "skip_reason": { "type": "string" },
        "confidence": {
          "type": "number",
          "minimum": 0.0,
          "maximum": 1.0,
          "description": "Per-stage confidence score (advisory, not standalone gate)"
        },
        "confidence_note": { "type": "string" }
      }
    },
    "stage_debrief": {
      "allOf": [
        { "$ref": "#/$defs/stage" },
        {
          "properties": {
            "skippable": { "type": "boolean", "const": false, "description": "Debrief is never skippable" },
            "ship_commits": {
              "type": "array",
              "items": { "type": "string" },
              "description": "Commit hashes from implementation"
            },
            "spec_delta_summary": { "type": ["string", "null"], "description": "Summary of spec changes" },
            "deferred_items": {
              "type": "array",
              "items": { "type": "string" },
              "description": "Items explicitly punted with reasons"
            },
            "discoveries": {
              "type": "array",
              "items": { "type": "string" },
              "description": "Unanticipated findings during implementation"
            },
            "sibling_impacts": {
              "type": "array",
              "items": { "type": "string" },
              "description": "Sibling blueprints affected by discoveries (linked blueprints only)"
            }
          }
        }
      ]
    },
    "stage_with_debate": {
      "allOf": [
        { "$ref": "#/$defs/stage" },
        {
          "properties": {
            "mode": {
              "type": "string",
              "enum": ["vanilla", "debate", "family", "team"]
            },
            "verdict": {
              "type": "string",
              "enum": ["PASS", "PASS_WITH_NOTES", "REGRESS", "NO_REGRESSION"]
            },
            "round": { "type": "string" },
            "findings_summary": { "type": "object" },
            "debate_progress": {
              "type": "object",
              "properties": {
                "rounds_completed": {
                  "type": "array",
                  "items": { "type": "string" }
                },
                "current_round": { "type": "string" }
              },
              "description": "Tracks debate rounds for mid-conversation resume"
            },
            "blocking_finding": {
              "type": "string",
              "description": "Finding ID if status is blocked_pending_resolution"
            }
          }
        }
      ]
    },
    "regression_entry": {
      "type": "object",
      "required": ["from_stage", "to_stage", "trigger_type", "trigger", "reason", "timestamp"],
      "properties": {
        "from_stage": { "type": "string" },
        "to_stage": { "type": "string" },
        "trigger_type": { "type": "string", "enum": ["automatic", "manual", "debate_verdict"] },
        "trigger": { "type": "string" },
        "reason": { "type": "string" },
        "timestamp": { "type": "string", "format": "date-time" },
        "revision": { "type": "integer" }
      }
    }
  }
}
```

### Example state.json (v2)

```json
{
  "name": "feature-auth",
  "blueprint_version": 2,
  "created": "2026-02-07T10:30:00Z",
  "updated": "2026-02-07T14:22:00Z",
  "recommended_path": "full",
  "chosen_path": "full",
  "current_stage": 3,
  "challenge_mode": "debate",
  "execution_preference": "auto",
  "revision": 1,
  "epistemic_session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "epistemic_preflight_complete": true,
  "manifest_stale": false,
  "work_graph_stale": false,
  "stages": {
    "describe": {
      "status": "complete",
      "completed": "2026-02-07T10:45:00Z",
      "confidence": 0.95,
      "confidence_note": "Clear scope, well-understood domain"
    },
    "specify": {
      "status": "complete",
      "completed": "2026-02-07T11:30:00Z",
      "confidence": 0.85,
      "confidence_note": "Token refresh edge cases need more thought"
    },
    "challenge": {
      "status": "in_progress",
      "started": "2026-02-07T14:00:00Z",
      "mode": "debate",
      "debate_progress": {
        "rounds_completed": ["challenger"],
        "current_round": "defender"
      }
    },
    "edge_cases": { "status": "pending", "skippable": true },
    "premortem": { "status": "pending", "skippable": true },
    "review": { "status": "pending", "skippable": true },
    "test": { "status": "pending", "skippable": true },
    "execute": { "status": "blocked" }
  },
  "skipped": [],
  "regression_log": [],
  "user_overrides": [],
  "notes": ""
}
```

### Confidence Scoring

After each stage, the agent assesses confidence on a 0.0-1.0 scale. Stored per-stage
in `state.json` under `stages.[name].confidence`.

**Threshold behavior:** Default threshold is 0.5. Below this, a regression is
**suggested** (not auto-triggered) IF a trigger event also occurs (critical finding,
schema validation failure, etc.). Confidence alone does NOT trigger regression.

**Epistemic vector mapping** — which vectors to focus on per stage:

| Stage | Primary Vectors | Focus |
|-------|----------------|-------|
| Describe | CLARITY, CONTEXT | "Do I understand what we're building and why?" |
| Specify | KNOW, DO, COMPLETENESS | "Do I know enough to specify this fully?" |
| Challenge | UNCERTAINTY, SIGNAL | "What don't I know? What am I missing?" |
| Edge Cases | SIGNAL, DENSITY | "Have I found the important boundaries?" |
| Pre-Mortem | CHANGE, IMPACT | "What could go wrong in production?" |
| Test | COHERENCE, COMPLETENESS | "Do the tests cover the spec?" |
| Execute | DO, STATE | "Can I implement this correctly?" |

### HALT State

When max regressions (3) are reached with confidence <0.5 on any completed stage,
the blueprint enters HALT. See the `/blueprint` command for escape hatches.

```json
{
  "stages": {
    "execute": {
      "status": "halted",
      "halted_reason": "Max regressions (3) reached with confidence <0.5 on specify",
      "halted_at": "2026-02-07T21:00:00Z"
    }
  }
}
```

---

## manifest.json Schema

Token-dense recovery format. Updated after every stage completion. Read (not full
markdown) at recovery points. ~5-10x more token-efficient than reading all artifacts.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["v", "name", "summary", "scope"],
  "properties": {
    "v": {
      "type": "integer",
      "const": 1,
      "description": "Manifest schema version"
    },
    "name": { "type": "string" },
    "summary": {
      "type": "string",
      "description": "One-line description of the blueprint's purpose"
    },
    "scope": {
      "type": "object",
      "properties": {
        "files_touched": {
          "type": "array",
          "items": { "type": "string" },
          "description": "File paths or globs affected"
        },
        "risk_flags": {
          "type": "array",
          "items": { "type": "string" }
        },
        "path": {
          "type": "string",
          "enum": ["light", "standard", "full"]
        },
        "challenge_mode": {
          "type": "string",
          "enum": ["vanilla", "debate", "family", "team"]
        },
        "execution_preference": {
          "type": "string",
          "enum": ["speed", "simplicity", "auto"]
        }
      }
    },
    "spec_digest": {
      "type": "object",
      "properties": {
        "changes": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "action": { "type": "string", "enum": ["create", "modify", "delete"] },
              "target": { "type": "string" },
              "desc": { "type": "string" }
            }
          }
        },
        "preserve": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Preservation contract items"
        },
        "success_criteria": {
          "type": "array",
          "items": { "type": "string" }
        },
        "failure_modes": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "adversarial_digest": {
      "type": "object",
      "properties": {
        "critical": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "high": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "medium": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "low": { "type": "array", "items": { "$ref": "#/$defs/finding" } },
        "regressions_triggered": { "type": "integer" }
      }
    },
    "edge_cases_digest": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "boundary": { "type": "string" },
          "impact": { "type": "string", "enum": ["critical", "high", "medium", "low"] },
          "likelihood": { "type": "string", "enum": ["common", "uncommon", "rare", "theoretical"] },
          "addressed": { "type": "boolean" }
        }
      }
    },
    "premortem_digest": {
      "type": "object",
      "properties": {
        "top_failure": { "type": "string" },
        "contributing_factors": { "type": "array", "items": { "type": "string" } },
        "new_findings_count": { "type": "integer" },
        "covered_count": { "type": "integer" }
      }
    },
    "work_units": {
      "type": "array",
      "items": { "$ref": "#/$defs/work_unit" }
    },
    "parallel_score": {
      "type": "object",
      "properties": {
        "width": { "type": "integer", "description": "Max concurrent work units" },
        "critical_path": { "type": "integer", "description": "Minimum sequential steps" },
        "file_conflicts": { "type": "array", "items": { "type": "string" } }
      }
    },
    "decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "topic": { "type": "string" },
          "chosen": { "type": "string" },
          "reason": { "type": "string" },
          "alternatives_rejected": { "type": "array", "items": { "type": "string" } }
        }
      }
    },
    "confidence": {
      "type": "object",
      "description": "Per-stage confidence scores",
      "additionalProperties": { "type": "number", "minimum": 0.0, "maximum": 1.0 }
    },
    "revision": { "type": "integer" },
    "last_regression": {
      "type": ["object", "null"],
      "properties": {
        "from_stage": { "type": "string" },
        "to_stage": { "type": "string" },
        "reason": { "type": "string" },
        "timestamp": { "type": "string", "format": "date-time" }
      }
    },
    "epistemic_session_id": {
      "type": ["string", "null"],
      "description": "Redundant copy for cross-session recovery"
    },
    "artifact_timestamps": {
      "type": "object",
      "description": "Last-modified timestamps per artifact for staleness detection",
      "additionalProperties": { "type": "string", "format": "date-time" }
    },
    "debrief_digest": {
      "type": "object",
      "description": "Debrief summary for token-efficient recovery",
      "properties": {
        "ship_commits": { "type": "array", "items": { "type": "string" } },
        "spec_revisions": { "type": "integer" },
        "deferred_count": { "type": "integer" },
        "discovery_count": { "type": "integer" },
        "sibling_impacts": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Blueprint names of impacted siblings. Full descriptions require reading debrief.md."
        }
      }
    }
  },
  "$defs": {
    "finding": {
      "type": "object",
      "properties": {
        "finding": { "type": "string" },
        "source": {
          "type": "string",
          "description": "challenger, defender, judge, boundary_explorer, stress_tester, synthesizer, pre-mortem"
        },
        "convergence": {
          "type": "string",
          "enum": ["both-agreed", "disputed", "newly-identified"]
        },
        "stage": { "type": "string" }
      }
    },
    "work_unit": {
      "type": "object",
      "required": ["id", "desc", "files", "deps", "complexity"],
      "properties": {
        "id": { "type": "string" },
        "desc": { "type": "string" },
        "files": { "type": "array", "items": { "type": "string" } },
        "deps": { "type": "array", "items": { "type": "string" } },
        "complexity": { "type": "string", "enum": ["low", "medium", "high"] },
        "status": { "type": "string", "enum": ["pending", "in_progress", "complete", "failed"] },
        "tdd": { "type": "boolean", "default": false, "description": "TDD enforcement flag. Absent defaults to false." }
      }
    }
  }
}
```

### Manifest Enforcement Points

The manifest MUST be **read** (not full markdown) at these recovery points:

| Trigger | Reader | Why |
|---------|--------|-----|
| Session start with active blueprint | Session sail hook | Orient to current state |
| `/blueprint [name]` resume | `/blueprint` command | Recover full context cheaply |
| `/status [name]` | Status display | Meaningful summary |
| `/checkpoint` | Checkpoint creation | Include in checkpoint |
| `/dispatch --plan-context [name]` | Dispatch enrichment | Feed implementer with intelligence |
| `/delegate --plan-context [name]` | Delegate enrichment | Feed orchestrator with intelligence |
| Context compaction | Continuation session | Carry forward context |

The manifest MUST be **written** (updated) at these points:

| Trigger | Writer |
|---------|--------|
| Each stage completion | Stage command |
| Regression occurs | Regression handler |
| Work unit status changes | Execution tracking |
| Decision recorded | `/decision` command |

### Manifest Write Failure Handling

If a manifest write fails:

1. Set `"manifest_stale": true` in state.json
2. Preserve previous manifest as `manifest.json.bak`
3. Block stage progression (stage gate hook checks for staleness flag)
4. On resume: attempt regeneration from source artifacts, clear flag if successful

### Manifest Corruption Recovery

If manifest.json cannot be read:

1. Regenerate from: `describe.md` (scope), `spec.md` (spec_digest + work_units), `adversarial.md` (adversarial_digest), `state.json` (confidence + revision)
2. If state.json also corrupt: derive stage status from artifact file existence/timestamps
3. If all fail: halt with explicit error listing missing artifacts

### Token Budget Comparison

| Recovery Method | Approx. Tokens | Information Quality |
|----------------|----------------|-------------------|
| Read all markdown artifacts | 3,000 - 8,000+ | Complete |
| Read manifest.json | 400 - 800 | High (all key facts, structured) |
| Read state.json only | 100 - 200 | Low (progress only, no substance) |
| Read manifest + state | 500 - 1,000 | High (facts + progress) |

---

## work-graph.json Schema

Dependency graph of work units. Computed during Stage 2 (Specify), consumed by
`/delegate` at Stage 7 (Execute). Includes checksum validation against spec.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["nodes", "edges", "batches", "analysis", "spec_work_units_checksum", "generated_at"],
  "properties": {
    "nodes": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "label", "files", "status", "complexity"],
        "properties": {
          "id": { "type": "string", "pattern": "^W[0-9]+$" },
          "label": { "type": "string" },
          "files": { "type": "array", "items": { "type": "string" } },
          "status": { "type": "string", "enum": ["pending", "in_progress", "complete", "failed"] },
          "complexity": { "type": "string", "enum": ["low", "medium", "high"] },
          "tdd": {
            "type": "boolean",
            "default": false,
            "description": "Whether this WU should use TDD (RED-GREEN-REFACTOR). Assigned during Stage 2 via module characteristic heuristic. Absent field defaults to false for backward compatibility."
          }
        }
      }
    },
    "edges": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["from", "to", "type"],
        "properties": {
          "from": { "type": "string" },
          "to": { "type": "string" },
          "type": { "type": "string", "enum": ["blocks"] }
        }
      }
    },
    "batches": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "batch": { "type": "integer" },
          "units": { "type": "array", "items": { "type": "string" } },
          "parallel": { "type": "boolean" }
        }
      },
      "description": "Topologically sorted execution batches"
    },
    "analysis": {
      "type": "object",
      "properties": {
        "total_units": { "type": "integer" },
        "max_parallel_width": { "type": "integer" },
        "critical_path_length": { "type": "integer" },
        "file_conflicts": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Files touched by multiple work units in the same batch"
        },
        "parallelization_recommendation": {
          "type": "string",
          "enum": ["none", "moderate", "strong"]
        }
      }
    },
    "spec_work_units_checksum": {
      "type": "string",
      "description": "SHA-256 of spec.md Work Units section. Validated on Stage 7 entry."
    },
    "generated_at": {
      "type": "string",
      "format": "date-time"
    }
  }
}
```

### Checksum Validation

On Stage 7 entry:

1. Recompute SHA-256 of the spec.md "Work Units" section
2. Compare with `spec_work_units_checksum` in work-graph.json
3. On mismatch: auto-regenerate work-graph.json from current spec
4. If regeneration fails (malformed table): halt with error pointing to spec

### Staleness on Regression

When regressing to Stage 2:

1. Set `"work_graph_stale": true` in state.json
2. Stage 2 completion MUST regenerate work-graph.json
3. A stale work graph blocks Stage 7 progression (`/delegate` refuses to consume it)

### Parallelization Recommendation

Based on graph analysis AND user's `execution_preference`:

| Width | Critical Path | Preference | Recommendation |
|-------|--------------|------------|----------------|
| Any | Any | `speed` | `strong` (always suggest `/delegate`) |
| Any | Any | `simplicity` | `none` (always suggest sequential) |
| 1 | Any | `auto` | `none` (sequential) |
| 2 | <=3 | `auto` | `moderate` (suggest `/delegate`) |
| 3+ | Any | `auto` | `strong` (recommend `/delegate --review`) |
| Any | >5 | `auto` | `strong` (recommend `/delegate --review`) |

---

## Debate Output Schema

All debate Judge/Synthesizer rounds MUST produce structured JSON output.
This enables automatic regression trigger parsing.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["findings", "verdict"],
  "properties": {
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "finding", "severity", "convergence", "addressed"],
        "properties": {
          "id": { "type": "string", "pattern": "^F[0-9]+$" },
          "finding": { "type": "string" },
          "severity": { "type": "string", "enum": ["critical", "high", "medium", "low"] },
          "convergence": { "type": "string", "enum": ["both-agreed", "disputed", "newly-identified"] },
          "addressed": { "type": "string", "enum": ["already-in-spec", "needs-spec-update", "needs-new-section"] }
        }
      }
    },
    "verdict": {
      "type": "string",
      "enum": ["PASS", "PASS_WITH_NOTES", "REGRESS"],
      "description": "PASS: no critical. PASS_WITH_NOTES: non-critical only, proceed. REGRESS: has critical findings."
    },
    "critical_count": { "type": "integer" },
    "regression_target": {
      "type": "string",
      "description": "Stage to regress to (when verdict is REGRESS)"
    }
  }
}
```

**Fallback on parse failure:** If output cannot be parsed as valid JSON matching
this schema, treat the entire markdown output as findings, assign all `medium`
severity, flag for human review. Do NOT silently skip.

---

## overrides.json Schema

Project-level tracking of when users override recommended planning depth.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "overrides": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["plan", "date", "recommended", "chosen", "reason"],
        "properties": {
          "plan": {
            "type": "string",
            "description": "Blueprint name that was overridden"
          },
          "date": { "type": "string", "format": "date-time" },
          "recommended": { "type": "string", "enum": ["light", "standard", "full"] },
          "chosen": { "type": "string", "enum": ["light", "standard", "full"] },
          "reason": { "type": "string" },
          "stage_at_override": { "type": "string" }
        }
      }
    },
    "summary": {
      "type": "object",
      "properties": {
        "total": { "type": "integer" },
        "by_direction": {
          "type": "object",
          "properties": {
            "full_to_standard": { "type": "integer" },
            "full_to_light": { "type": "integer" },
            "standard_to_light": { "type": "integer" },
            "light_to_standard": { "type": "integer" },
            "standard_to_full": { "type": "integer" },
            "light_to_full": { "type": "integer" }
          }
        }
      }
    }
  }
}
```

---

## Stage Mapping

| Stage # | Stage Name | Command | Skippable | Required For |
|---------|------------|---------|-----------|--------------|
| 1 | Describe | `/describe-change` | No | All paths |
| 2 | Specify | `/spec-change` | Light path auto-skips | Standard, Full |
| 3 | Challenge | Debate chain / `/devils-advocate` | Yes (with reason) | Full |
| 4 | Edge Cases | Debate chain / `/edge-cases` | Yes (with reason) | Full |
| 4.5 | Pre-Mortem | `/blueprint` (inline) | Yes (with reason) | Full (recommended) |
| 5 | Review | `/gpt-review` | Yes (optional) | None |
| 6 | Test | `/spec-to-tests` | Yes (with reason) | Full |
| 7 | Execute | Implementation | No | All paths |
| 8 | Debrief | `/blueprint` (inline) | No | All paths |

Stages are tracked by **name** in state.json, not by number. The "4.5" label is
human-readable only — no schema dependency on numbering.

---

## Path Requirements

### Light Path
- Stage 1: Describe (required)
- Stage 7: Execute
- Stage 8: Debrief (structurally expected — tier 2.5 enforcement)
- Preflight recommended but not tracked

### Standard Path
- Stage 1: Describe (required)
- Stage 2: Specify (required)
- Stage 7: Execute
- Stage 8: Debrief (structurally expected)
- Other stages optional

### Full Path
- All stages available
- Stage 1, 2 required
- Stages 3-6 recommended, tracked if skipped
- Stage 4.5 (Pre-Mortem) recommended, skippable
- Stage 5 (External Review) always optional
- Stage 8 (Debrief) structurally expected, not skippable

---

## File Naming Conventions

| Artifact | Filename | Created By |
|----------|----------|------------|
| Triage output | `describe.md` | `/describe-change` |
| Specification | `spec.md` | `/spec-change` |
| Adversarial findings | `adversarial.md` | `/blueprint` (debate chain), `/devils-advocate`, `/edge-cases` |
| Pre-mortem analysis | `premortem.md` | `/blueprint` (Stage 4.5) |
| Debate transcript | `debate-log.md` | `/blueprint` (debate/team mode, debug only) |
| Manifest | `manifest.json` | `/blueprint` (auto-maintained) |
| Work graph | `work-graph.json` | `/spec-change` (Stage 2), `/blueprint` (regeneration) |
| Spec revision log | `spec.diff.md` | `/blueprint` (on regression) |
| Pre-flight check | `preflight.md` | `/preflight` |
| Research output | `research.md` | `/research` |
| External review | `review.md` | `/gpt-review` |
| Test specifications | `tests.md` | `/spec-to-tests` |
| Decision records | `decisions/[name].md` | `/decision` |
| Debrief output | `debrief.md` | `/blueprint` (Stage 8) |
| Commit log | `commits.jsonl` | Commit-time signal (plugin-enhancer, opt-in via `SAIL_BLUEPRINT_ACTIVE`) |

`adversarial.md` is the **canonical source of truth** for all findings.
`debate-log.md` is the debug artifact (raw transcript). Manifest digests are
compressed indexes for recovery only.

### research.md Frontmatter

The `/research` command produces `research.md` with YAML frontmatter for structured metadata:

```yaml
---
topic: "user authentication strategies"       # Free-text research topic
topic_slug: "user-authentication-strategies"  # Slugified topic (used for directory naming)
date: "2026-03-25"                            # Research date (ISO-8601 date)
mode: "explore"                               # Research mode: explore | deep-dive | survey
linked_blueprint: "feature-auth"              # Blueprint name if linked (null if standalone)
coverage:                                     # Coverage dimensions assessed
  - approaches
  - tradeoffs
  - prior_art
  - open_questions
gate_score: 0.75                              # Research quality gate score (0.0-1.0)
vault_findings: 3                             # Count of findings exported to vault
---
```

When `linked_blueprint` is set, the research artifact is stored in the blueprint's plan directory (`.claude/plans/<name>/research.md`). Standalone research is stored in `.claude/plans/<topic_slug>/research.md`.

---

## Pre-v2 Migration

When `/blueprint` encounters a plan directory with state.json missing `blueprint_version`:

1. **Detect:** Missing field = pre-v2 plan
2. **Apply defaults:**
   - `blueprint_version: 2`
   - `challenge_mode: "vanilla"` (original behavior)
   - `execution_preference: "auto"`
   - `epistemic_session_id: null`
   - `epistemic_preflight_complete: false`
   - `manifest_stale: false`
   - `work_graph_stale: false`
   - `premortem: { "status": "skipped", "skip_reason": "created before blueprint-v2" }`
3. **Generate manifest** from existing artifacts
4. **Notify user** of migration (see `/blueprint` command)

Existing artifacts and progress are unchanged. The plan continues from its current stage.

---

## Cleanup

Blueprints can be cleaned up after completion:

```bash
# Archive completed blueprint
mv .claude/plans/feature-x .claude/plans/_archive/feature-x

# Or delete if not needed
rm -rf .claude/plans/feature-x
```

The `/blueprints` command shows active blueprints and flags stale ones (no activity > 7 days).
