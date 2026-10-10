//! The 6 AM splash — a real scene tree: the root node drives two `Label`
//! children through fade-in / hold / fade-out.

const std: type = @import("std");
const neko: type = @import("neko");

const screen: type = @import("../screen.zig");
const constants: type = @import("../config/constants.zig");

const Allocator: type = std.mem.Allocator;

const LINES: [2]struct { text: []const u8, size: u32, color: neko.Color } = .{
    .{ .text = "RL PROJECTS", .size = 48, .color = neko.Color{ .r = 230, .g = 230, .b = 235 } },
    .{ .text = "Powered by Neko engine", .size = 26, .color = neko.Color{ .r = 150, .g = 170, .b = 200 } },
};

const FADE_SPEED: f32 = 600.0;
const HOLD_TIME: f32 = 1.2;

/// Startup splash: shows the studio, then the engine, then finishes.
pub const Splash: type = struct {
    node: neko.scene.Node,
    labels: [2]*neko.scene.Label,

    line: i32 = 0,
    phase: i32 = 0,
    timer: f32 = 0,
    alpha: f32 = 0,
    done: bool = false,

    pub fn create(allocator: Allocator) !*neko.scene.Node {
        const self: *Splash = try allocator.create(Splash);
        self.* = Splash{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "splash",
            },
            .labels = undefined,
        };
        screen.attach(self, &screen_vtable);

        const cx: i32 = @divTrunc(constants.SCREEN_WIDTH, 2);
        const cy: i32 = @divTrunc(constants.SCREEN_HEIGHT, 2);
        inline for (LINES, 0..) |line, i| {
            const label = try neko.scene.addLabel(&self.node, neko.scene.Label.Options{
                .text = line.text,
                .pos = neko.Point{ .x = cx, .y = cy },
                .size = line.size,
                .center = true,
                .color = line.color,
            });
            label.node.visible = (i == 0);
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
    const self: *Splash = @ptrCast(@alignCast(ptr));
    self.timer += dt;

    if (self.phase == 0) {
        self.alpha += FADE_SPEED * dt;
        if (self.alpha >= 255.0) {
            self.alpha = 255.0;
            self.phase = 1;
            self.timer = 0;
        }
    } else if (self.phase == 1) {
        if (self.timer >= HOLD_TIME) self.phase = 2;
    } else if (self.phase == 2) {
        self.alpha -= FADE_SPEED * dt;
        if (self.alpha <= 0.0) {
            self.alpha = 0.0;
            if (self.line + 1 < LINES.len) {
                self.line += 1;
                self.phase = 0;
                self.timer = 0;
            } else {
                self.done = true;
            }
        }
    }

    const a: u8 = @intFromFloat(self.alpha);
    for (self.labels, 0..) |label, i| {
        label.node.visible = (@as(i32, @intCast(i)) == self.line);
        label.color.a = a;
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Splash = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down, .mouse_button_down => self.done = true,
        else => {},
    }
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Splash = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Splash = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
