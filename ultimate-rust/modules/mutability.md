# Mutability

## Core Question

**Why does this data need to change, and who can change it?**

Before adding interior mutability:
- Is mutation essential or accidental complexity?
- Who should control mutation?
- What is the thread context?

## Borrow Rules

At any time, you can have EITHER:
- Multiple `&T` (immutable borrows)
- OR one `&mut T` (mutable borrow)

Never both simultaneously.

## Error to Design Question

| Error | Don't Say | Ask Instead |
|-------|-----------|-------------|
| E0596 | "Add mut" | Should this really be mutable? |
| E0499 | "Split borrows" | Is the data structure right? |
| E0502 | "Separate scopes" | Why do we need both borrows? |
| RefCell panic | "Use try_borrow" | Is runtime checking appropriate here? |

## Interior Mutability Decision

| Scenario | Choose |
|----------|--------|
| T: Copy, single-thread | `Cell<T>` |
| T: !Copy, single-thread | `RefCell<T>` |
| T: Copy, multi-thread | `AtomicXxx` |
| T: !Copy, multi-thread, read-heavy | `RwLock<T>` |
| T: !Copy, multi-thread, write-heavy | `Mutex<T>` |
| Simple flags/counters | `AtomicBool`, `AtomicUsize` |

## Quick Reference

| Pattern | Thread-Safe | Runtime Cost | Use When |
|---------|-------------|--------------|----------|
| `&mut T` | N/A | Zero | Exclusive mutable access |
| `Cell<T>` | No | Zero | Copy types, no refs needed |
| `RefCell<T>` | No | Runtime check | Non-Copy, runtime borrow |
| `Mutex<T>` | Yes | Lock contention | Thread-safe mutation |
| `RwLock<T>` | Yes | Lock contention | Many readers, few writers |
| `Atomic*` | Yes | Minimal | Simple types (bool, usize) |

## Error Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| E0596 | Borrowing immutable as mutable | Add `mut` or redesign |
| E0499 | Multiple mutable borrows | Restructure code flow |
| E0502 | &mut while & exists | Separate borrow scopes |
