const std = @import("std");

const Apdu = @This();

meta: Meta,
len: u8,
data: [255]u8,

pub const Meta = struct {
    cla: u8,
    ins: u8,
    p1: u8,
    p2: u8,
};

pub fn init(meta: Meta, data: []const u8) !Apdu {
    var apdu = Apdu{ .meta = meta, .len = undefined, .data = undefined };
    try apdu.setData(data);

    return apdu;
}

pub fn setData(self: *Apdu, data: []const u8) !void {
    if (data.len > self.data.len) return error.Overflow;

    @memcpy(self.data[0..data.len], data);
    self.len = @intCast(data.len);
}

pub fn bytes(self: *const Apdu) []const u8 {
    const byte_count = self.len + @sizeOf(Meta) + @sizeOf(@TypeOf(self.len));
    return std.mem.asBytes(self)[0..byte_count];
}

pub const cmd = struct {
    pub fn selectFile(id: []const u8) !Apdu {
        return Apdu.init(.{
            .cla = 0x0,
            .ins = 0xa4,
            .p1 = 0x04,
            .p2 = 0x0,
        }, id);
    }
};
