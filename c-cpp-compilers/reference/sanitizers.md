# Sanitizers Reference

Runtime bug detection for C/C++ using compiler-instrumented sanitizers.

## Decision tree

```
Bug class?
  Heap/stack/global OOB, use-after-free, double-free
    -> ASan (-fsanitize=address)
  Uninitialised reads
    -> MSan (-fsanitize=memory, Clang only, requires all-instrumented build)
  Undefined behaviour (signed overflow, null deref, bad shift, misaligned)
    -> UBSan (-fsanitize=undefined)
  Data races (multithreaded)
    -> TSan (-fsanitize=thread)
  Memory leaks
    -> LSan (via ASan with detect_leaks=1, or standalone)
  Multiple classes
    -> ASan + UBSan (common combo)

Incompatible pairs: ASan vs TSan, ASan vs MSan, TSan vs MSan.
```

## Build flags

```bash
# ASan + UBSan (recommended default for dev/CI)
gcc -fsanitize=address,undefined -fno-sanitize-recover=all \
    -fno-omit-frame-pointer -g -O1 -o prog main.c

# TSan (separate build, cannot combine with ASan)
clang -fsanitize=thread -g -O1 -o prog main.c

# MSan (Clang only; every linked object must be MSan-instrumented)
clang -fsanitize=memory -fsanitize-memory-track-origins=2 \
      -fno-omit-frame-pointer -g -O1 -o prog main.c
```

`-fno-omit-frame-pointer` gives accurate stack traces. `-O1` balances debuggability with sanitizer accuracy.

## Runtime options

### ASan

```bash
ASAN_OPTIONS=detect_leaks=1:abort_on_error=1:log_path=/tmp/asan.log ./prog
```

| Key | Effect |
|-----|--------|
| `detect_leaks=1` | Enable leak detection (default on Linux) |
| `abort_on_error=1` | Abort instead of `_exit()` (enables core dumps) |
| `log_path=path` | Write report to file |
| `symbolize=1` | Symbolize (needs `llvm-symbolizer` in `PATH`) |
| `fast_unwind_on_malloc=0` | More accurate stacks (slower) |
| `quarantine_size_mb=256` | Delay reuse of freed memory |

### UBSan

```bash
UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 ./prog
```

### TSan

```bash
TSAN_OPTIONS=suppressions=tsan.supp:halt_on_error=1 ./prog
```

## Interpreting ASan reports

```
==PID==ERROR: AddressSanitizer: heap-buffer-overflow on address 0x...
READ of size 4 at 0x... thread T0
    #0 0x... in foo /path/main.c:15
    #1 0x... in main /path/main.c:42

0x... is located 0 bytes after a 40-byte region
[0x..start, 0x..end) allocated at:
    #0 ... in malloc
    #1 ... in main /path/main.c:10
```

- Top frame in `READ/WRITE` is the access site
- `allocated at` shows where the buffer was created
- `0 bytes after 40-byte region` = classic off-by-one (accessed byte 40 of a 40-byte buffer)

## Interpreting UBSan reports

```
src/main.c:15:12: runtime error: signed integer overflow:
    2147483647 + 1 cannot be represented in type 'int'
```

Direct source location with exact expression.

## Interpreting TSan reports

```
WARNING: ThreadSanitizer: data race (pid=PID)
  Write of size 4 at 0x... by thread T2:
    #0 increment /path/counter.c:8
  Previous read of size 4 at 0x... by thread T1:
    #0 read_counter /path/counter.c:3
```

Two stacks: one for the racing write, one for the conflicting access. Fix with mutex, atomic, or redesign.

## Suppressions

```bash
# ASan/LSan suppression file
cat > asan.supp << 'EOF'
leak:CRYPTO_malloc
leak:libfontconfig
EOF
LSAN_OPTIONS=suppressions=asan.supp ./prog

# UBSan suppression
cat > ubsan.supp << 'EOF'
signed-integer-overflow:third_party/fast_math.c
EOF
UBSAN_OPTIONS=suppressions=ubsan.supp:print_stacktrace=1 ./prog

# TSan suppression
cat > tsan.supp << 'EOF'
race:third_party/legacy_lib.c
EOF
TSAN_OPTIONS=suppressions=tsan.supp ./prog
```

## CMake integration

```cmake
option(SANITIZE "Build with ASan+UBSan" OFF)
option(SANITIZE_THREAD "Build with TSan" OFF)

if(SANITIZE AND SANITIZE_THREAD)
    message(FATAL_ERROR "ASan and TSan are mutually exclusive")
endif()

if(SANITIZE)
    set(san_flags -fsanitize=address,undefined -fno-sanitize-recover=all
                  -fno-omit-frame-pointer -g -O1)
    add_compile_options(${san_flags})
    add_link_options(${san_flags})
endif()

if(SANITIZE_THREAD)
    set(tsan_flags -fsanitize=thread -g -O1)
    add_compile_options(${tsan_flags})
    add_link_options(${tsan_flags})
endif()
```

## CI integration

```yaml
- name: Build with sanitizers
  run: |
    cmake -S . -B build -DSANITIZE=ON
    cmake --build build -j$(nproc)

- name: Test under sanitizers
  run: |
    ASAN_OPTIONS=abort_on_error=1:detect_leaks=1 \
    UBSAN_OPTIONS=print_stacktrace=1:halt_on_error=1 \
    ctest --test-dir build -j$(nproc) --output-on-failure
```

## Performance cost

| Sanitizer | CPU overhead | Memory overhead |
|-----------|-------------|-----------------|
| ASan | ~2x | ~2-3x |
| UBSan | ~1.1-1.2x | negligible |
| TSan | ~5-15x | ~5-10x |
| MSan | ~3x | ~2-3x |

ASan + UBSan together add roughly the cost of ASan alone.
