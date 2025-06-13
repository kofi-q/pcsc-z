const builtin = @import("builtin");

/// Maximum length of a card ATR.
///
/// https://pcsclite.apdu.fr/api/src_2PCSC_2pcsclite_8h.html#a7ac7915ff6f9baefa66886c98bdbb91e
pub const max_atr_len = 33;

/// Byte size for ATR buffers.
///
/// Padded on Windows with an an extra 3 bytes beyond `max_atr_len`.
///
/// https://pcsclite.apdu.fr/api/src_2PCSC_2pcsclite_8h.html#a24f9ac3acf22aa4a70fe7ba1a1546bae
pub const atr_buffer_len = switch (builtin.os.tag) {
    .windows => 36,
    else => 33,
};

/// Maximum transmit/receive buffer size needed for standard payloads.
///
/// https://pcsclite.apdu.fr/api/src_2PCSC_2pcsclite_8h.html#ad4d796b98c583d49e83adabd74a63bf6
pub const max_buffer_len = 264;

/// Maximum transmit/receive buffer size needed for extended payloads.
///
/// https://pcsclite.apdu.fr/api/src_2PCSC_2pcsclite_8h.html#ae4382a1a267f7d7f06c97ebef74d49e6
pub const max_buffer_len_extended = sum: {
    const apdu_header = 4; // .{ CLA, INS, P1, P2 }
    const payload_len = 3; // Lc
    const payload = 64 * 1024;
    const response_len = 3; // Le
    const status_word = 2; // .{ SW1, SW2 }

    break :sum apdu_header + payload_len + payload + response_len + status_word;
};

/// Maximum byte length for reader names.
///
/// https://pcsclite.apdu.fr/api/src_2PCSC_2pcsclite_8h.html#ae4382a1a267f7d7f06c97ebef74d49e6
pub const max_reader_name_len = switch (builtin.os.tag) {
    .macos => 52,
    .windows => 128, // Unsure; falling back to PCSCLite definition.
    else => 128,
};

/// Maximum number of readers supported by the PCSC implementation.
///
/// https://pcsclite.apdu.fr/api/src_2PCSC_2pcsclite_8h.html#af750e6e22c809de2b523c17e4a092036
pub const max_readers = switch (builtin.os.tag) {
    .windows => 10,
    else => 16,
};
