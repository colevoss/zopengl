const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl");
const engine = @import("engine");
const verts = @import("light_map_verts.zig");
const v = verts.verts;
const Vertex = verts.Vertex;
const cubes = @import("verts.zig").cubes;
const imgui = @import("imgui").c;

const glm = @import("zmath");
const math = std.math;

const WIDTH: f32 = 1800;
const HEIGHT: f32 = WIDTH / 1.77777;

// 16 / 9  = 1.7777
// 800

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const allocator, const is_debug = gpa: {
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };

    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var eng: engine.Engine = .{
        .title = "ZiGL",
        .window = .{
            .height = HEIGHT,
            .width = WIDTH,
        },
    };

    eng.init() catch |e| {
        std.debug.print("Error initializing engine: {s}\n", .{@errorName(e)});
        return;
    };
    defer eng.terminate();

    eng.initUI();
    defer eng.terminateUI();

    var attribs = [_]engine.Shader.VertexAttribute{
        .{
            .name = "aPos",
            .type = .float,
            .size = @typeInfo(@FieldType(Vertex, "pos")).array.len,
            .stride = @sizeOf(Vertex),
            .offset = @offsetOf(Vertex, "pos"),
        },
        .{
            .name = "aNormal",
            .type = .float,
            .size = @typeInfo(@FieldType(Vertex, "normals")).array.len,
            .stride = @sizeOf(Vertex),
            .offset = @offsetOf(Vertex, "normals"),
        },
        .{
            .name = "aTex",
            .type = .float,
            .size = @typeInfo(@FieldType(Vertex, "tex")).array.len,
            .stride = @sizeOf(Vertex),
            .offset = @offsetOf(Vertex, "tex"),
        },
    };

    var light_attribs = [_]engine.Shader.VertexAttribute{
        .{
            .name = "aPos",
            .type = .float,
            .size = @typeInfo(@FieldType(Vertex, "pos")).array.len,
            .stride = @sizeOf(Vertex),
            .offset = @offsetOf(Vertex, "pos"),
        },
    };

    const indices = [_]u32{
        0, 1, 3,
        1, 2, 3,
    };

    var ebo: engine.Shader.Vbo = .{
        .type = .element_array,
        .size = @sizeOf(@TypeOf(indices)),
        .data = &indices,
        .usage = .static_draw,
    };

    const vao: engine.Shader.Vao = .{
        .attributes = &attribs,
        .vbo = .{
            .type = .array,
            .size = @sizeOf(@TypeOf(v)),
            .data = &v,
            .usage = .static_draw,
        },
        .ebo = &ebo,
    };

    // var wall_texture = engine.Texture.init(allocator, .{
    //     .path = "./resources/wall.jpg",
    //     .type = .texture_2d,
    //     .format = .rgb,
    // });
    // try wall_texture.load();
    // defer wall_texture.delete();
    //
    // var face_texture = engine.Texture.init(allocator, .{
    //     .path = "./resources/awesomeface.png",
    //     .type = .texture_2d,
    //     .format = .rgba,
    // });
    // try face_texture.load();
    // defer face_texture.delete();

    var box_texture = engine.Texture.init(allocator, .{
        .path = "./resources/box.png",
        .type = .texture_2d,
        .format = .rgba,
    });
    try box_texture.load();
    defer box_texture.delete();

    var box_specular_texture = engine.Texture.init(allocator, .{
        .path = "./resources/box_specular.png",
        .type = .texture_2d,
        .format = .rgba,
    });
    try box_specular_texture.load();
    defer box_specular_texture.delete();

    var box_emission_texture = engine.Texture.init(allocator, .{
        .path = "./resources/box_emission.jpg",
        .type = .texture_2d,
        .format = .rgb,
    });
    try box_emission_texture.load();
    defer box_emission_texture.delete();

    var uniforms = [_][]const u8{
        "model",
        "view",
        "projection",

        "viewPos",

        // "material.ambient",
        // "material.diffuse",
        "material.specular",
        "material.shininess",
        "material.emission",

        // "light.position",
        "light.direction",
        "light.ambient",
        "light.diffuse",
        "light.specular",
    };

    var shader = engine.Shader.init(
        allocator,
        .{
            // .vertexPath = "./resources/test_vertex.glsl",
            // .fragmentPath = "./resources/test_fragment.glsl",
            .vertexPath = "./resources/shaders/light_map_vertex.glsl",
            .fragmentPath = "./resources/shaders/light_map_fragment.glsl",
        },
        vao,
        &uniforms,
        // null,
    );

    try shader.load();
    defer shader.deinit();

    const light_vao: engine.Shader.Vao = .{
        .attributes = &light_attribs,
        .vbo = .{
            .type = .array,
            .size = @sizeOf(@TypeOf(v)),
            .data = &v,
            .usage = .static_draw,
        },
        .ebo = null,
        // .ebo = &ebo,
    };

    var light_uniforms = [_][]const u8{
        "model",
        "view",
        "projection",
        "lightColor",
    };

    var light_shader = engine.Shader.init(
        allocator,
        .{
            .vertexPath = "./resources/shaders/light_vertex.glsl",
            .fragmentPath = "./resources/shaders/light_source_fragment.glsl",
        },
        light_vao,
        &light_uniforms,
    );

    try light_shader.load();
    defer light_shader.deinit();

    var camera: engine.Camera = .init;
    camera.speed = 5;
    camera.pos = .{ 1, 2, 5, 0 };

    eng.start();
    camera.look_at = @splat(0);

    var light: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    const light_pos: @Vector(4, f32) = .{ 1.2, 1, 2, 0 };

    // const label = "hello";
    // var value: i32 = 0;
    var counter: f32 = 0;
    var t = [_]bool{true};

    // camera.lookAt(@splat(1));

    while (eng.run()) {
        eng.startFrame();
        eng.startUIFrame();

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        gl.ClearColor(0, 0, 0, 0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        _ = imgui.ImGui_Begin(
            "New Window",
            &t,
            0,
            // imgui.ImGuiWindowFlags_NoBackground | imgui.ImGuiWindowFlags_NoDecoration,
        );

        _ = imgui.ImGui_ColorPicker4("Color", @ptrCast(&light), 0, null);

        if (imgui.ImGui_Button("Hello")) {
            counter += 1;
            std.debug.print("Hello {} \n", .{t[0]});
            std.debug.print("Hello!\n", .{});
        }

        const str = try std.fmt.allocPrint(arena.allocator(), "Hello: {d}", .{counter});
        // const str = try std.fmt.allocPrint(allocator, "Hello: {d}", .{counter});
        // defer allocator.free(str);
        imgui.ImGui_Text(str.ptr);
        imgui.ImGui_Text("BALLS");
        imgui.ImGui_End();

        if (eng.keyPressed(.esc)) {
            break;
        }

        // light[0] = (1 + @sin(eng.last_time)) / 2;
        // light_pos[0] = (2 * @sin(eng.last_time)) * 2;
        // light_pos[2] = 2 * @cos(eng.last_time) * 2;

        camera.update(&eng);
        // camera.lookAt(@splat(0));

        shader.use();

        gl.ActiveTexture(engine.Texture.active(0));
        box_texture.bind();

        gl.ActiveTexture(engine.Texture.active(1));
        box_specular_texture.bind();

        gl.ActiveTexture(engine.Texture.active(2));
        box_emission_texture.bind();

        // shader.setVec3("objectColor", color);
        shader.setVec3("viewPos", camera.pos);
        shader.setMat4("view", camera.view);
        shader.setMat4("projection", camera.projection);

        // shader.setVec3("material.ambient", .{ 1, 0.5, 0.31, 0 });
        // shader.setVec3("material.diffuse", .{ 1, 0.5, 0.31, 0 });
        // shader.setVec3("material.specular", .{ 0.5, 0.5, 0.5, 0 });
        shader.setInt("material.difuse", 0); // need to tell it which texture to sample i think
        shader.setInt("material.specular", 1); // need to tell it which texture to sample i think
        shader.setInt("material.emission", 2); // need to tell it which texture to sample i think
        shader.setFloat("material.shininess", 64);

        // shader.setVec3("light.position", light_pos);
        shader.setVec3("light.direction", .{ -0.2, -1, -0.3, 0 });
        // shader.setVec3("light.ambient", light * glm.f32x4s(0.2));
        shader.setVec3("light.ambient", glm.f32x4s(0.2));
        // shader.setVec3("light.diffuse", light * glm.f32x4s(0.5));
        // shader.setVec3("light.diffuse", glm.f32x4s(0.5));
        shader.setVec3("light.diffuse", light);
        shader.setVec3("light.specular", @splat(1));

        shader.vao.bind();
        for (cubes, 0..) |cube, i| {
            const angle: f32 = 20 * @as(f32, @floatFromInt(i));
            var model = glm.identity();

            model = glm.mul(
                model,
                glm.quatToMat(glm.quatFromAxisAngle(.{ 1, 0.3, 0.5, 1 }, math.degreesToRadians(angle))),
            );
            model = glm.mul(model, glm.translationV(cube));
            shader.setMat4("model", model);

            gl.DrawArrays(gl.TRIANGLES, 0, 36);
        }

        light_shader.use();
        light_shader.setMat4("view", camera.view);
        light_shader.setMat4("projection", camera.projection);

        light_shader.setVec3("lightColor", light);
        var light_model = glm.mul(glm.identity(), glm.scalingV(@splat(0.2)));
        light_model = glm.mul(light_model, glm.translationV(light_pos));

        light_shader.setMat4("model", light_model);
        gl.DrawArrays(gl.TRIANGLES, 0, 36);

        eng.endUIFrame();
        eng.endFrame();
    }

    const err = gl.GetError();
    std.debug.print("gl err {d}\n", .{err});
}
