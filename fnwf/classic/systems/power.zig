//! Power drain and HUD — port of `systems/Power`.

const std: type = @import("std");
const fmt: type = std.fmt;
const neko: type = @import("neko");

const constants: type = @import("../config/constants.zig");
const colors: type = @import("../config/colors.zig");

/// The office power system.
pub const Power: type = struct {
    power: f32 = 100.0,
    usage_level: i32 = 1,
    is_dead: bool = false,
    dead_timer: f32 = 0.0,

    /// `door_usage` is how many door/light toggles are on; `camera_open` adds
    /// one more. When `infinite` is true the meter never drains (a cheat).
    pub fn update(self: *Power, dt: f32, door_usage: i32, camera_open: bool, infinite: bool) void {
        if (self.is_dead) {
            self.dead_timer += dt;
            return;
        }

        self.usage_level = @min(5, 1 + door_usage + @as(i32, if (camera_open) 1 else 0));
        if (infinite) return;

        const drain_muls = [_]f32{ 1.0, 1.55, 2.35, 3.4, 4.8 };
        const mul = drain_muls[@intCast(@max(0, @min(4, self.usage_level - 1)))];

        self.power -= constants.BASE_POWER_DRAIN * mul * dt;
        if (self.power <= 0.0) {
            self.power = 0.0;
            self.is_dead = true;
            self.dead_timer = 0.0;
        }
    }

    pub fn draw(self: *const Power) void {
        const x: i32 = 24;
        const y: i32 = constants.SCREEN_HEIGHT - 78;
        const pct: i32 = @max(0, @as(i32, @intFromFloat(self.power)));

        var buf: [96]u8 = undefined;
        const label = format_int(&buf, neko.localization.text("power_left"), pct);
        neko.sprite.text(label, x, y, neko.sprite.Options{
            .size = 18,
            .color = neko.Color{ .r = 255, .g = 255, .b = 255 },
        });

        const uy: i32 = y + 28;
        neko.sprite.text(neko.localization.text("usage"), x, uy, neko.sprite.Options{
            .size = 16,
            .color = neko.Color{ .r = 200, .g = 200, .b = 200 },
        });

        var i: i32 = 0;
        while (i < 5) : (i += 1) {
            const ux: i32 = x + 78 + i * 16;
            const color = if (i < self.usage_level) colors.MONITOR_GREEN else neko.Color{ .r = 40, .g = 40, .b = 45 };
            neko.draw.rect(neko.Rect{ .x = ux, .y = uy + 4, .w = 10, .h = 16 }, color, true);
            neko.draw.rect(neko.Rect{ .x = ux, .y = uy + 4, .w = 10, .h = 16 }, neko.Color{ .r = 75, .g = 75, .b = 80 }, false);
        }
    }
};

/// Replaces `%d` with `value` and `%%` with `%` in a localized template.
fn format_int(buf: []u8, template: []const u8, value: i32) []const u8 {
    var out: usize = 0;
    var i: usize = 0;
    while (i < template.len and out < buf.len) {
        if (template[i] == '%' and i + 1 < template.len) {
            if (template[i + 1] == 'd') {
                const n = fmt.bufPrint(buf[out..], "{d}", .{value}) catch break;
                out += n.len;
                i += 2;
                continue;
            } else if (template[i + 1] == '%') {
                buf[out] = '%';
                out += 1;
                i += 2;
                continue;
            }
        }
        buf[out] = template[i];
        out += 1;
        i += 1;
    }
    return buf[0..out];
}
