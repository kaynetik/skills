# Modern C/C++ Reference (2026)

C++20/23/26 features, C23, modules, and migration guidance.

## C++20 (baseline for new projects in 2026)

### Concepts

Replace SFINAE with readable constraints:

```cpp
#include <concepts>

template <std::integral T>
T gcd(T a, T b) {
    while (b) { a %= b; std::swap(a, b); }
    return a;
}

// Custom concept
template <typename T>
concept Serializable = requires(T v, std::ostream& os) {
    { os << v } -> std::same_as<std::ostream&>;
};
```

### Ranges

```cpp
#include <ranges>
#include <vector>
#include <algorithm>

auto evens = vec | std::views::filter([](int x) { return x % 2 == 0; })
                 | std::views::transform([](int x) { return x * x; });

// Lazy evaluation; no intermediate containers
for (int v : evens) { /* ... */ }
```

### Coroutines

```cpp
#include <coroutine>
#include <generator>  // C++23, but often available via library

std::generator<int> fibonacci() {
    int a = 0, b = 1;
    while (true) {
        co_yield a;
        auto next = a + b;
        a = b;
        b = next;
    }
}
```

### Three-way comparison (spaceship)

```cpp
#include <compare>

struct Point {
    int x, y;
    auto operator<=>(const Point&) const = default;
};
```

### Modules

```cpp
// math.cppm -- module interface unit
export module math;

export int add(int a, int b) { return a + b; }

// Non-exported (module-private)
int internal_helper() { return 42; }
```

```cpp
// main.cpp -- consumer
import math;
import <iostream>;

int main() {
    std::cout << add(2, 3) << "\n";
}
```

Build with CMake 3.28+:

```cmake
cmake_minimum_required(VERSION 3.28)
project(myproject LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)

add_library(math)
target_sources(math
    PUBLIC FILE_SET CXX_MODULES FILES src/math.cppm
)

add_executable(myapp main.cpp)
target_link_libraries(myapp PRIVATE math)
```

Requires Ninja 1.11+ or MSBuild as generator. Module partitions, header units, and the Global Module Fragment are covered in detail in the upstream `cpp-modules` skill.

#### Module build commands (manual)

```bash
# Clang
clang++ -std=c++20 --precompile math.cppm -o math.pcm
clang++ -std=c++20 -fmodule-file=math=math.pcm main.cpp -o prog

# GCC (experimental, GCC 14+ recommended)
g++ -std=c++20 -fmodules-ts math.cppm -c -o math.o
g++ -std=c++20 -fmodules-ts main.cpp math.o -o prog
```

### Other C++20 features

| Feature | Header / syntax |
|---------|-----------------|
| `std::format` | `<format>` -- type-safe formatting |
| `std::span` | `<span>` -- non-owning view over contiguous data |
| `consteval` | Guaranteed compile-time evaluation |
| `constinit` | Guaranteed constant initialization |
| `std::jthread` | `<thread>` -- auto-joining, stoppable thread |
| `std::atomic_ref` | `<atomic>` -- atomic operations on non-atomic objects |
| Designated initializers | `Point{.x = 1, .y = 2}` |
| `[[likely]]` / `[[unlikely]]` | Branch prediction hints |

## C++23 (production-ready on GCC 14+, Clang 18+)

| Feature | What |
|---------|------|
| `std::expected<T,E>` | Error-or-value type (alternative to exceptions) |
| `std::print` / `std::println` | `<print>` -- formatted output without `iostream` overhead |
| Deducing this | Explicit object parameter: `void foo(this auto& self)` |
| `std::flat_map` / `std::flat_set` | Cache-friendly sorted containers |
| `std::mdspan` | Multi-dimensional span |
| `if consteval` | Compile-time branch on constant evaluation context |
| `std::unreachable()` | Hint for unreachable code paths |
| `std::to_underlying` | `enum` to underlying type conversion |
| `std::stacktrace` | `<stacktrace>` -- programmatic stack traces |

### std::expected example

```cpp
#include <expected>
#include <string>

std::expected<int, std::string> parse_int(const char* s) {
    char* end;
    long val = std::strtol(s, &end, 10);
    if (*end != '\0') return std::unexpected("invalid input");
    return static_cast<int>(val);
}

auto result = parse_int("42");
if (result) {
    use(*result);
} else {
    log_error(result.error());
}
```

### Deducing this

```cpp
struct Widget {
    void process(this auto&& self) {
        // 'self' deduced as lvalue ref or rvalue ref
        // Replaces CRTP for some patterns
    }
};
```

## C++26 (in progress, partial compiler support)

Key features expected or already landing:

| Feature | Status (2026) |
|---------|---------------|
| Reflection (`^^`, `[:..:]`) | Experimental in some compilers |
| `std::execution` (sender/receiver) | Partial |
| Contracts (`pre`, `post`, `contract_assert`) | Experimental |
| Pattern matching (`inspect`) | Proposal stage |
| `std::inplace_vector` | Approved |
| Trivial relocatability | Approved |
| `#embed` | GCC 15+, Clang 19+ |

### #embed (binary data inclusion)

```c
// Works in both C23 and C++26
const unsigned char icon[] = {
    #embed "icon.png"
};
```

Replaces `xxd` or `objcopy` workflows for embedding binary resources.

## C23 (the C side)

C23 is the current C standard. Compile with `-std=c23`.

| Feature | What |
|---------|------|
| `typeof` | Standard `typeof` (was GCC extension) |
| `nullptr` | Null pointer constant (replaces `(void*)0` / `NULL`) |
| `bool`, `true`, `false` | Keywords (no `#include <stdbool.h>` needed) |
| `constexpr` | Compile-time constants for objects |
| `static_assert` | No message argument required |
| `_BitInt(N)` | Arbitrary-width integers |
| `#embed` | Binary resource inclusion |
| `[[nodiscard]]`, `[[maybe_unused]]`, etc. | C++ attributes adopted into C |
| `auto` | Type inference for variables |
| Unnamed parameters | `void foo(int)` without naming the param |
| `#warning` | Standard preprocessor warning directive |

### C23 example

```c
// C23: no stdbool.h, typeof is standard, nullptr replaces NULL
constexpr int BUF_SIZE = 1024;

bool process(typeof(BUF_SIZE) size) {
    char* buf = malloc(size);
    if (buf == nullptr) return false;
    // ...
    free(buf);
    return true;
}
```

## Migration guidance

### Headers to modules (C++20)

1. Start with leaf libraries (no circular deps)
2. Create `.cppm` interface unit exporting the public API
3. Move implementation to module implementation units or keep inline
4. Replace `#include` with `import` in consumers
5. Use Global Module Fragment for headers that provide macros
6. Update CMake to `FILE_SET CXX_MODULES`

### C11/C17 to C23

1. Replace `#include <stdbool.h>` with direct `bool`/`true`/`false`
2. Replace `NULL` / `(void*)0` with `nullptr`
3. Replace `__typeof__` / `__auto_type` with standard `typeof` / `auto`
4. Add `constexpr` to compile-time constants
5. Replace `xxd`-embedded data with `#embed` if compiler supports it

### C++17 to C++20/23

1. Replace SFINAE (`enable_if`) with concepts where readability improves
2. Adopt `std::format` / `std::print` over `printf` or `iostream` formatting
3. Use `std::expected` for functions that can fail (where exceptions are unwanted)
4. Use `std::span` instead of raw pointer + length pairs
5. Replace manual `operator<` boilerplate with `<=>` defaulting
6. Evaluate ranges pipelines for transform/filter chains
