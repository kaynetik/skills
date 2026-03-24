# Clang / LLVM Reference

Detailed Clang-specific flags, diagnostics, and tooling beyond the main SKILL.md.

## Clang vs GCC flag differences

| Feature | GCC | Clang |
|---------|-----|-------|
| Aggressive size opt | `-Os` | `-Oz` (more aggressive than `-Os`) |
| PGO instrument | `-fprofile-generate` | `-fprofile-instr-generate` |
| PGO use | `-fprofile-use` | `-fprofile-instr-use=file.profdata` |
| LTO (fast) | `-flto=auto` | `-flto=thin` (preferred for large projects) |
| Static analyzer | `-fanalyzer` | `clang --analyze` or `clang-tidy` |
| All warnings | (no equivalent) | `-Weverything` (audit only, too noisy for prod) |
| Attribute check | N/A | `__has_attribute(foo)` |
| Template error tree | N/A | `-fdiagnostics-show-template-tree` |

## Diagnostic flags

```bash
# Range highlighting + fix-it hints
clang -Wall -Wextra --show-fixits src.c

# Limit error count
clang -ferror-limit=5 src.c

# Verbose template errors (C++)
clang -fno-elide-type -fdiagnostics-show-template-tree src.cpp

# Show category for each diagnostic
clang -fdiagnostics-show-category=name src.c
```

## Optimization remarks

See what Clang optimized or declined to optimize:

```bash
# Inlining decisions
clang -O2 -Rpass=inline src.c

# Missed vectorization
clang -O2 -Rpass-missed=loop-vectorize src.c

# Analysis of why a loop was not vectorized
clang -O2 -Rpass-analysis=loop-vectorize src.c

# Save all remarks to YAML for tooling
clang -O2 -fsave-optimization-record src.c
```

Interpreting remarks:

- `remark: foo inlined into bar` -- inlining succeeded
- `remark: loop not vectorized: loop control flow is not understood` -- restructure the loop
- `remark: cannot prove it is safe to reorder` -- add `__restrict__` or `#pragma clang loop vectorize(assume_safety)`

## LTO with lld

```bash
# Full LTO
clang -O2 -flto -fuse-ld=lld src.c -o prog

# ThinLTO (5-10x faster link, comparable code quality)
clang -O2 -flto=thin -fuse-ld=lld src.c -o prog
```

ThinLTO is preferred for projects with >100 TUs. Full LTO may yield marginally better code at the cost of link time.

## PGO (LLVM instrumentation)

```bash
clang -O2 -fprofile-instr-generate prog.c -o prog_inst
./prog_inst < workload.input
llvm-profdata merge -output=prog.profdata default.profraw
clang -O2 -fprofile-instr-use=prog.profdata prog.c -o prog
```

AutoFDO alternative: collect with `perf record`, convert with `create_llvm_prof`, use with `-fprofile-sample-use=profile.afdo`.

## Static analysis

```bash
# Clang Static Analyzer (CSA) -- path-sensitive
clang --analyze -Xanalyzer -analyzer-output=text src.c

# clang-tidy -- linter + checker
clang-tidy src.c -- -std=c23 -Iinclude/

# Targeted check families
clang-tidy -checks='bugprone-*,clang-analyzer-*,performance-*' src.cpp
```

See [static-analysis.md](static-analysis.md) for `.clang-tidy` config and CI setup.

## macOS / Apple LLVM

- `clang` on macOS is Apple LLVM (may lag upstream Clang by a version or two)
- Default linker is `ld64`; `lld` requires Homebrew LLVM and `-fuse-ld=lld`
- Set deployment target: `-mmacosx-version-min=14.0`
- Sanitizers use `DYLD_INSERT_LIBRARIES`; do not strip the binary
- `xcrun clang` resolves to the Xcode toolchain

Check actual Clang version:

```bash
# Apple reports its own version scheme
clang --version
# For upstream-equivalent version
xcrun clang -dM -E - < /dev/null | grep __clang_major__
```

## Clang version feature matrix (2026)

| Feature | Min Clang |
|---------|-----------|
| C++20 (concepts, coroutines, ranges) | 12+ (partial), 16+ (complete) |
| C++23 (`std::expected`, deducing this, `std::print`) | 17+ (partial), 19+ |
| C23 (`typeof`, `nullptr`, `constexpr`, `bool` keyword) | 18+ |
| `-Oz` (aggressive size optimization) | 3.5+ |
| `-flto=thin` (ThinLTO) | 3.9+ |
| `-fsave-optimization-record` | 5+ |
| C++20 modules (`-fmodule-file=`) | 16+ (usable), 18+ (stable with CMake 3.28) |
| `-fdiagnostics-show-template-tree` | 3.0+ |
