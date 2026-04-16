# Error Handling

## Core Question

**Is this failure expected or a bug?**

Before choosing error handling strategy:
- Can this fail in normal operation?
- Who should handle this failure?
- What context does the caller need?

## Decision Flowchart

```
Is failure expected?
  Yes -- Is absence the only "failure"?
    Yes -- Option<T>
    No -- Result<T, E>
      Library code -- thiserror
      Application code -- anyhow
  No -- Is it a bug?
    Yes -- panic!, assert!
    No -- Consider if truly unrecoverable

Need context on propagation?
  Yes -- .context("what was happening")
  No -- Plain ?
```

## Quick Reference

| Pattern | When | Example |
|---------|------|---------|
| `Result<T, E>` | Recoverable error | `fn read() -> Result<String, io::Error>` |
| `Option<T>` | Absence is normal | `fn find() -> Option<&Item>` |
| `?` | Propagate error | `let data = file.read()?;` |
| `unwrap()` | Dev/test only | Never in production paths |
| `expect("reason")` | Invariant holds | `env.get("HOME").expect("HOME set")` |
| `panic!` | Unrecoverable bug | `panic!("critical invariant violated")` |

## Library vs Application

| Context | Crate | Why |
|---------|-------|-----|
| Library | `thiserror` | Typed errors for consumers |
| Application | `anyhow` | Ergonomic error propagation |
| Mixed | Both | thiserror at boundaries, anyhow internally |

## Error to Design Question

| Pattern | Don't Say | Ask Instead |
|---------|-----------|-------------|
| unwrap panics | "Use ?" | Is None/Err actually possible here? |
| Type mismatch on ? | "Use anyhow" | Are error types designed correctly? |
| Lost error context | "Add .context()" | What does the caller need to know? |
| Too many error variants | "Use Box<dyn Error>" | Is error granularity right? |
