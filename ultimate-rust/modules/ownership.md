# Ownership and Lifetimes

## Core Question

**Who should own this data, and for how long?**

Before fixing ownership errors, understand the data's role:
- Is it shared or exclusive?
- Is it short-lived or long-lived?
- Is it transformed or read?

## Error to Design Question

| Error | Don't Say | Ask Instead |
|-------|-----------|-------------|
| E0382 | "Clone it" | Who should own this data? |
| E0597 | "Extend lifetime" | Is the scope boundary correct? |
| E0506 | "End borrow first" | Should mutation happen elsewhere? |
| E0507 | "Clone before move" | Why are we moving from a reference? |
| E0515 | "Return owned" | Should caller own the data? |
| E0716 | "Bind to variable" | Why is this temporary? |
| E0106 | "Add 'a" | What is the actual lifetime relationship? |

## Decision Guide

| Pattern | Cost | Use When |
|---------|------|----------|
| Move | Zero | Caller doesn't need data after |
| `&T` | Zero | Read-only access |
| `&mut T` | Zero | Exclusive modification |
| `clone()` | Alloc + copy | Actually need an independent copy |
| `Rc<T>` | Ref count | Single-thread shared ownership |
| `Arc<T>` | Atomic ref count | Multi-thread shared ownership |
| `Cow<T>` | Alloc if mutated | Might modify borrowed data |

## Error Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| E0382 | Value moved | Reference, clone, or redesign ownership |
| E0597 | Reference outlives owner | Extend owner scope or restructure |
| E0506 | Assign while borrowed | End borrow before mutation |
| E0507 | Move out of borrowed | Clone or use reference |
| E0515 | Return local reference | Return owned value |
| E0716 | Temporary dropped | Bind to variable |
| E0106 | Missing lifetime | Add lifetime annotation |

## Design Escalation

If the same ownership error recurs after two fix attempts, the problem is structural. Ask:

1. **What is this data's domain role?**
   - Entity (unique identity) -- must be owned
   - Value Object (interchangeable) -- clone/copy is fine
   - Temporary (computation result) -- restructure scope

2. **Is the ownership design intentional or accidental?**
   - Intentional -- work within constraints
   - Accidental -- read `modules/domain.md` and reconsider data flow
