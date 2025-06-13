const std = @import("std");

const Uword = @import("root.zig").Uword;

/// Reader attribute ID.
pub const Id = packed struct(u32) {
    tag: u16,
    class: Class,

    pub fn init(class: Class, tag: u16) Id {
        return .{ .class = class, .tag = tag };
    }

    pub fn toSys(self: Id) Sys {
        return .{ .id = self };
    }

    /// Wrapper type for the system-specific PCSC implementation.
    pub const Sys = packed struct(Uword) {
        id: Id,

        /// Potential padding.
        _: std.meta.Int(.unsigned, @bitSizeOf(Uword) -| @bitSizeOf(Id)) = 0,
    };
};

pub const Class = enum(u16) {
    COMMUNICATIONS = 0x2,
    ICC_STATE = 0x9,
    IFD_PROTOCOL = 0x8,
    MECHANICAL = 0x6,
    POWER_MGMT = 0x4,
    PROTOCOL = 0x3,
    SECURITY = 0x5,
    SYSTEM = 0x7fff,
    VENDOR_DEFINED = 0x7,
    VENDOR_INFO = 0x1,
    _,
};

pub const ids = struct {
    pub const ASYNC_PROTOCOL_TYPES = Id.init(.PROTOCOL, 0x0120);
    pub const ATR_STRING = Id.init(.ICC_STATE, 0x0303);
    pub const CHANNEL_ID = Id.init(.COMMUNICATIONS, 0x0110);
    pub const CHARACTERISTICS = Id.init(.MECHANICAL, 0x0150);
    pub const CURRENT_BWT = Id.init(.IFD_PROTOCOL, 0x0209);
    pub const CURRENT_CLK = Id.init(.IFD_PROTOCOL, 0x0202);
    pub const CURRENT_CWT = Id.init(.IFD_PROTOCOL, 0x020a);
    pub const CURRENT_D = Id.init(.IFD_PROTOCOL, 0x0204);
    pub const CURRENT_EBC_ENCODING = Id.init(.IFD_PROTOCOL, 0x020b);
    pub const CURRENT_F = Id.init(.IFD_PROTOCOL, 0x0203);
    pub const CURRENT_IFSC = Id.init(.IFD_PROTOCOL, 0x0207);
    pub const CURRENT_IFSD = Id.init(.IFD_PROTOCOL, 0x0208);
    pub const CURRENT_IO_STATE = Id.init(.ICC_STATE, 0x0302);
    pub const CURRENT_N = Id.init(.IFD_PROTOCOL, 0x0205);
    pub const CURRENT_PROTOCOL_TYPE = Id.init(.IFD_PROTOCOL, 0x0201);
    pub const CURRENT_W = Id.init(.IFD_PROTOCOL, 0x0206);
    pub const DEFAULT_CLK = Id.init(.PROTOCOL, 0x0121);
    pub const DEFAULT_DATA_RATE = Id.init(.PROTOCOL, 0x0123);
    pub const DEVICE_FRIENDLY_NAME = Id.init(.SYSTEM, 0x0003);
    pub const DEVICE_FRIENDLY_NAME_W = Id.init(.SYSTEM, 0x0005);
    pub const DEVICE_IN_USE = Id.init(.SYSTEM, 0x0002);
    pub const DEVICE_SYSTEM_NAME = Id.init(.SYSTEM, 0x0004);
    pub const DEVICE_SYSTEM_NAME_W = Id.init(.SYSTEM, 0x0006);
    pub const DEVICE_UNIT = Id.init(.SYSTEM, 0x0001);
    pub const ESC_AUTH_REQUEST = Id.init(.VENDOR_DEFINED, 0xa005);
    pub const ESC_CANCEL = Id.init(.VENDOR_DEFINED, 0xa003);
    pub const ESC_RESET = Id.init(.VENDOR_DEFINED, 0xa000);
    pub const EXTENDED_BWT = Id.init(.IFD_PROTOCOL, 0x020c);
    pub const ICC_INTERFACE_STATUS = Id.init(.ICC_STATE, 0x0301);
    pub const ICC_PRESENCE = Id.init(.ICC_STATE, 0x0300);
    pub const ICC_TYPE_PER_ATR = Id.init(.ICC_STATE, 0x0304);
    pub const MAX_CLK = Id.init(.PROTOCOL, 0x0122);
    pub const MAX_DATA_RATE = Id.init(.PROTOCOL, 0x0124);
    pub const MAX_IFSD = Id.init(.PROTOCOL, 0x0125);
    pub const MAX_INPUT = Id.init(.VENDOR_DEFINED, 0xa007);
    pub const POWER_MGMT_SUPPORT = Id.init(.POWER_MGMT, 0x0131);
    pub const SUPPRESS_T1_IFS_REQUEST = Id.init(.SYSTEM, 0x0007);
    pub const SYNC_PROTOCOL_TYPES = Id.init(.PROTOCOL, 0x0126);
    pub const USER_AUTH_INPUT_DEVICE = Id.init(.SECURITY, 0x0142);
    pub const USER_TO_CARD_AUTH_DEVICE = Id.init(.SECURITY, 0x0140);
    pub const VENDOR_IFD_SERIAL_NO = Id.init(.VENDOR_INFO, 0x0103);
    pub const VENDOR_IFD_TYPE = Id.init(.VENDOR_INFO, 0x0101);
    pub const VENDOR_IFD_VERSION = Id.init(.VENDOR_INFO, 0x0102);
    pub const VENDOR_NAME = Id.init(.VENDOR_INFO, 0x0100);
};
