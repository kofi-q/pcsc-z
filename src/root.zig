const builtin = @import("builtin");

pub const AttrId = @import("attributes.zig").Id;
pub const attributes = @import("attributes.zig");
pub const Card = @import("Card.zig");
pub const Client = @import("Client.zig");
pub const Err = @import("err.zig").Err;
pub const errDescription = @import("err.zig").errDescription;
pub const Iword = @import("types.zig").Iword;
pub const NameIterator = @import("types.zig").NameIterator;
pub const Protocol = @import("protocol.zig").Protocol;
pub const Reader = @import("reader.zig").Reader;
pub const ReaderT = @import("reader.zig").ReaderT;
pub const Result = @import("err.zig").Result;
pub const Uword = @import("types.zig").Uword;

const constants = @import("constants.zig");
pub const max_atr_len = constants.max_atr_len;
pub const max_buffer_len = constants.max_buffer_len;
pub const max_buffer_len_extended = constants.max_buffer_len_extended;
pub const max_reader_name_len = constants.max_reader_name_len;
pub const max_readers = constants.max_readers;

pub const control_codes = struct {
    pub const FEATURE_REQUEST = controlCode(3400);
};

pub inline fn controlCode(function_code: u32) u32 {
    switch (builtin.os.tag) {
        // From (Win32) winsmcrd.h:
        .windows => {
            const device_type_smart_card = 0x0000_0031;
            return (device_type_smart_card << 16) | (function_code << 2);
        },

        // From PCSCLite:
        // https://github.com/LudovicRousseau/PCSC/blob/c01a7ad/src/PCSC/reader.h#L118
        else => return 0x4200_0000 + function_code,
    }
}

test {
    const std = @import("std");
    std.testing.refAllDeclsRecursive(@This());
}
