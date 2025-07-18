const std = @import("std");
const err = @import("error.zig");
const gl = @import("gl");
const glfw = @import("glfw.zig");
const c = @import("c.zig").c;
const Key = @import("key.zig").Key;

const log = std.log.scoped(.engine);
const Engine = @This();

pub const CreateWindowOptions = glfw.CreateWindowOptions;

pub const EngineError = error{
    UnknownError,
};

pub const Error = err.GLFWError || EngineError;

procs: gl.ProcTable = undefined,
window: *glfw.Window = undefined,

pub fn init(self: *Engine, opts: CreateWindowOptions) Error!void {
    try glfw.init();
    glfw.setErrorCallback(errorCallback);
    try self.createWindow(opts);
}

pub fn createWindow(self: *Engine, opts: CreateWindowOptions) Error!void {
    const window = try glfw.createWindow(opts);

    if (window) |w| {
        self.window = w;
    }

    c.glfwSetWindowUserPointer(self.window, self);
    glfw.setFramebufferSizeCallback(self.window, framebufferSizeCallback);

    if (!self.procs.init(c.glfwGetProcAddress)) {
        return EngineError.UnknownError;
    }

    gl.makeProcTableCurrent(&self.procs);
}

pub fn key(self: *Engine, k: Key) bool {
    return glfw.getKey(self.window, k);
}

pub fn run(self: *Engine) bool {
    return !glfw.windowShouldClose(self.window);
}

pub fn endFrame(self: *Engine) void {
    c.glfwSwapBuffers(self.window);
    c.glfwPollEvents();
}

fn framebufferSizeCallback(_: ?*glfw.Window, width: i32, height: i32) void {
    // const eng: *Engine = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window)));
    gl.Viewport(0, 0, width, height);
}

fn errorCallback(desc: []const u8) void {
    log.err("GLFW Err: {s}", .{desc});
}

pub fn terminate(_: *Engine) void {
    glfw.terminate();
}
