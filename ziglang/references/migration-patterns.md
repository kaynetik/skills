# Migration Patterns: 0.13/0.14 to 0.15.x

Common code patterns that need updating when moving to Zig 0.15.x.

## ArrayList

### Before (0.14)

```zig
var list = std.ArrayList(u8).init(allocator);
defer list.deinit();
try list.append(42);
try list.appendSlice(&[_]u8{ 1, 2, 3 });
const slice = try list.toOwnedSlice();
```

### After (0.15)

```zig
var list = std.ArrayList(u8).init(allocator);
defer list.deinit(allocator);
try list.append(allocator, 42);
try list.appendSlice(allocator, &[_]u8{ 1, 2, 3 });
const slice = try list.toOwnedSlice(allocator);
```

All mutating methods now require an explicit `allocator`. `deinit` also requires it. The `AssumeCapacity` variants (`appendAssumeCapacity`, etc.) do not need an allocator.

## I/O (Writergate)

### Before (0.14)

```zig
const stdout = std.io.getStdOut().writer();
try stdout.print("Hello {s}\n", .{"world"});
```

### After (0.15)

```zig
var buf: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&buf);
const stdout: *std.Io.Writer = &stdout_writer.interface;
try stdout.print("Hello {s}\n", .{"world"});
try stdout.flush();
```

Key differences:

- No more `std.io.getStdOut()`. Use `std.fs.File.stdout()` directly.
- Writer requires an explicit buffer.
- Must call `.flush()` for output to appear.
- Type is `std.Io.Writer` (capital I), not `std.io.Writer`.

## build.zig

### Before (0.14)

```zig
const exe = b.addExecutable(.{
    .name = "app",
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = optimize,
});
exe.addModule("mymod", my_module);
```

### After (0.15)

```zig
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
exe.root_module.addImport("mymod", my_module);
```

### Library Changes

```zig
// Before
const lib = b.addStaticLibrary(.{ ... });
const shared = b.addSharedLibrary(.{ ... });

// After
const lib = b.addLibrary(.{ .linkage = .static, ... });
const shared = b.addLibrary(.{ .linkage = .dynamic, ... });
```

## @typeInfo Enum Cases

### Before (0.14)

```zig
if (@typeInfo(T) == .Struct) { ... }
if (@typeInfo(T) == .Pointer) { ... }
if (@typeInfo(T) == .Enum) { ... }
if (@typeInfo(T) == .Slice) { ... }
```

### After (0.15)

```zig
if (@typeInfo(T) == .@"struct") { ... }
if (@typeInfo(T) == .pointer) { ... }
if (@typeInfo(T) == .@"enum") { ... }
if (@typeInfo(T) == .slice) { ... }
```

Cases that are Zig keywords (struct, enum, union, fn, error, opaque) require `@""` escaping. Others are lowercase without escaping (pointer, slice, array, int, float, bool, void, etc.).

## Custom Format Functions

### Before (0.14)

```zig
pub fn format(
    self: Self,
    comptime spec: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = spec;
    _ = options;
    try writer.writeAll("...");
}
```

### After (0.15)

```zig
pub fn format(self: Self, writer: anytype) !void {
    try writer.writeAll("...");
}
// Invoked with {f} specifier
```

## usingnamespace

### Before (0.14)

```zig
pub usingnamespace @import("other.zig");
```

### After (0.15)

```zig
// Option 1: explicit re-exports
pub const foo = @import("other.zig").foo;
pub const bar = @import("other.zig").bar;

// Option 2: namespace import
pub const other = @import("other.zig");
// then use: other.foo, other.bar
```

## Ed25519

### Before (0.14)

```zig
const sig = try Ed25519.Signature.fromBytes(bytes);
```

### After (0.15)

```zig
const sig = Ed25519.Signature.fromBytes(bytes); // not an error union
```

## HTTP Client

### Before (0.14)

```zig
var client = std.http.Client{ .allocator = allocator };
var req = try client.open(.GET, uri, .{}, .{});
defer req.deinit();
try req.send();
try req.finish();
try req.wait();
const body = try req.reader().readAllAlloc(allocator, max);
```

### After (0.15)

```zig
var client: std.http.Client = .{ .allocator = allocator };
defer client.deinit();
var header_buf: [8192]u8 = undefined;
var req = try client.fetch(.{
    .uri = uri,
    .header_buf = &header_buf,
});
defer req.deinit();
const body = try req.reader().readAllAlloc(allocator, max);
```

## Arithmetic on undefined

Compile error in 0.15 for arithmetic on `undefined` values. Initialize variables explicitly:

```zig
// Before: var x: u32 = undefined; x += 1; -- compile error in 0.15
// After:
var x: u32 = 0;
x += 1;
```

## Lossy Integer-to-Float Coercion

Implicit coercion from integers wider than the float's mantissa is now a compile error:

```zig
// Before: implicitly allowed
const f: f32 = some_u64; // compile error in 0.15

// After: explicit cast required
const f: f32 = @floatFromInt(some_u64);
```

## Quick Migration Checklist

- [ ] Update all `ArrayList` calls to pass `allocator`
- [ ] Replace `std.io.getStdOut().writer()` with new `std.Io.Writer` pattern
- [ ] Update `build.zig` to use `root_module` / `b.createModule` / `b.path`
- [ ] Replace `addStaticLibrary`/`addSharedLibrary` with `addLibrary`
- [ ] Change `@typeInfo` cases to lowercase / `@""` escaped
- [ ] Replace `usingnamespace` with explicit imports
- [ ] Simplify custom `format` function signatures
- [ ] Remove `try` from `Ed25519.Signature.fromBytes`
- [ ] Update HTTP client to use `fetch` API
- [ ] Fix any arithmetic on `undefined` values
- [ ] Add explicit casts for integer-to-float conversions
