# Resource Management

## Core Question

**What ownership pattern does this resource need?**

Before choosing a smart pointer:
- Is ownership single or shared?
- Is access single-threaded or multi-threaded?
- Are there potential cycles?

## Decision Flowchart

```
Need heap allocation?
  Yes -- Single owner?
    Yes -- Box<T>
    No -- Multi-thread?
      Yes -- Arc<T>
      No -- Rc<T>
  No -- Stack allocation (default)

Have reference cycles?
  Yes -- Use Weak for one direction
  No -- Regular Rc/Arc

Need interior mutability?
  Yes -- Thread-safe needed?
    Yes -- Mutex<T> or RwLock<T>
    No -- T: Copy? Cell<T> : RefCell<T>
  No -- Use &mut T
```

## Quick Reference

| Type | Ownership | Thread-Safe | Use When |
|------|-----------|-------------|----------|
| `Box<T>` | Single | Yes | Heap allocation, recursive types |
| `Rc<T>` | Shared | No | Single-thread shared ownership |
| `Arc<T>` | Shared | Yes | Multi-thread shared ownership |
| `Weak<T>` | Weak ref | Same as parent | Break reference cycles |
| `Cell<T>` | Single | No | Interior mutability (Copy types) |
| `RefCell<T>` | Single | No | Interior mutability (runtime check) |

## Common Errors

| Problem | Cause | Fix |
|---------|-------|-----|
| Rc cycle leak | Mutual strong refs | Use Weak for one direction |
| RefCell panic | Borrow conflict at runtime | Use try_borrow or restructure |
| Arc overhead | Atomic ops in hot path | Consider Rc if single-threaded |
| Box unnecessary | Data fits on stack | Remove Box |
