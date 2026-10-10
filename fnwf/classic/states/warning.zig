//! The epilepsy warning — a scene tree: the root drives five `Label` children.

const std: type = @import("std");
const neko: type = @import("neko");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

const LINES: [5]struct { key: []const u8, size: u32, color: neko.Color, y: i32 } = .{
    .{ .key = "warning_title", .size = 40, .color = neko.Color{ .r = 200, .g = 50, .b = 50 }, .y = -80 },
    .{ .key = "warning_line1", .size = 24, .color = neko.Color{ .r = 255, .g = 255, .b = 255 }, .y = -20 },
    .{ .key = "warning_line2", .size = 24, .color = neko.Color{ .r = 255, .g = 255, .b = 255 }, .y = 10 },
    .{ .key = "warning_line3", .size = 24, .color = neko.Color{ .r = 255, .g = 255, .b = 255 }, .y = 40 },
    .{ .key = "warning_line4", .size = 24, .color = neko.Color{ .r = 255, .g = 255, .b = 255 }, .y = 70 },
};

/// The warning screen, fading in and out.
pub const Warning: type = struct {
    node: neko.scene.Node,
    labels: [5]*neko.scene.Label,

    timer: f32 = 0,
    alpha: f32 = 0,
    phase: i32 = 0,
    done: bool = false,

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Warning = try allocator.create(Warning);
        self.* = Warning{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "warning",
            },
            .labels = undefined,
        };
        screen.attach(self, &screen_vtable);

        const cx: i32 = @divTrunc(constants.SCREEN_WIDTH, 2);
        const cy: i32 = @divTrunc(constants.SCREEN_HEIGHT, 2);
        inline for (LINES, 0..) |line, i| {
            const label = try neko.scene.addLabel(&self.node, neko.scene.Label.Options{
                .text = neko.localization.text(line.key),
                .pos = neko.Point{ .x = cx, .y = cy + line.y },
                .size = line.size,
                .center = true,
                .color = line.color,
            });
            self.labels[i] = label;
        }
        return &self.node;
    }
};

const vtable: neko.scene.Node.VTable = neko.scene.Node.VTable{
    .ready = neko.scene.no_ready,
    .process = process,
    .draw = draw,
    .input = input,
    .deinit = deinit,
};

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = screen.no_result };

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = ptr;
    _ = at;
    neko.draw.clear(neko.Color{ .r = 0, .g = 0, .b = 0 });
}

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Warning = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.phase == 0) {
        self.alpha += 600.0 * dt;
        if (self.alpha >= 255.0) {
            self.alpha = 255.0;
            self.phase = 1;
            self.timer = 0;
        }
    } else if (self.phase == 1) {
        if (self.timer >= 1.0) self.phase = 2;
    } else if (self.phase == 2) {
        self.alpha -= 600.0 * dt;
        if (self.alpha <= 0.0) {
            self.alpha = 0.0;
            self.done = true;
        }
    }

    const a: u8 = @intFromFloat(self.alpha);
    for (self.labels) |label| label.color.a = a;
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Warning = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down, .mouse_button_down => {
            if (self.phase < 2) {
                self.phase = 2;
                self.alpha = 255.0;
            }
        },
        else => {},
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Warning = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Warning = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
