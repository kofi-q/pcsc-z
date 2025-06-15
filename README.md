# pcsc-z

` › Zig PC/SC API bindings for smart card access on Linux / MacOS / Win32 `

[Docs ↗](https://kofi-q.github.io/pcsc-z) | | [Prerequisites](#prerequisites) | | [Installation](#installation) | | [Usage](#usage)

## Prerequisites

### Linux - Alpine

Required packages:

- `ccid`
- `pcsc-lite`
- `pcsc-lite-libs`

```sh
doas apk add ccid pcsc-lite pcsc-lite-libs
```
To run the server daemon:
```sh
doas rc-service pcscd start
```

### Linux - Debian/Ubuntu/etc

Required packages:

- `libpcsclite1`
- `pcscd`

```sh
sudo apt install libpcsclite1 pcscd
```
To run the server daemon:
```sh
sudo systemctl start pcscd
```

### MacOS/Windows

**`N/A` ::** MacOS and Windows come pre-installed with smart card support. No additional installation needed.

<br />

## Installation

```sh
zig fetch --save=pcsc "git+https://github.com/kofi-q/pcsc-z.git"
```

## Usage

```zig
const std = @import("std");
const pcsc = @import("pcsc");

pub fn main() !void {
    const client = try pcsc.Client.init(.SYSTEM);
    defer client.deinit() catch |err| std.debug.print(
        "Unable to release client: {}",
        .{err},
    );

    // Detect connected card readers:
    var readers = [_]pcsc.Reader{.empty};
    while (true) {
        var reader_names = try client.readerNames();
        if (reader_names.next()) |name| {
            std.debug.print("Reader detected: {s}\n", .{name});
            readers[0].name_ptr = name.ptr;
            break;
        }

        std.debug.print("Connect a reader to continue...\n", .{});

        try client.waitForUpdates(&[_]pcsc.Reader{.pnp_query}, .infinite);
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
        "Unable to disconnect card: {}\n",
        .{err},
    );

    std.debug.print("Card connected with protocol {}\n", .{card.protocol});

    const command = [_]u8{ 0xca, 0xfe, 0xf0, 0x0d };

    std.debug.print("Transmitting APDU: {x:0>2}\n", .{command});

    // Transmit/receive data to/from a card:
    var buf_response: [pcsc.max_buffer_len]u8 = undefined;
    const response = try card.transmit(&command, &buf_response);

    std.debug.print("Received response: {x:0>2}\n", .{response});
}
```
```console
$ zig build example:transmit
Connect a reader to continue...
Reader detected: Gemalto USB SmartCard Reader
Insert a card to continue...
Connecting to card...
Card connected with protocol T=1
Transmitting APDU: { ca, fe, f0, 0d }
Received response: { 68, 81 }
```

> [!TIP]
>
> See the [E2E test application](./e2e/main.zig) for more involved usage.

## Developing

### Prerequisites

#### Zig

v0.14.1 required - see [`.zigversion`](.zigversion) for latest compatible version.

#### Linux

See [Linux](#linux) section above for a list of runtime prerequisites.

Other relevant development libraries (e.g. `libpcsclite-dev` on Debian-based distros) are included in this repo to ease cross-compilation. No additional installation needed.

#### MacOS

**`N/A` ::** Required MacOS Framework `.tbd`s are included here. No additional installation needed.

**NOTE:** To update the `.tbd`s, however, an XCode installation is needed.

#### Windows

**`N/A` ::** Required DLLs are shipped with the Zig compiler. No additional installation needed.

## License

[MIT](./LICENSE)
