const c = @import("c.zig").c;

pub const Key = enum(i32) {
    space,
    apostraphe,
    comma,
    minus,
    period,
    slash,
    @"0",
    @"1",
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    semicolon,
    equal,
    a,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    left_bracket,
    back_slash,
    right_bracket,
    grave_accent,
    world1,
    world2,
    esc,
    enter,
    tab,
    backspace,
    insert,
    delete,
    right,
    left,
    down,
    up,
    page_up,
    page_down,
    home,
    end,
    caps_lock,
    scroll_lock,
    num_lock,
    print_screen,
    pause,
    f1,
    f2,
    f3,
    f4,
    f5,
    f6,
    f7,
    f8,
    f9,
    f10,
    f11,
    f12,
    f13,
    f14,
    f15,
    f16,
    f17,
    f18,
    f19,
    f20,
    f21,
    f22,
    f23,
    f24,
    f25,
    kp0,
    kp1,
    kp2,
    kp3,
    kp4,
    kp5,
    kp6,
    kp7,
    kp8,
    kp9,
    kp_decimal,
    kp_divide,
    kp_multiply,
    kp_subtract,
    kp_add,
    kp_enter,
    kp_equal,
    left_shift,
    left_control,
    left_alt,
    left_super,
    right_shift,
    right_control,
    right_alt,
    right_super,
    menu,
    // Last = c.GLFW_KEY_LAST, //   GLFW_KEY_MENU

    pub inline fn glfw(self: Key) c_int {
        return switch (self) {
            .space => c.GLFW_KEY_SPACE, // 32
            .apostraphe => c.GLFW_KEY_APOSTROPHE, // 39 /* ' */
            .comma => c.GLFW_KEY_COMMA, // 44 /* , */
            .minus => c.GLFW_KEY_MINUS, // 45 /* - */
            .period => c.GLFW_KEY_PERIOD, // 46 /* . */
            .slash => c.GLFW_KEY_SLASH, // 47 /* / */
            .@"0" => c.GLFW_KEY_0, // 48
            .@"1" => c.GLFW_KEY_1, // 49
            .@"2" => c.GLFW_KEY_2, // 50
            .@"3" => c.GLFW_KEY_3, // 51
            .@"4" => c.GLFW_KEY_4, // 52
            .@"5" => c.GLFW_KEY_5, // 53
            .@"6" => c.GLFW_KEY_6, // 54
            .@"7" => c.GLFW_KEY_7, // 55
            .@"8" => c.GLFW_KEY_8, // 56
            .@"9" => c.GLFW_KEY_9, // 57
            .semicolon => c.GLFW_KEY_SEMICOLON, // 59 /* ; */
            .equal => c.GLFW_KEY_EQUAL, // 61 /* = */
            .a => c.GLFW_KEY_A, // 65
            .b => c.GLFW_KEY_B, // 66
            .c => c.GLFW_KEY_C, // 67
            .d => c.GLFW_KEY_D, // 68
            .e => c.GLFW_KEY_E, // 69
            .f => c.GLFW_KEY_F, // 70
            .g => c.GLFW_KEY_G, // 71
            .h => c.GLFW_KEY_H, // 72
            .i => c.GLFW_KEY_I, // 73
            .j => c.GLFW_KEY_J, // 74
            .k => c.GLFW_KEY_K, // 75
            .l => c.GLFW_KEY_L, // 76
            .m => c.GLFW_KEY_M, // 77
            .n => c.GLFW_KEY_N, // 78
            .o => c.GLFW_KEY_O, // 79
            .p => c.GLFW_KEY_P, // 80
            .q => c.GLFW_KEY_Q, // 81
            .r => c.GLFW_KEY_R, // 82
            .s => c.GLFW_KEY_S, // 83
            .t => c.GLFW_KEY_T, // 84
            .u => c.GLFW_KEY_U, // 85
            .v => c.GLFW_KEY_V, // 86
            .w => c.GLFW_KEY_W, // 87
            .x => c.GLFW_KEY_X, // 88
            .y => c.GLFW_KEY_Y, // 89
            .z => c.GLFW_KEY_Z, // 90
            .left_bracket => c.GLFW_KEY_LEFT_BRACKET, // 91 /* [ */
            .back_slash => c.GLFW_KEY_BACKSLASH, // 92 /* \ */
            .right_bracket => c.GLFW_KEY_RIGHT_BRACKET, // 93 /* ] */
            .grave_accent => c.GLFW_KEY_GRAVE_ACCENT, // 96 /* ` */
            .world1 => c.GLFW_KEY_WORLD_1, // 161 /* non-US #1 */
            .world2 => c.GLFW_KEY_WORLD_2, // 162 /* non-US #2 */
            .esc => c.GLFW_KEY_ESCAPE, // 256
            .enter => c.GLFW_KEY_ENTER, // 257
            .tab => c.GLFW_KEY_TAB, // 258
            .backspace => c.GLFW_KEY_BACKSPACE, // 259
            .insert => c.GLFW_KEY_INSERT, // 260
            .delete => c.GLFW_KEY_DELETE, // 261
            .right => c.GLFW_KEY_RIGHT, // 262
            .left => c.GLFW_KEY_LEFT, // 263
            .down => c.GLFW_KEY_DOWN, // 264
            .up => c.GLFW_KEY_UP, // 265
            .page_up => c.GLFW_KEY_PAGE_UP, // 266
            .page_down => c.GLFW_KEY_PAGE_DOWN, // 267
            .home => c.GLFW_KEY_HOME, // 268
            .end => c.GLFW_KEY_END, // 269
            .caps_lock => c.GLFW_KEY_CAPS_LOCK, // 280
            .scroll_lock => c.GLFW_KEY_SCROLL_LOCK, // 281
            .num_lock => c.GLFW_KEY_NUM_LOCK, // 282
            .print_screen => c.GLFW_KEY_PRINT_SCREEN, // 283
            .pause => c.GLFW_KEY_PAUSE, // 284
            .f1 => c.GLFW_KEY_F1, // 290
            .f2 => c.GLFW_KEY_F2, // 291
            .f3 => c.GLFW_KEY_F3, // 292
            .f4 => c.GLFW_KEY_F4, // 293
            .f5 => c.GLFW_KEY_F5, // 294
            .f6 => c.GLFW_KEY_F6, // 295
            .f7 => c.GLFW_KEY_F7, // 296
            .f8 => c.GLFW_KEY_F8, // 297
            .f9 => c.GLFW_KEY_F9, // 298
            .f10 => c.GLFW_KEY_F10, // 299
            .f11 => c.GLFW_KEY_F11, // 300
            .f12 => c.GLFW_KEY_F12, // 301
            .f13 => c.GLFW_KEY_F13, // 302
            .f14 => c.GLFW_KEY_F14, // 303
            .f15 => c.GLFW_KEY_F15, // 304
            .f16 => c.GLFW_KEY_F16, // 305
            .f17 => c.GLFW_KEY_F17, // 306
            .f18 => c.GLFW_KEY_F18, // 307
            .f19 => c.GLFW_KEY_F19, // 308
            .f20 => c.GLFW_KEY_F20, // 309
            .f21 => c.GLFW_KEY_F21, // 310
            .f22 => c.GLFW_KEY_F22, // 311
            .f23 => c.GLFW_KEY_F23, // 312
            .f24 => c.GLFW_KEY_F24, // 313
            .f25 => c.GLFW_KEY_F25, // 314
            .kp0 => c.GLFW_KEY_KP_0, // 320
            .kp1 => c.GLFW_KEY_KP_1, // 321
            .kp2 => c.GLFW_KEY_KP_2, // 322
            .kp3 => c.GLFW_KEY_KP_3, // 323
            .kp4 => c.GLFW_KEY_KP_4, // 324
            .kp5 => c.GLFW_KEY_KP_5, // 325
            .kp6 => c.GLFW_KEY_KP_6, // 326
            .kp7 => c.GLFW_KEY_KP_7, // 327
            .kp8 => c.GLFW_KEY_KP_8, // 328
            .kp9 => c.GLFW_KEY_KP_9, // 329
            .kp_decimal => c.GLFW_KEY_KP_DECIMAL, // 330
            .kp_divide => c.GLFW_KEY_KP_DIVIDE, // 331
            .kp_multiply => c.GLFW_KEY_KP_MULTIPLY, // 332
            .kp_subtract => c.GLFW_KEY_KP_SUBTRACT, // 333
            .kp_add => c.GLFW_KEY_KP_ADD, // 334
            .kp_enter => c.GLFW_KEY_KP_ENTER, // 335
            .kp_equal => c.GLFW_KEY_KP_EQUAL, // 336
            .left_shift => c.GLFW_KEY_LEFT_SHIFT, // 340
            .left_control => c.GLFW_KEY_LEFT_CONTROL, // 341
            .left_alt => c.GLFW_KEY_LEFT_ALT, // 342
            .left_super => c.GLFW_KEY_LEFT_SUPER, // 343
            .right_shift => c.GLFW_KEY_RIGHT_SHIFT, // 344
            .right_control => c.GLFW_KEY_RIGHT_CONTROL, // 345
            .right_alt => c.GLFW_KEY_RIGHT_ALT, // 346
            .right_super => c.GLFW_KEY_RIGHT_SUPER, // 347
            .menu => c.GLFW_KEY_MENU, // 348
        };
    }

    pub inline fn toCInt(self: Key) c_int {
        return @intCast(@intFromEnum(self));
    }
};

pub const MouseButton = enum {
    mouse_button_1, //   0
    mouse_button_2, //   1
    mouse_button_3, //   2
    mouse_button_4, //   3
    mouse_button_5, //   4
    mouse_button_6, //   5
    mouse_button_7, //   6
    mouse_button_8, //   7
    mouse_button_last, //   GLFW_MOUSE_BUTTON_8
    mouse_button_left, //   GLFW_MOUSE_BUTTON_1
    mouse_button_right, //   GLFW_MOUSE_BUTTON_2
    mouse_button_middle, //   GLFW_MOUSE_BUTTON_3

    pub inline fn glfw(self: MouseButton) c_int {
        return switch (self) {
            .mouse_button_1 => c.GLFW_MOUSE_BUTTON_1, //   0
            .mouse_button_2 => c.GLFW_MOUSE_BUTTON_2, //   1
            .mouse_button_3 => c.GLFW_MOUSE_BUTTON_3, //   2
            .mouse_button_4 => c.GLFW_MOUSE_BUTTON_4, //   3
            .mouse_button_5 => c.GLFW_MOUSE_BUTTON_5, //   4
            .mouse_button_6 => c.GLFW_MOUSE_BUTTON_6, //   5
            .mouse_button_7 => c.GLFW_MOUSE_BUTTON_7, //   6
            .mouse_button_8 => c.GLFW_MOUSE_BUTTON_8, //   7
            .mouse_button_last => c.GLFW_MOUSE_BUTTON_LAST, //   GLFW_MOUSE_BUTTON_8
            .mouse_button_left => c.GLFW_MOUSE_BUTTON_LEFT, //   GLFW_MOUSE_BUTTON_1
            .mouse_button_right => c.GLFW_MOUSE_BUTTON_RIGHT, //   GLFW_MOUSE_BUTTON_2
            .mouse_button_middle => c.GLFW_MOUSE_BUTTON_MIDDLE, //   GLFW_MOUSE_BUTTON_3
        };
    }
};

pub const Action = enum {
    pressed,
    released,

    pub inline fn glfw(self: Action) c_int {
        return switch (self) {
            .pressed => c.GLFW_PRESS,
            .released => c.GLFW_RELEASE,
        };
    }
};
