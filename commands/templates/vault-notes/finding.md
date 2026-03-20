---
type: finding
date: {{date}}
project: {{project}}
category: {{category}}
severity: {{severity}}
tags: [finding]
{{#if epistemic_confidence}}epistemic_confidence: {{epistemic_confidence}}{{/if}}
{{#if epistemic_assessed}}epistemic_assessed: {{epistemic_assessed}}{{/if}}
{{#if epistemic_session}}epistemic_session: {{epistemic_session}}{{/if}}
{{#if epistemic_status}}epistemic_status: {{epistemic_status}}{{/if}}
---

# {{title}}

{{description}}

## Source
- Session: [[{{session_link}}]]
{{#if blueprint_link}}- Blueprint: [[{{blueprint_link}}]]{{/if}}

## Implications
{{implications}}
