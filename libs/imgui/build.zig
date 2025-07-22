const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build, target: Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) *Build.Module {
    const module = b.addModule("imgui", .{
        .root_source_file = b.path("libs/imgui/src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    module.addIncludePath(.{ .cwd_relative = "include/imgui" });
    module.addCSourceFile(.{ .file = b.path("include/imgui/imgui.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/imgui_widgets.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/imgui_tables.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/imgui_draw.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/imgui_demo.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/dcimgui.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/dcimgui_internal.cpp"), .flags = &.{""} });

    // module.addCSourceFile(.{ .file = b.path("include/imgui/backends/dcimgui_impl_glfw.cpp"), .flags = &.{""} });
    // module.addCSourceFile(.{ .file = b.path("include/imgui/backends/dcimgui_impl_opengl3.cpp"), .flags = &.{""} });

    module.addCSourceFile(.{ .file = b.path("include/imgui/imgui_impl_glfw.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/imgui_impl_opengl3.cpp"), .flags = &.{""} });

    module.addCSourceFile(.{ .file = b.path("include/imgui/dcimgui_impl_glfw.cpp"), .flags = &.{""} });
    module.addCSourceFile(.{ .file = b.path("include/imgui/dcimgui_impl_opengl3.cpp"), .flags = &.{""} });

    return module;
}
