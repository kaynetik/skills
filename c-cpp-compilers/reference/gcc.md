# GCC Reference

Detailed GCC flags, diagnostics, and workflows beyond the main SKILL.md.

## Flag cheatsheet

### Optimization

| Flag | Effect |
|------|--------|
| `-O0` | No optimization (fast compile, full debug fidelity) |
| `-Og` | Optimization that preserves debuggability |
| `-O1` | Basic optimizations, reasonable compile time |
| `-O2` | Standard release optimization |
| `-O3` | Aggressive: loop unrolling, vectorization, wider inlining |
| `-Os` | Optimize for size (subset of `-O2` minus size-increasing transforms) |
| `-Ofast` | `-O3` + `-ffast-math` (breaks IEEE 754; opt-in only) |
| `-march=native` | Target the build machine's ISA (not portable) |
| `-mtune=generic` | Schedule for broad hardware (default) |
| `-flto=auto` | Link-time optimization with automatic parallelism |
| `-fprofile-generate` / `-fprofile-use` | PGO instrumentation and use passes |

### Warnings

| Flag | Effect |
|------|--------|
| `-Wall` | Common warnings (unused vars, implicit conversions, etc.) |
| `-Wextra` | Additional warnings beyond `-Wall` |
| `-Wpedantic` | Strict ISO compliance warnings |
| `-Werror` | Treat all warnings as errors |
| `-Wconversion` | Implicit conversion warnings (noisy but catches real bugs) |
| `-Wshadow` | Variable shadowing |
| `-Wformat=2` | Format string checking (extends `-Wformat`) |
| `-Wdouble-promotion` | `float` implicitly promoted to `double` |
| `-Wnull-dereference` | Warn on null pointer dereference paths (requires `-O1+`) |
| `-Wstrict-aliasing=2` | Type-punning through pointer casts |
| `-Wcast-align` | Cast increases alignment requirement |
| `-Wwrite-strings` | Warn on `const char*` assigned to `char*` |
| `-w` | Suppress all warnings (avoid except for third-party code) |

### Debug

| Flag | Effect |
|------|--------|
| `-g` | DWARF debug info (level 2) |
| `-g3` | Debug info including macro definitions |
| `-ggdb` | DWARF extensions tuned for GDB |
| `-gsplit-dwarf` | Split `.dwo` files for faster linking |

### Hardening (production)

| Flag | Effect |
|------|--------|
| `-fstack-protector-strong` | Stack canaries for functions with local arrays or address-taken locals |
| `-D_FORTIFY_SOURCE=2` | Runtime buffer overflow checks (requires `-O1+`) |
| `-D_FORTIFY_SOURCE=3` | GCC 12+ extended fortification |
| `-fPIE -pie` | Position-independent executable (ASLR) |
| `-Wl,-z,relro,-z,now` | Full RELRO (resolve all symbols at load time) |
| `-fcf-protection` | Control-flow integrity (x86, GCC 8+) |

## GCC-specific PGO workflow

```bash
# Step 1: instrument (generates .gcda files on run)
gcc -O2 -fprofile-generate -o prog_inst main.c

# Step 2: exercise with representative workload
./prog_inst < workload.input

# Step 3: build with profile
gcc -O2 -fprofile-use -fprofile-correction -o prog main.c
```

`-fprofile-correction` handles inconsistencies from multi-threaded profiling runs.

AutoFDO alternative: collect with `perf record -b`, convert with `create_gcov`, use with `-fprofile-use=profile.afdo`.

## GCC-specific LTO

```bash
gcc -O2 -flto=auto -c foo.c bar.c
gcc -O2 -flto=auto foo.o bar.o -o prog
```

For static libraries with LTO objects, use `gcc-ar` and `gcc-ranlib` instead of `ar`/`ranlib`.

Parallel LTO: `-flto=N` (explicit job count) or `-flto=auto` (jobserver).

## Diagnostic one-liners

```bash
# Show all flags enabled at a given optimization level
gcc -Q --help=optimizers -O2 | grep enabled

# Dump all predefined macros
gcc -dM -E - < /dev/null

# Preprocess with macro expansion trace
gcc -E -dD src.c -o src.i

# Assembly output (Intel syntax)
gcc -S -masm=intel -O2 foo.c -o foo.s

# Show include search path
gcc -v -E - < /dev/null 2>&1 | grep -A20 '#include <...>'

# Check if a flag is supported
gcc -Q --help=target | grep march

# Show ABI info
gcc -dumpmachine
```

## Common error patterns

| Error | Cause | Fix |
|-------|-------|-----|
| `undefined reference to 'foo'` | Missing `-lfoo` or wrong link order | Put libraries after objects |
| `multiple definition of 'x'` | Variable defined in header | `extern` in header; define in one TU |
| `implicit declaration of function 'f'` | Missing include or wrong C standard | Add `#include`; check `-std=` |
| `incompatible pointer types` | Mismatched pointer type or missing prototype | Fix type; add prototype |
| `relocation truncated to fit` | 32-bit relocation overflow in large binary | `-mcmodel=medium` or `-mcmodel=large` |
| `undefined reference to '__stack_chk_fail'` | `-fstack-protector` without `libssp` | Link with `-lssp` or remove the flag |
| ABI mismatch with C++ | Different `-std=` across TUs | Unify standard in build system |

## GCC version feature matrix (2026)

| Feature | Min GCC |
|---------|---------|
| C++20 (coroutines, concepts, ranges) | 10 (partial), 12+ (usable) |
| C++23 (`std::expected`, `std::print`, deducing this) | 14+ |
| C23 (`typeof`, `nullptr`, `bool`/`true`/`false` as keywords) | 13+ (partial), 15+ |
| `-fanalyzer` (built-in static analyzer) | 10+ |
| `-D_FORTIFY_SOURCE=3` | 12+ |
| C++20 modules (`-fmodules-ts`) | 11+ (experimental), 14+ (improved) |
| `-flto=auto` | 10+ |
