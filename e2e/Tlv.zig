//! BER-TLV reader/writer. Incomplete - for testing purposes only.

const std = @import("std");

const Tlv = @This();

tag: Tag,
value: []const u8,

const Tag = struct {
    head: Head,
    extra: []const u8,

    const Head = packed struct(u8) {
        type: TypeShort,
        form: Form,
        class: Class,
    };

    const Class = enum(u2) {
        /// Universal class (defined in ISO/IEC 8825-1/X.690)
        universal = 0b00,

        /// Application class (specific to an application)
        application = 0b01,

        /// Context-specific class (meaning depends on the context of the constructed data object it's part of)
        custom = 0b10,

        /// Private class (for private use)
        private = 0b11,
    };

    const Form = enum(u1) {
        /// Primitive (the Value field contains the actual data element).
        primitive = 0,

        /// Constructed (the Value field contains one or more nested BER-TLV
        /// data objects).
        constructed = 1,
    };

    const TypeShort = packed struct(u5) {
        value: u5,

        pub const long_form: TypeShort = .{ .value = 0b11111 };

        pub fn isLongForm(self: TypeShort) bool {
            return self == long_form;
        }
    };

    const TypeLong = packed struct(u8) {
        has_more: bool,
        value_prefix: u7,

        pub fn value(self: TypeLong) u8 {
            return @bitCast(self);
        }
    };

    pub fn format(
        self: Tag,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: std.io.AnyWriter,
    ) !void {
        try writer.writeAll("0x");
        try writer.print("{x:0>2}", .{@as(u8, @bitCast(self.head))});
        for (self.extra) |b| try writer.print("{x:0>2}", .{b});
    }
};

const Len = packed struct(u8) {
    value: u7,
    long_form: bool,

    comptime {
        std.debug.assert(
            std.mem.nativeToBig(u8, 0b1000_0000) == @as(u8, @bitCast(Len{
                .long_form = true,
                .value = 0,
            })),
        );
    }
};

pub const Iterator = struct {
    reader: std.io.FixedBufferStream([]const u8),

    pub const Err = error{
        Eof,
        InvalidLength,
        Malformed,
        UnsupportedLength,
    };

    pub fn init(buf: []const u8) Iterator {
        return .{ .reader = std.io.fixedBufferStream(buf) };
    }

    pub fn next(self: *Iterator) Err!Tlv {
        const reader = self.reader.reader().any();

        const tag = try self.readTag();
        const len_or_marker: Len = @bitCast(reader.readByte() catch {
            return Err.Malformed;
        });

        const len: u16 = @intCast(blk: {
            if (!len_or_marker.long_form) break :blk len_or_marker.value;

            break :blk switch (len_or_marker.value) {
                0 => {
                    // Special case: indeterminate length.
                    // [TODO] This doesn't handle nested indeterminate-length
                    // TLVs.
                    const end = std.mem.indexOfPos(
                        u8,
                        self.reader.buffer,
                        self.reader.pos,
                        "\x00\x00",
                    ) orelse return Err.Malformed;

                    // Skip the value-end marker found above.
                    defer self.reader.seekBy(2) catch unreachable;

                    const len: u16 = @intCast(end - self.reader.pos);

                    return .{
                        .tag = tag,
                        .value = self.readValue(len) catch return Err.Malformed,
                    };
                },
                inline 1...2 => |byte_count| try self.readLen(
                    std.meta.Int(.unsigned, byte_count * 8),
                ),
                else => return Err.UnsupportedLength,
            };
        });

        return .{
            .tag = tag,
            .value = self.readValue(len) catch return Err.Malformed,
        };
    }

    fn readTag(self: *Iterator) Err!Tag {
        const reader = self.reader.reader().any();

        const head: Tag.Head = @bitCast(reader.readByte() catch return Err.Eof);
        if (!head.type.isLongForm()) return .{
            .head = head,
            .extra = &.{},
        };

        const start = self.reader.pos;
        while (true) {
            const tag_type: Tag.TypeLong = @bitCast(reader.readByte() catch {
                return Err.Malformed;
            });
            if (!tag_type.has_more) break;
        } else unreachable;

        return .{
            .head = head,
            .extra = self.reader.buffer[start..self.reader.pos],
        };
    }

    fn readLen(self: *Iterator, comptime IntType: type) Err!u16 {
        return @intCast(self.reader.reader().readInt(IntType, .big) catch {
            return Err.InvalidLength;
        });
    }

    fn readValue(self: *Iterator, len: u16) error{Malformed}![]const u8 {
        const start = self.reader.pos;

        self.reader.seekBy(len) catch return Err.Malformed;
        if (len > self.reader.pos - start) return Err.Malformed;

        return self.reader.buffer[start..][0..len];
    }
};

pub fn iterator(buf: []const u8) Iterator {
    return .init(buf);
}

pub fn write(self: Tlv, writer: std.io.AnyWriter) !void {
    try writer.writeByte(self.tag);

    switch (self.value.len) {
        0...0x7f => |len| {
            try writer.writeInt(u8, @intCast(len), .big);
        },
        0x80 => {
            // Special case: indeterminate length.
            try writer.writeInt(u8, 0x80, .big);
            try writer.writeAll(self.value);
            try writer.writeInt(u16, 0);
            return;
        },
        0x81...0xff => |len| {
            try writer.writeInt(u8, 0x81, .big);
            try writer.writeInt(u8, @intCast(len), .big);
        },
        0x01_00...0xff_ff => |len| {
            try writer.writeInt(u8, 0x82, .big);
            try writer.writeInt(u16, @intCast(len), .big);
        },
        else => return error.UnsupportedLength,
    }

    try writer.writeAll(self.value);
}

test write {
    const buf = try std.testing.allocator.alloc(u8, 0x01_00_00);
    defer std.testing.allocator.free(buf);

    var stream = std.io.fixedBufferStream(buf);
    const writer = stream.writer().any();

    try (Tlv{ .tag = 0x55, .value = &.{} }).write(writer);
    try std.testing.expectEqualSlices(u8, &.{ 0x55, 0x00 }, buf[0..2]);

    stream.reset();
    try (Tlv{
        .tag = 0x44,
        .value = &@as([0x7f]u8, @splat(0xee)),
    }).write(writer);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x44, 0x7f, 0xee, 0xee },
        buf[0..4],
    );

    stream.reset();
    try (Tlv{
        .tag = 0x33,
        .value = &@as([0x80]u8, @splat(0xdd)),
    }).write(writer);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x33, 0x81, 0x80, 0xdd, 0xdd },
        buf[0..5],
    );

    stream.reset();
    try (Tlv{
        .tag = 0x22,
        .value = &@as([0x100]u8, @splat(0xcc)),
    }).write(writer);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 0x22, 0x82, 0x01, 0x00, 0xcc, 0xcc },
        buf[0..6],
    );

    stream.reset();
    try std.testing.expectError(
        error.UnsupportedLength,
        (Tlv{
            .tag = 0x11,
            .value = &@as([0x01_00_00]u8, @splat(0xbb)),
        }).write(writer),
    );
}

pub fn format(
    self: Tlv,
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: std.io.AnyWriter,
) !void {
    try std.fmt.format(writer, "[TLV] {}: {x:0>2}", .{
        self.tag,
        self.value,
    });
}
