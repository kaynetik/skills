# Mental Models

## Core Question

**What is the right way to think about this Rust concept?**

## Key Mental Models

| Concept | Model | Analogy |
|---------|-------|---------|
| Ownership | Unique key | Only one person has the house key |
| Move | Key handover | Giving away your key |
| `&T` | Lending for reading | Lending a book (many readers) |
| `&mut T` | Exclusive editing | Only you can edit the document |
| Lifetime `'a` | Valid scope | "Ticket valid until..." |
| `Box<T>` | Heap pointer | Remote control to TV |
| `Rc<T>` | Shared ownership | Multiple remotes, last one turns off |
| `Arc<T>` | Thread-safe Rc | Remotes usable from any room |

## Coming From Other Languages

| From | Key Shift |
|------|-----------|
| Java/C# | Values are owned, not GC-managed references |
| C/C++ | Compiler enforces safety rules you'd check manually |
| Python/Go | No GC -- deterministic destruction |
| Functional | Mutability is safe through ownership |
| JavaScript | No null -- use Option instead |

## Common Misconceptions

| Error | Wrong Model | Correct Model |
|-------|-------------|---------------|
| E0382 | "GC will clean it up" | Ownership is a unique key transfer |
| E0502 | "Multiple writers are fine" | Only one writer at a time |
| E0499 | "Aliased mutation is OK" | Exclusive access for mutation |
| E0106 | "Lifetimes don't matter" | References have a validity scope |
| E0507 | "References own data" | References are borrows, not owners |

## Ownership Visualization

```
Stack                          Heap
+----------------+            +----------------+
| main()         |            |                |
|   s1 ---------------------->| "hello"        |
|                |            |                |
| fn takes(s) {  |            |                |
|   s2 (moved) -------------->| "hello"        |
| }              |            | (s1 invalid)   |
+----------------+            +----------------+
```

## Deprecated Thinking

| Deprecated | Better |
|------------|--------|
| "Rust is like C++" | Different ownership model entirely |
| "Lifetimes are garbage collection" | Compile-time validity scope |
| "Clone solves everything" | Restructure ownership |
| "Fight the borrow checker" | Work with the compiler |
| "`unsafe` to avoid rules" | Understand safe patterns first |

## Learning Path

| Stage | Focus |
|-------|-------|
| Beginner | Ownership, borrowing, basic types |
| Intermediate | Smart pointers, error handling, traits |
| Advanced | Concurrency, async, unsafe |
| Expert | Domain modeling, performance, type-driven design |
