# Anti-Patterns

## Core Question

**Is this pattern hiding a design problem?**

When reviewing code:
- Is this solving the symptom or the cause?
- Is there a more idiomatic approach?
- Does this fight or flow with Rust's ownership model?

## Anti-Pattern Catalog

| Anti-Pattern | Why Bad | Better |
|--------------|---------|--------|
| `.clone()` everywhere | Hides ownership issues | Proper references or ownership design |
| `.unwrap()` in production | Runtime panics | `?`, `expect("reason")`, or match |
| `Rc` when single owner | Unnecessary overhead | Simple ownership |
| `unsafe` for convenience | UB risk | Find the safe pattern |
| OOP via `Deref` | Misleading API | Composition, traits |
| `String` everywhere | Allocation waste | `&str`, `Cow<str>` |
| Giant match arms | Unmaintainable | Extract to methods |
| `Arc<Mutex<T>>` everywhere | Contention, complexity | Message passing (channels) |
| `Box` for small types | Unnecessary allocation | Stack allocation |
| `HashMap` for small sets | Overhead | Vec with linear search |

## Code Smell to Refactoring

| Smell | Indicates | Refactoring |
|-------|-----------|-------------|
| Many `.clone()` | Ownership unclear | Clarify data flow |
| Many `.unwrap()` | Error handling absent | Add proper handling |
| Many `pub` fields | Encapsulation broken | Private + accessors |
| Deep nesting | Complex logic | Extract methods |
| Long functions (>50 lines) | Multiple responsibilities | Split |
| Giant enums | Missing abstraction | Trait + types |
| Index loops | Non-idiomatic | Use iterators |

## Top Beginner Mistakes

| Rank | Mistake | Fix |
|------|---------|-----|
| 1 | Clone to escape borrow checker | Use references |
| 2 | Unwrap in production | Propagate with `?` |
| 3 | String for everything | Use `&str` where possible |
| 4 | Index loops | Use iterators |
| 5 | Fighting lifetimes | Restructure to own data |

## Deprecated Patterns

| Deprecated | Use Instead |
|------------|-------------|
| Index-based loops | `.iter()`, `.enumerate()` |
| `collect::<Vec<_>>()` then iterate | Chain iterators |
| Manual unsafe cell | `Cell`, `RefCell` |
| `mem::transmute` for casts | `as` or `TryFrom` |
| Custom linked list | `Vec`, `VecDeque` |
| `lazy_static!` | `std::sync::OnceLock` |
| `once_cell::Lazy` | `std::sync::LazyLock` |

## Review Checklist

- No `.clone()` without justification
- No `.unwrap()` in library code
- No `pub` fields with invariants
- No index loops when iterator works
- No `String` where `&str` suffices
- No ignored `#[must_use]` warnings
- No `unsafe` without `// SAFETY:` comment
- No functions exceeding ~50 lines
