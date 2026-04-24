# Planning Lifecycle

How to drive flowd's prose-first DAG planner end-to-end, plus the DAG-first escape hatch and failure recovery.

## State machine

```
plan_create(prose)
   |
   v
+---------+   open_questions?   +-------------+
|  Draft  +-------------------->| plan_answer |<--+ overwrite
+----+----+                     +------+------+   | answer
     ^                                 |          |
     | plan_refine(feedback)           v          |
     +<----------------------+  re-compile -------+
     |                       |
     | open_questions empty  |
     v                       |
+----------+    plan_confirm    +---------+   plan_status   +-------------------+
| Confirmed|------------------->| Running |---------------->| Completed/Failed  |
+----+-----+                    +----+----+                 +---------+---------+
     |                               |                                |
     |                               | plan_cancel (latch)            | failed?
     v                               v                                v
+-----------+                   +-----------+                  plan_resume
| Cancelled |<------------------| Cancelled |
+-----------+                   +-----------+
```

States: `Draft -> Confirmed -> Running -> {Completed | Failed | Cancelled}`. `Cancelled` is reachable from Draft, Confirmed, and Running. `plan_resume` moves a Failed plan back through Confirmed -> Running with failed steps reset to pending.

## Prose-first authoring (default path)

Prefer prose over hand-authored DAGs. The compiler's job is to turn intent into a DAG; if it asks bad questions, that is a compiler bug worth surfacing, not a reason to bypass it.

### 1. Submit prose

```
plan_create(
  project = "<repo>",
  prose   = "Refactor the auth module so we can swap the JWT signing
             algorithm without touching the session layer. Then run
             the integration tests."
)
```

Returns `{ plan_id, status: "draft", open_questions: [...], decisions: [...], preview? }`.

### 2. Resolve clarifications

For each `OpenQuestion` in the response, pick the option whose `rationale` matches the user's intent. Bundle answers into one call:

```
plan_answer(
  plan_id = "...",
  answers = [
    { "question_id": "jwt_lib",      "kind": "choose",       "option_id": "jsonwebtoken" },
    { "question_id": "key_rotation", "kind": "explain_more", "note": "discuss zero-downtime rotation" },
    { "question_id": "test_scope",   "kind": "none_of_these" }
  ],
  defer_remaining = false
)
```

Three answer kinds:

- `choose` -- pick a surfaced option by `option_id`. Most common.
- `explain_more` -- ask the compiler to elaborate; **does not** resolve the question.
- `none_of_these` -- reject all options; compiler must propose new ones.

`defer_remaining: true` lets the compiler auto-fill any remaining questions with best-effort defaults marked as auto-decisions. Use sparingly; the user loses visibility.

### 3. Refine if needed

```
plan_refine(plan_id = "...", feedback = "make step `migrate-callers` idempotent and add a rollback step after it")
```

May surface new clarifications if the change introduces new architectural decisions.

### 4. Confirm and execute

```
plan_confirm(plan_id = "...")
```

Returns `pending_clarification` (with the outstanding question list) if any open questions remain -- that is normal control flow, not an error. Otherwise the plan transitions Draft -> Running and execution starts asynchronously.

### 5. Poll until terminal

```
plan_status(plan_id = "...")    # idle-safe; poll freely
```

Statuses: `draft`, `confirmed`, `running`, `completed`, `failed`, `cancelled`. Surface step-level status to the user as it arrives.

`plan_status` returns the full `Plan` object, including `source_doc` (the prose form, useful for inspecting what was actually compiled), `decisions` (answered clarifications), and per-step `started_at` / `completed_at` / `output` / `error`.

Two observability gaps to be aware of:

- The daemon does **not** emit a `step_started` lifecycle event. A step transitions directly from absent in the event log to either `step_completed` or `step_failed`. While a step is in flight, the only signals are `plan_status.steps[i].started_at` becoming non-null and any side effects (filesystem writes, DB rows) the agent itself produces. If you need real-time progress on a long step, watch the working tree.
- `plan_status` and `flowd plan events` show the same lifecycle but from different angles. Use `flowd plan events` (read-only, safe with the daemon running) when you need the chronological event log including `step_failed` error strings.

### 6. Recover from failure

```
plan_resume(plan_id = "...")    # only on `failed`
```

Resets failed steps to pending, re-confirms, re-runs. Use after the underlying issue is fixed.

### 7. Cancel cleanly

```
plan_cancel(plan_id = "...")    # legal from Draft, Confirmed, or Running
```

Idempotent; re-calling on a terminal plan is a no-op. Cancellation latches immediately; in-flight steps abort. There is nothing to wait for after `cancelled` is returned.

## Partial success on `step_failed`

A failed step **does not roll back the work the agent already did** before the failure was raised. Common case: an agent successfully writes files, then its summary message hits a transient provider error, the daemon marks the step `failed`, and the rest of the DAG short-circuits -- but the artifacts are still on disk.

Before re-running, **inspect the working tree** (`git status`, `ls` the expected paths). If the work landed, finish the verification step manually (run `cargo test` / `pnpm test` / whatever the verify-step would have run) and persist a closing `memory_store` decision row capturing the outcome. Do not call `plan_resume` on a step whose work already succeeded -- it will re-invoke the agent and risk duplicating side effects.

## DAG-first authoring (escape hatch)

When the user already has a structured plan in hand, skip the compiler:

```
plan_create(
  project = "<repo>",
  definition = {
    "name": "refactor-auth",
    "steps": [
      { "id": "extract-jwt",      "agent_type": "rust-engineer", "prompt": "..." },
      { "id": "migrate-callers",  "agent_type": "rust-engineer", "prompt": "...", "depends_on": ["extract-jwt"] },
      { "id": "smoke-test",       "agent_type": "tester",        "prompt": "...", "depends_on": ["migrate-callers"], "timeout_secs": 600 }
    ]
  }
)
```

`prose` and `definition` are mutually exclusive (enforced by `oneOf` in the schema). DAG-first plans skip the clarification loop entirely.

## Polling cadence

`plan_status` is idle-safe by design (it does not bump the activity monitor), but the executor still has to query SQLite. Do not poll faster than once per second; back off when the plan is `running` for a while.
