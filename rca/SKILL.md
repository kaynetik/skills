---
name: rca
description: Root cause analysis for bugs, incidents, failed tests, build errors, outages, and unexpected behavior. Use when the user asks for RCA, root cause, why something failed, or asks to diagnose a problem from code, logs, tests, traces, tickets, or terminal output.
---

# Root Cause Analysis

## Goal

Find the most likely root cause from available evidence. Stay brief, explicit, and falsifiable.

## Method

1. Identify the context: language, framework, runtime, toolchain, environment, and failure mode.
2. Separate observed facts from assumptions. Do not invent missing logs, code paths, services, timings, or user actions.
3. Trace backward from the symptom to the earliest credible cause.
4. Prefer causes supported by code, logs, tests, config, version changes, or reproducible behavior.
5. If evidence is incomplete, say what is unknown and name the next smallest check.

## Output

Use this format unless the user asks otherwise:

```markdown
Root cause: <one concise sentence>

Evidence:
- <fact that supports the cause>
- <fact that supports the cause>

Fix:
- <smallest corrective action>

Confidence: <high|medium|low> because <short reason>
```

## Rules

- Be concise. Do not pad with process language.
- Do not speculate beyond the evidence. Label hypotheses as hypotheses.
- Do not recommend broad rewrites unless the evidence points there.
- Do not hide uncertainty.
- When multiple causes are plausible, rank them by evidence and propose one discriminating check.
