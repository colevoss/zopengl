const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl");
const engine = @import("engine");
const verts = @import("verts.zig");
const v = verts.verts;
const Vertex = verts.Vertex;
const cubes = verts.cubes;

const glm = @import("zmath");
const math = std.math;

// const Vertex = extern struct {
//     pos: [3]f32,
//     color: [3]f32,
//     tex: [2]f32,
// };
const WIDTH = 800;
const HEIGHT = 600;

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // var gpa: std.heap.DebugAllocator(.{}) = .init;
    // const allocator = gpa.allocator();

    const allocator, const is_debug = gpa: {
        // if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };

    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };
    // defer _ = gpa.deinit();

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
        // .{
        //     .name = "aColor",
        //     .type = .Float,
        //     .size = @typeInfo(@FieldType(Vertex, "color")).array.len,
        //     .stride = @sizeOf(Vertex),
        //     .offset = @offsetOf(Vertex, "color"),
        // },
        .{
            .name = "aTex",
            .type = .float,
            .size = @typeInfo(@FieldType(Vertex, "tex")).array.len,
            .stride = @sizeOf(Vertex),
            .offset = @offsetOf(Vertex, "tex"),
        },
    };

    // std.debug.print("{any}\n", .{attribs});

    // const vertices = [_]f32{
    //     -0.5, -0.5, 0.0,
    //     0.5,  -0.5, 0.0,
    //     0.0,  0.5,  0.0,
    // };

    // const vertices = [_]f32{
    //     0.5, 0.5, 0.0, // top right
    //     0.5, -0.5, 0.0, // bottom right
    //     -0.5, -0.5, 0.0, // bottom let
    //     -0.5, 0.5, 0.0, // top let
    // };

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
            // .size = @sizeOf(@TypeOf(vertices)),
            .size = @sizeOf(@TypeOf(v)),
            // .data = &vertices,
            .data = &v,
            .usage = .static_draw,
        },
        .ebo = &ebo,
    };

    var wall_texture = engine.Texture.init(allocator, .{
        .path = "./resources/wall.jpg",
        .type = .texture_2d,
        .format = .rgb,
    });
    try wall_texture.load();
    defer wall_texture.delete();

    var face_texture = engine.Texture.init(allocator, .{
        .path = "./resources/awesomeface.png",
        .type = .texture_2d,
        .format = .rgba,
    });
    try face_texture.load();
    defer face_texture.delete();

    var uniforms = [_][]const u8{
        "texture1",
        "texture2",
        "model",
        "view",
        "projection",
    };

    var shader = engine.Shader.init(
        allocator,
        .{
            .vertexPath = "./resources/test_vertex.glsl",
            .fragmentPath = "./resources/test_fragment.glsl",
        },
        vao,
        &uniforms,
        // null,
    );

    var camera: engine.Camera = .init;
    camera.speed = 2.5;
    camera.pos = .{ 0, 0, 3, 0 };

    try shader.load();
    defer shader.deinit();

    eng.start();
    camera.look_at = cubes[0];

    while (eng.run()) {
        eng.startFrame();

        if (eng.keyPressed(.esc)) {
            break;
        }

        // gl.ClearColor(0.2, 0.3, 0.3, 1);
        gl.ClearColor(0, 0, 0, 0);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        camera.update(&eng);

        shader.use();
        shader.set4f("ourColor", [4]f32{ 0, 1, 1, 0 });
        shader.setInt("texture1", 0);
        shader.setInt("texture2", 1);

        shader.setMat4("view", camera.view);
        shader.setMat4("projection", camera.projection);

        gl.ActiveTexture(engine.Texture.active(0));
        wall_texture.bind();

        gl.ActiveTexture(engine.Texture.active(1));
        face_texture.bind();

        shader.vao.bind();
        for (cubes, 0..) |cube, i| {
            var model = glm.mul(glm.identity(), glm.translationV(cube));
            const angle: f32 = @as(f32, @floatFromInt(i)) * 20;

            const q = glm.quatToMat(
                glm.quatFromAxisAngle(
                    glm.Vec{ 1, 0.3, 0.5, 0 },
                    std.math.degreesToRadians(angle),
                ),
            );
            model = glm.mul(q, model);

            shader.setMat4("model", model);
            gl.DrawArrays(gl.TRIANGLES, 0, 36);
        }
        // gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);
        // gl.DrawArrays(gl.TRIANGLES, 0, 36);

        eng.endFrame();
    }

    const err = gl.GetError();
    std.debug.print("gl err {d}\n", .{err});
}
