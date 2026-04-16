# Domain Modeling

## Core Question

**What is this concept's role in the domain?**

Before modeling in code:
- Is it an Entity (identity matters) or Value Object (interchangeable)?
- What invariants must be maintained?
- Where are the aggregate boundaries?

## Domain Concept to Rust Pattern

| Domain Concept | Rust Pattern | Ownership Implication |
|----------------|--------------|----------------------|
| Entity | struct + Id field | Owned, unique identity |
| Value Object | struct + Clone/Copy | Shareable, immutable |
| Aggregate Root | struct owns children | Clear ownership tree |
| Repository | trait | Abstracts persistence |
| Domain Event | enum | Captures state changes |
| Service | impl block / free fn | Stateless operations |

## Pattern Templates

### Value Object

```rust
struct Email(String);

impl Email {
    pub fn new(s: &str) -> Result<Self, ValidationError> {
        validate_email(s)?;
        Ok(Self(s.to_string()))
    }
}
```

### Entity

```rust
struct UserId(Uuid);

struct User {
    id: UserId,
    email: Email,
}

impl PartialEq for User {
    fn eq(&self, other: &Self) -> bool {
        self.id == other.id  // Identity equality
    }
}
```

### Aggregate

```rust
mod order {
    pub struct Order {
        id: OrderId,
        items: Vec<OrderItem>,  // Owned children
    }

    impl Order {
        pub fn add_item(&mut self, item: OrderItem) {
            // Enforce aggregate invariants here
        }
    }
}
```

## Design Questions

| Question | Answer Determines |
|----------|-------------------|
| What makes two instances "the same"? | Entity vs Value Object |
| What must be consistent together? | Aggregate boundary |
| What business rules apply? | Validation in constructor |
| Who can modify this? | Visibility + mut access |
