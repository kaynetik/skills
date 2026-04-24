# Memory and Rules

How to write durable memory rows correctly and how the rules engine gates risky actions.

## Memory tier discipline

Three tiers (`Hot`, `Warm`, `Cold`) demoted automatically by the background compactor.

- `memory_store` writes at `Hot`. Optional `metadata: { ... }` carries free-form JSON tags; use it.
- `memory_search` returns hybrid FTS5 + ANN results fused via Reciprocal Rank Fusion (k=60). Vector recall ignores `Cold` rows.
- `memory_context` is the cheap, scoped read for "what should I know about this file/session right now"; skips Cold automatically.

## `memory_store` wire shape -- read this before every call

`memory_store` accepts **exactly four fields**: `project`, `session_id`, `content`, and optional `metadata`. Nothing else. Conceptual taxonomy fields (`kind`, `title`, `tags`, `area`, `plan_id`, `decision_id`, ...) live **inside `metadata`**, never at top level.

Correct:

```json
{
  "project": "flowd",
  "session_id": "9c8b7a6d-5e4f-4a3b-9c2d-1e0f9a8b7c6d",
  "content": "Adopted per-pillar karpathy rules under .flowd/rules/karpathy/. Rationale: atomic disable per pillar.",
  "metadata": {
    "kind": "decision",
    "title": "Karpathy guidelines induced",
    "tags": ["karpathy", "rules", "loader"],
    "plan_id": "c743f0a7-00d7-433a-976d-44495f711aea"
  }
}
```

Wrong (this fails with `missing field session_id` at best, silently drops `kind` / `title` / `tags` at worst):

```json
{
  "project": "flowd",
  "kind": "decision",
  "title": "...",
  "tags": ["..."],
  "content": "..."
}
```

If you do not have a session UUID yet, mint one (any v4 UUID -- the storage layer auto-creates the session row on first reference) and reuse it for every `memory_store` call this session. Do **not** generate a fresh UUID per call; that fragments history and breaks `memory_context` recall.

## What to store

- Architectural decisions, with rationale ("chose X over Y because Z").
- Surprising tool results worth not re-deriving.
- Why a given approach was rejected (negative evidence is high-signal).

## What NOT to store

- Verbatim file contents (use search + read instead).
- Secrets / tokens.
- Per-keystroke noise; aim for one durable observation per meaningful event.

## Rules: gate before you write

`rules_check` is the pre-flight gate. Engine model:

- `ProposedAction = { tool, file_path?, project? }` -- there is no `command` / `args` / `body` field. The engine cannot inspect what a `Bash` / `Write` / `Edit` invocation actually does. Rules at this layer are *advisory nudges* that fire on tool name + file scope; the agent is responsible for honoring them in the actual content it produces.
- A rule fires if its `scope` glob matches the project OR file_path AND its `match` regex matches the tool name OR file_path.
- `level: deny` blocks (`allowed: false`); `level: warn` advises (`allowed: true` with `violations: [...]`).

Practical use:

```
rules_check(tool = "Write", file_path = "crates/flowd-storage/src/migrations.rs", project = "flowd")
```

Honor `deny`. For `warn`, surface the description to the user and proceed unless they object.

`rules_list` is purely informational -- call it at session start to learn the project's conventions even when no specific action is queued.

## Rule file layout

Rule files live under two roots, both loaded **recursively** at daemon startup:

- `~/.flowd/rules/**/*.yaml` -- global rules.
- `<repo>/.flowd/rules/**/*.yaml` -- project rules.

The recursive walker honors a fixed contract: unbounded depth, depth-first, lexicographic order per directory; symlinks are never followed; `.yaml` / `.yml` only (case-insensitive); malformed YAML at any depth fails fast with a path-pointing error; duplicate `id` across files (or across global+project) is rejected rather than silently overridden. Project rules augment global rules; they never replace them.

Subdirectory grouping is purely organizational -- for example `.flowd/rules/karpathy/think-before-coding.yaml` loads identically to `.flowd/rules/think-before-coding.yaml`. Pick the layout that gives operators atomic per-area enable/disable.

## Daemon restart boundaries

Some changes only take effect after the daemon process restarts:

- New rule files anywhere under `~/.flowd/rules/` or `<repo>/.flowd/rules/`.
- Edits to existing rule files.
- New rules-engine code (loader changes, evaluator changes) -- requires a rebuild *and* restart.

Live MCP calls against a stale daemon will silently behave as if the new rules / code do not exist. After installing rules or rebuilding, surface to the user that a restart is required (e.g. "Run `flowd stop && flowd start` to pick up the new karpathy rules") rather than running `rules_check` / `memory_context` and reporting a misleading "0 rules found".
