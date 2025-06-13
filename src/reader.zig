const std = @import("std");
const builtin = @import("builtin");

const base = @import("base");

const Uword = @import("types.zig").Uword;

const atr_buffer_len = @import("constants.zig").atr_buffer_len;
const max_atr_len = @import("constants.zig").max_atr_len;

/// State info for a card reader.
///
/// Doubles as a reader status query for use with `Client.waitForUpdates()`.
pub const Reader = ReaderT(*anyopaque);

/// State info for a card reader.
///
/// Doubles as a reader status query for use with `Client.waitForUpdates()`.
pub fn ReaderT(
    /// Type for the `user_data` field - if not needed, the
    /// `Reader` type alias may be more convenient to use.
    comptime UserData: type,
) type {
    switch (@typeInfo(UserData)) {
        .pointer => |ptr_info| switch (ptr_info.size) {
            .slice => @compileError(
                "Expected pointer type, found " ++ @typeName(UserData),
            ),
            else => {},
        },
        else => @compileError(
            "Expected pointer type, found " ++ @typeName(UserData),
        ),
    }

    return extern struct {
        const Self = @This();
        const is_packed = (builtin.os.tag == .macos);

        /// Platform-specific field alignment.
        ///
        /// MacOS API requires a non-padded, 1-byte-aligned struct.
        fn aln(comptime T: type) u29 {
            return if (is_packed) 1 else @alignOf(T);
        }

        /// Pointer to the reader name. When used with `Client.waitForUpdates()`,
        /// set this to a name returned from `Client.readerNames()` (or a known
        /// reader on the system) to get reader-specific state change updates.
        name_ptr: [*:0]const u8 align(aln([*:0]const u8)),

        /// User-defined data.
        user_data: ?UserData align(aln(?*anyopaque)),

        /// Current status of reader.
        status: Status.Sys align(aln(Status.Sys)),

        /// Reader status after the last state change.
        status_new: Status.Sys align(aln(Status.Sys)),

        /// Length of the value in the `atr_buffer`.
        atr_len: Uword align(aln(Uword)),

        /// Buffer for the ATR (Answer To Reset) value of the inserted card,
        /// if any.
        atr_buffer: [atr_buffer_len]u8 align(aln([max_atr_len]u8)),

        pub const empty = Self{
            .atr_buffer = undefined,
            .atr_len = max_atr_len,
            .name_ptr = "",
            .status = .UNAWARE,
            .status_new = .UNAWARE,
            .user_data = null,
        };

        /// Initial state for the special-case reader state for detecting reader
        /// add/remove events via `Client.waitForUpdates()`.
        ///
        /// ## Example
        /// ```zig
        /// const std = @import("std");
        /// const pcsc = @import("pcsc");
        ///
        /// pub fn main() !void {
        ///     const client = try pcsc.Client.init(.SYSTEM);
        ///     defer client.deinit() catch |err| std.log.err(
        ///         "Unable to release client: {}",
        ///         .{err},
        ///     );
        ///
        ///     while (true) {
        ///         var reader_names = try client.readerNames();
        ///         if (reader_names.next()) |name| {
        ///             std.log.info("Reader detected: {s}\n", .{name});
        ///         }
        ///
        ///         std.log.info("Monitoring for reader state changes...\n", .{});
        ///
        ///         try client.waitForUpdates(&[_]pcsc.Reader{.pnp_query}, .infinite);
        ///     }
        /// }
        /// ```
        pub const pnp_query = Self{
            .atr_buffer = undefined,
            .atr_len = 0,
            .name_ptr = pnp_query_name,
            .status = .UNAWARE,
            .status_new = .UNAWARE,
            .user_data = null,
        };

        /// Special-case reader name for detecting reader add/remove events.
        /// See `ReaderT.pnp_query`.
        ///
        /// https://pcsclite.apdu.fr/api/group__API.html#ga33247d5d1257d59e55647c3bb717db24
        pub const pnp_query_name = "\\\\?PnP?\\Notification";

        pub const Status = StatusFlags;

        /// The ATR (Answer To Reset) value of the inserted card, if any.
        pub fn atr(self: Self) []const u8 {
            return self.atr_buffer[0..self.atr_len];
        }

        /// The device name of the reader.
        pub fn name(self: Self) [:0]const u8 {
            return std.mem.span(self.name_ptr);
        }

        pub fn format(
            self: Self,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: std.io.AnyWriter,
        ) !void {
            const name_str = self.name();
            if (name_str.len > 0) {
                try std.fmt.format(writer, "{s}: ", .{name_str});
            }

            var cur_status = self.status.flags;
            cur_status.CHANGED = false;
            try std.fmt.format(writer, "{s}", .{cur_status});

            if (self.status_new.flags.CHANGED) {
                var next_status = self.status_new.flags;
                next_status.CHANGED = false;

                if (cur_status != next_status) {
                    try std.fmt.format(writer, " -> {s}", .{next_status});
                }
            }
        }
    };
}

/// Reader status flags.
const StatusFlags = packed struct(u32) {
    /// The reader is currently not being tracked (likely disconnected from the
    /// system, if running on Windows).
    IGNORE: bool = false,

    /// There has been a change in the reader state.
    CHANGED: bool = false,

    /// The reader state is currently unknown (likely disconnected from the
    /// system).
    UNKNOWN: bool = false,

    UNAVAILABLE: bool = false,

    /// There is no card present in the reader.
    EMPTY: bool = false,

    /// A card has been inserted into (or is in contact with) the reader.
    PRESENT: bool = false,

    ATR_MATCH: bool = false,

    /// A card is present in the reader and has a `Card.Mode`.`EXCLUSIVE`
    /// connection with either the current process or another running process.
    EXCLUSIVE: bool = false,

    /// A card is present in the reader and has a `Card.Mode`.`SHARED`
    /// connection with either the current process or another running process.
    IN_USE: bool = false,

    /// A card is present in the reader, but is unresponsive (likely inserted
    /// with an invalid orientation).
    MUTE: bool = false,

    /// The card is not powered.
    UNPOWERED: bool = false,

    /// Unused padding.
    _: u21 = 0,

    /// Empty status to set when querying for an initial status for a reader.
    pub const UNAWARE = StatusFlags{};

    const Impl = base.BitFlagsImpl(@This());
    pub const format = Impl.format;
    pub const hasAll = Impl.hasAll;
    pub const hasAny = Impl.hasAny;
    pub const intersection = Impl.intersection;
    pub const unionWith = Impl.unionWith;
    pub const val = Impl.val;

    /// System-specific wrapper type for `StatusFlags`.
    ///
    /// Since different PCSC implementations/architectures may have different
    /// status word sizes, this enables the externally exposed `StatusFlags`
    /// type to have a consistent size across platforms.
    pub const Sys = packed struct(Uword) {
        flags: StatusFlags = .{},

        /// Potential padding.
        _: std.meta.Int(
            .unsigned,
            @bitSizeOf(Uword) -| @bitSizeOf(StatusFlags),
        ) = 0,

        /// Empty status to set when querying for an initial status for a reader.
        pub const UNAWARE = StatusFlags.Sys{};
    };
};
