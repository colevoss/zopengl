const Mouse = @This();

pos: @Vector(4, f32),
last: @Vector(4, f32),
offset: @Vector(4, f32),
scroll: Scroll = .init,

pub const Scroll = struct {
    offset: @Vector(4, f32),

    const init: Scroll = .{
        .offset = @splat(0),
    };

    pub inline fn offsetX(self: *const Scroll) f32 {
        return self.offset[0];
    }

    pub inline fn offsetY(self: *const Scroll) f32 {
        return self.offset[1];
    }

    pub fn update(self: *Scroll, offset_x: f32, offset_y: f32) void {
        self.offset = .{ offset_x, offset_y, 0, 0 };
    }

    pub fn scale(self: *const Scroll, s: f32) @Vector(4, f32) {
        const scale_vec: @Vector(4, f32) = @splat(s);
        return self.offset * scale_vec;
    }

    pub fn clear(self: *Scroll) void {
        self.offset = @splat(0);
    }
};

pub const init: Mouse = .{
    .pos = .{ 0, 0, 0, 0 },
    .last = .{ 0, 0, 0, 0 },
    .offset = .{ 0, 0, 0, 0 },
};

const offset_mask_a: @Vector(4, f32) = .{
    // posx, lasty
    0, ~@as(i32, 1), 2, 3,
    // 0, 0, 0, 0,
};

const offset_mask_b: @Vector(4, f32) = .{
    // posx, lasty
    ~@as(i32, 0), 1, 2, 3,
    // 0, 0, 0, 0,
};

pub inline fn x(self: *const Mouse) f32 {
    return self.pos[0];
}

pub inline fn y(self: *const Mouse) f32 {
    return self.pos[1];
}

pub inline fn lastX(self: *const Mouse) f32 {
    return self.last[0];
}

pub inline fn lastY(self: *const Mouse) f32 {
    return self.last[1];
}

pub inline fn offsetX(self: *const Mouse) f32 {
    return self.offset[0];
}

pub inline fn offsetY(self: *const Mouse) f32 {
    return self.offset[1];
}

pub fn scaleOffset(self: *const Mouse, sens: f32) @Vector(4, f32) {
    const scale: @Vector(4, f32) = @splat(sens);
    return self.offset * scale;
}

pub fn update(self: *Mouse, new_x: f32, new_y: f32) void {
    self.last = self.pos;
    self.pos = .{ new_x, new_y, 0, 0 };
    self.offset = @shuffle(f32, self.pos, self.last, Mouse.offset_mask_a) - @shuffle(f32, self.pos, self.last, Mouse.offset_mask_b);
}

pub fn clearOffset(self: *Mouse) void {
    self.offset = @splat(0);
    self.scroll.clear();
}
