# Type-Driven Design

## Core Question

**How can the type system prevent invalid states?**

Before reaching for runtime checks:
- Can the compiler catch this error?
- Can invalid states be made unrepresentable?
- Can the type encode the invariant?

## Pattern Catalog

| Pattern | Purpose | Example |
|---------|---------|---------|
| Newtype | Type safety for primitives | `struct UserId(u64);` |
| Type State | Compile-time state machine | `Connection<Connected>` |
| PhantomData | Variance/lifetime markers | `PhantomData<&'a T>` |
| Marker Trait | Capability flags | `trait Validated {}` |
| Builder | Gradual construction | `Builder::new().name("x").build()` |
| Sealed Trait | Prevent external impl | `mod private { pub trait Sealed {} }` |

## Newtype

```rust
struct Email(String);

impl Email {
    pub fn new(s: &str) -> Result<Self, ValidationError> {
        validate_email(s)?;
        Ok(Self(s.to_string()))
    }
}
```

Validate once at construction, trust the type everywhere after.

## Type State

```rust
struct Connection<State>(TcpStream, PhantomData<State>);

struct Disconnected;
struct Connected;
struct Authenticated;

impl Connection<Disconnected> {
    fn connect(self) -> Connection<Connected> { /* ... */ }
}

impl Connection<Connected> {
    fn authenticate(self) -> Connection<Authenticated> { /* ... */ }
}
```

Invalid transitions are compile errors.

## Decision Guide

| Need | Pattern |
|------|---------|
| Type safety for primitives | Newtype |
| Compile-time state validation | Type State |
| Lifetime/variance markers | PhantomData |
| Capability flags | Marker Trait |
| Gradual construction | Builder |
| Closed set of implementors | Sealed Trait |
