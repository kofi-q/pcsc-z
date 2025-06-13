const std = @import("std");
const builtin = @import("builtin");

pub const Uword = @import("types.zig").Uword;

/// Error translations of PCSC API response codes (see `Result`).
pub const Err = error{
    /// [Win32] Received error code 0x5 (ERROR_ACCESS_DENIED).
    AccessDenied,

    /// The device does not recognize the command.
    BadCommand,

    /// There was an error trying to set the smart card file object pointer.
    BadSeek,

    /// The action was cancelled by an SCardCancel request.
    Cancelled,

    /// The user pressed "Cancel" on a Smart Card Selection Dialog.
    CancelledByUser,

    /// The system could not dispose of the media in the requested manner.
    CantDispose,

    /// No PIN was presented to the smart card.
    CardNotAuthenticated,

    /// The smart card does not meet minimal requirements for support.
    CardUnsupported,

    /// The requested certificate could not be obtained.
    CertificateUnavailable,

    /// The card cannot be accessed because the maximum number of PIN entry
    /// attempts has been reached.
    ChvBlocked,

    /// A communications error with the smart card has been detected.
    /// Retry the operation.
    CommDataLost,

    /// An internal communications error has been detected.
    CommError,

    /// The identified directory does not exist in the smart card.
    DirNotFound,

    /// The reader driver did not produce a unique reader name.
    DuplicateReader,

    /// The end of the smart card file has been reached.
    Eof,

    /// The identified file does not exist in the smart card.
    FileNotFound,

    /// The requested order of object creation is not supported.
    IccCreateOrder,

    /// No primary provider can be found for the smart card.
    IccInstallation,

    /// The data buffer to receive returned data is too small for the returned
    /// data.
    InsufficientBuffer,

    /// An internal consistency check failed.
    InternalError,

    /// An ATR obtained from the registry is not a valid ATR string.
    InvalidAtr,

    /// The supplied PIN is incorrect.
    InvalidChv,

    /// The supplied handle was invalid.
    InvalidHandle,

    /// One or more of the supplied parameters could not be properly
    /// interpreted.
    InvalidParameter,

    /// Registry startup information is missing or invalid.
    InvalidTarget,

    /// One or more of the supplied parameters values could not be properly
    /// interpreted.
    InvalidValue,

    /// Access is denied to this file.
    NoAccess,

    /// The supplied path does not represent a smart card directory.
    NoDir,

    /// The supplied path does not represent a smart card file.
    NoFile,

    /// The requested key container does not exist on the smart card.
    NoKeyContainer,

    /// Not enough memory available to complete this command.
    NoMemory,

    /// Cannot find a smart card reader.
    NoReadersAvailable,

    /// The Smart card resource manager is not running.
    NoService,

    /// The operation requires a Smart Card, but no Smart Card is currently in
    /// the device.
    NoSmartCard,

    /// The requested certificate does not exist.
    NoSuchCertificate,

    /// The reader or smart card is not ready to accept commands.
    NotReady,

    /// An attempt was made to end a non-existent transaction.
    NotTransacted,

    /// The PCI Receive buffer was too small.
    PciTooSmall,

    /// The requested protocols are incompatible with the protocol currently in
    /// use with the smart card.
    ProtoMismatch,

    /// The specified reader is not currently available for use.
    ReaderUnavailable,

    /// The reader driver does not meet minimal requirements for support.
    ReaderUnsupported,

    /// The smart card has been removed, so further communication is not
    /// possible.
    RemovedCard,

    /// The smart card has been reset, so any shared state information is
    /// invalid.
    ResetCard,

    /// Access was denied because of a security violation.
    SecurityViolation,

    /// The Smart Card Resource Manager is too busy to complete this operation.
    ServerTooBusy,

    /// The Smart card resource manager has shut down.
    ServiceStopped,

    /// The smart card cannot be accessed because of other connections
    /// outstanding.
    SharingViolation,

    /// The operation has been aborted to allow the server application to exit.
    Shutdown,

    /// The action was cancelled by the system, presumably to log off or shut
    /// down.
    SystemCancelled,

    /// The user-specified timeout value has expired.
    Timeout,

    /// Received an error code not yet covered by these bindings.
    UnboundError,

    /// The specified smart card name is not recognized.
    UnknownCard,

    /// An internal error has been detected, but the source is unknown.
    UnknownError,

    /// The specified reader name is not recognized.
    UnknownReader,

    /// An unrecognized error code was returned from a layered component.
    UnknownResMng,

    /// Power has been removed from the smart card, so that further
    /// communication is not possible.
    UnpoweredCard,

    /// The smart card is not responding to a reset.
    UnresponsiveCard,

    /// The reader cannot communicate with the card, due to ATR string
    /// configuration conflicts.
    UnsupportedCard,

    /// This smart card does not support the requested feature.
    UnsupportedFeature,

    /// An internal consistency timer has expired.
    WaitedTooLong,

    /// The smart card does not have enough memory to store the information.
    WriteTooMany,

    /// The card cannot be accessed because the wrong PIN was presented.
    WrongChv,
};

pub fn errDescription(err: Err) [:0]const u8 {
    return switch (err) {
        Err.AccessDenied =>
        \\[Win32] Received error code 0x5 (ERROR_ACCESS_DENIED).
        ,
        Err.BadCommand =>
        \\The device does not recognize the command.
        ,
        Err.BadSeek =>
        \\There was an error trying to set the smart card file object pointer.
        ,
        Err.Cancelled =>
        \\The action was cancelled by an SCardCancel request.
        ,
        Err.CancelledByUser =>
        \\The user pressed "Cancel" on a Smart Card Selection Dialog.
        ,
        Err.CantDispose =>
        \\The system could not dispose of the media in the requested manner.
        ,
        Err.CardNotAuthenticated =>
        \\No PIN was presented to the smart card.
        ,
        Err.CardUnsupported =>
        \\The smart card does not meet minimal requirements for support.
        ,
        Err.CertificateUnavailable =>
        \\The requested certificate could not be obtained.
        ,
        Err.ChvBlocked =>
        \\The card cannot be accessed because the maximum number of PIN entry attempts has been reached.
        ,
        Err.CommDataLost =>
        \\A communications error with the smart card has been detected. Retry the operation.
        ,
        Err.CommError =>
        \\An internal communications error has been detected.
        ,
        Err.DirNotFound =>
        \\The identified directory does not exist in the smart card.
        ,
        Err.DuplicateReader =>
        \\The reader driver did not produce a unique reader name.
        ,
        Err.Eof =>
        \\The end of the smart card file has been reached.
        ,
        Err.FileNotFound =>
        \\The identified file does not exist in the smart card.
        ,
        Err.IccCreateOrder =>
        \\The requested order of object creation is not supported.
        ,
        Err.IccInstallation =>
        \\No primary provider can be found for the smart card.
        ,
        Err.InsufficientBuffer =>
        \\The data buffer to receive returned data is too small for the returned data.
        ,
        Err.InternalError =>
        \\An internal consistency check failed.
        ,
        Err.InvalidAtr =>
        \\An ATR obtained from the registry is not a valid ATR string.
        ,
        Err.InvalidChv =>
        \\The supplied PIN is incorrect.
        ,
        Err.InvalidHandle =>
        \\The supplied handle was invalid.
        ,
        Err.InvalidParameter =>
        \\One or more of the supplied parameters could not be properly interpreted.
        ,
        Err.InvalidTarget =>
        \\Registry startup information is missing or invalid.
        ,
        Err.InvalidValue =>
        \\One or more of the supplied parameters values could not be properly interpreted.
        ,
        Err.NoAccess =>
        \\Access is denied to this file.
        ,
        Err.NoDir =>
        \\The supplied path does not represent a smart card directory.
        ,
        Err.NoFile =>
        \\The supplied path does not represent a smart card file.
        ,
        Err.NoKeyContainer =>
        \\The requested key container does not exist on the smart card.
        ,
        Err.NoMemory =>
        \\Not enough memory available to complete this command.
        ,
        Err.NoReadersAvailable =>
        \\Cannot find a smart card reader.
        ,
        Err.NoService =>
        \\The Smart card resource manager is not running.
        ,
        Err.NoSmartCard =>
        \\The operation requires a Smart Card, but no Smart Card is currently in the device.
        ,
        Err.NoSuchCertificate =>
        \\The requested certificate does not exist.
        ,
        Err.NotReady =>
        \\The reader or smart card is not ready to accept commands.
        ,
        Err.NotTransacted =>
        \\An attempt was made to end a non-existent transaction.
        ,
        Err.PciTooSmall =>
        \\The PCI Receive buffer was too small.
        ,
        Err.ProtoMismatch =>
        \\The requested protocols are incompatible with the protocol currently in use with the smart card.
        ,
        Err.ReaderUnavailable =>
        \\The specified reader is not currently available for use.
        ,
        Err.ReaderUnsupported =>
        \\The reader driver does not meet minimal requirements for support.
        ,
        Err.RemovedCard =>
        \\The smart card has been removed, so further communication is not possible.
        ,
        Err.ResetCard =>
        \\The smart card has been reset, so any shared state information is invalid.
        ,
        Err.SecurityViolation =>
        \\Access was denied because of a security violation.
        ,
        Err.ServerTooBusy =>
        \\The Smart Card Resource Manager is too busy to complete this operation.
        ,
        Err.ServiceStopped =>
        \\The Smart card resource manager has shut down.
        ,
        Err.SharingViolation =>
        \\The smart card cannot be accessed because of other connections outstanding.
        ,
        Err.Shutdown =>
        \\The operation has been aborted to allow the server application to exit.
        ,
        Err.SystemCancelled =>
        \\The action was cancelled by the system, presumably to log off or shut down.
        ,
        Err.Timeout =>
        \\The user-specified timeout value has expired.
        ,
        Err.UnboundError =>
        \\Received an error code not yet covered by these bindings.
        ,
        Err.UnknownCard =>
        \\The specified smart card name is not recognized.
        ,
        Err.UnknownError =>
        \\An internal error has been detected, but the source is unknown.
        ,
        Err.UnknownReader =>
        \\The specified reader name is not recognized.
        ,
        Err.UnknownResMng =>
        \\An unrecognized error code was returned from a layered component.
        ,
        Err.UnpoweredCard =>
        \\Power has been removed from the smart card, so that further communication is not possible.
        ,
        Err.UnresponsiveCard =>
        \\The smart card is not responding to a reset.
        ,
        Err.UnsupportedCard =>
        \\The reader cannot communicate with the card, due to ATR string configuration conflicts.
        ,
        Err.UnsupportedFeature =>
        \\This smart card does not support the requested feature.
        ,
        Err.WaitedTooLong =>
        \\An internal consistency timer has expired.
        ,
        Err.WriteTooMany =>
        \\The smart card does not have enough memory to store the information.
        ,
        Err.WrongChv =>
        \\The card cannot be accessed because the wrong PIN was presented.
        ,
    };
}

// [TODO] Considering filling in some relevant Windows-specific errors:
// https://learn.microsoft.com/en-us/windows/win32/secauthn/authentication-return-values
// https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes--0-499-

/// Represents a PCSC API response code.
///
/// https://pcsclite.apdu.fr/api/group__ErrorCodes.html
pub const Result = enum(Uword) {
    /// There was an error trying to set the smart card file object pointer.
    BAD_SEEK = 0x8010_0029,

    /// The action was cancelled by an SCardCancel request.
    CANCELLED = 0x8010_0002,

    /// The user pressed "Cancel" on a Smart Card Selection Dialog.
    CANCELLED_BY_USER = 0x8010_006e,

    /// The system could not dispose of the media in the requested manner.
    CANT_DISPOSE = 0x8010_000e,

    /// No PIN was presented to the smart card.
    CARD_NOT_AUTHENTICATED = 0x8010_006f,

    /// The smart card does not meet minimal requirements for support.
    CARD_UNSUPPORTED = 0x8010_001c,

    /// The requested certificate could not be obtained.
    CERTIFICATE_UNAVAILABLE = 0x8010_002d,

    /// The card cannot be accessed because the maximum number of PIN entry
    /// attempts has been reached.
    CHV_BLOCKED = 0x8010_006c,

    /// A communications error with the smart card has been detected.
    /// Retry the operation.
    COMM_DATA_LOST = 0x8010_002f,

    /// An internal communications error has been detected.
    COMM_ERROR = 0x8010_0013,

    /// The identified directory does not exist in the smart card.
    DIR_NOT_FOUND = 0x8010_0023,

    /// The reader driver did not produce a unique reader name.
    DUPLICATE_READER = 0x8010_001b,

    /// The end of the smart card file has been reached.
    EOF = 0x8010_006d,

    /// The identified file does not exist in the smart card.
    FILE_NOT_FOUND = 0x8010_0024,

    /// The requested order of object creation is not supported.
    ICC_CREATE_ORDER = 0x8010_0021,

    /// No primary provider can be found for the smart card.
    ICC_INSTALLATION = 0x8010_0020,

    /// The data buffer to receive returned data is too small for the
    /// returned data.
    INSUFFICIENT_BUFFER = 0x8010_0008,

    /// An internal consistency check failed.
    INTERNAL_ERROR = 0x8010_0001,

    /// An ATR obtained from the registry is not a valid ATR string.
    INVALID_ATR = 0x8010_0015,

    /// The supplied PIN is incorrect.
    INVALID_CHV = 0x8010_002a,

    /// The supplied handle was invalid.
    INVALID_HANDLE = 0x8010_0003,

    /// One or more of the supplied parameters could not be properly
    /// interpreted.
    INVALID_PARAMETER = 0x8010_0004,

    /// Registry startup information is missing or invalid.
    INVALID_TARGET = 0x8010_0005,

    /// One or more of the supplied parameters values could not be properly
    /// interpreted.
    INVALID_VALUE = 0x8010_0011,

    /// Access is denied to this file.
    NO_ACCESS = 0x8010_0027,

    /// The supplied path does not represent a smart card directory.
    NO_DIR = 0x8010_0025,

    /// The supplied path does not represent a smart card file.
    NO_FILE = 0x8010_0026,

    /// The requested key container does not exist on the smart card.
    NO_KEY_CONTAINER = 0x8010_0030,

    /// Not enough memory available to complete this command.
    NO_MEMORY = 0x8010_0006,

    /// Cannot find a smart card reader.
    NO_READERS_AVAILABLE = 0x8010_002e,

    /// The Smart card resource manager is not running.
    NO_SERVICE = 0x8010_001d,

    /// The operation requires a Smart Card, but no Smart Card is currently in
    /// the device.
    NO_SMART_CARD = 0x8010_000c,

    /// The requested certificate does not exist.
    NO_SUCH_CERTIFICATE = 0x8010_002c,

    /// The reader or smart card is not ready to accept commands.
    NOT_READY = 0x8010_0010,

    /// An attempt was made to end a non-existent transaction.
    NOT_TRANSACTED = 0x8010_0016,

    /// The PCI Receive buffer was too small.
    PCI_TOO_SMALL = 0x8010_0019,

    /// The requested protocols are incompatible with the protocol currently in
    /// use with the smart card.
    PROTO_MISMATCH = 0x8010_000f,

    /// The specified reader is not currently available for use.
    READER_UNAVAILABLE = 0x8010_0017,

    /// The reader driver does not meet minimal requirements for support.
    READER_UNSUPPORTED = 0x8010_001a,

    /// The smart card has been removed, so further communication is not
    /// possible.
    REMOVED_CARD = 0x8010_0069,

    /// The smart card has been reset, so any shared state information is
    /// invalid.
    RESET_CARD = 0x8010_0068,

    /// Access was denied because of a security violation.
    SECURITY_VIOLATION = 0x8010_006a,

    /// The Smart Card Resource Manager is too busy to complete this operation.
    SERVER_TOO_BUSY = 0x8010_0031,

    /// The Smart card resource manager has shut down.
    SERVICE_STOPPED = 0x8010_001e,

    /// The smart card cannot be accessed because of other connections
    /// outstanding.
    SHARING_VIOLATION = 0x8010_000b,

    /// The operation has been aborted to allow the server application to exit.
    SHUTDOWN = 0x8010_0018,

    /// No error was encountered.
    SUCCESS = 0,

    /// The action was cancelled by the system, presumably to log off or shut
    /// down.
    SYSTEM_CANCELLED = 0x8010_0012,

    /// The user-specified timeout value has expired.
    TIMEOUT = 0x8010_000a,

    /// The specified smart card name is not recognized.
    UNKNOWN_CARD = 0x8010_000d,

    /// An internal error has been detected, but the source is unknown.
    UNKNOWN_ERROR = 0x8010_0014,

    /// The specified reader name is not recognized.
    UNKNOWN_READER = 0x8010_0009,

    /// An unrecognized error code was returned from a layered component.
    UNKNOWN_RES_MNG = 0x8010_002b,

    /// Power has been removed from the smart card, so that further
    /// communication is not possible.
    UNPOWERED_CARD = 0x8010_0067,

    /// The smart card is not responding to a reset.
    UNRESPONSIVE_CARD = 0x8010_0066,

    /// The reader cannot communicate with the card, due to ATR string
    /// configuration conflicts.
    UNSUPPORTED_CARD = 0x8010_0065,

    /// This smart card does not support the requested feature.
    UNSUPPORTED_FEATURE_UNIX = 0x8010_001f,

    /// This smart card does not support the requested feature.
    UNSUPPORTED_FEATURE_WIN = 0x8010_0022,

    /// An internal consistency timer has expired.
    WAITED_TOO_LONG = 0x8010_0007,

    /// Access is denied.
    WIN32_ACCESS_DENIED = 0x0000_0005,

    /// The device does not recognize the command.
    WIN32_BAD_COMMAND = 0x0000_0016,

    /// The supplied handle was invalid.
    WIN32_INVALID_HANDLE = 0x0000_0006,

    /// One or more of the supplied parameters could not be properly
    /// interpreted.
    WIN32_INVALID_PARAMETER = 0x0000_0057,

    /// This smart card does not support the requested feature.
    WIN32_NOT_SUPPORTED = 0x0000_0032,

    /// No media in drive - a card operation was attempted with no card present.
    WIN32_NO_MEDIA_IN_DRIVE = 0x0000_0458,

    /// The smart card does not have enough memory to store the information.
    WRITE_TOO_MANY = 0x8010_0028,

    /// The card cannot be accessed because the wrong PIN was presented.
    WRONG_CHV = 0x8010_006b,

    _,

    /// Returns an error corresponding to this result, or `void` iff `SUCCESS`.
    pub fn check(self: Result) Err!void {
        switch (self) {
            .BAD_SEEK => return Err.BadSeek,
            .CANCELLED => return Err.Cancelled,
            .CANCELLED_BY_USER => return Err.CancelledByUser,
            .CANT_DISPOSE => return Err.CantDispose,
            .CARD_NOT_AUTHENTICATED => return Err.CardNotAuthenticated,
            .CARD_UNSUPPORTED => return Err.CardUnsupported,
            .CERTIFICATE_UNAVAILABLE => return Err.CertificateUnavailable,
            .CHV_BLOCKED => return Err.ChvBlocked,
            .COMM_DATA_LOST => return Err.CommDataLost,
            .COMM_ERROR => return Err.CommError,
            .DIR_NOT_FOUND => return Err.DirNotFound,
            .DUPLICATE_READER => return Err.DuplicateReader,
            .EOF => return Err.Eof,
            .FILE_NOT_FOUND => return Err.FileNotFound,
            .ICC_CREATE_ORDER => return Err.IccCreateOrder,
            .ICC_INSTALLATION => return Err.IccInstallation,
            .INSUFFICIENT_BUFFER => return Err.InsufficientBuffer,
            .INTERNAL_ERROR => return Err.InternalError,
            .INVALID_ATR => return Err.InvalidAtr,
            .INVALID_CHV => return Err.InvalidChv,
            .INVALID_HANDLE => return Err.InvalidHandle,
            .INVALID_PARAMETER => return Err.InvalidParameter,
            .INVALID_TARGET => return Err.InvalidTarget,
            .INVALID_VALUE => return Err.InvalidValue,
            .NO_ACCESS => return Err.NoAccess,
            .NO_DIR => return Err.NoDir,
            .NO_FILE => return Err.NoFile,
            .NO_KEY_CONTAINER => return Err.NoKeyContainer,
            .NO_MEMORY => return Err.NoMemory,
            .NO_READERS_AVAILABLE => return Err.NoReadersAvailable,
            .NO_SERVICE => return Err.NoService,
            .NO_SMART_CARD => return Err.NoSmartCard,
            .NO_SUCH_CERTIFICATE => return Err.NoSuchCertificate,
            .NOT_READY => return Err.NotReady,
            .NOT_TRANSACTED => return Err.NotTransacted,
            .PCI_TOO_SMALL => return Err.PciTooSmall,
            .PROTO_MISMATCH => return Err.ProtoMismatch,
            .READER_UNAVAILABLE => return Err.ReaderUnavailable,
            .READER_UNSUPPORTED => return Err.ReaderUnsupported,
            .REMOVED_CARD => return Err.RemovedCard,
            .RESET_CARD => return Err.ResetCard,
            .SECURITY_VIOLATION => return Err.SecurityViolation,
            .SERVER_TOO_BUSY => return Err.ServerTooBusy,
            .SERVICE_STOPPED => return Err.ServiceStopped,
            .SHARING_VIOLATION => return Err.SharingViolation,
            .SHUTDOWN => return Err.Shutdown,
            .SUCCESS => {},
            .SYSTEM_CANCELLED => return Err.SystemCancelled,
            .TIMEOUT => return Err.Timeout,
            .UNKNOWN_CARD => return Err.UnknownCard,
            .UNKNOWN_ERROR => return Err.UnknownError,
            .UNKNOWN_READER => return Err.UnknownReader,
            .UNKNOWN_RES_MNG => return Err.UnknownResMng,
            .UNPOWERED_CARD => return Err.UnpoweredCard,
            .UNRESPONSIVE_CARD => return Err.UnresponsiveCard,
            .UNSUPPORTED_CARD => return Err.UnsupportedCard,
            .UNSUPPORTED_FEATURE_UNIX => return Err.UnsupportedFeature,
            .UNSUPPORTED_FEATURE_WIN => return Err.UnsupportedFeature,
            .WAITED_TOO_LONG => return Err.WaitedTooLong,
            .WIN32_ACCESS_DENIED => return Err.AccessDenied,
            .WIN32_BAD_COMMAND => return Err.BadCommand,
            .WIN32_INVALID_HANDLE => return Err.InvalidHandle,
            .WIN32_INVALID_PARAMETER => return Err.InvalidParameter,
            .WIN32_NO_MEDIA_IN_DRIVE => return Err.NoSmartCard,
            .WIN32_NOT_SUPPORTED => return Err.UnsupportedFeature,
            .WRITE_TOO_MANY => return Err.WriteTooMany,
            .WRONG_CHV => return Err.WrongChv,
            else => {
                std.log.err(
                    \\{s} Error Code: [ {[1]d} (0x{[1]x}) ]
                    \\See https://learn.microsoft.com/en-us/windows/win32/debug/system-error-codes#system-error-codes
                    \\
                , .{
                    errDescription(Err.UnboundError),
                    @intFromEnum(self),
                });

                return Err.UnboundError;
            },
        }
    }
};
