const std = @import("std");
const gl = @import("gl");
const engine = @import("engine");
const verts = @import("verts.zig");
const v = verts.verts;
const Vertex = verts.Vertex;
const cubes = verts.cubes;

const math = @import("zmath");

// const Vertex = extern struct {
//     pos: [3]f32,
//     color: [3]f32,
//     tex: [2]f32,
// };
const WIDTH = 800;
const HEIGHT = 600;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    defer _ = gpa.deinit();

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

    // const v = [_]Vertex{
    //     .{
    //         .pos = .{ 0.5, 0.5, 0.0 },
    //         .color = .{ 0, 0, 1 },
    //         .tex = .{ 1, 1 },
    //     },
    //     .{
    //         .pos = .{ 0.5, -0.5, 0.0 },
    //         .color = .{ 0, 1, 0 },
    //         .tex = .{ 1, 0 },
    //     },
    //     .{
    //         .pos = .{ -0.5, -0.5, 0.0 },
    //         .color = .{ 1, 0, 1 },
    //         .tex = .{ 0, 0 },
    //     },
    //     .{
    //         .pos = .{ -0.5, 0.5, 0.0 },
    //         .color = .{ 1, 1, 0 },
    //         .tex = .{ 0, 1 },
    //     },
    // };

    var attribs = [_]engine.Shader.VertexAttribute{
        .{
            .name = "aPos",
            .type = .Float,
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
            .type = .Float,
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

    var wall_texture = engine.Texture.init(allocator, .{
        .path = "./resources/wall.jpg",
        .type = .Texture2D,
        .format = .Rgb,
    });
    try wall_texture.load();
    defer wall_texture.delete();

    var face_texture = engine.Texture.init(allocator, .{
        .path = "./resources/awesomeface.png",
        .type = .Texture2D,
        .format = .Rgba,
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

    var camera_pos = math.Vec{ 0, 0, 3, 0 };
    const camera_front = math.Vec{ 0, 0, -1, 0 };
    // const camera_target = math.Vec{ 0, 0, 0, 0 };
    // const camera_direction = math.normalize3(camera_pos - camera_target);
    const up = math.Vec{ 0, 1, 0, 0 };
    // const camera_right = math.normalize3(math.cross3(up, camera_direction));
    // const camera_up = math.cross(camera_direction, camera_right);
    // const view = math.lookAtRh(camera_pos, camera_target, up);

    const projection = math.perspectiveFovRhGl(
        std.math.degreesToRadians(45),
        @as(f32, @floatFromInt(WIDTH)) / @as(f32, @floatFromInt(HEIGHT)),
        0.1,
        100,
    );

    try shader.load();
    defer shader.deinit();

    // const camera_speed = math.f32x4s(0.0005);

    eng.start();
    while (eng.run()) {
        eng.startFrame();
        gl.ClearColor(0.2, 0.3, 0.3, 1);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const camera_speed = math.f32x4s(2.5 * eng.deltaTime);

        if (eng.key(engine.Key.Esc)) {
            break;
        }

        if (eng.key(.W)) {
            camera_pos += camera_speed * camera_front;
        }

        if (eng.key(.S)) {
            camera_pos -= camera_speed * camera_front;
        }

        if (eng.key(.A)) {
            camera_pos -= math.normalize3(math.cross3(camera_front, up)) * camera_speed;
        }

        if (eng.key(.D)) {
            camera_pos += math.normalize3(math.cross3(camera_front, up)) * camera_speed;
        }

        const view = math.lookAtRh(
            camera_pos,
            camera_pos + camera_front,
            up,
        );

        shader.use();
        shader.set4f("ourColor", [4]f32{ 0, 1, 1, 0 });
        shader.setInt("texture1", 0);
        shader.setInt("texture2", 1);

        shader.setMat4("view", view);
        shader.setMat4("projection", projection);

        gl.ActiveTexture(engine.Texture.active(0));
        wall_texture.bind();

        gl.ActiveTexture(engine.Texture.active(1));
        face_texture.bind();

        shader.vao.bind();
        for (cubes, 0..) |cube, i| {
            var model = math.mul(math.identity(), math.translationV(cube));
            const angle: f32 = @as(f32, @floatFromInt(i)) * 20;

            const q = math.quatToMat(
                math.quatFromAxisAngle(
                    math.Vec{ 1, 0.3, 0.5, 0 },
                    std.math.degreesToRadians(angle),
                ),
            );
            model = math.mul(q, model);

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
