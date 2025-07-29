const std = @import("std");
const builtin = @import("builtin");
const gl = @import("gl");
const engine = @import("engine");
const verts = @import("light_map_verts.zig");
const v = verts.verts;
const Vertex = verts.Vertex;
const cubes_and_lights = @import("verts.zig");
const cubes = cubes_and_lights.cubes;
const lights = cubes_and_lights.lights;
const imgui = @import("imgui").c;

const glm = @import("zmath");
const math = std.math;

const WIDTH: f32 = 1800;
const HEIGHT: f32 = WIDTH / 1.77777;

fn indexedUniformName(arena: std.mem.Allocator, uniform: []const u8, index: usize, prop: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(arena, "{s}[{d}].{s}", .{ uniform, index, prop });
}

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
        .texture_loader = engine.TextureLoader.init(allocator),
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

    // MODEL TESTING
    // var test_model = engine.Model.init(allocator, "./resources/models/backpack/backpack.obj");
    var test_model = engine.Model.init(allocator, "./resources/models/nanosuit/nanosuit.obj");
    try test_model.load(&eng.texture_loader);
    defer test_model.deinit();
    var err = gl.GetError();
    // MODEL TESTING

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

    // var light_attribs = [_]engine.Shader.VertexAttribute{
    //     .{
    //         .name = "aPos",
    //         .type = .float,
    //         .size = @typeInfo(@FieldType(Vertex, "pos")).array.len,
    //         .stride = @sizeOf(Vertex),
    //         .offset = @offsetOf(Vertex, "pos"),
    //     },
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
            .size = @sizeOf(@TypeOf(v)),
            .data = &v,
            .usage = .static_draw,
        },
        .ebo = &ebo,
    };

    var shader = engine.Shader.init(
        allocator,
        .{
            .vertexPath = "./resources/shaders/lit-object/vert.glsl",
            .fragmentPath = "./resources/shaders/lit-object/frag.glsl",

            // .vertexPath = "./resources/shaders/model_vert.glsl",
            // .fragmentPath = "./resources/shaders/model_frag.glsl",
        },
        vao,
    );

    try shader.load();
    defer shader.deinit();

    var camera: engine.Camera = .init;
    camera.speed = 5;
    camera.pos = .{ 1, 2, 5, 0 };

    eng.start();
    camera.look_at = @splat(0);

    shader.use();

    err = gl.GetError();
    std.debug.print("gl err {x}\n", .{err});

    const light: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    const point_light: @Vector(4, f32) = .{ 1, 1, 1, 1 };
    // const point_light: @Vector(4, f32) = @splat(0);

    while (eng.run()) {
        eng.startFrame();
        eng.startUIFrame();

        if (eng.keyPressed(.esc)) {
            break;
        }

        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();

        gl.ClearColor(0.1, 0.1, 0.1, 0.1);
        gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        camera.update(&eng);

        shader.use();
        shader.setMat4("view", camera.view);
        shader.setMat4("projection", camera.projection);

        const model = glm.identity();
        shader.setMat4("model", model);
        shader.setFloat("material.shininess", 64);

        // Directional light
        // shader.setVec3("dirLight.direction", .{ -1, -1, -1, 0 });
        shader.setVec3("dirLight.direction", .{ -0.2, -1, -0.3, 0 });
        shader.setVec3("dirLight.ambient", glm.f32x4s(0.2));
        shader.setVec3("dirLight.diffuse", light * glm.f32x4s(1));
        shader.setVec3("dirLight.specular", @splat(1));

        // shader.setInt("numLights", 0);
        shader.setInt("numLights", lights.len);

        for (lights, 0..) |l, i| {
            var pl = point_light;
            pl[1] *= @sin(@as(f32, @floatFromInt(i)));
            const diffuse = pl * glm.f32x4s(0.5);
            const ambient = diffuse * glm.f32x4s(0.2);
            shader.setVec3(try indexedUniformName(arena.allocator(), "pointLights", i, "position"), l);
            shader.setFloat(try indexedUniformName(arena.allocator(), "pointLights", i, "constant"), 1);
            shader.setFloat(try indexedUniformName(arena.allocator(), "pointLights", i, "linear"), 0.09);
            shader.setFloat(try indexedUniformName(arena.allocator(), "pointLights", i, "quadratic"), 0.032);

            // shader.setVec3(try indexedUniformName(arena.allocator(), "pointLights", i, "ambient"), glm.f32x4s(0.1));
            // shader.setVec3(try indexedUniformName(arena.allocator(), "pointLights", i, "diffuse"), point_light * glm.f32x4s(0.8));

            shader.setVec3(try indexedUniformName(arena.allocator(), "pointLights", i, "ambient"), ambient);
            shader.setVec3(try indexedUniformName(arena.allocator(), "pointLights", i, "diffuse"), diffuse);

            shader.setVec3(try indexedUniformName(arena.allocator(), "pointLights", i, "specular"), pl);
        }

        test_model.draw(&shader);

        eng.endUIFrame();
        eng.endFrame();
    }

    err = gl.GetError();
    std.debug.print("gl err {x}\n", .{err});
}
