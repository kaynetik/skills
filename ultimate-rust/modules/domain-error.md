# Domain Error Strategy

## Core Question

**Who needs to handle this error, and how should they recover?**

Before designing error types:
- Is this user-facing or internal?
- Is recovery possible?
- What context is needed for debugging?

## Error Categorization

| Type | Audience | Recovery | Example |
|------|----------|----------|---------|
| User-facing | End users | Guide action | `InvalidEmail`, `NotFound` |
| Internal | Developers | Debug info | `DatabaseError`, `ParseError` |
| System | Ops/SRE | Monitor/alert | `ConnectionTimeout`, `RateLimited` |
| Transient | Automation | Retry | `NetworkError`, `ServiceUnavailable` |
| Permanent | Human | Investigate | `ConfigInvalid`, `DataCorrupted` |

## Recovery Patterns

| Pattern | When | Implementation |
|---------|------|----------------|
| Retry | Transient failures | Exponential backoff |
| Fallback | Degraded mode | Cached/default value |
| Circuit Breaker | Cascading failures | failsafe-rs |
| Timeout | Slow operations | `tokio::time::timeout` |
| Bulkhead | Isolation | Separate thread pools |

## Example Hierarchy

```rust
#[derive(thiserror::Error, Debug)]
pub enum AppError {
    #[error("Invalid input: {0}")]
    Validation(String),

    #[error("Service temporarily unavailable")]
    ServiceUnavailable(#[source] reqwest::Error),

    #[error("Internal error")]
    Internal(#[source] anyhow::Error),
}

impl AppError {
    pub fn is_retryable(&self) -> bool {
        matches!(self, Self::ServiceUnavailable(_))
    }
}
```

## Common Mistakes

| Mistake | Why Wrong | Better |
|---------|-----------|--------|
| Same error type for all failures | No actionability | Categorize by audience |
| Retry everything | Wasted resources | Only transient errors |
| Infinite retry | Self-inflicted DoS | Max attempts + backoff |
| Expose internal errors to users | Security risk | User-friendly messages |
| No context | Hard to debug | `.context()` on propagation |
