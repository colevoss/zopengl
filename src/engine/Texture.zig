const std = @import("std");
const gl = @import("gl");
const zimg = @import("zigimg");
const Allocator = std.mem.Allocator;

const Texture = @This();

id: u32 = undefined,
path: []const u8,
type: Type,
target: Target,

pub fn init(self: *Texture) void {
    gl.GenTextures(1, (&self.id)[0..1]);
}

pub fn bind(self: *const Texture) void {
    gl.BindTexture(self.target.glType(), self.id);
}

pub fn load(self: *Texture, allocator: Allocator) !void {
    self.bind();
    const tex_type = self.opts.type.glType();

    gl.TexParameteri(tex_type, WrappingParam.s.glType(), self.opts.s_wrap.glType());
    gl.TexParameteri(tex_type, WrappingParam.t.glType(), self.opts.t_wrap.glType());
    gl.TexParameteri(tex_type, FilterParam.min.glType(), self.opts.min_filter.glType());
    gl.TexParameteri(tex_type, FilterParam.mag.glType(), self.opts.mag_filter.glType());

    var file = try std.fs.cwd().openFile(self.opts.path, .{});
    defer file.close();

    var image = try zimg.Image.fromFile(allocator, &file);
    try image.flipVertically();

    defer image.deinit();

    const format = Format.fromImage(&image).glType();

    // TODO: Load image
    gl.TexImage2D(
        tex_type,
        0,
        @intCast(format),
        @intCast(image.width),
        @intCast(image.height),
        0, // always be 0.
        // self.opts.format.glType(),
        format,
        gl.UNSIGNED_BYTE,
        image.rawBytes().ptr,
    );
    gl.GenerateMipmap(tex_type);
}

pub fn delete(self: *Texture) void {
    gl.DeleteTextures(1, (&self.id)[0..1]); // TODO: Is this right?
}

pub const Type = enum {
    diffuse,
    specular,
};

pub const Target = enum {
    texture_2d,
    // Texture1DArray,
    // Texture2DArray,
    // Texture2DMultisample,
    // Texture2DMultisampleArray,
    // Texture3D,
    // TextureCubeMap,
    // TextureCubeMapArray,
    // TextureRectangle,

    pub inline fn glType(self: Target) c_uint {
        return switch (self) {
            .texture_2d => gl.TEXTURE_2D,
            // .Texture1DArray => gl.TEXTURE_1D_ARRAY,
            // .Texture2DArray => gl.TEXTURE_2D_ARRAY,
            // .Texture2DMultisample => gl.TEXTURE_2D_MULTISAMPLE,
            // .Texture2DMultisampleArray => gl.TEXTURE_2D_MULTISAMPLE_ARRAY,
            // .Texture3D => gl.TEXTURE_3D,
            // .TextureCubeMap => gl.TEXTURE_CUBE_MAP,
            // .TextureCubeMapArray => gl.TEXTURE_CUBE_MAP_ARRAY,
            // .TextureRectangle => gl.TEXTURE_RECTANGLE,
        };
    }
};

pub const WrappingParam = enum {
    s,
    t,
    r,

    pub inline fn glType(self: WrappingParam) c_uint {
        return switch (self) {
            .s => gl.TEXTURE_WRAP_S,
            .t => gl.TEXTURE_WRAP_T,
            .r => gl.TEXTURE_WRAP_R,
        };
    }
};

pub const Wrapping = enum {
    repeat,
    mirrored_repeat,
    clamp_to_edge,
    clamp_to_border,

    pub inline fn glType(self: Wrapping) c_int {
        return switch (self) {
            .repeat => gl.REPEAT,
            .mirrored_repeat => gl.MIRRORED_REPEAT,
            .clamp_to_edge => gl.CLAMP_TO_EDGE,
            .clamp_to_border => gl.CLAMP_TO_BORDER,
        };
    }
};

pub const FilterParam = enum {
    min,
    mag,

    pub inline fn glType(self: FilterParam) c_uint {
        return switch (self) {
            .min => gl.TEXTURE_MIN_FILTER,
            .mag => gl.TEXTURE_MAG_FILTER,
        };
    }
};

pub const Filtering = enum {
    nearest,
    linear,

    // mipmaps
    nearest_mip_map_nearest,
    linear_mip_map_nearest,
    nearest_mip_map_linear,
    lienar_mip_map_linear,

    pub inline fn glType(self: Filtering) c_int {
        return switch (self) {
            .nearest => gl.NEAREST,
            .linear => gl.LINEAR,

            .nearest_mip_map_nearest => gl.NEAREST_MIPMAP_NEAREST,
            .linear_mip_map_nearest => gl.LINEAR_MIPMAP_NEAREST,
            .nearest_mip_map_linear => gl.NEAREST_MIPMAP_LINEAR,
            .lienar_mip_map_linear => gl.LINEAR_MIPMAP_LINEAR,
        };
    }
};

pub const Format = enum {
    red,
    rg,
    rgb,
    bgr,
    rgba,
    bgra,
    red_integer,
    rg_integer,
    rgb_integer,
    bgr_integer,
    rgba_integer,
    bgra_integer,
    stencil_index,
    depth_component,
    depth_stencil,

    pub inline fn glType(self: Format) c_uint {
        return switch (self) {
            .red => gl.RED,
            .rg => gl.RG,
            .rgb => gl.RGB,
            .bgr => gl.BGR,
            .rgba => gl.RGBA,
            .bgra => gl.BGRA,
            .red_integer => gl.RED_INTEGER,
            .rg_integer => gl.RG_INTEGER,
            .rgb_integer => gl.RGB_INTEGER,
            .bgr_integer => gl.BGR_INTEGER,
            .rgba_integer => gl.RGBA_INTEGER,
            .bgra_integer => gl.BGRA_INTEGER,
            .stencil_index => gl.STENCIL_INDEX,
            .depth_component => gl.DEPTH_COMPONENT,
            .depth_stencil => gl.DEPTH_STENCIL,
        };
    }

    pub fn fromImage(image: *zimg.Image) Format {
        return switch (image.pixelFormat()) {
            .rgb332, .rgb555, .rgb565, .rgb24, .rgb48 => .rgb,
            .rgba32, .rgba64 => .rgba,
            else => unreachable,
        };
    }
};

pub fn active(i: u32) c_uint {
    const c_i: c_uint = @intCast(i);
    const zero: c_uint = @intCast(gl.TEXTURE0);
    return zero + c_i;
}
