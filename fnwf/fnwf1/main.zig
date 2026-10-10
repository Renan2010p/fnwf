// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! Five Nights With Friends **1** — the first night of the franchise.
//!
//! Entry point and state graph. Built from scratch for this package: its own
//! office, cameras, power, animatronic AI and story (Cedro's nightly calls).

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const config: type = @import("config.zig");
const screen: type = @import("screen.zig");
const save: type = @import("save.zig");
const menu: type = @import("menu.zig");
const call: type = @import("call.zig");
const gameplay: type = @import("gameplay.zig");
const six_am: type = @import("six_am.zig");
const gameover: type = @import("gameover.zig");
const paycheck: type = @import("paycheck.zig");
const newspaper: type = @import("newspaper.zig");
const custom_night: type = @import("custom_night.zig");
const options: type = @import("options.zig");
const extras: type = @import("extras.zig");

const Allocator: type = std.mem.Allocator;
const mem: type = std.mem;

/// Progress carried across screens.
const Progress: type = struct {
    pending_night: i32 = 1,
    custom_ai: [4]i32 = .{ 0, 0, 0, 0 },
    has_custom: bool = false,

    fn custom(self: *Progress) ?[]const i32 {
        if (!self.has_custom) return null;
        return self.custom_ai[0..];
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator: Allocator = init.gpa;

    const cfg: neko.Config = neko.Config{
        .allocator = allocator,
        .io = init.io,
        .title = "Five Nights With Friends 1",
        .width = @intCast(config.SCREEN_W),
        .height = @intCast(config.SCREEN_H),
        .assets_dir = config.ASSETS_DIR,
        .fullscreen = false,
        .vsync = true,
    };
    if (!neko.screen.init(cfg)) return error.EngineInitFailed;
    defer neko.screen.shutdown();
    defer common.sound.deinit();

    neko.screen.set_logical_size(@intCast(config.SCREEN_W), @intCast(config.SCREEN_H));
    neko.sprite.load_default_font();

    save.init(init.io, init.environ_map.get("HOME"), allocator);
    defer save.deinit(allocator);
    save.load(allocator);
    neko.sound.master_volume(save.settings.master_volume);
    neko.sound.sfx_volume(save.settings.sfx_volume);
    neko.sound.music_volume(save.settings.music_volume);
    neko.sprite.set_quality(if (save.settings.quality_high) "high" else "low");
    if (save.settings.render.len > 0) _ = neko.screen.set_renderer(save.settings.render);

    var progress: Progress = .{};

    neko.scene.init(allocator);
    defer neko.scene.deinit();
    go_node(try menu.Menu.create(allocator, save.progress.completed_nights));

    var last_ticks: u64 = neko.time.ticks_ms();
    while (neko.lifecycle.keeps_running()) {
        const now: u64 = neko.time.ticks_ms();
        const dt: f32 = @as(f32, @floatFromInt(now - last_ticks)) / 1000.0;
        last_ticks = now;

        while (neko.input.poll_event()) |ev| {
            const is_quit: bool = switch (ev) {
                .quit => true,
                else => false,
            };
            if (is_quit) neko.lifecycle.request_stop();
            neko.scene.input(ev);
        }

        if (neko.scene.current()) |root| {
            if (screen.is_done()) try dispatch(allocator, &progress, root, root.name, screen.result());
        }

        neko.scene.process(dt);
        neko.scene.draw();
        neko.screen.present();
    }
}

fn go_node(node: *neko.scene.Node) void {
    neko.scene.switch_to(node);
}

fn dispatch(allocator: Allocator, progress: *Progress, root: *neko.scene.Node, name: []const u8, result: []const u8) !void {
    if (mem.eql(u8, name, "menu")) {
        try dispatch_menu(allocator, progress, result);
    } else if (mem.eql(u8, name, "call")) {
        go_node(try gameplay.Gameplay.create(allocator, progress.pending_night, progress.custom()));
    } else if (mem.eql(u8, name, "game")) {
        if (mem.eql(u8, result, "win")) {
            save.progress.completed_nights = @max(save.progress.completed_nights, progress.pending_night);
            save.save_progress();
            go_node(try six_am.SixAm.create(allocator, progress.pending_night));
        } else if (mem.eql(u8, result, "jumpscare")) {
            go_node(try gameover.GameOver.create(allocator, progress.pending_night));
        } else {
            go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
        }
    } else if (mem.eql(u8, name, "six_am")) {
        if (progress.pending_night >= 5) {
            go_node(try paycheck.Paycheck.create(allocator));
        } else {
            go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
        }
    } else if (mem.eql(u8, name, "paycheck")) {
        go_node(try newspaper.Newspaper.create(allocator));
    } else if (mem.eql(u8, name, "newspaper")) {
        go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
    } else if (mem.eql(u8, name, "gameover")) {
        go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
    } else if (mem.eql(u8, name, "custom_night")) {
        if (mem.eql(u8, result, "start")) {
            progress.custom_ai = custom_night.CustomNight.from_node(root).ai();
            progress.has_custom = true;
            progress.pending_night = 7;
            go_node(try gameplay.Gameplay.create(allocator, 7, progress.custom()));
        } else {
            go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
        }
    } else if (mem.eql(u8, name, "extras") or mem.eql(u8, name, "options")) {
        go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
    } else {
        go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
    }
}

fn dispatch_menu(allocator: Allocator, progress: *Progress, result: []const u8) !void {
    progress.has_custom = false;
    if (mem.eql(u8, result, "start1")) {
        progress.pending_night = 1;
        go_node(try call.Call.create(allocator, 1));
    } else if (mem.eql(u8, result, "continue")) {
        progress.pending_night = @min(save.progress.completed_nights + 1, 6);
        go_node(try call.Call.create(allocator, progress.pending_night));
    } else if (mem.eql(u8, result, "night6")) {
        progress.pending_night = 6;
        go_node(try call.Call.create(allocator, 6));
    } else if (mem.eql(u8, result, "custom")) {
        go_node(try custom_night.CustomNight.create(allocator));
    } else if (mem.eql(u8, result, "extras")) {
        go_node(try extras.Extras.create(allocator));
    } else if (mem.eql(u8, result, "options")) {
        go_node(try options.Options.create(allocator));
    } else if (mem.eql(u8, result, "quit")) {
        neko.lifecycle.request_stop();
    } else {
        go_node(try menu.Menu.create(allocator, save.progress.completed_nights));
    }
}
