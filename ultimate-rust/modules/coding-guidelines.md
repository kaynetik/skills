# Rust Coding Guidelines

## Naming

| Rule | Guideline |
|------|-----------|
| No `get_` prefix | `fn name()` not `fn get_name()` |
| Iterator convention | `iter()` / `iter_mut()` / `into_iter()` |
| Conversion naming | `as_` (cheap &), `to_` (expensive), `into_` (ownership) |
| Static var prefix | `G_CONFIG` for `static`, no prefix for `const` |

```
Naming: snake_case (fn/var), CamelCase (type), SCREAMING_CASE (const)
```

## Data Types

| Rule | Guideline |
|------|-----------|
| Use newtypes | `struct Email(String)` for domain semantics |
| Pre-allocate | `Vec::with_capacity()`, `String::with_capacity()` |
| Avoid Vec abuse | Use arrays for fixed sizes |
| Prefer slice patterns | `if let [first, .., last] = slice` |

## Strings

| Rule | Guideline |
|------|-----------|
| Prefer bytes | `s.bytes()` over `s.chars()` when ASCII |
| Use `Cow<str>` | When might modify borrowed data |
| Use `format!` | Over string concatenation with `+` |

## Error Handling

| Rule | Guideline |
|------|-----------|
| Use `?` propagation | Not `try!()` macro |
| `expect()` over `unwrap()` | With a reason string when invariant holds |
| Assertions for invariants | `assert!` at function entry |

## Memory

| Rule | Guideline |
|------|-----------|
| Meaningful lifetimes | `'src`, `'ctx` not `'a` |
| `try_borrow()` for RefCell | Avoid panic |
| Shadowing for transformation | `let x = x.parse()?` |

## Concurrency

| Rule | Guideline |
|------|-----------|
| Identify lock ordering | Prevent deadlocks |
| Atomics for primitives | Not Mutex for bool/usize |
| Sync for CPU-bound | Async is for I/O |
| No locks across await | Use scoped guards |

## Comments

- `///` for public item docs, `//!` for module/crate docs, `//` for inline.
- No decorative Unicode separators in comments or config.
- No box-drawing characters as dividers.

## Deprecated Patterns

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `lazy_static!` | `std::sync::OnceLock` | 1.70 |
| `once_cell::Lazy` | `std::sync::LazyLock` | 1.80 |
| `std::sync::mpsc` | `crossbeam::channel` | - |
| `std::sync::Mutex` (perf) | `parking_lot::Mutex` | - |
| `failure`/`error-chain` | `thiserror`/`anyhow` | - |
| `try!()` | `?` operator | 2018 |
| `#[macro_use]` | Explicit import | 2018 |
| `extern crate` | `use` directly | 2018 |

## Macros

| Rule | Guideline |
|------|-----------|
| Avoid unless necessary | Prefer functions/generics |
| Follow Rust syntax | Macro input should look like Rust |
