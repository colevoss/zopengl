const gl = @import("gl");

pub inline fn boolean(value: c_int) bool {
    return value == gl.TRUE;
}
