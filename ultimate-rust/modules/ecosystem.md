# Ecosystem Integration

## Core Question

**What is the right crate for this job, and how should it integrate?**

Before adding dependencies:
- Is there a standard solution?
- What is the maintenance status?
- What is the API stability?

## Common Crate Choices

| Need | Crate | Notes |
|------|-------|-------|
| Serialization | serde, serde_json | Derive-based |
| Async runtime | tokio | De facto standard |
| HTTP client | reqwest | Built on tokio |
| HTTP server | axum | Tower-based, modern |
| Database | sqlx | Compile-time checked SQL |
| CLI parsing | clap | Derive-based |
| Error (library) | thiserror | Typed errors |
| Error (application) | anyhow | Ergonomic propagation |
| Logging | tracing | Structured, async-aware |

## Language Interop

| Integration | Crate/Tool | Use Case |
|-------------|------------|----------|
| C/C++ to Rust | `bindgen` | Auto-generate bindings |
| Rust to C | `cbindgen` | Export C headers |
| Python | `pyo3` | Python extensions |
| Node.js | `napi-rs` | Node addons |
| WebAssembly | `wasm-bindgen` | Browser/WASI |

## Cargo Features

| Concept | Purpose |
|---------|---------|
| `[features]` | Optional functionality |
| `default = [...]` | Features enabled by default |
| `feature = "serde"` | Conditional dependencies |
| `[workspace]` | Multi-crate projects |

## Crate Selection Criteria

| Criterion | Good Sign | Warning Sign |
|-----------|-----------|--------------|
| Maintenance | Recent commits | Years inactive |
| Community | Active issues/PRs | No response |
| Documentation | Examples, API docs | Minimal docs |
| Stability | Semantic versioning | Frequent breaking |
| Dependencies | Minimal, well-known | Heavy, obscure |

## Error Quick Reference

| Error | Cause | Fix |
|-------|-------|-----|
| E0433 | Can't find crate | Add to Cargo.toml |
| E0603 | Private item | Check crate docs for public API |
| Feature not enabled | Optional feature | Enable in `features` |
| Version conflict | Incompatible deps | `cargo update` or pin version |
