/// Byte tag for a reader-supported feature.
pub const Feature = enum(u8) {
    ABORT = 0x0b,
    CCID_ESC_COMMAND = 0x13,
    EXECUTE_PACE = 0x20,
    GET_KEY_PRESSED = 0x05,
    GET_KEY = 0x10,
    GET_TLV_PROPERTIES = 0x12,
    IFD_DISPLAY_PROPERTIES = 0x11,
    IFD_PIN_PROPERTIES = 0x0a,
    MCT_READER_DIRECT = 0x08,
    MCT_UNIVERSAL = 0x09,
    MODIFY_PIN_DIRECT_APP_ID = 0x0e,
    MODIFY_PIN_DIRECT = 0x07,
    MODIFY_PIN_FINISH = 0x04,
    MODIFY_PIN_START = 0x03,
    SET_SPE_MESSAGE = 0x0c,
    VERIFY_PIN_DIRECT_APP_ID = 0x0d,
    VERIFY_PIN_DIRECT = 0x06,
    VERIFY_PIN_FINISH = 0x02,
    VERIFY_PIN_START = 0x01,
    WRITE_DISPLAY = 0x0f,
    _,

    /// Converts a raw byte tag, from a TLV response, to a `Feature` enum value.
    pub fn init(raw: u8) Feature {
        return @enumFromInt(raw);
    }
};
