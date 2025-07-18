const c = @import("c.zig").c;
const gl = @import("gl");

// https://www.glfw.org/docs/latest/group__errors.html
pub const GLFWError = error{
    // GLFW_NOT_INITIALIZED   0x00010001 GLFW has not been initialized.
    NotInitialized,
    // GLFW_NO_CURRENT_CONTEXT 0x00010002 No context is current for this thread.
    NoCurrentContext,
    // GLFW_INVALID_ENUM 0x00010003 One of the arguments to the function was an invalid enum value.
    InvalidEnum,
    // GLFW_INVALID_VALUE 0x00010004 One of the arguments to the function was an invalid value.
    InvalidValue,
    // GLFW_OUT_OF_MEMORY 0x00010005 A memory allocation failed.
    OutOfMemory,
    // GLFW_API_UNAVAILABLE 0x00010006 GLFW could not find support for the requested API on the system.
    ApiUnavailable,
    // GLFW_VERSION_UNAVAILABLE 0x00010007 The requested OpenGL or OpenGL ES version is not available.
    VersionUnavailable,
    // GLFW_PLATFORM_ERROR 0x00010008 A platform-specific error occurred that does not match any of the more specific categories.
    PlatformError,
    // GLFW_FORMAT_UNAVAILABLE 0x00010009 The requested format is not supported or available.
    FormatUnavailable,
    // GLFW_NO_WINDOW_CONTEXT 0x0001000A The specified window does not have an OpenGL or OpenGL ES context.
    NoWindowContext,
    // GLFW_CURSOR_UNAVAILABLE 0x0001000B The specified cursor shape is not available.
    CursorUnavailable,
    // GLFW_FEATURE_UNAVAILABLE 0x0001000C The requested feature is not provided by the platform.
    FeatureUnavailable,
    // GLFW_FEATURE_UNIMPLEMENTED 0x0001000D The requested feature is not implemented for the platform.
    Unimplemented,
    // GLFW_PLATFORM_UNAVAILABLE 0x0001000E Platform unavailable or no matching platform was found.
    PlatformUnavailable,

    UnknownError,
};

pub inline fn errify(err: c_int) GLFWError!void {
    return switch (err) {
        c.GLFW_NO_ERROR => {},
        c.GLFW_NOT_INITIALIZED => GLFWError.NotInitialized,
        c.GLFW_NO_CURRENT_CONTEXT => GLFWError.NoCurrentContext,
        c.GLFW_INVALID_ENUM => GLFWError.InvalidEnum,
        c.GLFW_INVALID_VALUE => GLFWError.InvalidValue,
        c.GLFW_OUT_OF_MEMORY => GLFWError.OutOfMemory,
        c.GLFW_API_UNAVAILABLE => GLFWError.ApiUnavailable,
        c.GLFW_VERSION_UNAVAILABLE => GLFWError.VersionUnavailable,
        c.GLFW_PLATFORM_ERROR => GLFWError.PlatformError,
        c.GLFW_FORMAT_UNAVAILABLE => GLFWError.FormatUnavailable,
        c.GLFW_NO_WINDOW_CONTEXT => GLFWError.NoWindowContext,
        c.GLFW_CURSOR_UNAVAILABLE => GLFWError.CursorUnavailable,
        c.GLFW_FEATURE_UNAVAILABLE => GLFWError.FeatureUnavailable,
        c.GLFW_FEATURE_UNIMPLEMENTED => GLFWError.Unimplemented,
        c.GLFW_PLATFORM_UNAVAILABLE => GLFWError.PlatformUnavailable,
        else => GLFWError.UnknownError,
    };
}

pub const GLError = error{
    InvalidEnum,
    InvalidValue,
    InvalidOperation,
    InvalidFrameBufferOperation,
    OutOfMemory,
    StackUnderflow,
    StackOverflow,
    UnknownError,
};
