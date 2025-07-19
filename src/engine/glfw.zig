const std = @import("std");
const c = @import("c.zig").c;
const err = @import("error.zig");
const keys = @import("keys.zig");

pub const Window = c.GLFWwindow;

pub fn init() err.GLFWError!void {
    if (!boolean(c.glfwInit())) {
        try checkError();
    }

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 1);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

    try checkError();
}

pub fn terminate() void {
    c.glfwTerminate();
}

pub fn windowShouldClose(window: ?*Window) bool {
    return boolean(c.glfwWindowShouldClose(window));
}

pub const CreateWindowOptions = struct {
    width: i32,
    height: i32,
    title: []const u8,
};

pub fn createWindow(opts: CreateWindowOptions) err.GLFWError!?*Window {
    const window = c.glfwCreateWindow(
        opts.width,
        opts.height,
        opts.title.ptr,
        null,
        null,
    );

    if (window) |w| {
        try makeContextCurrent(w);
        c.glfwSwapInterval(0);
        return w;
    }

    try checkError();
    unreachable;
}

pub fn getKey(window: ?*Window, k: keys.Key, action: keys.Action) bool {
    return c.glfwGetKey(window, k.glfw()) == action.glfw();
}

pub const FrameBufferCallback = fn (?*Window, i32, i32) void;

var frameBufferCallback: *const FrameBufferCallback = undefined;

pub fn setFramebufferSizeCallback(window: ?*Window, cb: FrameBufferCallback) void {
    frameBufferCallback = cb;
    _ = c.glfwSetFramebufferSizeCallback(window, frameBufferSizeCallback);
}

pub inline fn getTime() f32 {
    return @floatCast(c.glfwGetTime());
}

fn frameBufferSizeCallback(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.c) void {
    frameBufferCallback(window, width, height);
}

pub const ErrorCallback = fn (desc: []const u8) void;

var errorCallback: *const ErrorCallback = undefined;

pub fn setErrorCallback(cb: ErrorCallback) void {
    errorCallback = cb;

    _ = c.glfwSetErrorCallback(glfwErrorCallback);
}

fn glfwErrorCallback(_: c_int, desc: [*c]const u8) callconv(.c) void {
    errorCallback(std.mem.span(desc));
}

pub fn makeContextCurrent(window: ?*Window) err.GLFWError!void {
    c.glfwMakeContextCurrent(window);
    try checkError();
}

pub fn checkError() err.GLFWError!void {
    return try err.errify(c.glfwGetError(null));
}

pub inline fn boolean(i: c_int) bool {
    return i == c.GLFW_TRUE;
}
