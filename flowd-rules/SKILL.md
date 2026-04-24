---
name: flowd-rules-author
description: Authors flowd rule YAML files for `.flowd/rules/` (project) or `~/.flowd/rules/` (global), encoding the engine's `ProposedAction` blind spots, the `deny` vs `warn` decision, glob `scope` vs regex `match`, and a four-part description template. Use when creating or editing flowd rules, when the user mentions flowd, rules engine, rules_check, rules_list, ProposedAction, or asks to gate or warn against tool calls or file edits in a flowd-managed repo.
---

# flowd Rules Author

## What the engine actually sees

The flowd rules engine evaluates a `ProposedAction` carrying only three fields:

```
tool:      String          // e.g. "Bash", "Edit", "Write"
file_path: Option<String>  // target path of the action
project:   Option<String>  // current project context
```

It does not see command arguments, edit bodies, diff contents, or source text. Schema lives in `crates/flowd-core/src/rules.rs`.

A rule has five fields:

```yaml
id:          # stable identifier, unique across loaded rules
scope:       # glob over file path or project name
level:       # warn | deny
description: # multi-line guidance shown to the agent
match:       # regex matched against tool name OR file_path
```

## deny vs warn -- the decision rule

Use `deny` only when the gate (`scope` glob plus `match` regex) can be evaluated purely from `{tool, file_path}` and a true match means the action itself is wrong.

Use `warn` when the rule depends on content the engine cannot see -- command arguments, diff body, intent. The agent honors warnings by reading them via `rules_list` or `rules_check`.

| Constraint                                | Engine can enforce?  | Level  |
| ----------------------------------------- | -------------------- | ------ |
| "Don't edit this Cargo.toml"              | Yes (file_path)      | `deny` |
| "Don't run `cargo build`"                 | No (args invisible)  | `warn` |
| "Don't add `println!` to mcp/src"         | No (diff invisible)  | `warn` |
| "Don't run any shell tool in test dirs"   | Yes (tool + scope)   | `deny` |

Promoting an advisory rule to `deny` blocks legitimate edits across the whole scope.

## scope vs match

`scope` is a glob; `match` is a regex. They look similar in YAML and use different engines.

- `scope: "**"` matches every action. Use for tool-name-only rules.
- `scope: "crates/flowd-core/**"` matches by file path.
- `scope: "my-project"` matches by project name (no globbing).
- `match: "^(Bash|...)$"` matches the tool name.
- `match: "crates/flowd-mcp/src/.*\\.rs$"` matches the file path.

Either `scope` or `match` may carry the path constraint; pick one and keep the other broad. Mixing both narrows the rule unintentionally.

### Canonical tool-name regexes

Copy verbatim. Shell-class tools across Claude Code, Cursor, and generic MCP wire:

```
^(Bash|shell|shell_exec|run_command|run_terminal_cmd)$
```

Edit-class plus shell-class:

```
^(Bash|Write|Edit|MultiEdit|shell|shell_exec|run_command|run_terminal_cmd)$
```

## Global vs project placement

| Rule references...                              | Place under         |
| ----------------------------------------------- | ------------------- |
| Specific paths in this repo                     | `.flowd/rules/`     |
| Engineering principles, language conventions    | `~/.flowd/rules/`   |
| Tool or CLI invocations regardless of project   | `~/.flowd/rules/`   |

Project rules augment globals. Uniqueness is enforced by `id`, so prefix repo-local ids with the repo name when collision is plausible.

## Description template

Every rule description follows this four-part structure:

1. **What and why** -- one or two sentences of intent.
2. **The footgun** -- the future mistake this rule prevents (often "a future agent will look at X and try to fix it").
3. **Engine caveat** -- when the rule is advisory, state the limitation so the next author does not promote it to `deny`.
4. **Cross-reference** -- README section, sibling rule id, or source file path.

Skip step 3 when the rule is enforceable (`deny` on observable `file_path`).

## File layout

Prefer one rule per file, named after the rule id. Both single-rule and list layouts are accepted by `crates/flowd-core/src/rules/loader.rs`. Use the list layout only for tightly-coupled rule families sharing intent (for example multiple `cargo-*` rules grouped in `cargo-discipline.yaml`).

## Worked examples

### Enforceable deny

```yaml
id: forward-only-migrations
scope: "crates/flowd-storage/src/**"
level: deny
description: |
  Schema migrations are forward-only by project policy and live as inline
  `const MIGRATION_NNN: &str` constants in
  `crates/flowd-storage/src/migrations.rs` (not as .sql files).

  Editing or reordering an existing MIGRATION_NNN constant is a breaking
  change for every installed user -- append a new, higher-numbered constant
  and add it to the MIGRATIONS slice instead.
match: "crates/flowd-storage/src/migrations\\.rs$"
```

### Advisory warn

```yaml
id: mcp-wire-discipline
scope: "crates/flowd-mcp/src/**"
level: warn
description: |
  Stdout is reserved for JSON-RPC 2.0 frames when flowd runs as an MCP stdio
  subprocess. Diagnostics MUST go to stderr -- use `eprintln!`, `tracing::*`,
  or write to `std::io::stderr()`. A single stray `println!`, `print!`, or
  `dbg!` corrupts the wire and breaks every connected MCP client silently.

  Note: the rules engine cannot read source contents (a ProposedAction carries
  only { tool, file_path, project }), so this rule is an advisory triggered on
  any edit under crates/flowd-mcp/src/. The agent is responsible for honoring
  the constraint in the diff itself.
match: "crates/flowd-mcp/src/.*\\.rs$"
```

## Validation

After writing or editing a rule:

1. Parse and compile check:

   ```bash
   cargo test -p flowd-core --lib rules::
   ```

2. Confirm the daemon loaded it for the intended scope:

   ```bash
   flowd rules list -p <project-name>
   flowd rules list -f <repo-relative-path>
   ```

   Bare `flowd rules list` evaluates against an empty scope and returns no matches even when rules are loaded.

## Anti-patterns

- `level: deny` on a rule whose `match` only constrains the tool name with no `file_path` predicate. Blocks the entire toolclass across the scope.
- File name differs from the `id`. Breaks grep-by-id.
- Rule body embedded in `match` instead of `description`. `match` is a regex, not prose.
- Globally scoped rules referencing repo-specific paths. They fire in unrelated projects.
- Adding `level: deny` to advisory rules because "the comment said it was a mistake". If the engine cannot observe the violation, `deny` blocks legitimate work.

## Reference

- Schema: `crates/flowd-core/src/rules.rs` (`Rule`, `RuleLevel`, `ProposedAction`).
- Loader: `crates/flowd-core/src/rules/loader.rs` (single vs list layout, recursive YAML discovery, no symlink follow).
- Evaluator: `crates/flowd-core/src/rules/evaluator.rs` (glob compilation, regex compilation, lookup).
- README sections: "Use the agent" (MCP tool table) and "Recommendations" (rule placement guidance).
