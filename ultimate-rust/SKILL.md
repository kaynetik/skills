---
name: ultimate-rust
description: "Comprehensive Rust language skill covering ownership, borrowing, lifetimes, smart pointers, mutability, generics, traits, type-driven design, error handling, concurrency, async, domain modeling, performance, ecosystem integration, resource lifecycle, domain errors, unsafe code, and coding guidelines. Routes queries through a layered meta-cognition framework. Use for all Rust questions including compile errors (E0382, E0597, E0277, E0308, E0499, E0502, E0596, E0038, E0433), design decisions, code review, anti-patterns, and best practices. Triggers on: Rust, cargo, rustc, Cargo.toml, .rs files, crate, borrow checker, lifetime, trait bound, async, tokio, Send, Sync."
globs: ["**/Cargo.toml", "**/*.rs"]
---

# Rust -- Hub

## Meta-Cognition Framework

Before answering, identify the cognitive layer:

```
Layer 3: Domain Constraints (WHY)
  Business rules, regulatory requirements
  "Why is it designed this way?"

Layer 2: Design Choices (WHAT)
  Architecture patterns, DDD, error strategy
  "What pattern should I use?"

Layer 1: Language Mechanics (HOW)
  Ownership, borrowing, lifetimes, traits
  "How do I implement this in Rust?"
```

| User Signal | Entry Layer | Direction |
|-------------|-------------|-----------|
| E0xxx error code | L1 | Trace UP |
| Compile error | L1 | Trace UP |
| "How to design..." | L2 | Check L3, then DOWN |
| "Building [domain] app" | L3 | Trace DOWN |
| "Best practice..." | L2 | Both directions |
| Performance issue | L1 then L2 | UP then DOWN |

## Routing

Match the query to the right module, then **Read** it. For cross-cutting queries, read multiple modules.

### Error Code Routing

| Error | Module | Cause |
|-------|--------|-------|
| E0382 | `modules/ownership.md` | Use of moved value |
| E0597 | `modules/ownership.md` | Lifetime too short |
| E0506 | `modules/ownership.md` | Cannot assign to borrowed |
| E0507 | `modules/ownership.md` | Cannot move out of borrowed |
| E0515 | `modules/ownership.md` | Return local reference |
| E0716 | `modules/ownership.md` | Temporary value dropped |
| E0106 | `modules/ownership.md` | Missing lifetime specifier |
| E0596 | `modules/mutability.md` | Cannot borrow as mutable |
| E0499 | `modules/mutability.md` | Multiple mutable borrows |
| E0502 | `modules/mutability.md` | Borrow conflict |
| E0277 | `modules/zero-cost.md` or `modules/concurrency.md` | Trait bound not satisfied |
| E0308 | `modules/zero-cost.md` | Type mismatch |
| E0599 | `modules/zero-cost.md` | No method found |
| E0038 | `modules/zero-cost.md` | Trait not object-safe |
| E0433 | `modules/ecosystem.md` | Cannot find crate/module |

### Keyword Routing

| Keywords | Module |
|----------|--------|
| move, borrow, lifetime, 'a, 'static, clone, Copy | `modules/ownership.md` |
| Box, Rc, Arc, Weak, RefCell, Cell, smart pointer | `modules/resource.md` |
| mut, &mut, interior mutability | `modules/mutability.md` |
| generic, trait, impl, dyn, where, monomorphization, dispatch | `modules/zero-cost.md` |
| type state, PhantomData, newtype, marker trait, builder, sealed | `modules/type-driven.md` |
| Result, Option, Error, ?, unwrap, expect, panic, anyhow, thiserror | `modules/error-handling.md` |
| Send, Sync, thread, async, await, Future, tokio, channel, Mutex | `modules/concurrency.md` |
| domain model, DDD, entity, value object, aggregate, repository | `modules/domain.md` |
| performance, benchmark, profiling, flamegraph, criterion, allocation | `modules/performance.md` |
| crate, cargo, dependency, feature flag, workspace, FFI, interop | `modules/ecosystem.md` |
| RAII, Drop, resource lifecycle, pool, OnceLock, LazyLock, guard | `modules/lifecycle.md` |
| domain error, retry, fallback, circuit breaker, recovery, resilience | `modules/domain-error.md` |
| mental model, how to think, analogy, coming from Java/Python/C++ | `modules/mental-model.md` |
| anti-pattern, code smell, pitfall, common mistake, idiomatic | `modules/anti-patterns.md` |
| unsafe, raw pointer, FFI, extern, transmute, *mut, *const, UB | `modules/unsafe.md` |
| naming, formatting, clippy, rustfmt, lint, code style, comment | `modules/coding-guidelines.md` |

### Keyword Conflicts

| Keyword | Resolution |
|---------|------------|
| `unsafe` | `modules/unsafe.md` (not ecosystem) |
| `error` | `modules/error-handling.md` for general; `modules/domain-error.md` for recovery strategy |
| `RAII` | `modules/lifecycle.md` for design; `modules/ownership.md` for implementation |
| `crate` | `modules/ecosystem.md` for integration; delegate to `rust-learner` for version lookup |
| `tokio` | `modules/concurrency.md` for concepts; delegate to docs-researcher for API specifics |

## Negotiation Protocol

For comparative queries ("X vs Y", "best practice for..."), cross-domain questions, or ambiguous scope -- read `patterns/negotiation.md` and follow the structured analysis format.

## Default Project Settings

When creating new Rust projects or Cargo.toml files:

```toml
[package]
edition = "2024"
rust-version = "1.85"

[lints.rust]
unsafe_code = "warn"

[lints.clippy]
all = "warn"
pedantic = "warn"
```

## Domain Dual-Loading

When domain keywords appear alongside an error or design question, read both the relevant L1/L2 module and the domain skill:

| Domain Keywords | L1/L2 Module | Domain Skill |
|-----------------|--------------|--------------|
| Web API, HTTP, axum, handler | `modules/concurrency.md` | domain-web (external) |
| trading, payment, fintech | `modules/ownership.md` | domain-fintech (external) |
| CLI, terminal, clap | `modules/concurrency.md` | domain-cli (external) |
| embedded, no_std, MCU | `modules/resource.md` | domain-embedded (external) |
| kubernetes, grpc, microservice | `modules/concurrency.md` | domain-cloud-native (external) |

## Priority Order

1. Identify cognitive layer (L1/L2/L3)
2. Read the entry module
3. If domain context present, load domain skill
4. Answer with reasoning chain from layer analysis
