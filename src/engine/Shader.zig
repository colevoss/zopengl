const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const opengl = @import("opengl.zig");
const math = @import("zmath");
const assert = std.debug.assert;

const log = std.log.scoped(.shader);

const Shader = @This();

pub const ShaderOpts = struct {
    vertexPath: []const u8,
    fragmentPath: []const u8,
};

pub const Error = error{
    CompileError,
    LinkError,
    UniformError,
};

vbo: u32 = undefined,
program_id: u32 = undefined,
uniform_ids: std.StringHashMap(Uniform),

opts: ShaderOpts,
gpa: Allocator,
vao: Vao,

pub fn init(gpa: Allocator, opts: ShaderOpts, vao: Vao) Shader {
    return .{
        .opts = opts,
        .gpa = gpa,
        .vao = vao,
        .uniform_ids = std.StringHashMap(Uniform).init(gpa),
    };
}

pub fn deinit(self: *Shader) void {
    var iter = self.uniform_ids.iterator();

    while (iter.next()) |e| {
        self.gpa.free(e.key_ptr.*);
    }

    self.uniform_ids.deinit();
    self.delete();
}

pub fn load(self: *Shader) !void {
    var arena = std.heap.ArenaAllocator.init(self.gpa);
    defer arena.deinit();

    const aa = arena.allocator();

    var vertex_source: ShaderSource = .{
        .path = self.opts.vertexPath,
        .type = .vertex,
    };

    try vertex_source.load(aa);
    defer vertex_source.delete();

    var fragment_source: ShaderSource = .{
        .path = self.opts.fragmentPath,
        .type = .fragment,
    };

    try fragment_source.load(aa);
    defer fragment_source.delete();

    vertex_source.compile() catch |e| {
        vertex_source.infoLog();
        return e;
    };

    fragment_source.compile() catch |e| {
        fragment_source.infoLog();
        return e;
    };

    self.program_id = gl.CreateProgram();
    errdefer self.delete();

    gl.AttachShader(self.program_id, vertex_source.shader_id);
    gl.AttachShader(self.program_id, fragment_source.shader_id);

    self.link() catch |e| {
        self.infoLog();
        return e;
    };

    self.vao.init();
    try self.vao.load(aa, self.program_id);
    try self.loadUniformData(aa);
}

pub fn loadUniformData(self: *Shader, arena: Allocator) !void {
    var active_uniforms: i32 = undefined;
    gl.GetProgramiv(self.program_id, gl.ACTIVE_UNIFORMS, &active_uniforms);

    log.debug("loading {d} uniforms from shader", .{active_uniforms});

    try self.uniform_ids.ensureTotalCapacity(@intCast(active_uniforms));

    var i: u32 = 0;

    while (i < active_uniforms) {
        var buf: [256]u8 = undefined;
        var len: i32 = undefined;
        var size: i32 = undefined;
        var t: c_uint = undefined;

        gl.GetActiveUniform(self.program_id, @as(c_uint, i), 256, &len, &size, &t, &buf);

        const name = try self.gpa.dupe(u8, buf[0..@intCast(len) :0]);

        const c_name = try arena.dupeZ(u8, name);
        const id: i32 = @intCast(gl.GetUniformLocation(self.program_id, c_name));

        const uniform: Uniform = .{
            .id = id,
            .name = name,
            .size = @intCast(size),
            .type = Uniform.Type.fromGL(t),
        };

        try self.uniform_ids.put(name, uniform);

        i += 1;
    }
}

pub fn use(self: *const Shader) void {
    gl.UseProgram(self.program_id);
}

pub fn delete(self: *const Shader) void {
    gl.DeleteProgram(self.program_id);
}

pub fn setSampler2d(self: *const Shader, uniform: []const u8, sampler: i32) void {
    if (self.uniform_ids.get(uniform)) |u| {
        assert(u.type == .sampler_2d);
        gl.Uniform1i(u.id, sampler);
    } else unreachable;
}

pub fn setInt(self: *const Shader, uniform: []const u8, i: i32) void {
    if (self.uniform_ids.get(uniform)) |u| {
        assert(u.type == .int);
        gl.Uniform1i(u.id, i);
    } else unreachable;
}

pub fn setFloat(self: *const Shader, uniform: []const u8, f: f32) void {
    if (self.uniform_ids.get(uniform)) |u| {
        assert(u.type == .float);
        gl.Uniform1f(u.id, f);
    } else unreachable;
}

pub fn setVec3(self: *const Shader, uniform: []const u8, vec: math.Vec) void {
    if (self.uniform_ids.get(uniform)) |u| {
        assert(u.type == .float_vec3);
        gl.Uniform3fv(u.id, 1, math.arr3Ptr(&vec));
    } else unreachable;
}

pub fn set4f(self: *const Shader, uniform: []const u8, values: [4]f32) void {
    if (self.uniform_ids.get(uniform)) |u| {
        assert(u.type == .float_vec4);
        gl.Uniform4f(u.id, values[0], values[1], values[2], values[3]);
    } else unreachable;
}

pub fn setMat4(self: *const Shader, uniform: []const u8, mat: math.Mat) void {
    if (self.uniform_ids.get(uniform)) |u| {
        assert(u.type == .float_mat4);
        gl.UniformMatrix4fv(u.id, 1, gl.FALSE, math.arrNPtr(&mat));
    } else unreachable;
}

fn loadUniforms(self: *Shader, arena: Allocator) !void {
    if (self.uniforms) |uniforms| {
        for (uniforms) |uniform| {
            const name = try arena.dupeZ(u8, uniform);
            const id: i32 = @intCast(gl.GetUniformLocation(self.program_id, name));

            if (id == -1) {
                log.warn("Could not find uniform {s}", .{uniform});
                continue;
            }

            try self.uniform_ids.put(uniform, id);
        }
    }
}

pub const BufferBindingTarget = enum {
    array, // Vertex attributes
    copy_read, // Buffer copy source
    copy_write, // Buffer copy destination
    draw_indirect, // Indirect command arguments
    element_array, // Vertex array indices
    pixel_pack, // Pixel read target
    pixel_unpack, // Texture data source
    texture, // Texture data buffer
    transform_feedback, // Transform feedback buffer
    uniform, // Uniform block storage
    // AtomicCounter, // Atomic counter storage
    // DispatchIndirect, // Indirect compute dispatch commands
    // Query, // Query result buffer
    // ShaderStorage, // Read-write storage for shaders

    pub fn glType(self: BufferBindingTarget) c_uint {
        return switch (self) {
            .array => gl.ARRAY_BUFFER,
            .copy_read => gl.COPY_READ_BUFFER,
            .copy_write => gl.COPY_WRITE_BUFFER,
            .draw_indirect => gl.DRAW_INDIRECT_BUFFER,
            .element_array => gl.ELEMENT_ARRAY_BUFFER,
            .pixel_pack => gl.PIXEL_PACK_BUFFER,
            .pixel_unpack => gl.PIXEL_UNPACK_BUFFER,
            .texture => gl.TEXTURE_BUFFER,
            .transform_feedback => gl.TRANSFORM_FEEDBACK_BUFFER,
            .uniform => gl.UNIFORM_BUFFER,
            // .AtomicCounter => gl.ATOMIC_COUNTER_BUFFER,
            // .DispatchIndirect => gl.DISPATCH_INDIRECT_BUFFER,
            // .Query => gl.QUERY_BUFFER,
            // .ShaderStorage => gl.SHADER_STORAGE_BUFFER,
        };
    }
};

pub const BufferUsage = enum {
    stream_draw,
    stream_read,
    stream_copy,
    static_draw,
    static_read,
    static_copy,
    dynamic_draw,
    dynamic_read,
    dynamic_copy,

    pub fn glType(self: BufferUsage) c_uint {
        return switch (self) {
            .stream_draw => gl.STREAM_DRAW,
            .stream_read => gl.STREAM_READ,
            .stream_copy => gl.STREAM_COPY,
            .static_draw => gl.STATIC_DRAW,
            .static_read => gl.STATIC_READ,
            .static_copy => gl.STATIC_COPY,
            .dynamic_draw => gl.DYNAMIC_DRAW,
            .dynamic_read => gl.DYNAMIC_READ,
            .dynamic_copy => gl.DYNAMIC_COPY,
        };
    }
};

pub const BufferInformation = struct {
    type: BufferBindingTarget,
    size: u32,
    data: ?*const anyopaque,
    usage: BufferUsage,
};

pub const VertexAttribType = enum {
    byte,
    u_byte,
    short,
    u_short,
    int,
    u_int,
    float,
    double,
    fixed,

    pub fn glType(self: VertexAttribType) c_uint {
        return switch (self) {
            .byte => gl.BYTE,
            .u_byte => gl.UNSIGNED_BYTE,
            .short => gl.SHORT,
            .u_short => gl.UNSIGNED_SHORT,
            .int => gl.INT,
            .u_int => gl.UNSIGNED_INT,
            .float => gl.FLOAT,
            .double => gl.DOUBLE,
            .fixed => gl.FIXED,
        };
    }
};

pub const VertexAttribute = struct {
    name: []const u8,
    type: VertexAttribType,
    size: u32,
    stride: u32,
    normalized: bool = false,
    offset: u32,
};

fn link(self: *Shader) Error!void {
    gl.LinkProgram(self.program_id);

    var success: c_int = undefined;

    gl.GetProgramiv(self.program_id, gl.LINK_STATUS, &success);

    if (!opengl.boolean(success)) {
        return Error.LinkError;
    }
}

fn infoLog(self: *Shader) void {
    var buf: [512]u8 = undefined;
    gl.GetProgramInfoLog(self.program_id, 512, null, &buf);

    log.err("Shader link err: {s}", .{buf});
}

pub const Vbo = struct {
    id: u32 = undefined,

    type: BufferBindingTarget,
    size: u32,
    data: ?*const anyopaque,
    usage: BufferUsage,

    pub fn init(self: *Vbo) void {
        gl.GenBuffers(1, (&self.id)[0..1]);
    }

    pub fn load(self: *Vbo) void {
        gl.BindBuffer(self.type.glType(), self.id);

        gl.BufferData(
            self.type.glType(),
            self.size,
            self.data,
            self.usage.glType(),
        );
    }
};

pub const Vao = struct {
    id: u32 = undefined,

    vbo: Vbo,
    ebo: ?*Vbo,
    attributes: []VertexAttribute,

    pub fn init(self: *Vao) void {
        gl.GenVertexArrays(1, (&self.id)[0..1]);

        self.vbo.init();

        if (self.ebo) |ebo| {
            ebo.init();
        }
    }

    pub fn bind(self: *Vao) void {
        gl.BindVertexArray(self.id);
    }

    pub fn load(self: *Vao, gpa: Allocator, program_id: u32) !void {
        self.bind();
        self.vbo.load();

        if (self.ebo) |ebo| {
            ebo.load();
        }

        try self.registerAttributes(gpa, program_id);
    }

    fn registerAttributes(self: *Vao, arena: Allocator, program_id: u32) !void {
        for (self.attributes) |attribute| {
            const name = try arena.dupeZ(u8, attribute.name);
            const id: u32 = @intCast(gl.GetAttribLocation(program_id, name));

            gl.VertexAttribPointer(
                id,
                @intCast(attribute.size),
                attribute.type.glType(),
                if (attribute.normalized) gl.TRUE else gl.FALSE,
                @intCast(attribute.stride),
                attribute.offset,
            );

            gl.EnableVertexAttribArray(id);
        }
    }
};

pub const ShaderSource = struct {
    path: []const u8,
    type: Type,

    source: []u8 = undefined,
    shader_id: u32 = undefined,

    pub const Type = enum {
        vertex,
        fragment,

        pub fn glType(self: Type) c_uint {
            return switch (self) {
                .vertex => gl.VERTEX_SHADER,
                .fragment => gl.FRAGMENT_SHADER,
            };
        }
    };

    pub fn load(self: *ShaderSource, arena: Allocator) !void {
        log.debug("loading {s} shader source {s}", .{ @tagName(self.type), self.path });

        const file = try std.fs.cwd().openFile(self.path, .{});
        defer file.close();

        const stat = try file.stat();

        var buffered = std.io.bufferedReader(file.reader());
        var reader = buffered.reader();

        self.source = try reader.readAllAlloc(arena, stat.size);

        // Create GL Shader
        self.shader_id = gl.CreateShader(self.type.glType());
        gl.ShaderSource(
            self.shader_id,
            1,
            &.{self.source.ptr},
            &.{@intCast(self.source.len)},
        );
    }

    pub fn compile(self: *ShaderSource) Error!void {
        log.debug("compiling {s} shader: {s}", .{ @tagName(self.type), self.path });

        gl.CompileShader(self.shader_id);

        var success: c_int = undefined;

        gl.GetShaderiv(self.shader_id, gl.COMPILE_STATUS, &success);

        if (!opengl.boolean(success)) {
            return Error.CompileError;
        }
    }

    pub fn delete(self: *ShaderSource) void {
        gl.DeleteShader(self.shader_id);
    }

    pub fn infoLog(self: *ShaderSource) void {
        var buf: [512]u8 = undefined;

        gl.GetShaderInfoLog(self.shader_id, 512, null, &buf);

        log.err("{s} {s} Shader compile status: {s}", .{ self.path, @tagName(self.type), buf });
    }
};

pub const Uniform = struct {
    id: i32,
    size: u32,
    name: []const u8,
    type: Type,

    pub const Type = enum {
        float,
        float_vec2,
        float_vec3,
        float_vec4,
        double,
        double_vec2,
        double_vec3,
        double_vec4,
        int,
        int_vec2,
        int_vec3,
        int_vec4,
        unsigned_int,
        unsigned_int_vec2,
        unsigned_int_vec3,
        unsigned_int_vec4,
        bool,
        bool_vec2,
        bool_vec3,
        bool_vec4,
        float_mat2,
        float_mat3,
        float_mat4,
        float_mat2x3,
        float_mat2x4,
        float_mat3x2,
        float_mat3x4,
        float_mat4x2,
        float_mat4x3,
        double_mat2,
        double_mat3,
        double_mat4,
        double_mat2x3,
        double_mat2x4,
        double_mat3x2,
        double_mat3x4,
        double_mat4x2,
        double_mat4x3,
        sampler_1d,
        sampler_2d,
        sampler_3d,
        sampler_cube,
        sampler_1d_shadow,
        sampler_2d_shadow,
        sampler_1d_array,
        sampler_2d_array,
        sampler_1d_array_shadow,
        sampler_2d_array_shadow,
        sampler_2d_multisample,
        sampler_2d_multisample_array,
        sampler_cube_shadow,
        sampler_buffer,
        sampler_2d_rect,
        sampler_2d_rect_shadow,
        int_sampler_1d,
        int_sampler_2d,
        int_sampler_3d,
        int_sampler_cube,
        int_sampler_1d_array,
        int_sampler_2d_array,
        int_sampler_2d_multisample,
        int_sampler_2d_multisample_array,
        int_sampler_buffer,
        int_sampler_2d_rect,
        unsigned_int_sampler_1d,
        unsigned_int_sampler_2d,
        unsigned_int_sampler_3d,
        unsigned_int_sampler_cube,
        unsigned_int_sampler_1d_array,
        unsigned_int_sampler_2d_array,
        unsigned_int_sampler_2d_multisample,
        unsigned_int_sampler_2d_multisample_array,
        unsigned_int_sampler_buffer,
        unsigned_int_sampler_2d_rect,
        image_1d,
        image_2d,
        image_3d,
        image_2d_rect,
        image_cube,
        image_buffer,
        image_1d_array,
        image_2d_array,
        image_2d_multisample,
        image_2d_multisample_array,
        // int_image_1d,
        // int_image_2d,
        // int_image_3d,
        // int_image_2d_rect,
        // int_image_cube,
        // int_image_buffer,
        // int_image_1d_array,
        // int_image_2d_array,
        // int_image_2d_multisample,
        // int_image_2d_multisample_array,
        // unsigned_int_image_1d,
        // unsigned_int_image_2d,
        // unsigned_int_image_3d,
        // unsigned_int_image_2d_rect,
        // unsigned_int_image_cube,
        // unsigned_int_image_buffer,
        // unsigned_int_image_1d_array,
        // unsigned_int_image_2d_array,
        // unsigned_int_image_2d_multisample,
        // unsigned_int_image_2d_multisample_array,
        // unsigned_int_atomic_counter,
        unknown,

        pub fn fromGL(t: c_uint) Type {
            return switch (t) {
                gl.FLOAT => .float,
                gl.FLOAT_VEC2 => .float_vec2,
                gl.FLOAT_VEC3 => .float_vec3,
                gl.FLOAT_VEC4 => .float_vec4,
                gl.DOUBLE => .double,
                gl.DOUBLE_VEC2 => .double_vec2,
                gl.DOUBLE_VEC3 => .double_vec3,
                gl.DOUBLE_VEC4 => .double_vec4,
                gl.INT => .int,
                gl.INT_VEC2 => .int_vec2,
                gl.INT_VEC3 => .int_vec3,
                gl.INT_VEC4 => .int_vec4,
                gl.UNSIGNED_INT => .unsigned_int,
                gl.UNSIGNED_INT_VEC2 => .unsigned_int_vec2,
                gl.UNSIGNED_INT_VEC3 => .unsigned_int_vec3,
                gl.UNSIGNED_INT_VEC4 => .unsigned_int_vec4,
                gl.BOOL => .bool,
                gl.BOOL_VEC2 => .bool_vec2,
                gl.BOOL_VEC3 => .bool_vec3,
                gl.BOOL_VEC4 => .bool_vec4,
                gl.FLOAT_MAT2 => .float_mat2,
                gl.FLOAT_MAT3 => .float_mat3,
                gl.FLOAT_MAT4 => .float_mat4,
                gl.FLOAT_MAT2x3 => .float_mat2x3,
                gl.FLOAT_MAT2x4 => .float_mat2x4,
                gl.FLOAT_MAT3x2 => .float_mat3x2,
                gl.FLOAT_MAT3x4 => .float_mat3x4,
                gl.FLOAT_MAT4x2 => .float_mat4x2,
                gl.FLOAT_MAT4x3 => .float_mat4x3,
                gl.DOUBLE_MAT2 => .double_mat2,
                gl.DOUBLE_MAT3 => .double_mat3,
                gl.DOUBLE_MAT4 => .double_mat4,
                gl.DOUBLE_MAT2x3 => .double_mat2x3,
                gl.DOUBLE_MAT2x4 => .double_mat2x4,
                gl.DOUBLE_MAT3x2 => .double_mat3x2,
                gl.DOUBLE_MAT3x4 => .double_mat3x4,
                gl.DOUBLE_MAT4x2 => .double_mat4x2,
                gl.DOUBLE_MAT4x3 => .double_mat4x3,
                gl.SAMPLER_1D => .sampler_1d,
                gl.SAMPLER_2D => .sampler_2d,
                gl.SAMPLER_3D => .sampler_3d,
                gl.SAMPLER_CUBE => .sampler_cube,
                gl.SAMPLER_1D_SHADOW => .sampler_1d_shadow,
                gl.SAMPLER_2D_SHADOW => .sampler_2d_shadow,
                gl.SAMPLER_1D_ARRAY => .sampler_1d_array,
                gl.SAMPLER_2D_ARRAY => .sampler_2d_array,
                gl.SAMPLER_1D_ARRAY_SHADOW => .sampler_1d_array_shadow,
                gl.SAMPLER_2D_ARRAY_SHADOW => .sampler_2d_array_shadow,
                gl.SAMPLER_2D_MULTISAMPLE => .sampler_2d_multisample,
                gl.SAMPLER_2D_MULTISAMPLE_ARRAY => .sampler_2d_multisample_array,
                gl.SAMPLER_CUBE_SHADOW => .sampler_cube_shadow,
                gl.SAMPLER_BUFFER => .sampler_buffer,
                gl.SAMPLER_2D_RECT => .sampler_2d_rect,
                gl.SAMPLER_2D_RECT_SHADOW => .sampler_2d_rect_shadow,
                gl.INT_SAMPLER_1D => .int_sampler_1d,
                gl.INT_SAMPLER_2D => .int_sampler_2d,
                gl.INT_SAMPLER_3D => .int_sampler_3d,
                gl.INT_SAMPLER_CUBE => .int_sampler_cube,
                gl.INT_SAMPLER_1D_ARRAY => .int_sampler_1d_array,
                gl.INT_SAMPLER_2D_ARRAY => .int_sampler_2d_array,
                gl.INT_SAMPLER_2D_MULTISAMPLE => .int_sampler_2d_multisample,
                gl.INT_SAMPLER_2D_MULTISAMPLE_ARRAY => .int_sampler_2d_multisample_array,
                gl.INT_SAMPLER_BUFFER => .int_sampler_buffer,
                gl.INT_SAMPLER_2D_RECT => .int_sampler_2d_rect,
                gl.UNSIGNED_INT_SAMPLER_1D => .unsigned_int_sampler_1d,
                gl.UNSIGNED_INT_SAMPLER_2D => .unsigned_int_sampler_2d,
                gl.UNSIGNED_INT_SAMPLER_3D => .unsigned_int_sampler_3d,
                gl.UNSIGNED_INT_SAMPLER_CUBE => .unsigned_int_sampler_cube,
                gl.UNSIGNED_INT_SAMPLER_1D_ARRAY => .unsigned_int_sampler_1d_array,
                gl.UNSIGNED_INT_SAMPLER_2D_ARRAY => .unsigned_int_sampler_2d_array,
                gl.UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE => .unsigned_int_sampler_2d_multisample,
                gl.UNSIGNED_INT_SAMPLER_2D_MULTISAMPLE_ARRAY => .unsigned_int_sampler_2d_multisample_array,
                gl.UNSIGNED_INT_SAMPLER_BUFFER => .unsigned_int_sampler_buffer,
                gl.UNSIGNED_INT_SAMPLER_2D_RECT => .unsigned_int_sampler_2d_rect,
                // gl.IMAGE_1D => .image_1d,
                // gl.IMAGE_2D => .image_2d,
                // gl.IMAGE_3D => .image_3d,
                // gl.IMAGE_2D_RECT => .image_2d_rect,
                // gl.IMAGE_CUBE => .image_cube,
                // gl.IMAGE_BUFFER => .image_buffer,
                // gl.IMAGE_1D_ARRAY => .image_1d_array,
                // gl.IMAGE_2D_ARRAY => .image_2d_array,
                // gl.IMAGE_2D_MULTISAMPLE => .image_2d_multisample,
                // gl.IMAGE_2D_MULTISAMPLE_ARRAY => .image_2d_multisample_array,
                // gl.INT_IMAGE_1D => .int_image_1d,
                // gl.INT_IMAGE_2D => .int_image_2d,
                // gl.INT_IMAGE_3D => .int_image_3d,
                // gl.INT_IMAGE_2D_RECT => .int_image_2d_rect,
                // gl.INT_IMAGE_CUBE => .int_image_cube,
                // gl.INT_IMAGE_BUFFER => .int_image_buffer,
                // gl.INT_IMAGE_1D_ARRAY => .int_image_1d_array,
                // gl.INT_IMAGE_2D_ARRAY => .int_image_2d_array,
                // gl.INT_IMAGE_2D_MULTISAMPLE => .int_image_2d_multisample,
                // gl.INT_IMAGE_2D_MULTISAMPLE_ARRAY => .int_image_2d_multisample_array,
                // gl.UNSIGNED_INT_IMAGE_1D => .unsigned_int_image_1d,
                // gl.UNSIGNED_INT_IMAGE_2D => .unsigned_int_image_2d,
                // gl.UNSIGNED_INT_IMAGE_3D => .unsigned_int_image_3d,
                // gl.UNSIGNED_INT_IMAGE_2D_RECT => .unsigned_int_image_2d_rect,
                // gl.UNSIGNED_INT_IMAGE_CUBE => .unsigned_int_image_cube,
                // gl.UNSIGNED_INT_IMAGE_BUFFER => .unsigned_int_image_buffer,
                // gl.UNSIGNED_INT_IMAGE_1D_ARRAY => .unsigned_int_image_1d_array,
                // gl.UNSIGNED_INT_IMAGE_2D_ARRAY => .unsigned_int_image_2d_array,
                // gl.UNSIGNED_INT_IMAGE_2D_MULTISAMPLE => .unsigned_int_image_2d_multisample,
                // gl.UNSIGNED_INT_IMAGE_2D_MULTISAMPLE_ARRAY => .unsigned_int_image_2d_multisample_array,
                // gl.UNSIGNED_INT_ATOMIC_COUNTER => .unsigned_int_atomic_counter,
                else => .unknown,
            };
        }
    };
};
