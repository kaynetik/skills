# Zig 0.15.x Standard Library API Reference

Detailed API patterns for commonly used std modules that changed in 0.15.x.

## std.http.Client

The HTTP client API was rewritten. The 0.14 `open`/`finish`/`read` flow is gone.

```zig
const std = @import("std");

pub fn httpGet(allocator: std.mem.Allocator) ![]const u8 {
    var client: std.http.Client = .{ .allocator = allocator };
    defer client.deinit();

    var buf: [8192]u8 = undefined;
    var req = try client.fetch(.{
        .uri = try std.Uri.parse("https://example.com"),
        .header_buf = &buf,
    });
    defer req.deinit();

    const body = try req.reader().readAllAlloc(allocator, 1 << 20);
    return body;
}
```

For streaming responses, use `req.reader()` and read in chunks.

## std.crypto.sign.Ed25519

```zig
const Ed25519 = std.crypto.sign.Ed25519;

// Key generation
const kp = try Ed25519.KeyPair.generate(null);

// Signing
const sig = kp.sign("message", null);

// Verification
sig.verify("message", kp.public_key) catch return error.InvalidSignature;

// IMPORTANT: fromBytes does NOT return an error union
const sig2 = Ed25519.Signature.fromBytes(byte_array);
// NOT: const sig2 = try Ed25519.Signature.fromBytes(byte_array); -- compile error
```

## std.base64

The encoder/decoder APIs were reorganized.

```zig
const base64 = std.base64;

// Standard encoding
const encoded = base64.standard.encode(&dest_buf, source);
const decoded = try base64.standard.Decoder.decode(&dest_buf, encoded);

// URL-safe encoding
const url_encoded = base64.url_safe.encode(&dest_buf, source);

// Allocating variants
const alloc_encoded = try base64.standard.Encoder.allocEncode(allocator, source);
defer allocator.free(alloc_encoded);
```

## std.Io.Writer and std.Io.Reader

The new I/O types are non-generic. They use a buffer-in-interface design with ring buffers internally.

### Writer

```zig
// Create a writer backed by a file
var buf: [4096]u8 = undefined;
var file_writer = file.writer(&buf);
const w: *std.Io.Writer = &file_writer.interface;
try w.print("value: {d}\n", .{42});
try w.flush();

// Create a writer backed by an ArrayList
var output = std.ArrayList(u8).init(allocator);
defer output.deinit(allocator);
var list_writer = output.writer(&.{});
const w2: *std.Io.Writer = &list_writer.interface;
```

### Reader

```zig
var buf: [4096]u8 = undefined;
var file_reader = file.reader(&buf);
const r: *std.Io.Reader = &file_reader.interface;
const line = try r.readUntilDelimiterOrEof('\n');
```

### Fixed Buffer Stream

```zig
var fbs = std.io.fixedBufferStream(&buffer);
// For writing:
const w = fbs.writer();
// For reading:
const r = fbs.reader();
```

## std.fmt

### Format Specifiers (0.15)

| Specifier | Purpose |
|-----------|---------|
| `{d}` | Integer (decimal) |
| `{x}` | Integer (hex lowercase) |
| `{X}` | Integer (hex uppercase) |
| `{s}` | String / slice of u8 |
| `{f}` | Custom format function |
| `{e}` | Float (scientific) |
| `{any}` | Debug format (any type) |
| `{}` | Default format |

### bufPrint and allocPrint

```zig
var buf: [256]u8 = undefined;
const str = try std.fmt.bufPrint(&buf, "x={d}", .{42});

const allocated = try std.fmt.allocPrint(allocator, "x={d}", .{42});
defer allocator.free(allocated);
```

## std.mem Patterns

```zig
// Comparison
const equal = std.mem.eql(u8, "abc", "abc");
const order = std.mem.order(u8, "abc", "abd");

// Search
const idx = std.mem.indexOf(u8, haystack, needle);
const last = std.mem.lastIndexOf(u8, haystack, needle);
const has = std.mem.containsAtLeast(u8, haystack, 1, needle);

// Manipulation
std.mem.copyForwards(u8, dest, src);
std.mem.reverse(u8, slice);
@memset(slice, 0);

// Alignment
const aligned = std.mem.alignForward(usize, addr, alignment);
```

## std.fs

```zig
// Open and read a file
const file = try std.fs.cwd().openFile("path.txt", .{});
defer file.close();
const content = try file.readToEndAlloc(allocator, max_size);
defer allocator.free(content);

// Write a file
const out = try std.fs.cwd().createFile("out.txt", .{});
defer out.close();
try out.writeAll("data");

// Directory operations
var dir = try std.fs.cwd().openDir("subdir", .{ .iterate = true });
defer dir.close();
var iter = dir.iterate();
while (try iter.next()) |entry| {
    // entry.name, entry.kind
}
```

## Allocators

| Allocator | Use Case |
|-----------|----------|
| `std.heap.page_allocator` | Simple, large allocations |
| `std.heap.c_allocator` | C interop (requires libc) |
| `std.heap.ArenaAllocator` | Batch allocation, single free |
| `std.heap.FixedBufferAllocator` | No-heap, stack-backed |
| `std.heap.smp_allocator` | Thread-safe general purpose (new in 0.15) |
| `std.testing.allocator` | Tests; detects leaks |
| `std.testing.FailingAllocator` | Tests; simulates OOM |
| `std.heap.DebugAllocator` | Debug; detects use-after-free |

### Arena Pattern

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const alloc = arena.allocator();
// all allocations freed at once when arena is deinitialized
```
