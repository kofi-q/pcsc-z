//! Represents a connection to a reader with an active card.

const std = @import("std");
const builtin = @import("builtin");
const Writer = std.io.Writer;

const base = @import("base");

const attributes = @import("attributes.zig");
const HandleType = @import("types.zig").HandleType;
const Protocol = @import("protocol.zig").Protocol;
const ProtocolInfo = @import("protocol.zig").ProtocolInfo;
const Result = @import("err.zig").Result;
const Uword = @import("types.zig").Uword;

const max_atr_len = @import("constants.zig").max_atr_len;
const max_reader_name_len = @import("constants.zig").max_reader_name_len;

const Card = @This();

/// Handle for the card connection.
handle: Handle,

/// Currently active protocol.
protocol: Protocol,

pub const Handle = packed struct { ref: HandleType };

/// Card disposition action to perform when disconnecting or reconnecting.
pub const Disposition = enum(u8) {
    /// Eject the card - not currently implemented by any known devices.
    EJECT = 3,

    /// Do nothing.
    LEAVE = 0,

    /// Reset the card (warm reset).
    RESET = 1,

    /// Power down the card (cold reset).
    UNPOWER = 2,

    inline fn toSys(self: Disposition) Sys {
        return .{ .disposition = self };
    }

    const Sys = packed struct(Uword) {
        disposition: Disposition,

        /// Potential padding.
        _: std.meta.Int(
            .unsigned,
            @bitSizeOf(Uword) - @bitSizeOf(Disposition),
        ) = 0,
    };
};

/// Card connection mode.
pub const Mode = enum(u8) {
    /// This application will NOT allow others to share the reader.
    EXCLUSIVE = 1,

    /// This application will allow others to share the reader.
    SHARED = 2,

    /// Direct control of the reader, even without a card.
    ///
    /// `DIRECT` can be used for sending control commands to the reader even
    /// if a card is not present in the reader.
    ///
    /// On Windows, the reader is accessed in `EXCLUSIVE` mode - on other
    /// systems, `SHARED` mode is used instead.
    DIRECT = 3,

    /// Converts to the system-specific representation of th value,
    /// for FFI calls.
    pub inline fn toSys(self: Mode) Sys {
        return .{ .mode = self };
    }

    /// System-specific wrapper type for `Card.Mode`.
    ///
    /// Since different PCSC implementations/architectures may have different
    /// status word sizes, this enables the externally exposed `Card.Mode` type
    /// to have a consistent size across platforms.
    pub const Sys = packed struct(Uword) {
        mode: Mode,

        /// Potential padding.
        _: std.meta.Int(.unsigned, @bitSizeOf(Uword) - @bitSizeOf(Mode)) = 0,
    };
};

/// Status of the card connection.
pub const Status = packed struct(u32) {
    /// Card status is unknown.
    UNKNOWN: bool = false,

    /// There is no card in the reader.
    ABSENT: bool = false,

    /// There is a card in the reader, but it has not been moved into
    /// position for use.
    PRESENT: bool = false,

    /// There is a card in the reader in position for use.
    /// The card is not powered.
    SWALLOWED: bool = false,

    /// Power is being provided to the card, but the reader driver is
    /// unaware of the mode of the card.
    POWERED: bool = false,

    /// The card has been reset and is awaiting PTS negotiation.
    NEGOTIABLE: bool = false,

    /// The card has been reset and specific communication protocols
    /// have been established.
    SPECIFIC: bool = false,

    /// Unused padding.
    _: u25 = 0,

    const Impl = base.BitFlagsImpl(@This());
    pub const format = Impl.format;
    pub const hasAll = Impl.hasAll;
    pub const hasAny = Impl.hasAny;
    pub const intersection = Impl.intersection;
    pub const unionWith = Impl.unionWith;
    pub const val = Impl.val;

    /// Unix system-specific wrapper type for `Card.Status`.
    /// Since different PCSC implementations/architectures may have different
    /// status word sizes, this enables the externally exposed `Card.Status`
    /// type to have a consistent size across platforms.
    const Unix = packed struct(Uword) {
        flags: Status,

        /// Potential padding.
        _: std.meta.Int(.unsigned, @bitSizeOf(Uword) -| @bitSizeOf(Status)) = 0,
    };

    /// Windows-specific wrapper type for `Card.Status`.
    ///
    /// The card status is an integer enum value on Windows, in contrast to the
    /// bitflags used in the PCSCLite implementations.
    ///
    /// https://pcsclite.apdu.fr/api/group__API.html#differences
    const Win = @Type(.{ .@"enum" = .{
        .fields = blk: {
            const flags = @typeInfo(Status).@"struct".fields;
            var fields: [flags.len]std.builtin.Type.EnumField = undefined;

            var len = 0;
            for (flags) |flag| {
                if (flag.type != bool) continue;

                fields[len] = .{ .name = flag.name, .value = len };
                len += 1;
            }

            break :blk fields[0..len];
        },
        .tag_type = Uword,
        .decls = &.{},
        .is_exhaustive = true,
    } });

    fn fromWin(value: Win) Status {
        var status = Status{};
        switch (value) {
            inline else => |v| @field(status, @tagName(v)) = true,
        }

        return status;
    }

    test fromWin {
        try std.testing.expectEqualDeep(
            Status{ .UNKNOWN = true },
            Status.fromWin(Win.UNKNOWN),
        );

        try std.testing.expectEqualDeep(
            Status{ .PRESENT = true },
            Status.fromWin(Win.PRESENT),
        );

        try std.testing.expectEqualDeep(
            Status{ .SWALLOWED = true },
            Status.fromWin(Win.SWALLOWED),
        );
    }
};

pub const State = struct {
    /// Current card ATR.
    atr: base.BoundedArray(u8, max_atr_len) = .initEmpty(),

    /// Currently active protocol.
    protocol: Protocol,

    /// Name of the reader containing the card.
    reader_name: base.BoundedArray(u8, max_reader_name_len) = .initEmpty(),

    /// Current card connection status.
    status: Status,

    pub fn format(self: State, writer: *Writer) Writer.Error!void {
        try Writer.print(
            writer,
            Fmt.underline("\n{s}\n") ++
                "  Status: {f}\n" ++
                "  Protocol: {f}\n" ++
                "  ATR: {x}\n",
            .{
                self.reader_name.constSlice(),
                self.status,
                self.protocol,
                self.atr.constSlice(),
            },
        );
    }
};

/// Returns the value of the given attribute. The return value is a slice
/// of `buf_output` with the appropriate length.
///
/// `Card.attributeLen()` can be called first, to determine an appropriate size
/// for `buf_output`.
///
/// https://pcsclite.apdu.fr/api/group__API.html#gaacfec51917255b7a25b94c5104961602
pub fn attribute(self: Card, id: attributes.Id, buf_output: []u8) ![]u8 {
    var len: Uword = @intCast(buf_output.len);
    try SCardGetAttrib(self.handle, id.toSys(), buf_output.ptr, &len)
        .check();

    return buf_output[0..len];
}

/// Returns the size of the buffer needed to store the given attribute.
///
/// This can be called before `Card.attribute()` to ensure enough space is
/// allocated for the response.
///
/// https://pcsclite.apdu.fr/api/group__API.html#gaacfec51917255b7a25b94c5104961602
pub fn attributeLen(self: Card, id: attributes.Id) !usize {
    var len: Uword = 0;
    try SCardGetAttrib(self.handle, id.toSys(), null, &len).check();

    return len;
}

/// Set an attribute of the IFD Handler.
///
/// The list of attributes you can set is dependent on the IFD Handler you
/// are using.
pub fn attributeSet(self: Card, id: attributes.Id, value: []const u8) !void {
    try SCardSetAttrib(self.handle, id.toSys(), value.ptr, @intCast(value.len))
        .check();
}

/// Sends a command directly to the IFD Handler (reader driver) to be
/// processed by the reader.
///
/// This is useful for creating client side reader drivers for functions
/// like PIN pads, biometrics, or other extensions to the normal smart card
/// reader that are not normally handled by PC/SC.
///
/// https://pcsclite.apdu.fr/api/group__API.html#gac3454d4657110fd7f753b2d3d8f4e32f
pub fn control(self: Card, code: u32, cmd: ?[]const u8, out: []u8) ![]const u8 {
    const data = cmd orelse &.{};

    var response_len: Uword = undefined;
    try SCardControl(
        self.handle,
        @intCast(code),
        data.ptr,
        @intCast(data.len),
        out.ptr,
        @intCast(out.len),
        &response_len,
    ).check();

    return out[0..response_len];
}

/// Closes the connection to the card and takes the specified action, if
/// supported.
///
/// https://pcsclite.apdu.fr/api/group__API.html#ga4be198045c73ec0deb79e66c0ca1738a
pub fn disconnect(self: Card, then: Disposition) !void {
    try SCardDisconnect(self.handle, .{ .disposition = then }).check();
}

/// Attempts to re-establish a card connection that has been lost with the
/// previously negotiated communication `Protocol`.
///
/// To provide an explicit protocol for the renewed connection, use
/// `Card.reconnectProtocol()` instead.
///
/// https://pcsclite.apdu.fr/api/group__API.html#gad5d4393ca8c470112ad9468c44ed8940
pub fn reconnect(self: *Card, mode: Card.Mode, disposition: Disposition) !void {
    try self.reconnectProtocol(mode, self.protocol, disposition);
}

/// Attempts to re-establish a card connection that has been lost.
///
/// If reconnecting with the same `Protocol` from the original connection,
/// `Card.reconnect()` may be more convenient.
///
/// https://pcsclite.apdu.fr/api/group__API.html#gad5d4393ca8c470112ad9468c44ed8940
pub fn reconnectProtocol(
    self: *Card,
    mode: Card.Mode,
    protocol: Protocol,
    disposition: Disposition,
) !void {
    var protocol_sys: Protocol.Sys = undefined;
    try SCardReconnect(
        self.handle,
        mode.toSys(),
        protocol.toSys(),
        disposition.toSys(),
        &protocol_sys,
    ).check();

    self.protocol = protocol_sys.val;
}

pub inline fn state(self: Card) !State {
    var atr_len: Uword = max_atr_len;
    var protocol_sys: Protocol.Sys = undefined;
    var reader_name_len: Uword = max_reader_name_len;
    var result = State{ .protocol = undefined, .status = undefined };

    if (comptime builtin.os.tag == .windows) {
        var status_win: Status.Win = undefined;

        try SCardStatus(
            self.handle,
            &result.reader_name.buf,
            &reader_name_len,
            &status_win,
            &protocol_sys,
            &result.atr.buf,
            &atr_len,
        ).check();

        result.status = .fromWin(status_win);
    } else {
        var status_unix: Status.Unix = undefined;

        try SCardStatus(
            self.handle,
            &result.reader_name.buf,
            &reader_name_len,
            &status_unix,
            &protocol_sys,
            &result.atr.buf,
            &atr_len,
        ).check();

        result.status = status_unix.flags;
    }

    // String length from PCSC includes the null terminator byte.
    result.reader_name.len = @intCast(reader_name_len -| 1);

    result.atr.len = @intCast(atr_len);
    result.protocol = protocol_sys.val;

    return result;
}

/// Establishes a temporary exclusive access mode for issuing a series of
/// commands in a transaction.
///
/// You might want to use this when you are selecting a few files and then
/// writing a large file so you can make sure that another application will
/// not change the current file. If another application has a lock on this
/// reader, the function will block until it can continue.
///
/// https://pcsclite.apdu.fr/api/group__API.html#gaddb835dce01a0da1d6ca02d33ee7d861
pub fn transaction(self: Card) !Transaction {
    try SCardBeginTransaction(self.handle).check();

    return .{ .handle = self.handle };
}

/// Represents a temporary `Mode`.`EXCLUSIVE` connection session, which can be
/// started from `Mode`.`SHARED` connection via `Card.transaction()`.
///
/// `Transaction.end()` must be called to end the transaction when done.
pub const Transaction = struct {
    handle: Card.Handle,

    /// Ends a transaction previously started with `Card.transaction()`.
    ///
    /// https://pcsclite.apdu.fr/api/group__API.html#gae8742473b404363e5c587f570d7e2f3b
    pub fn end(self: Transaction, then: Disposition) !void {
        try SCardEndTransaction(self.handle, then.toSys()).check();
    }
};

/// Transmits `input` to the card, using the protocol included in the initial
/// card connection response, and returns a slice of `out` containing the
/// response data.
///
/// If a `Card.Mode`.`DIRECT` connection was established,
/// `Card.transmitProtocol()` can be used instead to specify an explicit
/// protocol, since the current card protocol may be unset or invalid.
///
/// https://pcsclite.apdu.fr/api/group__API.html#ga9a2d77242a271310269065e64633ab99
pub fn transmit(self: Card, input: []const u8, out: []u8) ![]const u8 {
    return self.transmitProtocol(self.protocol, input, out);
}

/// Transmits `input` to the card, and returns a slice of `out` containing
/// the response data.
///
/// To use the same protocol that was negotiated when the card connection was
/// established, `Card.transmit()` can be used instead for a more convenient
/// API.
///
///
/// https://pcsclite.apdu.fr/api/group__API.html#ga9a2d77242a271310269065e64633ab99
pub fn transmitProtocol(
    self: Card,
    protocol: Protocol,
    input: []const u8,
    out: []u8,
) ![]const u8 {
    var protocol_info = ProtocolInfo{ .protocol = protocol.toSys() };
    var len_response: Uword = @intCast(out.len);

    try SCardTransmit(
        self.handle,
        &protocol_info,
        input.ptr,
        @intCast(input.len),
        null,
        out.ptr,
        &len_response,
    ).check();

    return out[0..len_response];
}

pub fn format(self: Card, writer: *Writer) Writer.Error!void {
    try Writer.print(writer, "[{any}] {f}", .{ self.handle, self.protocol });
}

const Fmt = struct {
    pub fn underline(comptime fragment: []const u8) []const u8 {
        return "\x1b[4m" ++ fragment ++ "\x1b[0m";
    }
};

extern fn SCardBeginTransaction(card: Card.Handle) Result;

/// [NOTE] The MacOS symbol for the current version of this API is
/// `SCardControl132`, which is mapped to `SCardControl` here for consistency.
///
/// The legacy (pre-v1.3.2) version of `SCardControl`, if needed, is mapped to
/// `SCardControl112`.
const SCardControl = @extern(*const fn (
    card: Card.Handle,
    code: Uword,
    data_ptr: [*]const u8,
    data_len: Uword,
    out_response_buf_ptr: [*]u8,
    response_buf_len: Uword,
    out_response_len: *Uword,
) callconv(.c) Result, .{
    .name = if (builtin.os.tag == .macos)
        "SCardControl132"
    else
        "SCardControl",
});

const SCardControl112 = if (builtin.os.tag == .macos) @extern(
    *const fn (
        card: Card.Handle,
        pbSendBuffer: [*]const u8,
        cbSendLength: Uword,
        pbRecvBuffer: [*]u8,
        pcbRecvLength: *Uword,
    ) callconv(.c) Result,
    .{
        .name = "SCardControl",
    },
) else @compileError("MacOS-only API");

extern fn SCardDisconnect(card: Card.Handle, then: Card.Disposition.Sys) Result;

extern fn SCardEndTransaction(
    card: Card.Handle,
    then: Card.Disposition.Sys,
) Result;

extern fn SCardGetAttrib(
    card: Card.Handle,
    id: attributes.Id.Sys,
    out_buf_ptr: ?[*]u8,
    in_out_buf_len: *Uword,
) Result;

extern fn SCardReconnect(
    card: Card.Handle,
    mode: Card.Mode.Sys,
    preferred_protocol: Protocol.Sys,
    disposition: Card.Disposition.Sys,
    out_active_protocol: *Protocol.Sys,
) Result;

extern fn SCardSetAttrib(
    card: Card.Handle,
    id: attributes.Id.Sys,
    data_ptr: [*]const u8,
    data_len: Uword,
) Result;

const SCardStatus = switch (builtin.os.tag) {
    .windows => @extern(*const fn (
        card: Card.Handle,
        int_out_reader_name: [*]u8,
        in_out_reader_name_len: *Uword,
        out_status: *Card.Status.Win,
        out_active_protocol: *Protocol.Sys,
        out_atr_ptr: [*]u8,
        out_atr_len: *Uword,
    ) callconv(.c) Result, .{
        .name = "SCardStatusA",
    }),

    else => @extern(*const fn (
        card: Card.Handle,
        int_out_reader_name: [*]u8,
        in_out_reader_name_len: *Uword,
        out_status: *Card.Status.Unix,
        out_active_protocol: *Protocol.Sys,
        out_atr_ptr: [*]u8,
        out_atr_len: *Uword,
    ) callconv(.c) Result, .{
        .name = "SCardStatus",
    }),
};

extern fn SCardTransmit(
    card: Card.Handle,
    protocol_info: *const ProtocolInfo,
    data_ptr: [*]const u8,
    data_len: Uword,
    in_out_protocol_info: ?*ProtocolInfo,
    out_response_ptr: [*]u8,
    in_out_response_len: *Uword,
) Result;
