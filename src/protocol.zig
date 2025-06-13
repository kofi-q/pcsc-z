const base = @import("base");
const builtin = @import("builtin");
const std = @import("std");

const Uword = @import("types.zig").Uword;

/// Card communication protocol type.
pub const Protocol = enum(u32) {
    /// No protocol set.
    UNSET = 0,

    /// Used when a no specific protocol is required. May also be returned from
    /// a connection request if no protocol has been negotiated. (e.g. on MacOS,
    /// `Protocol.ANY` is returned from `Client.connect()` when using
    /// `Card.Mode`.`DIRECT` with `Protocol.ANY`.)
    ANY = (ProtocolFlags{ .T0 = true, .T1 = true }).val(),

    /// The T=0 protocol.
    T0 = (ProtocolFlags{ .T0 = true }).val(),

    /// The T=1 protocol.
    T1 = (ProtocolFlags{ .T1 = true }).val(),

    /// Used with memory type cards.
    RAW = ProtocolFlags.RAW.val(),

    /// The T=15 protocol (might not be supported on all systems).
    T15 = (ProtocolFlags{ .T15 = true }).val(),

    pub fn format(
        self: Protocol,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: std.io.AnyWriter,
    ) !void {
        try writer.writeAll(switch (self) {
            .RAW => "RAW",
            .ANY => "ANY( T=0, T=1 )",
            .T0 => "T=0",
            .T1 => "T=1",
            .T15 => "T=15",
            .UNSET => "<UNSET>",
        });
    }

    /// Converts to a value compatible with the current PCSC implementation.
    pub inline fn toSys(self: Protocol) Sys {
        return .{ .val = self };
    }

    /// System-specific wrapper type for `Protocol`.
    ///
    /// Since different PCSC implementations/architectures may have different
    /// status word sizes, this enables the externally exposed `Protocol` type
    /// to have a consistent size across platforms.
    pub const Sys = packed struct(Uword) {
        val: Protocol,

        /// Potential padding.
        _: std.meta.Int(
            .unsigned,
            @bitSizeOf(Uword) -| @bitSizeOf(Protocol),
        ) = 0,
    };
};

/// Card communication protocol option bitflags, used for specifying preferred
/// protocols when connecting or reconnecting to an inserted card.
const ProtocolFlags = packed struct(u32) {
    /// The T=0 protocol.
    T0: bool = false,

    /// The T=1 protocol.
    T1: bool = false,

    /// Used with memory type cards.
    ///
    /// > #### ⚠ NOTE
    /// > For portability, use `RAW`/`setRaw` instead of initializing/setting
    /// this directly, and `hasRaw` for checking the `RAW` flag.
    RAW_UNIX: bool = false,

    /// The T=15 protocol (might be supported on all systems).
    T15: bool = false,

    /// Unused padding.
    _4: u12 = 0,

    /// Used with memory type cards.
    ///
    /// > #### ⚠ NOTE
    /// > For portability, use `RAW`/`setRaw` instead of initializing/setting
    /// this directly, and `hasRaw` for checking the `RAW` flag.
    RAW_WIN32: bool = false,

    /// Unused padding.
    _: u15 = 0,

    /// For cases where no specific protocol is required.
    pub const ANY = ProtocolFlags{ .T0 = true, .T1 = true };

    /// Used with memory type cards.
    pub const RAW: ProtocolFlags = switch (builtin.os.tag) {
        .windows => .{ .RAW_WIN32 = true },
        else => .{ .RAW_UNIX = true },
    };

    const Impl = base.BitFlagsImpl(@This());
    pub const format = Impl.format;
    pub const hasAll = Impl.hasAll;
    pub const hasAny = Impl.hasAny;
    pub const intersection = Impl.intersection;
    pub const unionWith = Impl.unionWith;
    pub const val = Impl.val;

    pub fn fromEnum(protocol: Protocol) ProtocolFlags {
        return @bitCast(@intFromEnum(protocol));
    }

    /// `true` iff the system-specific `RAW` flag is set.
    pub fn hasRaw(self: ProtocolFlags) bool {
        return self.hasAll(RAW);
    }

    /// Sets the appropriate system-specific `RAW` flag.
    pub fn setRaw(self: *ProtocolFlags) void {
        self.* = self.unionWith(RAW);
    }

    /// Converts to a value compatible with the current PCSC implementation.
    pub inline fn toSys(self: ProtocolFlags) Sys {
        return .{ .flags = self };
    }

    /// System-specific wrapper type for `ProtocolFlags`.
    ///
    /// Since different PCSC implementations/architectures may have different
    /// status word sizes, this enables the externally exposed `ProtocolFlags`
    /// type to have a consistent size across platforms.
    pub const Sys = packed struct(Uword) {
        flags: ProtocolFlags,

        /// Potential padding.
        _: std.meta.Int(
            .unsigned,
            @bitSizeOf(Uword) -| @bitSizeOf(ProtocolFlags),
        ) = 0,

        pub fn fromEnum(protocol: Protocol) ProtocolFlags.Sys {
            return .{ .flags = @bitCast(@intFromEnum(protocol)) };
        }
    };
};

pub const ProtocolInfo = extern struct {
    protocol: Protocol.Sys,
    length: Uword = @sizeOf(ProtocolInfo),
};
