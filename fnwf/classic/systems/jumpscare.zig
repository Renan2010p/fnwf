//! Jumpscare sequence — port of `systems/Jumpscare`.

const std: type = @import("std");
const neko: type = @import("neko");

const constants: type = @import("../config/constants.zig");
const animatronics: type = @import("animatronics.zig");
const AnimatronicId: type = animatronics.AnimatronicId;

/// A short scare: a shake, a fade-in flash and the animatronic face.
pub const Jumpscare: type = struct {
    active: bool = false,
    anim: AnimatronicId = .cedro,
    timer: f32 = 0,
    duration: f32 = 1.2,
    done: bool = false,

    pub fn trigger(self: *Jumpscare, anim: AnimatronicId) void {
        if (self.active) return;
        self.active = true;
        self.anim = anim;
        self.timer = 0;
        self.done = false;
    }

    pub fn update(self: *Jumpscare, dt: f32) void {
        if (!self.active) return;
        self.timer += dt;
        if (self.timer >= self.duration) self.done = true;
    }

    pub fn draw(self: *const Jumpscare) void {
        if (!self.active) return;

        const prog: f32 = @min(1.0, self.timer / self.duration);
        neko.draw.clear(neko.Color{ .r = 0, .g = 0, .b = 0 });

        const sxr: i32 = neko.random.int_range(-20, 20);
        const syr: i32 = neko.random.int_range(-20, 20);
        const sx: i32 = @intFromFloat(@as(f32, @floatFromInt(sxr)) * (1.0 - prog * 0.5));
        const sy: i32 = @intFromFloat(@as(f32, @floatFromInt(syr)) * (1.0 - prog * 0.5));

        if (prog < 0.1) {
            const a: u8 = @intFromFloat(255.0 * (1.0 - prog / 0.1));
            neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = constants.SCREEN_WIDTH, .h = constants.SCREEN_HEIGHT }, neko.Color{ .r = 255, .g = 255, .b = 255, .a = a }, true);
        }

        const fw: i32 = @intFromFloat(@as(f32, @floatFromInt(constants.SCREEN_WIDTH)) * 0.6 * (1.0 + prog * 0.3));
        const fh: i32 = @intFromFloat(@as(f32, @floatFromInt(constants.SCREEN_HEIGHT)) * 0.7 * (1.0 + prog * 0.3));
        neko.sprite.face(
            self.anim.name(),
            @divTrunc(constants.SCREEN_WIDTH, 2) - @divTrunc(fw, 2) + sx,
            @divTrunc(constants.SCREEN_HEIGHT, 2) - @divTrunc(fh, 2) + sy - 30,
            fw,
            fh,
        );

        neko.effect.noise(0, 0, constants.SCREEN_WIDTH, constants.SCREEN_HEIGHT, 0.1 + prog * 0.2);

        const s: f32 = @sin(self.timer * 20.0);
        const red_a: u8 = @intFromFloat(80.0 * s * s);
        neko.draw.rect(neko.Rect{ .x = 0, .y = 0, .w = constants.SCREEN_WIDTH, .h = constants.SCREEN_HEIGHT }, neko.Color{ .r = 200, .g = 0, .b = 0, .a = red_a }, true);
    }

    pub fn reset(self: *Jumpscare) void {
        self.active = false;
        self.timer = 0;
        self.done = false;
    }
};
