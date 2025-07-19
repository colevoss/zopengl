const std = @import("std");
const Allocator = std.mem.Allocator;
const gl = @import("gl");
const opengl = @import("opengl.zig");
const math = @import("zmath");

const log = std.log.scoped(.shader);

const Shader = @This();

pub const ShaderOpts = struct {
    vertexPath: []const u8,
    fragmentPath: []const u8,
};

pub const Error = error{
    CompileError,
    LinkError,
};

vertex_attributes: std.StringHashMap(u32),
uniforms: ?[][]const u8,

vbo: u32 = undefined,
program_id: u32 = undefined,
uniform_ids: std.StringHashMap(i32),

opts: ShaderOpts,
gpa: Allocator,
vao: Vao,

pub fn init(gpa: Allocator, opts: ShaderOpts, vao: Vao, uniforms: ?[][]const u8) Shader {
    return .{
        .opts = opts,
        .gpa = gpa,
        .vao = vao,
        .vertex_attributes = std.StringHashMap(u32).init(gpa),
        .uniforms = uniforms,
        .uniform_ids = std.StringHashMap(i32).init(gpa),
    };
}

pub fn deinit(self: *Shader) void {
    self.delete();
    self.vertex_attributes.deinit();
    self.uniform_ids.deinit();
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
    try self.loadUniforms(aa);
}

pub fn use(self: *Shader) void {
    gl.UseProgram(self.program_id);
}

pub fn delete(self: *Shader) void {
    gl.DeleteProgram(self.program_id);
}

pub fn setInt(self: *Shader, uniform: []const u8, i: i32) void {
    if (self.uniform_ids.get(uniform)) |id| {
        gl.Uniform1i(id, i);
    }
}

pub fn set4f(self: *Shader, uniform: []const u8, values: [4]f32) void {
    if (self.uniform_ids.get(uniform)) |id| {
        gl.Uniform4f(
            id,
            values[0],
            values[1],
            values[2],
            values[3],
        );
    }
}

pub fn setMat4(self: *Shader, uniform: []const u8, mat: math.Mat) void {
    if (self.uniform_ids.get(uniform)) |id| {
        gl.UniformMatrix4fv(
            id,
            1,
            gl.FALSE,
            math.arrNPtr(&mat),
        );
    }
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
