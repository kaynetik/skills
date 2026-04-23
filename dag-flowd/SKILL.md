---
name: dag-flowd
description: Use flowd's local-first MCP server (12 tools) for cross-session memory, prose-first DAG planning with a clarification loop, and rules-based action gating. Activate when the agent should persist a decision, recall prior context, plan a multi-step change, gate a risky action, or when the user mentions flowd, memory_store, memory_search, memory_context, plan_create, plan_answer, plan_refine, plan_confirm, plan_status, plan_resume, plan_cancel, rules_check, or rules_list.
---

# dag-flowd: Use Flowd's MCP Surface Effectively

flowd is a local-first memory + orchestration + rules engine that exposes a 12-tool MCP server over stdio. This skill body is intentionally thin; depth lives in `references/`. Open at most one reference per turn.

## When this skill activates

- The flowd MCP server is wired into this client (`mcp.json` lists `flowd` or the client's tool list contains any `memory_*` / `plan_*` / `rules_*` tool).
- The user mentions flowd, planning, memory, dogfooding, "what did we decide about X", or asks for a multi-step change.
- The agent is about to do something risky (write to a sensitive path, run a destructive command, edit migrations).
- The agent has a non-trivial decision worth preserving across sessions.

If flowd is not wired, mention it once and proceed without it. Do not block on missing infrastructure.

## Schema discipline (mandatory, no exceptions)

**Read the JSON descriptor at `mcps/<server>/tools/<tool>.json` before every MCP call.**

This skill is a *guide* describing intent and composition. The JSON descriptor is the *contract*. The two can drift, and "I called this tool last week" is not justification to skip the schema check. The most common failure mode is lifting conceptual fields (`kind`, `title`, `tags`, `area`, `plan_id`) to top-level args when the schema only accepts a small fixed set and expects the rest under `metadata`.

The descriptor tells you exactly three things you need:

1. The `required` array -- anything missing here fails with `missing field <name>` immediately.
2. The full `properties` map -- anything not listed here is silently dropped or rejected.
3. Constraint blocks like `oneOf` (e.g. `plan_create`'s `prose` XOR `definition`) -- easy to miss in the prose description.

Cost of compliance: one Read per tool, once per tool you have not used in this session. Cost of skipping: a round trip per misshaped call, plus the agent's tendency to "fix" the error by switching to the wrong tool entirely.

## The 12 tools at a glance

| Tool | Purpose | Required params | When to call |
|---|---|---|---|
| `memory_store` | Persist an observation (decision, design note, tool result) | `project`, `session_id`, `content` | After every architectural decision, surprising tool result, or "remember this" moment |
| `memory_search` | Hybrid FTS5 + ANN search across all stored memory | `query` | Before designing anything non-trivial; check what past sessions decided |
| `memory_context` | Auto-inject relevant memory + active rules for a file/session | `project` | At session start, and when switching to a new file |
| `plan_create` | Register a plan (prose-first or DAG-first) | `project` + (`prose` XOR `definition`) | When the work is multi-step or has clarifications worth recording |
| `plan_answer` | Resolve open clarification questions on a Draft plan | `plan_id`, `answers` | After `plan_create` returns `open_questions` |
| `plan_refine` | Apply freeform feedback to a Draft plan and re-compile | `plan_id`, `feedback` | When the user says "no, do it this way instead" |
| `plan_confirm` | Move Draft -> Running, kick off async execution | `plan_id` | Once `open_questions` is empty and the preview looks right |
| `plan_status` | Poll execution progress (read-only, idle-safe) | `plan_id` | After `plan_confirm`, in a polling loop |
| `plan_resume` | Reset failed steps, re-run from the failure boundary | `plan_id` | When `plan_status` shows `failed` and the underlying issue is fixed |
| `plan_cancel` | Idempotently abandon a Draft / Confirmed / Running plan | `plan_id` | When the plan is wrong or the user changes direction |
| `rules_check` | Gate a proposed tool invocation against deny / warn rules | `tool` (+ optional `file_path`, `project`) | Before any write/exec the user might consider risky |
| `rules_list` | Enumerate rules in scope for the current project / file | (both optional) | At session start, and when starting work in a new directory |

The `Required params` column is a summary, not a substitute for the descriptor. Always re-check the live schema.

## Routing table

| User intent or task | Open file |
|---|---|
| Drive a plan end-to-end (prose-first lifecycle, DAG-first escape hatch, `plan_resume`, partial-success recovery, polling cadence) | `references/planning.md` |
| Write durable memory rows correctly (`memory_store` wire shape, tier behavior), or work with the rules engine (`rules_check` semantics, rule file layout, daemon restart boundaries) | `references/memory-and-rules.md` |
| CLI vs MCP write conflicts, configuration surfaces (`flowd.toml`, `compiler_override`), the full anti-pattern catalogue, or a reference session trace | `references/operations.md` |

## Session bootstrap (run once per session)

Do this in the first turn whenever flowd is wired and the project is identifiable:

1. **Mint a session_id.** Generate a UUID and reuse it for every `memory_store` call this session. Do not fabricate one per call.
2. **Pull context.** `memory_context(project, file_path?, session_id, hint)` -- `hint` is a short string describing what the user just asked for. The response contains both prior observations and the matching rules; use both to inform the plan.
3. **Note the rules.** `rules_list(project, file_path?)` if you need a fuller view than what `memory_context` returned. Read every `description`; rules are the codified scars of past mistakes.

```
session_id = "<uuid you generate once>"
memory_context(project="<repo>", session_id, hint="<what the user wants>")
rules_list(project="<repo>")     # optional, for the full view
```

## Decision tree

```
User asks for...                                Call...
-------------------------------------------     -------------------------------------------
"What did we decide about X?"                   memory_search(query="X", project, limit=5)
"Help me with this file"                        memory_context(project, file_path, session_id, hint)
A multi-step change                             plan_create(prose), then plan_answer / plan_refine / plan_confirm
A one-shot edit                                 rules_check(tool, file_path, project), then do the edit
"Why is X done that way?"                       memory_search first; only re-derive if no hits
"Run these N steps in order"                    plan_create(definition=...)  (DAG-first, skip compiler)
A failed plan recovered                         plan_resume(plan_id)
"Forget that plan"                              plan_cancel(plan_id)

After completing any non-trivial decision       memory_store(project, session_id, content, metadata)
```

## Top mistakes to avoid

The full list is in `references/operations.md`. The five worst are:

1. **Skipping the JSON schema check before MCP calls.** One Read prevents a round trip.
2. **Lifting `kind` / `title` / `tags` / `area` / `plan_id` to top-level on `memory_store`.** They live inside `metadata`. Top-level is exactly `project`, `session_id`, `content`, `metadata`.
3. **Per-call `session_id`s.** Mint one UUID at session start and reuse it.
4. **Treating `step_failed` as "nothing happened".** Inspect the working tree before `plan_resume`; the daemon does not roll back.
5. **Sidestepping a misshaped MCP call by switching to the offline CLI.** The CLI write paths fail on the SQLite lock while the daemon is up. Re-read the schema and retry the MCP call.

## When flowd is not wired

If the MCP tools are not available, fall back gracefully:

- For "what did we decide about X" -> grep the repo for related commits / docs.
- For multi-step plans -> use the agent's native TODO mechanism.
- For risky writes -> ask the user explicitly instead of running a gate.

Mention once that flowd would have helped, then move on. Do not block.
