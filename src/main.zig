const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl");
const engine = @import("engine");
const verts = @import("light_verts.zig");
const v = verts.verts;
const Vertex = verts.Vertex;
const cubes = verts.cubes;

const glm = @import("zmath");
const math = std.math;

const WIDTH = 800;
const HEIGHT = 600;

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

    var eng: engine.Engine = .{};

    eng.init(.{
        .width = WIDTH,
        .height = HEIGHT,
        .title = "ZiGL",
    }) catch |e| {
        std.debug.print("Error initializing engine: {s}\n", .{@errorName(e)});
        return;
    };

    defer eng.terminate();

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
        // .{
        //     .name = "aColor",
        //     .type = .Float,
        //     .size = @typeInfo(@FieldType(Vertex, "color")).array.len,
        //     .stride = @sizeOf(Vertex),
        //     .offset = @offsetOf(Vertex, "color"),
        // },
        // .{
        //     .name = "aTex",
        //     .type = .float,
        //     .size = @typeInfo(@FieldType(Vertex, "tex")).array.len,
        //     .stride = @sizeOf(Vertex),
        //     .offset = @offsetOf(Vertex, "tex"),
        // },
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

    var uniforms = [_][]const u8{
        "model",
        "view",
        "projection",
        "objectColor",
        "lightColor",
        "lightPos",
        "viewPos",
    };

    var shader = engine.Shader.init(
        allocator,
        .{
            // .vertexPath = "./resources/test_vertex.glsl",
            // .fragmentPath = "./resources/test_fragment.glsl",
            .vertexPath = "./resources/light_vertex.glsl",
            .fragmentPath = "./resources/light_fragment.glsl",
        },
        vao,
        &uniforms,
        // null,
    );

    try shader.load();
    defer shader.deinit();

    var light_uniforms = [_][]const u8{
        "model",
        "view",
        "projection",
        "lightColor",
    };

    var light_shader = engine.Shader.init(
        allocator,
        .{
            .vertexPath = "./resources/light_vertex.glsl",
            .fragmentPath = "./resources/light_source_fragment.glsl",
        },
        vao,
        &light_uniforms,
    );

    try light_shader.load();
    defer light_shader.deinit();

    var camera: engine.Camera = .init;
    camera.speed = 2.5;
    camera.pos = .{ 1, 2, 5, 0 };

    eng.start();
    camera.look_at = @splat(0);

    const color: @Vector(4, f32) = .{ 1, 0.5, 0.31, 1 };
    // const color: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    var light: @Vector(4, f32) = .{ 1, 1, 1, 1 };

    var light_pos: @Vector(4, f32) = .{ 0, 0, 0, 0 };

    while (eng.run()) {
        eng.startFrame();

        if (eng.keyPressed(.esc)) {
            break;
        }

        gl.ClearColor(0, 0, 0, 0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        light[0] = (1 + @sin(eng.last_time)) / 2;
        light_pos[0] = (2 * @sin(eng.last_time)) * 2;
        light_pos[2] = 2 * @cos(eng.last_time) * 2;

        camera.update(&eng);

        shader.use();
        shader.setVec3("objectColor", color);
        shader.setVec3("lightColor", light);
        shader.setVec3("lightPos", light_pos);
        shader.setVec3("viewPos", camera.pos);
        shader.setMat4("view", camera.view);
        shader.setMat4("projection", camera.projection);

        var model = glm.identity();
        shader.setMat4("model", model);

        shader.vao.bind();
        gl.DrawArrays(gl.TRIANGLES, 0, 36);

        light_shader.use();
        light_shader.setMat4("view", camera.view);
        light_shader.setMat4("projection", camera.projection);

        light_shader.setVec3("lightColor", light);
        model = glm.mul(model, glm.scalingV(@splat(0.2)));
        model = glm.mul(model, glm.translationV(light_pos));

        light_shader.setMat4("model", model);
        gl.DrawArrays(gl.TRIANGLES, 0, 36);

        eng.endFrame();
    }

    const err = gl.GetError();
    std.debug.print("gl err {d}\n", .{err});
}
