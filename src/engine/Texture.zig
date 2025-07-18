const std = @import("std");
const gl = @import("gl");
const zimg = @import("zigimg");
const Allocator = std.mem.Allocator;

const Texture = @This();

id: u32 = undefined,
allocator: Allocator,
opts: Opts,

pub const Opts = struct {
    path: []const u8,
    type: Target,
    format: Format,
    s_wrap: Wrapping = .Repeat,
    t_wrap: Wrapping = .Repeat,

    min_filter: Filtering = .LienarMipMapLinear,
    mag_filter: Filtering = .Linear,
};

pub fn init(allocator: Allocator, opts: Opts) Texture {
    var texture: Texture = .{
        .allocator = allocator,
        .opts = opts,
    };

    texture.gen();

    return texture;
}

fn gen(self: *Texture) void {
    gl.GenTextures(1, (&self.id)[0..1]);
}

pub fn bind(self: *Texture) void {
    gl.BindTexture(self.opts.type.glType(), self.id);
}

pub fn load(self: *Texture) !void {
    self.bind();
    const tex_type = self.opts.type.glType();

    gl.TexParameteri(tex_type, WrappingParam.S.glType(), self.opts.s_wrap.glType());
    gl.TexParameteri(tex_type, WrappingParam.T.glType(), self.opts.t_wrap.glType());
    gl.TexParameteri(tex_type, FilterParam.Min.glType(), self.opts.min_filter.glType());
    gl.TexParameteri(tex_type, FilterParam.Mag.glType(), self.opts.mag_filter.glType());

    var file = try std.fs.cwd().openFile(self.opts.path, .{});
    defer file.close();

    var image = try zimg.Image.fromFile(self.allocator, &file);
    try image.flipVertically();

    defer image.deinit();

    // TODO: Load image
    gl.TexImage2D(
        tex_type,
        0,
        gl.RGB,
        @intCast(image.width),
        @intCast(image.height),
        0, // always be 0.
        self.opts.format.glType(),
        gl.UNSIGNED_BYTE,
        image.rawBytes().ptr,
    );
    gl.GenerateMipmap(tex_type);
}

pub fn delete(self: *Texture) void {
    gl.DeleteTextures(1, (&self.id)[0..1]); // TODO: Is this right?

    errdefer self.delete();
}

pub const Target = enum {
    Texture2D,
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
            .Texture2D => gl.TEXTURE_2D,
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
    S,
    T,
    R,

    pub inline fn glType(self: WrappingParam) c_uint {
        return switch (self) {
            .S => gl.TEXTURE_WRAP_S,
            .T => gl.TEXTURE_WRAP_T,
            .R => gl.TEXTURE_WRAP_R,
        };
    }
};

pub const Wrapping = enum {
    Repeat,
    MirroredRepeat,
    ClampToEdge,
    ClampToBorder,

    pub inline fn glType(self: Wrapping) c_int {
        return switch (self) {
            .Repeat => gl.REPEAT,
            .MirroredRepeat => gl.MIRRORED_REPEAT,
            .ClampToEdge => gl.CLAMP_TO_EDGE,
            .ClampToBorder => gl.CLAMP_TO_BORDER,
        };
    }
};

pub const FilterParam = enum {
    Min,
    Mag,

    pub inline fn glType(self: FilterParam) c_uint {
        return switch (self) {
            .Min => gl.TEXTURE_MIN_FILTER,
            .Mag => gl.TEXTURE_MAG_FILTER,
        };
    }
};

pub const Filtering = enum {
    Nearest,
    Linear,

    // mipmaps
    NearestMipMapNearest,
    LinearMipMapNearest,
    NearestMipMapLinear,
    LienarMipMapLinear,

    pub inline fn glType(self: Filtering) c_int {
        return switch (self) {
            .Nearest => gl.NEAREST,
            .Linear => gl.LINEAR,

            .NearestMipMapNearest => gl.NEAREST_MIPMAP_NEAREST,
            .LinearMipMapNearest => gl.LINEAR_MIPMAP_NEAREST,
            .NearestMipMapLinear => gl.NEAREST_MIPMAP_LINEAR,
            .LienarMipMapLinear => gl.LINEAR_MIPMAP_LINEAR,
        };
    }
};

pub const Format = enum {
    Red,
    Rg,
    Rgb,
    Bgr,
    Rgba,
    Bgra,
    RedInteger,
    RgInteger,
    RgbInteger,
    BgrInteger,
    RgbaInteger,
    BgraInteger,
    StencilIndex,
    DepthComponent,
    DepthStencil,

    pub inline fn glType(self: Format) c_uint {
        return switch (self) {
            .Red => gl.RED,
            .Rg => gl.RG,
            .Rgb => gl.RGB,
            .Bgr => gl.BGR,
            .Rgba => gl.RGBA,
            .Bgra => gl.BGRA,
            .RedInteger => gl.RED_INTEGER,
            .RgInteger => gl.RG_INTEGER,
            .RgbInteger => gl.RGB_INTEGER,
            .BgrInteger => gl.BGR_INTEGER,
            .RgbaInteger => gl.RGBA_INTEGER,
            .BgraInteger => gl.BGRA_INTEGER,
            .StencilIndex => gl.STENCIL_INDEX,
            .DepthComponent => gl.DEPTH_COMPONENT,
            .DepthStencil => gl.DEPTH_STENCIL,
        };
    }
};

pub fn active(i: u32) c_uint {
    const c_i: c_uint = @intCast(i);
    const zero: c_uint = @intCast(gl.TEXTURE0);
    return zero + c_i;
}
