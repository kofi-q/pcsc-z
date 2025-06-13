const std = @import("std");
const builtin = @import("builtin");

/// Basic signed integer type used by PCSC middleware, which differs based on
/// the OS-specific API implementation.
pub const Iword = switch (builtin.os.tag) {
    .macos => i32,
    else => c_long,
};

/// Basic unsigned integer type used by PCSC middleware, which differs based on
/// the OS-specific API implementation.
pub const Uword = switch (builtin.os.tag) {
    .macos => u32,
    else => c_ulong,
};

/// Type for PCSC client context/card handles, which differs based on the
/// OS-specific API implementation.
pub const HandleType = switch (builtin.os.tag) {
    .windows => c_ulonglong,
    else => Iword,
};

/// Iterator for reader/group names, which are returned from PCSC as a single,
/// combined, sentinel-delimited string.
pub const NameIterator = struct {
    const Inner = std.mem.TokenIterator(u8, .scalar);

    inner: Inner,

    pub fn init(names: []const u8) NameIterator {
        return .{ .inner = std.mem.tokenizeScalar(u8, names, 0x0) };
    }

    pub fn next(self: *NameIterator) ?[:0]const u8 {
        const name = self.inner.next() orelse return null;
        return name.ptr[0..name.len :0];
    }

    pub fn peek(self: *NameIterator) ?[:0]const u8 {
        const name = self.inner.peek() orelse return null;
        return name.ptr[0..name.len :0];
    }

    pub fn reset(self: *NameIterator) void {
        self.inner.reset();
    }

    pub fn rest(self: *NameIterator) []const u8 {
        return self.inner.rest();
    }
};
