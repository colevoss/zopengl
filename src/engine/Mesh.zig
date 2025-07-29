const std = @import("std");
const gl = @import("gl");
const assimp = @import("assimp.zig");
const Texture = @import("Texture.zig");
const TextureLoader = @import("TextureLoader.zig");
const Shader = @import("Shader.zig");

const log = std.log.scoped(.mesh);

const Allocator = std.mem.Allocator;

const Mesh = @This();

pub const Vertex = extern struct {
    position: [3]f32,
    normals: [3]f32,
    tex_coords: [2]f32,
};

const VertListUnmanaged = std.ArrayListUnmanaged(Vertex);
const IndexListUnmanaged = std.ArrayListUnmanaged(u32);
const TextureHandleListUnmanaged = std.ArrayListUnmanaged(Texture);

// TODO: I think we just use a normal Texture instead of this type
pub const TextureHandle = struct {
    id: u32,
    type: Texture.Type,
    path: []const u8,

    pub fn delete(self: *TextureHandle) void {
        gl.DeleteTextures(1, (&self.id)[0..1]); // TODO: Is this right?
    }
};

vertices: VertListUnmanaged,
indices: IndexListUnmanaged,
textures: TextureHandleListUnmanaged,

vao: Vao = undefined,

pub const init: Mesh = .{
    .vertices = VertListUnmanaged{},
    .indices = IndexListUnmanaged{},
    .textures = TextureHandleListUnmanaged{},
};

pub fn deinit(self: *Mesh, gpa: Allocator) void {
    self.vertices.deinit(gpa);
    self.indices.deinit(gpa);

    // for (self.textures.items) |*t| {
    //     t.delete();
    //     gpa.free(t.path);
    // }

    self.textures.deinit(gpa);
}

pub fn loadFromAssimp(self: *Mesh, gpa: Allocator, texture_loader: *TextureLoader, ai_mesh: *assimp.Mesh, ai_scene: *assimp.Scene, dir: []const u8) !void {
    try self.processVerts(gpa, ai_mesh);
    try self.processIndicies(gpa, ai_mesh);
    try self.processMaterials(gpa, texture_loader, ai_mesh, ai_scene, dir);

    self.load();
}

fn processVerts(self: *Mesh, gpa: Allocator, ai_mesh: *assimp.Mesh) !void {
    const vert_count = ai_mesh.mNumVertices;
    try self.vertices.ensureTotalCapacity(gpa, vert_count);

    var i: u32 = 0;

    while (i < vert_count) {
        var vert = self.vertices.addOneAssumeCapacity();

        const ai_vert = ai_mesh.mVertices[i];

        vert.position[0] = ai_vert.x;
        vert.position[1] = ai_vert.y;
        vert.position[2] = ai_vert.z;

        const ai_normals = ai_mesh.mNormals[i];
        vert.normals[0] = ai_normals.x;
        vert.normals[1] = ai_normals.y;
        vert.normals[2] = ai_normals.z;

        if (ai_mesh.mTextureCoords.len > 0) {
            const ai_tex_coords = ai_mesh.mTextureCoords[0][i];
            vert.tex_coords[0] = ai_tex_coords.x;
            vert.tex_coords[1] = ai_tex_coords.y;
        } else {
            // Do we need to do this???
            vert.tex_coords = .{ 0, 0 };
        }

        i += 1;
    }
}

fn processIndicies(self: *Mesh, gpa: Allocator, ai_mesh: *assimp.Mesh) !void {
    const face_count = ai_mesh.mNumFaces;
    var i: u32 = 0;

    while (i < face_count) {
        const ai_face = ai_mesh.mFaces[i];

        var f: u32 = 0;
        const index_count = ai_face.mNumIndices;

        try self.indices.ensureUnusedCapacity(gpa, index_count);

        while (f < index_count) {
            self.indices.appendAssumeCapacity(ai_face.mIndices[f]);
            f += 1;
        }

        i += 1;
    }
}

fn processMaterials(self: *Mesh, gpa: Allocator, texture_loader: *TextureLoader, ai_mesh: *assimp.Mesh, ai_scene: *assimp.Scene, dir: []const u8) !void {
    if (ai_mesh.mMaterialIndex < 0) {
        return;
    }

    const ai_mat = try assimp.sceneMaterial(ai_scene, ai_mesh.mMaterialIndex);

    const diffuse_count = assimp.materialTextureCount(ai_mat, .diffuse);
    try self.textures.ensureUnusedCapacity(gpa, diffuse_count);

    var i: u32 = 0;

    var arena = std.heap.ArenaAllocator.init(gpa);
    const aa = arena.allocator();
    defer arena.deinit();

    while (i < diffuse_count) {
        const path = try assimp.getMaterialTexture(aa, ai_mat, .diffuse, i);
        const handle = self.textures.addOneAssumeCapacity();

        handle.* = try texture_loader.load(.{
            .dir = dir,
            .file_name = path,
            .type = .diffuse,
        });

        i += 1;
    }

    i = 0;

    const specular_count = assimp.materialTextureCount(ai_mat, .specular);
    try self.textures.ensureUnusedCapacity(gpa, specular_count);

    while (i < specular_count) {
        const path = try assimp.getMaterialTexture(aa, ai_mat, .specular, i);

        const handle = self.textures.addOneAssumeCapacity();

        handle.* = try texture_loader.load(.{
            .dir = dir,
            .file_name = path,
            .type = .specular,
        });

        i += 1;
    }
}

pub fn load(self: *Mesh) void {
    const vbo: Vbo = .{
        .type = .array,
        .size = @sizeOf(Vertex) * @as(u32, @intCast(self.vertices.items.len)),
        // .data = @ptrCast(&self.vertices.items),
        .data = self.vertices.items.ptr,
        .usage = .static_draw,
    };

    const ebo: Vbo = .{
        .type = .element_array,
        .size = @sizeOf(u32) * @as(u32, @intCast(self.indices.items.len)),
        .data = self.indices.items.ptr,
        .usage = .static_draw,
    };

    self.vao = .{
        .attributes = &default_attributes,
        .vbo = vbo,
        .ebo = ebo,
    };

    self.vao.init();
    self.vao.load();
}

pub fn draw(self: *const Mesh, shader: *const Shader) void {
    var diffuse_index: u32 = 0;
    var specular_index: u32 = 0;

    for (self.textures.items, 0..) |texture, i| {
        const active = Texture.active(@intCast(i));
        // log.debug("active texture {d}", .{active});
        gl.ActiveTexture(active);

        const name = switch (texture.type) {
            .diffuse => blk: {
                const uniform_name = diffuse_uniform_names[diffuse_index];
                diffuse_index += 1;
                break :blk uniform_name;
            },
            .specular => blk: {
                const uniform_name = specular_uniform_names[specular_index];
                specular_index += 1;
                break :blk uniform_name;
            },
        };

        // log.debug("texture name {s}", .{name});

        shader.setSampler2d(name, @intCast(i));
        texture.bind();
    }

    self.vao.bind();
    gl.DrawElements(gl.TRIANGLES, @intCast(self.indices.items.len), gl.UNSIGNED_INT, 0);
}

pub const Vbo = struct {
    id: u32 = undefined,

    type: BufferBindingTarget,
    size: u32,
    data: *anyopaque,
    usage: BufferUsage,

    pub fn init(self: *Vbo) void {
        gl.GenBuffers(1, (&self.id)[0..1]);
    }

    pub fn load(self: *const Vbo) void {
        gl.BindBuffer(self.type.glType(), self.id);
        gl.BufferData(self.type.glType(), self.size, self.data, self.usage.glType());
    }
};

pub const Vao = struct {
    id: u32 = undefined,

    vbo: Vbo,
    ebo: ?Vbo,
    attributes: []VertexAttribute,

    pub fn init(self: *Vao) void {
        gl.GenVertexArrays(1, (&self.id)[0..1]);

        self.vbo.init();

        if (self.ebo) |*ebo| {
            ebo.init();
        }
    }

    pub fn bind(self: *const Vao) void {
        gl.BindVertexArray(self.id);
    }

    pub fn load(self: *Vao) void {
        self.bind();
        self.vbo.load();

        if (self.ebo) |ebo| {
            ebo.load();
        }

        self.registerAttributes();
    }

    fn registerAttributes(self: *Vao) void {
        for (self.attributes, 0..) |attribute, id| {
            gl.VertexAttribPointer(
                @intCast(id),
                @intCast(attribute.size),
                attribute.type.glType(),
                if (attribute.normalized) gl.TRUE else gl.FALSE,
                @intCast(attribute.stride),
                attribute.offset,
            );

            gl.EnableVertexAttribArray(@intCast(id));
        }
    }
};

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

var default_attributes = [_]VertexAttribute{
    .{
        .name = "aPos",
        .type = .float,
        .size = @typeInfo(@FieldType(Vertex, "position")).array.len,
        .stride = @sizeOf(Vertex),
        .offset = @offsetOf(Vertex, "position"),
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
        .size = @typeInfo(@FieldType(Vertex, "tex_coords")).array.len,
        .stride = @sizeOf(Vertex),
        .offset = @offsetOf(Vertex, "tex_coords"),
    },
};

const diffuse_uniform_names = [_][]const u8{
    "material.diffuse",
    // "texture_diffuse1",
    // "texture_diffuse2",
    // "texture_diffuse3",
    // "texture_diffuse4",
    // "texture_diffuse5",
    // "material.texture_diffuse1",
    // "material.texture_diffuse2",
    // "material.texture_diffuse3",
    // "material.texture_diffuse4",
    // "material.texture_diffuse5",
};

const specular_uniform_names = [_][]const u8{
    "material.specular",
    // "texture_specular1",
    // "texture_specular2",
    // "texture_specular3",
    // "texture_specular4",
    // "texture_specular5",

    // "material.texture_specular1",
    // "material.texture_specular2",
    // "material.texture_specular3",
    // "material.texture_specular4",
    // "material.texture_specular5",
};
