# Zero-Cost Abstraction

## Core Question

**Do we need compile-time or runtime polymorphism?**

Before choosing between generics and trait objects:
- Is the type known at compile time?
- Is a heterogeneous collection needed?
- What is the performance priority?

## Error to Design Question

| Error | Don't Say | Ask Instead |
|-------|-----------|-------------|
| E0277 | "Add trait bound" | Is this abstraction at the right level? |
| E0308 | "Fix the type" | Should types be unified or distinct? |
| E0599 | "Import the trait" | Is the trait the right abstraction? |
| E0038 | "Make object-safe" | Do we actually need dynamic dispatch? |

## Decision Guide

| Scenario | Choose | Why |
|----------|--------|-----|
| Performance critical | Generics | Zero runtime cost |
| Heterogeneous collection | `dyn Trait` | Different types at runtime |
| Plugin architecture | `dyn Trait` | Unknown types at compile |
| Reduce compile time | `dyn Trait` | Less monomorphization |
| Small, known type set | `enum` | No indirection |

## Dispatch Comparison

| Pattern | Dispatch | Code Size | Runtime Cost |
|---------|----------|-----------|--------------|
| `fn foo<T: Trait>()` | Static | Larger (monomorphization) | Zero |
| `fn foo(x: &dyn Trait)` | Dynamic | Minimal | vtable lookup |
| `impl Trait` return | Static | Larger | Zero |
| `Box<dyn Trait>` | Dynamic | Minimal | Allocation + vtable |

## Syntax

```rust
// Static dispatch
fn process(x: impl Display) { }
fn process<T: Display>(x: T) { }
fn get() -> impl Display { }

// Dynamic dispatch
fn process(x: &dyn Display) { }
fn process(x: Box<dyn Display>) { }
```

## Object Safety

A trait is object-safe if it:
- Has no `Self: Sized` bound
- Does not return `Self`
- Has no generic methods
- Uses `where Self: Sized` for non-object-safe methods

## Error Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| E0277 | Type doesn't impl trait | Add impl or change bound |
| E0308 | Type mismatch | Check generic params |
| E0599 | No method found | Import trait with `use` |
| E0038 | Trait not object-safe | Use generics or redesign |
