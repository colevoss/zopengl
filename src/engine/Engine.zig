const std = @import("std");
const err = @import("error.zig");
const gl = @import("gl");
const glfw = @import("glfw.zig");
const c = @import("c.zig").c;
const keys = @import("keys.zig");

const log = std.log.scoped(.engine);
const Engine = @This();

pub const CreateWindowOptions = glfw.CreateWindowOptions;

pub const EngineError = error{
    UnknownError,
};

pub const Error = err.GLFWError || EngineError;

lastTime: f32 = 0,
deltaTime: f32 = 0,

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
    gl.Enable(gl.DEPTH_TEST);
}

pub fn key(self: *Engine, k: keys.Key, action: keys.Action) bool {
    return glfw.getKey(self.window, k, action);
}

pub fn keyPressed(self: *Engine, k: keys.Key) bool {
    return self.key(k, .pressed);
}

pub fn keyReleased(self: *Engine, k: keys.Key) bool {
    return self.key(k, .released);
}

pub fn start(self: *Engine) void {
    self.lastTime = self.getTime();
}

pub fn run(self: *Engine) bool {
    return !glfw.windowShouldClose(self.window);
}

pub fn startFrame(self: *Engine) void {
    c.glfwPollEvents();

    const now = self.getTime();
    self.deltaTime = now - self.lastTime;
    self.lastTime = now;
}

pub fn endFrame(self: *Engine) void {
    c.glfwSwapBuffers(self.window);
}

pub inline fn getTime(_: *Engine) f32 {
    return glfw.getTime();
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
