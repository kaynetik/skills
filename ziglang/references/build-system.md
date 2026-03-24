# Zig 0.15.x Build System Reference

Detailed patterns for `build.zig` configuration in 0.15.x.

## Executable

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "myapp",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);
}
```

## Library

```zig
const lib = b.addLibrary(.{
    .name = "mylib",
    .linkage = .static, // or .dynamic
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
b.installArtifact(lib);
```

Previous `addStaticLibrary` / `addSharedLibrary` calls are replaced by `addLibrary` with explicit `.linkage`.

## Module Dependencies

```zig
const sdk_mod = b.createModule(.{
    .root_source_file = b.path("vendor/sdk/root.zig"),
    .target = target,
    .optimize = optimize,
});

const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sdk", .module = sdk_mod },
        },
    }),
});

// Alternatively, add after creation:
exe.root_module.addImport("sdk", sdk_mod);
```

In application code:

```zig
const sdk = @import("sdk");
```

## Dependency Packages (build.zig.zon)

```zig
// build.zig.zon
.{
    .name = .myproject,
    .version = "0.1.0",
    .dependencies = .{
        .@"dep-name" = .{
            .url = "https://github.com/user/repo/archive/refs/tags/v1.0.0.tar.gz",
            .hash = "...",
        },
    },
}
```

```zig
// build.zig
const dep = b.dependency("dep-name", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("dep-name", dep.module("dep-name"));
```

## Testing

```zig
const unit_tests = b.addTest(.{
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = b.graph.host,
    }),
});

const run_tests = b.addRunArtifact(unit_tests);
const test_step = b.step("test", "Run unit tests");
test_step.dependOn(&run_tests.step);
```

Key points:

- Use `b.graph.host` as the target for tests that run on the build machine.
- For cross-compiled test binaries, use the explicit `target` instead.

### Test Filters

```bash
zig build test -- --test-filter "my test name"
```

## Run Steps

```zig
const run = b.addRunArtifact(exe);
run.step.dependOn(b.getInstallStep());

if (b.args) |args| {
    run.addArgs(args);
}

const run_step = b.step("run", "Run the application");
run_step.dependOn(&run.step);
```

## Build Modes

| Mode | Flag | Safety | Debug Info | Performance |
|------|------|--------|------------|-------------|
| Debug | (default) | Full | Yes | Slow |
| ReleaseSafe | `-Doptimize=ReleaseSafe` | Full | No | Medium |
| ReleaseFast | `-Doptimize=ReleaseFast` | None | No | Fast |
| ReleaseSmall | `-Doptimize=ReleaseSmall` | None | No | Small binary |

## Compile Variables

```zig
const builtin = @import("builtin");

if (builtin.mode == .Debug) { ... }
if (builtin.os.tag == .linux) { ... }
if (builtin.cpu.arch == .x86_64) { ... }
if (builtin.is_test) { ... }
```

## C Interop in Build

```zig
exe.root_module.addCSourceFiles(.{
    .files = &.{ "vendor/lib.c" },
    .flags = &.{ "-Wall", "-O2" },
});
exe.root_module.addIncludePath(b.path("vendor/include"));
exe.root_module.linkSystemLibrary("pthread", .{});
exe.root_module.linkLibC();
```

## Cross-Compilation

```bash
zig build -Dtarget=aarch64-linux-gnu
zig build -Dtarget=x86_64-windows-msvc
zig build -Dtarget=wasm32-freestanding
```

Target triple format: `<arch>-<os>-<abi>`

## Install Artifacts

```zig
b.installArtifact(exe);           // installs to zig-out/bin/
b.installArtifact(lib);           // installs to zig-out/lib/
b.installFile(b.path("config.toml"), "etc/config.toml");
b.installDirectory(.{
    .source = b.path("assets"),
    .dest = "share/assets",
});
```
