const std = @import("std");
const gl = @import("gl");
const engine = @import("engine");

const Vertex = extern struct {
    pos: [3]f32,
    color: [3]f32,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer _ = gpa.deinit();

    var eng: engine.Engine = .{};

    eng.init(.{
        .width = 800,
        .height = 600,
        .title = "ZiGL",
    }) catch |e| {
        std.debug.print("Error initializing engine: {s}\n", .{@errorName(e)});
        return;
    };

    defer eng.terminate();

    const v = [_]Vertex{
        .{
            .pos = .{ 0.5, 0.5, 0.0 },
            .color = .{ 0, 0, 1 },
        },
        .{
            .pos = .{ 0.5, -0.5, 0.0 },
            .color = .{ 0, 1, 0 },
        },
        .{
            .pos = .{ -0.5, -0.5, 0.0 },
            .color = .{ 1, 0, 1 },
        },
        .{
            .pos = .{ -0.5, 0.5, 0.0 },
            .color = .{ 1, 1, 0 },
        },
    };

    var attribs = [_]engine.Shader.VertexAttribute{
        .{
            .name = "aPos",
            .type = .Float,
            .size = @typeInfo(@FieldType(Vertex, "pos")).array.len,
            .stride = @sizeOf(Vertex),
            .offset = @offsetOf(Vertex, "pos"),
        },
        .{
            .name = "aColor",
            .type = .Float,
            .size = @typeInfo(@FieldType(Vertex, "color")).array.len,
            .stride = @sizeOf(Vertex),
            .offset = @offsetOf(Vertex, "color"),
        },
    };

    std.debug.print("{any}\n", .{attribs});

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
        .type = .ElementArray,
        .size = @sizeOf(@TypeOf(indices)),
        .data = &indices,
        .usage = .StaticDraw,
    };

    const vao: engine.Shader.Vao = .{
        .attributes = &attribs,
        .vbo = .{
            .type = .Array,
            // .size = @sizeOf(@TypeOf(vertices)),
            .size = @sizeOf(@TypeOf(v)),
            // .data = &vertices,
            .data = &v,
            .usage = .StaticDraw,
        },
        .ebo = &ebo,
    };

    var uniforms = [_][]const u8{"ourColor"};

    var shader = engine.Shader.init(
        allocator,
        .{
            .vertexPath = "./resources/test_vertex.glsl",
            .fragmentPath = "./resources/test_fragment.glsl",
        },
        vao,
        &uniforms,
    );

    try shader.load();
    defer shader.deinit();

    while (eng.run()) {
        gl.ClearColor(0.2, 0.3, 0.3, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        if (eng.key(engine.Key.Esc)) {
            break;
        }

        shader.use();
        shader.uniform4f("ourColor", [4]f32{ 0, 1, 1, 0 });

        shader.vao.bind();
        // gl.DrawArrays(gl.TRIANGLES, 0, 3);
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, 0);

        eng.endFrame();
    }
}
