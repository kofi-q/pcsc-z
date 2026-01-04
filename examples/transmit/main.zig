const std = @import("std");
const pcsc = @import("pcsc");

pub fn main() !void {
    const client = try pcsc.Client.init(.SYSTEM);
    defer client.deinit() catch |err| std.debug.print(
        "Unable to release client: {t}",
        .{err},
    );

    // Detect connected card readers:
    var readers = [_]pcsc.Reader{.pnp_query};
    while (true) {
        var reader_names = try client.readerNames();
        if (reader_names.next()) |name| {
            std.debug.print("Reader detected: {s}\n", .{name});
            readers[0].name_ptr = name.ptr;
            break;
        }

        std.debug.print("Connect a reader to continue...\n", .{});

        try client.waitForUpdates(&readers, .infinite);
    }

    // Detect inserted cards:
    while (true) {
        try client.waitForUpdates(&readers, .infinite);

        readers[0].status = readers[0].status_new;

        if (readers[0].status.flags.IN_USE) {
            std.debug.print("Card in use. Waiting...\n", .{});
            continue;
        }

        if (readers[0].status.flags.MUTE) {
            std.debug.print("Card not readable. Check orientation...\n", .{});
            continue;
        }

        if (readers[0].status.flags.PRESENT) break;

        std.debug.print("Insert a card to continue...\n", .{});
    }

    std.debug.print("Connecting to card...\n", .{});

    // Connect to an inserted card:
    const card = try client.connect(readers[0].name_ptr, .SHARED, .ANY);
    defer card.disconnect(.RESET) catch |err| std.debug.print(
        "Unable to disconnect card: {t}\n",
        .{err},
    );

    std.debug.print("Card connected with protocol {f}\n", .{card.protocol});

    const command = [_]u8{ 0xca, 0xfe, 0xf0, 0x0d };

    std.debug.print("Transmitting APDU: 0x{x}\n", .{command});

    // Transmit/receive data to/from a card:
    var buf_response: [pcsc.max_buffer_len]u8 = undefined;
    const response = try card.transmit(&command, &buf_response);

    std.debug.print("Received response: 0x{x}\n", .{response});
}
