const std = @import("std");
const glm = @import("zmath");
const Engine = @import("Engine.zig");
const math = std.math;

const Camera = @This();

pub const world_up: @Vector(4, f32) = .{ 0, 1, 0, 0 };

view: glm.Mat,
projection: glm.Mat,

speed: f32,
fov: f32,
pos: @Vector(4, f32),
direction: @Vector(4, f32),
forward: @Vector(4, f32),
right: @Vector(4, f32),
up: @Vector(4, f32),

ypr: @Vector(4, f32),

look_at: @Vector(4, f32),

const ratio = @as(f32, @floatFromInt(800)) / @as(f32, @floatFromInt(600));

pub const init: Camera = .{
    .fov = 45,
    .pos = @splat(0),
    .forward = .{ 0, 0, -1, 0 },
    .right = @splat(0),
    .up = @splat(0),
    .ypr = .{ -90, 0, 0, 0 },
    .direction = @splat(0),
    .speed = 0,
    .look_at = @splat(0),

    .view = glm.identity(),
    .projection = glm.identity(),
};

pub fn update(self: *Camera, eng: *Engine) void {
    const camera_speed = eng.delta_time_vec * @as(@Vector(4, f32), @splat(self.speed));
    self.ypr += eng.mouse.scaleOffset(0.05);

    const y = self.ypr[0];
    const p = self.ypr[1];

    self.direction[0] = @cos(math.degreesToRadians(y) * @cos(math.degreesToRadians(p)));
    self.direction[1] = @sin(math.degreesToRadians(p));
    self.direction[2] = @sin(math.degreesToRadians(y)) * @cos(math.degreesToRadians(p));
    self.forward = glm.normalize3(self.direction);

    self.fov = math.clamp(self.fov - eng.mouse.scroll.offsetY(), 1, 100);
    self.projection = glm.perspectiveFovRhGl(
        math.degreesToRadians(self.fov),
        ratio,
        0.1,
        100,
    );

    self.right = glm.normalize3(glm.cross3(self.forward, world_up));
    self.up = glm.normalize3(glm.cross3(self.direction, self.right));

    if (eng.keyPressed(.w)) {
        self.pos += camera_speed * self.forward;
    }

    if (eng.keyPressed(.s)) {
        self.pos -= camera_speed * self.forward;
    }

    if (eng.keyPressed(.q)) {
        self.pos[1] -= self.speed * eng.delta_time;
    }

    if (eng.keyPressed(.e)) {
        self.pos[1] += self.speed * eng.delta_time;
    }

    if (eng.keyPressed(.a)) {
        self.pos -= self.right * camera_speed;
    }

    if (eng.keyPressed(.d)) {
        self.pos += self.right * camera_speed;
    }

    self.look_at = self.pos + self.forward;
    // self.view = glm.lookAtRh(self.pos, self.pos + self.forward, world_up);
    self.view = glm.lookAtRh(self.pos, self.look_at, world_up);
}

pub fn yaw(self: *const Camera) f32 {
    return self.ypr[0];
}

pub fn pitch(self: *const Camera) f32 {
    return self.ypr[1];
}
