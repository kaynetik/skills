# Concurrency

## Core Question

**Is this CPU-bound or I/O-bound, and what is the sharing model?**

Before choosing concurrency primitives:
- What is the workload type?
- What data needs to be shared?
- What are the thread safety requirements?

## Decision Flowchart

```
What type of work?
  CPU-bound -- std::thread or rayon
  I/O-bound -- async/await (tokio)
  Mixed -- hybrid (spawn_blocking)

Need to share data?
  No -- message passing (channels)
  Immutable -- Arc<T>
  Mutable --
    Read-heavy -- Arc<RwLock<T>>
    Write-heavy -- Arc<Mutex<T>>
    Simple counter -- AtomicUsize

Async context?
  Type is Send -- tokio::spawn
  Type is !Send -- spawn_local
  Blocking code -- spawn_blocking
```

## Send/Sync

| Marker | Meaning | Example |
|--------|---------|---------|
| `Send` | Can transfer ownership between threads | Most types |
| `Sync` | Can share references between threads | `Arc<T>` |
| `!Send` | Must stay on one thread | `Rc<T>` |
| `!Sync` | No shared refs across threads | `RefCell<T>` |

## Quick Reference

| Pattern | Thread-Safe | Blocking | Use When |
|---------|-------------|----------|----------|
| `std::thread` | Yes | Yes | CPU-bound parallelism |
| `async/await` | Yes | No | I/O-bound concurrency |
| `Mutex<T>` | Yes | Yes | Shared mutable state |
| `RwLock<T>` | Yes | Yes | Read-heavy shared state |
| `mpsc::channel` | Yes | Optional | Message passing |
| `Arc<Mutex<T>>` | Yes | Yes | Shared mutable across threads |

## Error to Design Question

| Error | Don't Say | Ask Instead |
|-------|-----------|-------------|
| E0277 Send | "Add Send bound" | Should this type cross threads? |
| E0277 Sync | "Wrap in Mutex" | Is shared access really needed? |
| Future not Send | "Use spawn_local" | Is async the right choice? |
| Deadlock | "Reorder locks" | Is the locking design correct? |

## Async Pitfalls

**MutexGuard across await:**

```rust
// Wrong: guard held across await
let guard = mutex.lock().await;
do_async().await;  // guard still held

// Right: scope the lock
{
    let guard = mutex.lock().await;
    // use guard
}  // guard dropped
do_async().await;
```

**Non-Send types in async:** Rc is !Send. Either use Arc, spawn_local, or drop the Rc before `.await`.

## Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| E0277 `Send` not satisfied | Non-Send in async | Use Arc or spawn_local |
| E0277 `Sync` not satisfied | Non-Sync shared | Wrap with Mutex |
| Deadlock | Lock ordering | Consistent lock order |
| `future is not Send` | Non-Send across await | Drop before await |
| `MutexGuard` across await | Guard held during suspend | Scope guard properly |
