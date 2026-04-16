# Negotiation Protocol

For comparative queries, cross-domain questions, and ambiguous scope.

## When to Enable

| Query Pattern | Enable | Reason |
|---------------|--------|--------|
| Single error code lookup | No | Direct answer |
| Single crate version | No | Direct lookup |
| "Compare X and Y" | Yes | Multi-faceted |
| Domain + error | Yes | Cross-layer context |
| "Best practices for..." | Yes | Requires synthesis |
| Ambiguous scope | Yes | Needs clarification |

## Response Format

When negotiation is enabled, structure the response as:

```markdown
## Analysis

**Query Type:** Comparative | Cross-domain | Synthesis | Ambiguous
**Confidence:** HIGH | MEDIUM | LOW

### Findings
[Structured comparison or synthesis]

### Gaps
[What information is missing or uncertain]
```

## Decision Flow

```
Is query a single lookup? (version, error code, definition)
  Yes -- Direct answer, no negotiation

Does query require comparison, cross-domain context, or synthesis?
  Yes -- Enable negotiation, structured response

Is scope ambiguous?
  Yes -- Enable negotiation, ask clarifying questions
  No -- Direct answer
```

## Escalation

If confidence is LOW after initial analysis:

1. Refine with more context from the user
2. Try alternative module or source
3. If still insufficient, provide best-effort answer with explicitly disclosed gaps

Do not fabricate confidence. If uncertain, say so.
