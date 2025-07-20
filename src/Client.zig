//! API for establishing a client connection context and communicating with the
//! PCSC server.
//!
//! A `Client` can be used to monitor for reader state and presence updates, via
//! `Client.waitForUpdates()`. When used in this way, it's recommended that a
//! separate `Client` instance be initialized when connection to a card.
//! Likewise, a separate `Client` context for each additional card connection is
//! recommended.
//!
//! ## Example
//! ```zig
//! const std = @import("std");
//! const pcsc = @import("pcsc");
//!
//! pub fn main() !void {
//!     const client = try pcsc.Client.init(.SYSTEM);
//!     defer client.deinit() catch |err| std.debug.print(
//!         "Unable to release client: {}",
//!         .{err},
//!     );
//!
//!     // Detect connected card readers:
//!     var readers = [_]pcsc.Reader{.init};
//!     while (true) {
//!         var reader_names = try client.readerNames();
//!         if (reader_names.next()) |name| {
//!             std.debug.print("Reader detected: {s}\n", .{name});
//!             readers[0].name_ptr = name.ptr;
//!             break;
//!         }
//!
//!         std.debug.print("Connect a reader to continue...\n", .{});
//!
//!         try client.waitForUpdates(&[_]pcsc.Reader{.pnp_query}, .infinite);
//!     }
//!
//!     // Detect inserted cards:
//!     while (true) {
//!         try client.waitForUpdates(&readers, .infinite);
//!
//!         readers[0].status = readers[0].status_new;
//!         if (readers[0].status.flags.PRESENT) break;
//!
//!         std.debug.print("Insert a card to continue...\n", .{});
//!     }
//!
//!     std.debug.print("Connecting to card...\n", .{});
//!
//!     // Connect to an inserted card:
//!     const card = try client.connect(readers[0].name_ptr, .SHARED, .ANY);
//!     defer card.disconnect(.RESET) catch |err| std.debug.print(
//!         "Unable to disconnect card: {}\n",
//!         .{err},
//!     );
//!
//!     std.debug.print("Card connected: {}\n", .{card});
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");

const Card = @import("Card.zig");
const Err = @import("err.zig").Err;
const HandleType = @import("types.zig").HandleType;
const max_readers = @import("root.zig").max_readers;
const max_reader_name_len = @import("root.zig").max_reader_name_len;
const NameIterator = @import("types.zig").NameIterator;
const Protocol = @import("protocol.zig").Protocol;
const Reader = @import("reader.zig").Reader;
const Result = @import("err.zig").Result;
const Uword = @import("types.zig").Uword;

const Client = @This();

/// Server-assigned handle for the client connection context.
handle: Handle,

const Handle = packed struct { ref: HandleType };

/// Scope for a PCSC connection.
pub const Scope = enum(u8) {
    /// Services on the local machine.
    SYSTEM = 2,

    /// Currently Windows-only
    USER = 0,

    fn toSys(self: Scope) Sys {
        return .{ .scope = self };
    }

    /// Wrapper type for the system-specific PCSC implementation.
    const Sys = packed struct(Uword) {
        scope: Scope,

        /// Potential padding.
        _: std.meta.Int(.unsigned, @bitSizeOf(Uword) - @bitSizeOf(Scope)) = 0,
    };
};

/// Establishes a client connection context with the given `scope`.
pub fn init(scope: Scope) !Client {
    var handle: Client.Handle = undefined;
    try SCardEstablishContext(scope.toSys(), null, null, &handle).check();

    return .{ .handle = handle };
}

/// Cancels any in-flight status change requests and releases the client
/// context, rendering this client unusable.
pub fn deinit(self: Client) !void {
    try SCardCancel(self.handle).check();
    try SCardReleaseContext(self.handle).check();
}

/// Cancels any in-flight status change requests.
pub fn cancel(self: Client) !void {
    try SCardCancel(self.handle).check();
}

/// Establishes a connection to an inserted card.
pub fn connect(
    self: Client,
    reader_name: [*:0]const u8,
    mode: Card.Mode,
    protocol: Protocol,
) !Card {
    var card: Card = undefined;
    var protocol_sys: Protocol.Sys = undefined;

    try SCardConnect(
        self.handle,
        reader_name,
        mode.toSys(),
        protocol.toSys(),
        &card.handle,
        &protocol_sys,
    ).check();

    card.protocol = protocol_sys.val;

    return card;
}

/// `true` iff the current client connection context is active and valid.
///
/// https://pcsclite.apdu.fr/api/group__API.html#ga722eb66bcc44d391f700ff9065cc080b
pub fn isValid(self: Client) !bool {
    SCardIsValidContext(self.handle).check() catch |err| switch (err) {
        Err.InvalidHandle => return false,
        else => return err,
    };

    return true;
}

/// Returns an iterator over the names of all available reader groups,
/// backed by the given buffer. The required buffer size can be determined by
/// calling `Client.groupNamesLen()` first.
///
/// Caller retains ownership of `buf`.
///
/// ## Example
/// ```zig
/// const pcsc = @import("pcsc");
///
/// pub fn main() !void {
///    var client = try pcsc.Client.init(.SYSTEM);
///    defer client.deinit() catch unreachable;
///
///    var names = try client.groupNames();
///    while (names.next()) |name| {
///        std.debug.print("Reader group: {s}\n", name);
///    }
/// }
/// ```
pub fn groupNames(self: Client, buf: []u8) !NameIterator {
    var names_len: Uword = @intCast(buf.len);
    try SCardListReaderGroups(self.handle, buf.ptr, &names_len).check();

    return .init(buf[0..names_len]);
}

/// The buffer length needed to store the concatenated reader names string
/// returned from `Client.groupNames()`.
pub fn groupNamesLen(self: Client) !usize {
    var names_len: Uword = undefined;
    try SCardListReaderGroups(self.handle, null, &names_len).check();

    return names_len;
}

/// Returns an iterator over the names of all available readers.
///
/// The returned iterator is valid for the lifetime of the calling function
/// scope.
///
/// ## Example
/// ```zig
/// const pcsc = @import("pcsc");
///
/// pub fn main() !void {
///    var client = try pcsc.Client.init(.SYSTEM);
///    defer client.deinit() catch unreachable;
///
///    var names = try client.readerNames();
///    while (names.next()) |name| {
///        std.debug.print("Reader detected: {s}\n", name);
///    }
/// }
///
/// ```
pub inline fn readerNames(self: Client) !NameIterator {
    var buf: [max_readers * max_reader_name_len]u8 = undefined;
    return self.readerNamesBuf(&buf);
}

/// Returns an iterator over the names of all available readers, backed by
/// the given buffer.
///
/// `max_reader_name_len` can be used in determining an appropriate buffer
/// size, along a known maximum number of readers for the target machine.
/// The number of supported concurrent readers is limited to `max_readers`.
///
/// If needed, the required buffer size can be obtained by calling
/// `readerNamesLen` first.
pub fn readerNamesBuf(self: Client, buf: []u8) !NameIterator {
    var len: Uword = @intCast(buf.len);

    SCardListReaders(self.handle, null, buf.ptr, &len).check() catch |err| {
        return switch (err) {
            Err.NoReadersAvailable => .init(""),
            else => err,
        };
    };

    return .init(buf[0..len]);
}

/// The buffer length needed to store the concatenated reader names string
/// returned from `Client.readerNames()`.
pub fn readerNamesLen(self: Client) !usize {
    var len: Uword = undefined;

    SCardListReaders(self.handle, null, null, &len).check() catch |err| {
        return switch (err) {
            Err.NoReadersAvailable => 0,
            else => err,
        };
    };

    return len;
}

/// Timeout value for `Client.waitForUpdates()` calls.
pub const Timeout = struct {
    ms: u32,

    /// Causes `waitForStatusUpdate` queries to block indefinitely until a
    /// reader or card status change is detected.
    pub const infinite: Timeout = .{ .ms = 0xffff_ffff };

    fn toSys(self: Timeout) Uword {
        return self.ms;
    }
};

/// Blocks until a status change is detected for any of the given `readers`,
/// compared to the reference status(es) specified in the `status` field.
///
/// The `status_new` field of the relevant reader is updated in place with
/// the new status.
///
/// `readers` must be able to coerce to a `[]const` `Reader` slice.
///
/// https://pcsclite.apdu.fr/api/group__API.html#ga33247d5d1257d59e55647c3bb717db24
pub fn waitForUpdates(self: Client, readers: anytype, timeout: Timeout) !void {
    const readers_resolved: []const Reader = @ptrCast(readers);

    try SCardGetStatusChange(
        self.handle,
        timeout.toSys(),
        readers_resolved.ptr,
        @intCast(readers_resolved.len),
    ).check();
}

extern fn SCardCancel(client: Client.Handle) Result;

const SCardConnect = @extern(*const fn (
    client: Client.Handle,
    reader_name: [*:0]const u8,
    mode: Card.Mode.Sys,
    preferred_protocol: Protocol.Sys,
    out_card: *Card.Handle,
    out_active_protocol: *Protocol.Sys,
) callconv(.c) Result, .{
    .name = if (builtin.os.tag == .windows)
        "SCardConnectA"
    else
        "SCardConnect",
});

extern fn SCardEstablishContext(
    scope: Client.Scope.Sys,
    _reserved: ?*const anyopaque,
    _reserved: ?*const anyopaque,
    out_client: *Client.Handle,
) Result;

const SCardGetStatusChange = @extern(*const fn (
    client: Client.Handle,
    timeout: Uword,
    in_out_readers_ptr: [*]const Reader,
    readers_len: Uword,
) callconv(.c) Result, .{
    .name = if (builtin.os.tag == .windows)
        "SCardGetStatusChangeA"
    else
        "SCardGetStatusChange",
});

extern fn SCardIsValidContext(client: Client.Handle) Result;

const SCardListReaderGroups = @extern(*const fn (
    client: Client.Handle,
    out_group_names_combined: ?[*]u8,
    in_out_group_names_len: *Uword,
) callconv(.c) Result, .{
    .name = if (builtin.os.tag == .windows)
        "SCardListReaderGroupsA"
    else
        "SCardListReaderGroups",
});

const SCardListReaders = @extern(*const fn (
    client: Client.Handle,
    /// #### ⚠ NOTE
    /// Used only on Windows; ignored everywhere else.
    group_name: ?[*:0]const u8,
    out_reader_names_combined: ?[*]u8,
    in_out_reader_names_len: *Uword,
) callconv(.c) Result, .{
    .name = if (builtin.os.tag == .windows)
        "SCardListReadersA"
    else
        "SCardListReaders",
});

extern fn SCardReleaseContext(client: Client.Handle) Result;
