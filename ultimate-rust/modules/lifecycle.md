# Resource Lifecycle

## Core Question

**When should this resource be created, used, and cleaned up?**

Before implementing lifecycle:
- What is the resource's scope?
- Who owns cleanup responsibility?
- What happens on error during cleanup?

## Pattern Catalog

| Pattern | When | Implementation |
|---------|------|----------------|
| RAII | Auto cleanup on scope exit | `Drop` trait |
| Lazy init | Deferred creation | `OnceLock`, `LazyLock` |
| Pool | Reuse expensive resources | `r2d2`, `deadpool` |
| Guard | Scoped access with auto-release | `MutexGuard` pattern |
| Scope | Transaction boundary | Custom struct + Drop |

## Design Questions

| Question | Determines |
|----------|------------|
| What is the resource cost? | Create per use vs pool vs cache |
| What is the scope? | Stack, request-scoped, or application-wide |
| What about errors during cleanup? | Drop (infallible) vs explicit close (Result) |

## RAII Guard

```rust
struct FileGuard {
    path: PathBuf,
    _handle: File,
}

impl Drop for FileGuard {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.path);
    }
}
```

## Lazy Singleton

```rust
use std::sync::OnceLock;

static CONFIG: OnceLock<Config> = OnceLock::new();

fn get_config() -> &'static Config {
    CONFIG.get_or_init(|| {
        Config::load().expect("config required")
    })
}
```

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| Resource leak | Forgot Drop | Implement Drop or RAII wrapper |
| Use after drop | Dangling reference | Check lifetimes |
| E0509 move out of Drop | Moving owned field | `Option::take()` |
| Pool exhaustion | Not returned | Ensure Drop returns to pool |

## Deprecated Patterns

| Deprecated | Use Instead |
|------------|-------------|
| `lazy_static!` | `std::sync::OnceLock` |
| `once_cell::Lazy` | `std::sync::LazyLock` |
| Manual cleanup calls | RAII / Drop |
