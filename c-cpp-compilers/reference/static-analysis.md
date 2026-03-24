# Static Analysis Reference

Selecting, configuring, and triaging static analysis for C/C++ projects.

## Tools overview

| Tool | Strength | Analysis type |
|------|----------|---------------|
| clang-tidy | Linting + checks + auto-fix | AST-based + some path-sensitive |
| Clang Static Analyzer (CSA) | Deep bug finding | Path-sensitive |
| cppcheck | Portable, no compilation database needed | Pattern-based + data flow |
| GCC `-fanalyzer` | Built into GCC 10+, no extra tooling | Path-sensitive (GCC only) |

## Compilation database

clang-tidy requires `compile_commands.json`:

```bash
# CMake (preferred)
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
ln -sf build/compile_commands.json .

# Bear (for Make-based projects)
bear -- make

# compiledb (pip-installable alternative)
compiledb make
```

## clang-tidy

### Running

```bash
# Single file
clang-tidy src/foo.c -- -std=c23 -Iinclude/

# Whole project
run-clang-tidy -p build/ -j$(nproc)

# Specific checks
clang-tidy -checks='bugprone-*,performance-*,modernize-*' src/foo.cpp

# Auto-fix
clang-tidy -checks='modernize-use-nullptr' -fix src/foo.cpp
```

### Check families

| Family | What it catches |
|--------|----------------|
| `bugprone-*` | Real bugs: use-after-move, integer-division, suspicious-memset |
| `clang-analyzer-*` | CSA path-sensitive: null deref, memory leaks, use-after-free |
| `modernize-*` | C++11/14/17/20 idiom upgrades |
| `performance-*` | Unnecessary copies, `std::endl` vs `'\n'`, move candidates |
| `cppcoreguidelines-*` | C++ Core Guidelines compliance |
| `cert-*` | CERT secure coding standard |
| `readability-*` | Naming, complexity, braces |

### Decision tree

```
Goal?
  Find real bugs       -> bugprone-*, clang-analyzer-*
  Modernize codebase   -> modernize-*
  Performance issues   -> performance-*
  Security hardening   -> cert-*, clang-analyzer-security.*
  Style/readability    -> readability-*
  Core Guidelines      -> cppcoreguidelines-*
```

### .clang-tidy config

```yaml
Checks: >
  bugprone-*,
  clang-analyzer-*,
  modernize-*,
  performance-*,
  -modernize-use-trailing-return-type,
  -bugprone-easily-swappable-parameters
WarningsAsErrors: 'bugprone-*,clang-analyzer-*'
HeaderFilterRegex: '^(src|include)/.*'
CheckOptions:
  - key: modernize-loop-convert.MinConfidence
    value: reasonable
  - key: readability-identifier-naming.VariableCase
    value: camelCase
```

Place at project root. Excluded directories (third-party, generated) are handled by `HeaderFilterRegex`.

### Suppression

```cpp
// Suppress single line
int x = riskyOp(); // NOLINT(bugprone-signed-char-misuse)

// Suppress next line
// NOLINTNEXTLINE(cppcoreguidelines-avoid-magic-numbers)
constexpr int BUF_SIZE = 4096;

// Suppress a block (Clang 16+)
// NOLINTBEGIN(bugprone-*)
void legacy() { /* ... */ }
// NOLINTEND(bugprone-*)
```

## cppcheck

```bash
# Basic
cppcheck --enable=warning,performance,portability --std=c23 src/

# With compilation database
cppcheck --project=build/compile_commands.json

# Suppress noise
cppcheck --enable=warning,performance \
         --suppress=missingIncludeSystem \
         --suppress=unmatchedSuppression \
         --error-exitcode=1 src/

# XML report for CI
cppcheck --xml --xml-version=2 src/ 2> cppcheck-report.xml
```

| `--enable=` | What |
|-------------|------|
| `warning` | Undefined behaviour, bad practices |
| `performance` | Redundant operations |
| `portability` | Non-portable constructs |
| `information` | Configuration notes |
| `all` | Everything above |

## scan-build (CSA)

```bash
# Intercept build
scan-build make
scan-build cmake --build build/

# View report
scan-view /tmp/scan-build-*/

# Enable specific checkers
scan-build -enable-checker security.insecureAPI.gets \
           -enable-checker alpha.unix.cstring.BufferOverlap \
           make
```

Finds deeper bugs than clang-tidy: cross-function use-after-free, dead stores from logic errors, null dereferences on complex control paths.

## GCC -fanalyzer

```bash
gcc -fanalyzer -Wall -O1 src.c -o prog
```

Built-in since GCC 10. No extra tools needed. Finds double-free, use-after-free, null deref, leak, buffer overflow. Slower than clang-tidy but useful when Clang is not available.

## CI integration

```yaml
# GitHub Actions
- name: clang-tidy
  run: |
    cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    run-clang-tidy -p build -j$(nproc) -warnings-as-errors '*'

- name: cppcheck
  run: |
    cppcheck --enable=warning,performance \
             --suppress=missingIncludeSystem \
             --error-exitcode=1 src/
```

## Recommended CI pipeline order

1. Compile with `-Wall -Wextra -Werror`
2. Run clang-tidy (AST + path-sensitive checks)
3. Run cppcheck (supplementary pattern checks)
4. Build with sanitizers + run tests
5. (Optional) scan-build for deep path analysis on changed files
