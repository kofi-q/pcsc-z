const std = @import("std");

const Apdu = @import("Apdu.zig");
const attributes = @import("pcsc").attributes;
const base = @import("base");
const Feature = @import("features.zig").Feature;
const pcsc = @import("pcsc");
const Tlv = @import("Tlv.zig");

const NameBuf = base.BoundedArray(u8, pcsc.max_reader_name_len);
const Reader = pcsc.ReaderT(*NameBuf);
const ReaderList = std.ArrayListUnmanaged(Reader);

pub fn main() !void {
    var dba = std.heap.DebugAllocator(.{}){};
    defer switch (dba.deinit()) {
        .leak => @panic("Memory leak detected"),
        .ok => {},
    };

    var client = try pcsc.Client.init(.SYSTEM);
    defer client.deinit() catch unreachable;

    if (!try client.isValid()) return fail(
        "Client.isValid() is unexpectedly `false` after init.\n",
        .{},
    );

    var reader_names: [3]NameBuf = undefined;
    var readers = [_]Reader{
        .pnp_query,
        newReader(&reader_names[0]),
        newReader(&reader_names[1]),
        newReader(&reader_names[2]),
    };

    std.debug.print("Listing reader groups:\n", .{});

    var buf_group_names: [pcsc.max_reader_name_len * 2]u8 = undefined;
    var groups = try client.groupNames(&buf_group_names);
    while (groups.next()) |group| std.debug.print("  {s}\n", .{group});

    const group_names_len = try client.groupNamesLen();
    if (group_names_len != groups.inner.buffer.len) return fail(
        \\Mismatched length from Client.groupNamesLen():
        \\Expected: {d}
        \\Received: {d}
        \\
    , .{ groups.inner.buffer.len, group_names_len });

    while (true) {
        var names = try client.readerNames();

        while (names.next()) |name| {
            var is_existing = false;

            for (readers[1..]) |*reader| {
                if (std.mem.eql(u8, name, reader.name())) {
                    reader.status.flags.IGNORE = false;
                    is_existing = true;
                    break;
                }
            }

            if (is_existing) continue;

            for (readers[1..]) |*reader| {
                const is_empty_slot = reader.status.flags.IGNORE;
                if (!is_empty_slot) continue;

                // [ASSERT]: Names are never longer than `NameBuf`'s capacity.
                reader.user_data.?.copyFrom(name) catch unreachable;

                reader.status = .UNAWARE;
                reader.status_new = .UNAWARE;

                break;
            }
        }

        const queries = compactReaders(readers[0..]);
        std.debug.print(
            \\
            \\Connected readers: {d}
            \\
        , .{queries.len - 1});
        for (queries[1..]) |reader| std.debug.print(
            \\  ┗━ {s}
            \\
        , .{reader.name_ptr});

        std.debug.print(
            \\
            \\Waiting for updates...
            \\
        , .{});

        try client.waitForUpdates(queries, .infinite);

        for (queries) |*reader| {
            if (reader.name_ptr == Reader.pnp_query_name) continue;

            defer if (reader.status_new.flags.hasAny(.{
                .UNAVAILABLE = true,
                .UNKNOWN = true,
            })) {
                clearReader(reader);
            } else {
                reader.status = reader.status_new;
            };

            if (!reader.status_new.flags.CHANGED) continue;

            std.debug.print(
                \\
                \\Reader state changed:
                \\  ┗━ {f}
                \\
            , .{reader});

            const status = reader.status_new.flags;
            if (!status.PRESENT or status.MUTE or status.IN_USE) continue;

            std.debug.print(
                \\
                \\{s} - Connecting to card...
            , .{reader.name()});

            const session_client = try pcsc.Client.init(.SYSTEM);
            defer session_client.deinit() catch unreachable;

            const card = try session_client.connect(
                reader.name_ptr,
                .SHARED,
                .ANY,
            );
            defer card.disconnect(.RESET) catch unreachable;

            std.debug.print(
                \\✅
                \\  ┗━ Protocol: {f}
                \\
            , .{card.protocol});

            const card_state = try card.state();
            std.debug.print(
                \\
                \\Card State: {f}
                \\
            , .{card_state});

            const cmd = (try Apdu.cmd.selectFile("\x3f\x00")).bytes();
            std.debug.print(
                \\Test transmission: 0x{x}
                \\
            , .{cmd});
            var buf: [pcsc.max_buffer_len]u8 = undefined;

            const response = try card.transmit(cmd, &buf);
            std.debug.print(
                \\  ┗━ Response: 0x{x}
                \\
            , .{response});

            std.debug.print(
                \\
                \\Test transaction...
                \\
            , .{});
            blk: {
                const txn = try card.transaction();
                defer txn.end(.LEAVE) catch |err| {
                    std.debug.print("[ERROR][{}] Unable to end txn", .{err});
                    std.process.exit(1);
                };

                std.debug.print(
                    \\  ┣━ Control request code: 0x{x}
                    \\
                , .{pcsc.control_codes.FEATURE_REQUEST});

                const ctrl_response = try card.control(
                    pcsc.control_codes.FEATURE_REQUEST,
                    null,
                    &buf,
                );
                std.debug.print(
                    \\  ┃    ┗━ Response: 0x{x}
                    \\
                , .{ctrl_response});

                if (ctrl_response.len == 0) break :blk;

                var tlv_iterator = Tlv.iterator(ctrl_response);
                const tlv = try tlv_iterator.next();

                const feat_code = std.mem.readInt(u32, tlv.value[0..4], .big);
                std.debug.print(
                    \\  ┗━ Control request code: 0x{x}
                    \\
                , .{feat_code});
                const feat_response = try card.control(feat_code, null, &buf);
                std.debug.print(
                    \\       ┗━ Response: 0x{x}
                    \\
                , .{feat_response});
            }

            std.debug.print(
                \\
                \\Card.attribute({})
                \\  ┗━ Response: {!x}
                \\
            , .{
                attributes.ids.ATR_STRING,
                card.attribute(attributes.ids.ATR_STRING, &buf),
            });

            std.debug.print(
                \\
                \\Card.attributeSet({any}, "Foo Bar"):
                \\  ┗━ Response: {!}
                \\
            , .{
                attributes.ids.VENDOR_NAME,
                card.attributeSet(attributes.ids.VENDOR_NAME, "Foo Bar"),
            });
        }
    }
}

fn clearReader(reader: *Reader) void {
    reader.status = .{ .flags = .{ .IGNORE = true } };
    reader.status_new = .UNAWARE;
    reader.user_data.?.clear();
}

fn compactReaders(readers: []Reader) []Reader {
    var count: u8 = 1;
    for (1..readers.len) |i| {
        const src = &readers[i];

        if (src.status.flags.IGNORE) continue;
        defer count += 1;

        if (i == count) continue;

        const dest = &readers[count];
        dest.status = src.status;
        dest.status_new = .UNAWARE;
        dest.user_data.?.copyFrom(src.name()) catch unreachable;

        clearReader(src);
    }

    return readers[0..count];
}

fn fail(comptime fmt: []const u8, args: anytype) error{TestFailed} {
    std.debug.print(fmt, args);
    return error.TestFailed;
}

pub fn newReader(name: *NameBuf) Reader {
    var reader = Reader.empty;

    name.* = .initEmpty();
    reader.user_data = name;
    reader.name_ptr = name.constSliceZ().ptr;
    reader.status = .{ .flags = .{ .IGNORE = true } };

    return reader;
}
