# Unsafe Rust

## When Unsafe is Valid

| Use Case | Example |
|----------|---------|
| FFI | Calling C functions |
| Low-level abstractions | Implementing `Vec`, `Arc` |
| Measured performance bottleneck | Safe alternative proven too slow |

**Not valid:** Escaping the borrow checker without understanding why.

## Required Documentation

Every unsafe block requires a SAFETY comment:

```rust
// SAFETY: pointer is valid, aligned, and initialized; no aliasing violations
unsafe { *ptr }

/// # Safety
/// Caller must ensure `ptr` is valid and properly aligned.
pub unsafe fn dangerous(ptr: *const u8) { /* ... */ }
```

## Operation Safety Requirements

| Operation | Requirements |
|-----------|-------------|
| `*ptr` deref | Valid, aligned, initialized |
| `&*ptr` | Above + no aliasing violations |
| `transmute` | Same size, valid bit pattern for target |
| `extern "C"` | Correct signature and ABI |
| `static mut` | Synchronization guaranteed |
| `impl Send/Sync` | Type is actually thread-safe |

## Common Errors

| Error | Fix |
|-------|-----|
| Null pointer deref | Check for null before deref |
| Use after free | Ensure lifetime validity |
| Data race | Add proper synchronization |
| Alignment violation | Use `#[repr(C)]`, check alignment |
| Invalid bit pattern | Use `MaybeUninit` |
| Missing SAFETY comment | Add `// SAFETY:` explaining invariants |

## Deprecated Patterns

| Deprecated | Use Instead |
|------------|-------------|
| `mem::uninitialized()` | `MaybeUninit<T>` |
| `mem::zeroed()` for refs | `MaybeUninit<T>` |
| Raw pointer arithmetic | `NonNull<T>`, `ptr::add` |
| `CString::new().unwrap().as_ptr()` | Store `CString` in a binding first |
| `static mut` | `AtomicT` or `Mutex` |
| Manual extern declarations | `bindgen` |

## FFI Crates

| Direction | Crate |
|-----------|-------|
| C to Rust | bindgen |
| Rust to C | cbindgen |
| Python | PyO3 |
| Node.js | napi-rs |
