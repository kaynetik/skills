# Operations, Anti-Patterns, and Example Trace

CLI vs MCP boundaries, configuration surfaces, the full anti-pattern catalogue, and a reference session trace.

## CLI vs MCP -- write paths conflict with the live daemon

The `flowd` CLI binary and the MCP server share one SQLite database. **While the daemon is running, every CLI write path will fail** with `attempt to write a readonly database`:

- `flowd observe` -- fails. Use `memory_store` over MCP.
- `flowd plan refine` (offline form) -- fails. Use `plan_refine` over MCP.
- Any other CLI command that mutates state -- same.

CLI **read** commands (`flowd search`, `flowd history`, `flowd plan events`, `flowd plan preview`, `flowd rules list`, `flowd status`, `flowd export`) are safe because they open the DB read-only. Use them freely for inspection -- they often surface fields the MCP tools do not (e.g. `flowd plan events` shows the lifecycle event log including `step_failed` rows, which is the fastest way to understand a plan that finished in `failed` status).

If a CLI write fails on the lock, do **not** sidestep by stopping the daemon -- that orphans MCP context for any other client connected to the same daemon. Just route the call through the MCP tool instead.

## Configuration surfaces

- `~/.flowd/flowd.toml` -- daemon config. `[plan].compiler` selects `stub` (deterministic markdown parser) or `llm`. `[plan.llm].provider` is `claude-cli` (default), `mlx` (any OpenAI-compatible local server), or `claude-http` (reserved). `[plan.llm.refine]` configures two-tier escalation.
- `~/.flowd/rules/**/*.yaml` -- global rules, loaded recursively.
- `<repo>/.flowd/rules/**/*.yaml` -- project rules, loaded recursively. Both roots load at daemon startup; project rules augment global, never override. Subdirectory grouping (e.g. `karpathy/`, `ci/`) is purely organizational; depth is unbounded; symlinks are not followed; duplicate `id` across files is rejected. See `memory-and-rules.md` "Rule file layout".
- `compiler_override` on `plan_create` -- one-shot per-request override of the LLM backend (`"claude-cli"`, `"mlx"`, `"claude-http"`) on the **initial** compile. Ignored on subsequent `plan_answer` / `plan_refine`, when `definition` is supplied, or when the active compiler is not the LLM compiler.

## Anti-patterns

1. **Skipping the schema check before MCP calls.** The skill is a guide; the JSON descriptor in `mcps/.../tools/<tool>.json` is the contract. Even for tools you have used in this session, re-check when the call shape is non-trivial (`memory_store`, `plan_create`, `plan_answer`). Cost: one Read. Reward: no `missing field` round trips and no silently-dropped fields.
2. **Lifting conceptual fields to top-level on `memory_store`.** `kind`, `title`, `tags`, `area`, `plan_id`, etc. all live **inside `metadata`**. The four top-level fields are `project`, `session_id`, `content`, `metadata`. See `memory-and-rules.md`.
3. **Per-call session_ids.** Mint one UUID at session start and reuse it. Per-call IDs fragment history and break `memory_context` recall.
4. **Sidestepping a misshaped MCP call by switching to the offline CLI.** `flowd observe` / `flowd plan refine` will fail on the SQLite write lock while the daemon is up. Re-read the schema and retry the MCP call instead.
5. **Treating `step_failed` as "nothing happened".** The daemon does not roll back agent work. Inspect the working tree before re-running. See `planning.md` "Partial success on `step_failed`".
6. **Calling `rules_check` / `memory_context` after editing rules without restarting the daemon.** The live daemon holds a snapshot from startup; new rules and rebuilt loader code are invisible until restart. See `memory-and-rules.md` "Daemon restart boundaries".
7. **Storing file contents.** Memory rows should carry decisions and rationale, not raw code. Use search + read for code.
8. **Hand-authored DAGs by default.** Prefer prose; only fall back to `definition` when the user already has the structure or the compiler is unavailable.
9. **Ignoring `pending_clarification`.** Treat it as control flow: route the open questions back through `plan_answer`. Do not surface it to the user as an error.
10. **Polling `plan_status` faster than once per second.** It is idle-safe by design but still queries SQLite. Back off when the plan is `running` for a while.
11. **Skipping `rules_check` on writes inside someone else's repo.** Project-local rules under `<repo>/.flowd/rules/` exist precisely to catch outside contributors. Always run the gate.
12. **Calling `plan_cancel` then waiting.** Cancellation latches immediately; in-flight steps abort. There is nothing to wait for after `cancelled` is returned.
13. **Treating `warn` violations as blockers.** `warn` is advisory. Surface the description to the user and proceed unless they object.

## Example session trace

A typical "user asks for a refactor" flow:

```
1. session_id = uuid()

2. memory_context(project="flowd", session_id, hint="refactor auth module")
   -> { observations: [...past auth work...], rules: [crate-boundaries, mcp-wire-discipline, ...] }

3. memory_search(query="JWT signing decision", project="flowd")
   -> hits or empty; informs whether the user has revisited this before

4. plan_create(project="flowd", prose="<user's request>")
   -> { plan_id, status: "draft", open_questions: [q1, q2] }

5. plan_answer(plan_id, answers=[{question_id:"q1", kind:"choose", option_id:"opt_a"}, ...])
   -> { status: "draft", open_questions: [], decisions: [...], preview: { layers, edges } }

6. plan_confirm(plan_id)
   -> { status: "running" }

7. plan_status(plan_id)   # poll loop, >= 1s cadence
   -> { status: "completed", steps: [...] }

8. memory_store(
     project    = "flowd",
     session_id = session_id,
     content    = "Refactored auth: extracted JWT helpers into auth/jwt.rs, switched to jsonwebtoken crate, kept session layer untouched. Rationale: keeps signing-algorithm swap to one module.",
     metadata   = { "kind": "decision", "area": "auth", "plan_id": <plan_id> }
   )
   # NOTE: kind/area/plan_id live INSIDE metadata. The four top-level fields
   # are exactly: project, session_id, content, metadata.
```
