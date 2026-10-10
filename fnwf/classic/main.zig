// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! Five Nights With Friends — Zig rewrite.
//!
//! Entry point and main loop. Screens are scene-tree nodes managed by
//! `neko.scene`; each screen is hosted by a `Screen` node (bridge to the
//! imperative screen logic). I/O goes through `init.io`.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const constants: type = @import("config/constants.zig");
const settings: type = @import("config/settings.zig");
const cheats_mod: type = @import("config/cheats.zig");
const Cheats: type = cheats_mod.Cheats;
const localization: type = @import("i18n/localization.zig");
const save: type = @import("save.zig");
const screen: type = @import("screen.zig");
const splash: type = @import("states/splash.zig");
const warning: type = @import("states/warning.zig");
const loading: type = @import("states/loading.zig");
const menu: type = @import("states/menu.zig");
const options: type = @import("states/options.zig");
const story: type = @import("states/story.zig");
const night_transition: type = @import("states/night_transition.zig");
const custom_night: type = @import("states/custom_night.zig");
const gameplay: type = @import("states/gameplay.zig");
const six_am: type = @import("states/six_am.zig");
const paycheck: type = @import("states/paycheck.zig");
const newspaper: type = @import("states/newspaper.zig");
const game_over: type = @import("states/game_over.zig");
const extras: type = @import("states/extras.zig");
const conquistas: type = @import("states/conquistas.zig");
const arcade: type = @import("states/arcade.zig");

const Allocator: type = std.mem.Allocator;
const mem: type = std.mem;

const WINDOW_TITLE: []const u8 = "Five Nights With Friends";

/// Sprites decoded while the menu loading screen is up.
const PRELOAD_MENU: [5][]const u8 = .{ "cedro", "eser", "alice", "Sonk", "mafia" };
/// Sprites decoded before a night starts.
const PRELOAD_GAME: [4][]const u8 = .{ "cedro", "eser", "alice", "Sonk" };

/// Mutable progress carried across screens.
const Progress: type = struct {
    pending_night: i32 = 1,
    completed_nights: i32 = 0,
    has_seen_story: bool = false,
    cheats: Cheats = .{},
    custom_ai: [4]i32 = .{ 0, 0, 0, 0 },
    has_custom_ai: bool = false,
    data: save.GameData = .{},

    fn has_achievement(self: *const Progress, id: []const u8) bool {
        for (self.data.achievements.items) |a| {
            if (mem.eql(u8, a, id)) return true;
        }
        return false;
    }

    fn add_achievement(self: *Progress, allocator: Allocator, id: []const u8) void {
        if (self.has_achievement(id)) return;
        const dup = allocator.dupe(u8, id) catch return;
        self.data.achievements.append(allocator, dup) catch {
            allocator.free(dup);
        };
    }

    /// The levels to hand to a night, or null to use the night's defaults.
    fn custom_levels(self: *Progress) ?[]const i32 {
        if (!self.has_custom_ai) return null;
        return self.custom_ai[0..];
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator: Allocator = init.gpa;

    const config: neko.Config = neko.Config{
        .allocator = allocator,
        .io = init.io,
        .title = WINDOW_TITLE,
        .width = @intCast(constants.SCREEN_WIDTH),
        .height = @intCast(constants.SCREEN_HEIGHT),
        .assets_dir = constants.ASSETS_DIR,
        .fullscreen = false,
        .vsync = true,
    };
    if (!neko.screen.init(config)) {
        return error.EngineInitFailed;
    }
    defer neko.screen.shutdown();
    defer common.sound.deinit();

    neko.screen.set_logical_size(@intCast(constants.SCREEN_WIDTH), @intCast(constants.SCREEN_HEIGHT));
    neko.sprite.load_default_font();
    neko.localization.load(localization.tables);

    settings.load();
    const s: *settings.Settings = settings.get();
    neko.localization.set_language(s.language.code());
    neko.sprite.set_quality(s.quality.code());
    common.sound.master_volume(s.master_volume);
    common.sound.sfx_volume(s.sfx_volume);
    common.sound.music_volume(s.music_volume);
    if (s.render.len > 0) _ = neko.screen.set_renderer(s.render);

    save.init(init.io, init.environ_map.get("HOME"), allocator);
    defer save.deinit(allocator);

    var progress: Progress = .{};
    progress.data = save.load_data(allocator);
    defer progress.data.deinit(allocator);
    progress.completed_nights = progress.data.completed_nights;
    progress.has_seen_story = progress.data.has_seen_story;
    progress.cheats = Cheats{
        .infinite_power = progress.data.infinite_power,
        .fast_nights = progress.data.fast_nights,
    };

    neko.scene.init(allocator);
    defer neko.scene.deinit();
    go_node(try splash.Splash.create(allocator));

    var last_ticks: u64 = neko.time.ticks_ms();

    while (neko.lifecycle.keeps_running()) {
        const now: u64 = neko.time.ticks_ms();
        const dt: f32 = @as(f32, @floatFromInt(now - last_ticks)) / 1000.0;
        last_ticks = now;
        neko.debug.tick();

        while (neko.input.poll_event()) |ev| {
            const is_quit: bool = switch (ev) {
                .quit => true,
                else => false,
            };
            if (is_quit) neko.lifecycle.request_stop();
            neko.scene.input(ev);
        }

        if (neko.scene.current()) |root| {
            if (screen.is_done()) {
                try dispatch(allocator, &progress, root, root.name, screen.result());
            }
        }

        neko.scene.process(dt);
        neko.scene.draw();

        if (settings.get().show_fps) {
            neko.debug.draw_fps(constants.SCREEN_WIDTH - 110, 16, neko.Color{ .r = 130, .g = 255, .b = 170 });
        }

        neko.screen.present();
    }
}

/// Switches directly to a scene-tree node.
fn go_node(node: *neko.scene.Node) void {
    neko.scene.switch_to(node);
}

/// The state graph: decodes the finished screen's name/result and enters the
/// next one — a direct port of `main.cpp`'s `do_switch`/`game_loop_iter`.
fn dispatch(allocator: Allocator, progress: *Progress, root: *neko.scene.Node, name: []const u8, result: []const u8) !void {
    if (mem.eql(u8, name, "splash")) {
        go_node(try warning.Warning.create(allocator));
    } else if (mem.eql(u8, name, "warning")) {
        go_node(try loading.Loading.create(allocator, &PRELOAD_MENU, "menu"));
    } else if (mem.eql(u8, name, "loading")) {
        if (mem.eql(u8, result, "game")) {
            go_node(try gameplay.Gameplay.create(allocator, progress.pending_night, progress.custom_levels(), progress.cheats));
        } else {
            go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
        }
    } else if (mem.eql(u8, name, "menu")) {
        try dispatch_menu(allocator, progress, result);
    } else if (mem.eql(u8, name, "story")) {
        go_node(try loading.Loading.create(allocator, &PRELOAD_GAME, "game"));
    } else if (mem.eql(u8, name, "night_transition")) {
        go_node(try loading.Loading.create(allocator, &PRELOAD_GAME, "game"));
    } else if (mem.eql(u8, name, "custom_night")) {
        if (mem.eql(u8, result, "start")) {
            progress.custom_ai = custom_night.CustomNight.from_node(root).levels();
            progress.has_custom_ai = true;
            progress.pending_night = 7;
            go_node(try loading.Loading.create(allocator, &PRELOAD_GAME, "game"));
        } else {
            go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
        }
    } else if (mem.eql(u8, name, "game")) {
        try dispatch_game(allocator, progress, result);
    } else if (mem.eql(u8, name, "six_am")) {
        if (mem.eql(u8, result, "paycheck")) {
            go_node(try paycheck.Paycheck.create(allocator));
        } else {
            go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
        }
    } else if (mem.eql(u8, name, "paycheck")) {
        go_node(try newspaper.Newspaper.create(allocator));
    } else if (mem.eql(u8, name, "newspaper")) {
        go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
    } else if (mem.eql(u8, name, "gameover")) {
        if (mem.eql(u8, result, "newspaper")) {
            go_node(try newspaper.Newspaper.create(allocator));
        } else {
            go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
        }
    } else if (mem.eql(u8, name, "extras")) {
        const st = extras.Extras.from_node(root);
        progress.data.infinite_power = st.infinite_power;
        progress.data.fast_nights = st.fast_nights;
        progress.cheats = Cheats{ .infinite_power = st.infinite_power, .fast_nights = st.fast_nights };
        save.save_progress(progress.data);
        go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
    } else if (mem.eql(u8, name, "conquistas")) {
        go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
    } else if (mem.eql(u8, name, "options")) {
        go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
    } else if (mem.eql(u8, name, "arcade")) {
        if (mem.eql(u8, result, "arcade_die")) {
            go_node(try game_over.GameOver.create(allocator, false, 0));
        } else {
            go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
        }
    } else {
        go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
    }
}

/// The menu's outcomes.
fn dispatch_menu(allocator: Allocator, progress: *Progress, result: []const u8) !void {
    if (mem.eql(u8, result, "start")) {
        progress.pending_night = 1;
        progress.has_custom_ai = false;
        go_node(try story.Story.create(allocator, 1));
    } else if (mem.eql(u8, result, "continue")) {
        progress.pending_night = @min(progress.completed_nights + 1, 6);
        progress.has_custom_ai = false;
        go_node(try story.Story.create(allocator, progress.pending_night));
    } else if (mem.eql(u8, result, "night6")) {
        progress.pending_night = 6;
        progress.has_custom_ai = false;
        go_node(try story.Story.create(allocator, 6));
    } else if (mem.eql(u8, result, "night7")) {
        go_node(try custom_night.CustomNight.create(allocator));
    } else if (mem.eql(u8, result, "extras")) {
        go_node(try extras.Extras.create(allocator, progress.data.infinite_power, progress.data.fast_nights, progress.data.achievements.items));
    } else if (mem.eql(u8, result, "options")) {
        go_node(try options.Options.create(allocator));
    } else if (mem.eql(u8, result, "conquistas")) {
        go_node(try conquistas.Conquistas.create(allocator, progress.data.achievements.items));
    } else if (mem.eql(u8, result, "arcade")) {
        go_node(try arcade.Arcade.create(allocator));
    } else if (mem.eql(u8, result, "quit")) {
        neko.lifecycle.request_stop();
    } else {
        go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
    }
}

/// The gameplay's outcomes.
fn dispatch_game(allocator: Allocator, progress: *Progress, result: []const u8) !void {
    if (mem.eql(u8, result, "win")) {
        if (progress.pending_night >= 1) progress.add_achievement(allocator, "survive_n1");
        if (progress.pending_night >= 5) progress.add_achievement(allocator, "survive_n5");
        if (progress.pending_night >= 6) progress.add_achievement(allocator, "survive_n6");
        if (progress.pending_night >= 7) progress.add_achievement(allocator, "survive_n7");
        progress.completed_nights = @max(progress.completed_nights, progress.pending_night);
        progress.has_seen_story = true;
        save.save_progress(progress.data);
        go_node(try six_am.SixAm.create(allocator, progress.pending_night));
    } else if (mem.eql(u8, result, "jumpscare")) {
        go_node(try game_over.GameOver.create(allocator, false, progress.pending_night));
    } else if (mem.eql(u8, result, "load_done")) {
        go_node(try gameplay.Gameplay.create(allocator, progress.pending_night, progress.custom_levels(), progress.cheats));
    } else {
        go_node(try menu.Menu.create(allocator, progress.completed_nights, progress.has_seen_story));
    }
}
