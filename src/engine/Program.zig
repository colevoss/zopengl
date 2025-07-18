const std = @import("std");
const gl = @import("gl");
const Shader = @import("Shader.zig");

const Program = @This();

pub const Error = error{
    LinkError,
};

program_id: u32 = undefined,

attribs: std.StringHashMap(u32) = undefined,
gpa: std.mem.Allocator,

pub fn init(gpa: std.mem.Allocator) Program {
    const program_id = gl.CreateProgram();

    return .{
        .program_id = program_id,
        .attribs = std.StringHashMap(u32).init(gpa),
        .gpa = gpa,
    };
}

pub fn deinit(self: *Program) void {
    self.attribs.deinit();
}

pub fn attachShader(self: *Program, shader: *Shader) void {
    gl.AttachShader(self.program_id, shader.shader_id);
}

pub fn link(self: *Program) Error!void {
    gl.LinkProgram(self.program_id);

    var success: c_int = undefined;

    gl.GetProgramiv(self.program_id, gl.LINK_STATUS, &success);

    if (success != gl.TRUE) {
        return Error.LinkError;
    }
}

pub fn use(self: *Program) void {
    gl.UseProgram(self.program_id);
}

pub fn infoLog(self: *Program) void {
    var buf: [512]u8 = undefined;
    gl.GetProgramInfoLog(self.program_id, 512, null, &buf);

    std.debug.print("Program Err: {s}\n", .{buf});
}

pub const VertexAttribType = enum(c_int) {
    Byte = gl.BYTE,
    UByte = gl.UNSIGNED_BYTE,
    Short = gl.SHORT,
    UShort = gl.UNSIGNED_SHORT,
    Int = gl.INT,
    UInt = gl.UNSIGNED_INT,
    Float = gl.FLOAT,
    Double = gl.DOUBLE,
    Fixed = gl.FIXED,
};

pub const VertexAttrib = struct {
    name: []const u8,
    type: VertexAttribType,
    size: u32,
    stride: u32,
    normalized: bool = false,
    offset: u32,
};

pub fn vertexAttrib(self: *Program, vab: VertexAttrib) !void {
    const id: u32 = gl.GetAttribLocation(self.program_id, vab.name);

    try self.attribs.put(vab.name, id);

    gl.VertexAttribPointer(
        id,
        vab.size,
        vab.type,
        if (vab.normalize) gl.TRUE else gl.FALSE,
        vab.stride,
        vab.offset,
    );
}
