const std = @import("std");
const Texture = @import("Texture.zig");
const zimg = @import("zigimg");
const gl = @import("gl");

const log = std.log.scoped(.texture_loader);

const Allocator = std.mem.Allocator;

const TextureLoader = @This();

allocator: Allocator,
textures: std.StringArrayHashMap(Texture),

pub const Opts = struct {
    dir: []const u8,
    file_name: []const u8,
    // path: []const u8,

    type: Texture.Type,
    target: Texture.Target = .texture_2d,

    s_wrap: Texture.Wrapping = .repeat,
    t_wrap: Texture.Wrapping = .repeat,

    min_filter: Texture.Filtering = .lienar_mip_map_linear,
    mag_filter: Texture.Filtering = .linear,
};

pub fn init(gpa: Allocator) TextureLoader {
    return .{
        .allocator = gpa,
        .textures = std.StringArrayHashMap(Texture).init(gpa),
    };
}

pub fn deinit(self: *TextureLoader) void {
    var iter = self.textures.iterator();

    while (iter.next()) |e| {
        e.value_ptr.delete();
        self.allocator.free(e.key_ptr.*);
    }

    self.textures.deinit();
}

pub fn load(self: *TextureLoader, opts: Opts) !Texture {
    const path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ opts.dir, opts.file_name });

    if (self.textures.get(path)) |t| {
        self.allocator.free(path);
        return t;
    }

    log.debug("loading texture: {s}", .{path});

    const tex_type = opts.target.glType();

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    var image = try zimg.Image.fromFile(self.allocator, &file);
    defer image.deinit();

    try image.flipVertically();
    // const format = Texture.Format.fromImage(&image).glType();
    const format = Texture.Format.fromImage(&image);

    var texture: Texture = .{
        .path = path,
        .type = opts.type,
        .target = opts.target,
    };
    texture.init();

    try self.textures.put(path, texture);

    texture.bind();

    gl.TexParameteri(tex_type, Texture.WrappingParam.s.glType(), opts.s_wrap.glType());
    gl.TexParameteri(tex_type, Texture.WrappingParam.t.glType(), opts.t_wrap.glType());
    gl.TexParameteri(tex_type, Texture.FilterParam.min.glType(), opts.min_filter.glType());
    gl.TexParameteri(tex_type, Texture.FilterParam.mag.glType(), opts.mag_filter.glType());

    gl.TexImage2D(
        tex_type,
        0,
        @intCast(format.glType()),
        @intCast(image.width),
        @intCast(image.height),
        0, // always be 0.
        format.glType(),
        gl.UNSIGNED_BYTE,
        image.rawBytes().ptr,
    );
    gl.GenerateMipmap(tex_type);

    return texture;
}
