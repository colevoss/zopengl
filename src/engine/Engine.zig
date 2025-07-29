const std = @import("std");
const err = @import("error.zig");
const gl = @import("gl");
const glfw = @import("glfw.zig");
const c = @import("c.zig").c;
const keys = @import("keys.zig");
const Mouse = @import("Mouse.zig");
const imgui = @import("imgui").c;
const TextureLoader = @import("TextureLoader.zig");

const log = std.log.scoped(.engine);
const Engine = @This();

pub const CreateWindowOptions = glfw.CreateWindowOptions;

pub const EngineError = error{
    UnknownError,
};

pub const Window = struct {
    width: f32,
    height: f32,

    pub fn ratio(self: *const Window) f32 {
        return self.width / self.height;
    }
};

pub const Error = err.GLFWError || EngineError;

mouse: Mouse = .init,

last_time: f32 = 0,
delta_time: f32 = 0,
delta_time_vec: @Vector(4, f32) = @splat(0),

procs: gl.ProcTable = undefined,

window: Window,
title: []const u8,

glfw_window: *glfw.Window = undefined,

imgui_context: *imgui.ImGuiContext = undefined,
texture_loader: TextureLoader,

pub fn init(self: *Engine) Error!void {
    try glfw.init();
    glfw.setErrorCallback(errorCallback);

    try self.createWindow(.{
        .width = @intFromFloat(self.window.width),
        .height = @intFromFloat(self.window.height),
        .title = self.title,
    });
}

pub fn createWindow(self: *Engine, opts: CreateWindowOptions) Error!void {
    const window = try glfw.createWindow(opts);

    if (window) |w| {
        self.glfw_window = w;
    }

    c.glfwSetWindowUserPointer(self.glfw_window, self);
    glfw.setFramebufferSizeCallback(self.glfw_window, framebufferSizeCallback);
    glfw.setMouseCallback(self.glfw_window, mouseCallback);
    glfw.setScrollCallback(self.glfw_window, scrollCallback);

    if (!self.procs.init(c.glfwGetProcAddress)) {
        return EngineError.UnknownError;
    }

    gl.makeProcTableCurrent(&self.procs);
    gl.Enable(gl.DEPTH_TEST);
}

pub fn initUI(self: *Engine) void {
    _ = imgui.CIMGUI_CHECKVERSION();

    if (imgui.ImGui_CreateContext(null)) |ctx| {
        self.imgui_context = ctx;
    } else {
        @panic("IMGUI Could not create context");
    }

    const io = imgui.ImGui_GetIO();
    io[0].ConfigFlags |= imgui.ImGuiConfigFlags_NavEnableKeyboard;

    if (!imgui.cImGui_ImplGlfw_InitForOpenGL(@ptrCast(self.glfw_window), true)) {
        @panic("Could not initialize IMGui for GLFW");
    }

    if (!imgui.cImGui_ImplOpenGL3_Init()) {
        @panic("Could not initialize IMGui for OpenGL");
    }
}

pub fn mouseButton(self: *const Engine, button: keys.MouseButton, action: keys.Action) bool {
    return glfw.getMouseButton(self.glfw_window, button, action);
}

pub fn key(self: *const Engine, k: keys.Key, action: keys.Action) bool {
    return glfw.getKey(self.glfw_window, k, action);
}

pub fn keyPressed(self: *Engine, k: keys.Key) bool {
    return self.key(k, .pressed);
}

pub fn keyReleased(self: *const Engine, k: keys.Key) bool {
    return self.key(k, .released);
}

pub fn start(self: *Engine) void {
    self.last_time = self.getTime();
}

pub fn run(self: *Engine) bool {
    return !glfw.windowShouldClose(self.glfw_window);
}

pub fn startFrame(self: *Engine) void {
    c.glfwPollEvents();

    const now = self.getTime();
    self.delta_time = now - self.last_time;
    self.delta_time_vec = @splat(self.delta_time);
    self.last_time = now;
}

pub fn startUIFrame(_: *const Engine) void {
    imgui.cImGui_ImplOpenGL3_NewFrame();
    imgui.cImGui_ImplGlfw_NewFrame();
    imgui.ImGui_NewFrame();
}

pub fn endUIFrame(_: *const Engine) void {
    imgui.ImGui_EndFrame();
    imgui.ImGui_Render();
    imgui.cImGui_ImplOpenGL3_RenderDrawData(imgui.ImGui_GetDrawData());
}

pub fn endFrame(self: *Engine) void {
    self.mouse.clearOffset();
    c.glfwSwapBuffers(self.glfw_window);
}

pub inline fn getTime(_: *Engine) f32 {
    return glfw.getTime();
}

fn framebufferSizeCallback(window: ?*glfw.Window, width: i32, height: i32) void {
    const eng: *Engine = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window)));
    eng.window.height = @floatFromInt(height);
    eng.window.width = @floatFromInt(width);
    gl.Viewport(0, 0, width, height);
}

fn mouseCallback(window: ?*glfw.Window, x: f32, y: f32) void {
    const eng: *Engine = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window)));
    eng.mouse.update(x, y);
}

fn scrollCallback(window: ?*glfw.Window, offset_x: f32, offset_y: f32) void {
    const eng: *Engine = @ptrCast(@alignCast(c.glfwGetWindowUserPointer(window)));
    eng.mouse.scroll.update(offset_x, offset_y);
}

fn errorCallback(desc: []const u8) void {
    log.err("GLFW Err: {s}", .{desc});
}

pub fn terminate(self: *Engine) void {
    // TODO: move this to a deinit
    self.texture_loader.deinit();
    glfw.terminate();
}

pub fn terminateUI(self: *const Engine) void {
    imgui.cImGui_ImplOpenGL3_Shutdown();
    imgui.cImGui_ImplGlfw_Shutdown();
    imgui.ImGui_DestroyContext(self.imgui_context);
}
