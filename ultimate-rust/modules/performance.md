# Performance Optimization

## Core Question

**What is the bottleneck, and is optimization worth it?**

Before optimizing:
- Have you measured? (Do not guess)
- What is the acceptable performance target?
- Will optimization add meaningful complexity?

## Priority Order

```
1. Algorithm choice       (10x - 1000x)
2. Data structure          (2x - 10x)
3. Allocation reduction    (2x - 5x)
4. Cache optimization      (1.5x - 3x)
5. SIMD / Parallelism      (2x - 8x)
```

## Tools

| Tool | Purpose |
|------|---------|
| `cargo bench` | Micro-benchmarks |
| `criterion` | Statistical benchmarks |
| `perf` / `flamegraph` | CPU profiling |
| `heaptrack` | Allocation tracking |
| `valgrind` / `cachegrind` | Cache analysis |

## Common Techniques

| Technique | When | How |
|-----------|------|-----|
| Pre-allocation | Known size | `Vec::with_capacity(n)` |
| Avoid cloning | Hot paths | Use references or `Cow<T>` |
| Batch operations | Many small ops | Collect then process |
| SmallVec | Usually small | `smallvec::SmallVec<[T; N]>` |
| Inline buffers | Fixed-size data | Arrays over Vec |

## Common Mistakes

| Mistake | Why Wrong | Better |
|---------|-----------|--------|
| Optimize without profiling | Wrong target | Profile first |
| Benchmark in debug mode | Meaningless results | Always `--release` |
| Use LinkedList | Cache unfriendly | `Vec` or `VecDeque` |
| String concat in loop | O(n^2) | `String::with_capacity` or `format!` |
| Clone to avoid lifetimes | Hidden allocation cost | Proper ownership design |
| HashMap for small sets | Overhead | Vec with linear search (<50 items) |
