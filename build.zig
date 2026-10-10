// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

const std: type = @import("std");
const Target: type = std.Target;
const Builder: type = std.Build;
const mem: type = std.mem;
const engine_config: type = @import("neko/config.zig");

pub fn build(b: *Builder) void {
    // ── Options ──────────────────────────────────────────────────────────
    const game_name: []const u8 = b.option(
        []const u8,
        "game",
        "Game to build: classic (default)",
    ) orelse "classic";

    const backend_name: []const u8 = b.option(
        []const u8,
        "backend",
        "Codegen backend: llvm (default) or c",
    ) orelse "llvm";
    const use_c_backend: bool = mem.eql(u8, backend_name, "c");

    // The neko backend comes from `neko/config.zig` (the single source of
    // truth); this option only exists to test the other backends without
    // editing that file.
    const neko_backend: engine_config.Backend = b.option(
        engine_config.Backend,
        "neko-backend",
        "Override the neko backend from neko/config.zig (sdl2, sdl2-opengl, sdl2-vulkan, ps2, psx, headless)",
    ) orelse engine_config.backend;
    const is_ps2: bool = neko_backend == .ps2;

    // Cross-compile target triple (default: the host). Needed for the Windows
    // packages, which are built from a Linux runner.
    const target_triple: ?[]const u8 = b.option(
        []const u8,
        "target",
        "Cross-compile target triple (default: the host)",
    );
    // For platforms without pkg-config (Windows), point at the SDL3 headers and
    // libraries; the SDL3 backend of neko consumes these.
    const sdl_include: ?[]const u8 = b.option(
        []const u8,
        "sdl3-include",
        "Directory holding the SDL3 headers (platforms without pkg-config)",
    );
    const sdl_lib: ?[]const u8 = b.option(
        []const u8,
        "sdl3-lib",
        "Directory holding the SDL3 libraries (platforms without pkg-config)",
    );

    // ── Target ───────────────────────────────────────────────────────────
    var query: Target.Query = b.graph.host.query;
    if (target_triple) |triple| {
        query = Target.Query.parse(.{ .arch_os_abi = triple }) catch {
            std.debug.print("fnwf: bad -Dtarget '{s}'\n", .{triple});
            @panic("fnwf: bad target");
        };
    }
    if (use_c_backend or is_ps2) query.ofmt = .c;
    if (is_ps2) {
        query.cpu_arch = .mips64el;
        query.os_tag = .freestanding;
        query.abi = .gnuabin32;
    }
    const target: Builder.ResolvedTarget = b.resolveTargetQuery(query);
    const hosted: bool = target.result.os.tag != .freestanding;

    const optimize: std.lang.Optimize = .fast;

    // On Linux we use Zig's self-hosted codegen backend (no LLVM). Every other
    // target keeps LLVM, and the C backend is unaffected.
    const target_is_linux: bool = target.result.os.tag == .linux;
    const use_llvm: ?bool = if (use_c_backend or !target_is_linux) null else false;

    // ── Engine dependency ────────────────────────────────────────────────
    const neko_dep: *Builder.Dependency = b.dependency("neko", .{
        .target = target,
        .optimize = optimize,
        .backend = neko_backend,
        .@"sdl2-include" = sdl_include,
        .@"sdl2-lib" = sdl_lib,
    });
    const neko: *Builder.Module = neko_dep.module("neko");
    const neko_backend_mod: *Builder.Module = neko_dep.module("neko_backend");

    // ── Shared franchise module ──────────────────────────────────────────
    const common_module: *Builder.Module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .code_model = .default,
        .link_libc = hosted,
        .root_source_file = b.path("fnwf/common/common.zig"),
        .imports = &.{
            .{ .name = "neko", .module = neko },
        },
    });

    // ── Game module ──────────────────────────────────────────────────────
    const game_root: []const u8 = b.pathJoin(&.{
        "fnwf", game_name, "main.zig",
    });
    const game_module: *Builder.Module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .code_model = .default,
        .link_libc = hosted,
        .root_source_file = b.path(game_root),
        .imports = &.{
            .{ .name = "neko", .module = neko },
            .{ .name = "neko_backend", .module = neko_backend_mod },
            .{ .name = "common", .module = common_module },
        },
    });

    // ── Executable root ──────────────────────────────────────────────────
    // On the desktop the game's `main.zig` is the root. On the PS2 the root is
    // neko's `entry.zig`, which imports the game as `game` and calls its
    // `main(init: std.process.Init)` with a hand-built `Init` — the game source
    // does not change.
    const exe_root: *Builder.Module = if (is_ps2)
        b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = neko_dep.path("src/backend/PS2/entry.zig"),
            .imports = &.{
                .{ .name = "game", .module = game_module },
                .{ .name = "neko_backend", .module = neko_backend_mod },
            },
        })
    else
        game_module;

    const game_exe: *Builder.Step.Compile = b.addExecutable(.{
        .name = "fnwf",
        .root_module = exe_root,
        .use_llvm = use_llvm,
    });

    b.installArtifact(game_exe);

    if (is_ps2) {
        build_ps2(b, neko_dep, game_exe);
    } else if (use_c_backend) {
        build_c_backend(b, game_exe);
    } else {
        const run_cmd: *Builder.Step.Run = b.addRunArtifact(game_exe);
        run_cmd.step.dependOn(b.getInstallStep());
        const run_step: *Builder.Step = b.step("run", "Build and run the game");
        run_step.dependOn(&run_cmd.step);
    }
}

/// PS2 pipeline: compile Zig → C → `ee-gcc` → link with gsKit + PS2SDK.
fn build_ps2(b: *Builder, neko_dep: *Builder.Dependency, game_exe: *Builder.Step.Compile) void {
    const ps2dev: []const u8 = b.option(
        []const u8,
        "ps2dev",
        "PS2DEV root (default: $PS2DEV or /usr/local/ps2dev)",
    ) orelse b.graph.environ_map.get("PS2DEV") orelse "/usr/local/ps2dev";
    const ps2sdk: []const u8 = b.fmt("{s}/ps2sdk", .{ps2dev});
    const ports: []const u8 = b.fmt("{s}/ports", .{ps2sdk});
    const ee: []const u8 = b.fmt("{s}/ee/bin/mips64r5900el-ps2-elf", .{ps2dev});
    // The directory holding Zig's `zig.h`, which the emitted C includes.
    const zig_lib: Builder.LazyPath = Builder.LazyPath.zig_lib;

    // test.c -> fnwf.o. GCC 15 promotes -Wincompatible-pointer-types to an
    // error; Zig's C output trips it on the N32 ABI (`uintptr_t` vs `uint32_t`).
    const cc: *Builder.Step.Run = b.addSystemCommand(&.{
        b.fmt("{s}-gcc", .{ee}),
        "-D_EE",
        "-G0",
        "-O1",
        "-Wno-incompatible-pointer-types",
        "-c",
    });
    cc.addDirectoryArg2(zig_lib, .{ .prefix = "-I" });
    cc.addFileArg(game_exe.getEmittedBin());
    cc.addArg("-o");
    const obj: Builder.LazyPath = cc.addOutputFileArg("fnwf.o");

    // font_shim.c: the FreeType wrapper (Zig cannot translate-c FreeType on
    // this target). Compiled by ee-gcc and linked with -lfreetype.
    const shim_cc: *Builder.Step.Run = b.addSystemCommand(&.{
        b.fmt("{s}-gcc", .{ee}),
        "-D_EE",
        "-G0",
        "-O2",
        b.fmt("-I{s}/include/freetype2", .{ports}),
        "-c",
    });
    shim_cc.addFileArg(neko_dep.path("src/backend/PS2/platform/font_shim.c"));
    shim_cc.addArg("-o");
    const shim_obj: Builder.LazyPath = shim_cc.addOutputFileArg("font_shim.o");

    const ld: *Builder.Step.Run = b.addSystemCommand(&.{
        b.fmt("{s}-gcc", .{ee}),
        b.fmt("-T{s}/ee/startup/linkfile", .{ps2sdk}),
        "-O1",
        "-o",
    });
    const elf: Builder.LazyPath = ld.addOutputFileArg("fnwf.elf");
    ld.addFileArg(obj);
    ld.addFileArg(shim_obj);
    ld.addArgs(&.{
        b.fmt("-L{s}/ee/lib", .{ps2sdk}),
        b.fmt("-L{s}/gsKit/lib", .{ps2dev}),
        b.fmt("-L{s}/lib", .{ports}),
        "-Wl,-zmax-page-size=128",
        "-Wl,--start-group",
        "-lgskit",
        "-lgskit_toolkit",
        "-ldmakit",
        "-lfreetype",
        "-lpng",
        "-lz",
        "-laudsrv",
        "-lc",
        "-lkernel",
        "-lcglue",
        "-ldebug",
        "-lpad",
        "-Wl,--end-group",
    });

    // Everything PS2 goes under bin/ps2/ so it does not clash with the desktop
    // executable named `fnwf`. PCSX2 roots its `host:` device at the ELF's
    // directory, so assets must sit next to the ELF under the game's path.
    b.getInstallStep().dependOn(&b.addInstallFile(elf, "bin/ps2/fnwf.elf").step);

    const assets: *Builder.Step.InstallDir = b.addInstallDirectory(.{
        .source_dir = b.path("fnwf/classic/assets"),
        .install_dir = .bin,
        .install_subdir = "ps2/fnwf/classic/assets",
    });
    b.getInstallStep().dependOn(&assets.step);

    // Convert the game's OGGs to 16-bit mono WAV: the PS2 has no Ogg decoder
    // in this build, and audsrv streams WAV/PCM. The backend loads `<name>.wav`
    // when the game asks for `<name>.ogg`.
    const audio_src: []const u8 = b.pathJoin(&.{ "fnwf", "classic", "assets", "audio" });
    const audio_files = [_][]const u8{
        "ambient",       "animatronic_na_porta", "colocar_mascara",
        "menu_ambient",  "noite_concluida",      "passos",
        "portas",        "retirar_mascara",      "sonk_indo_pra_porta",
        "trocar_camera", "usando_a_mascara",     "ventilacao",
    };
    for (audio_files) |stem| {
        const conv: *Builder.Step.Run = b.addSystemCommand(&.{
            "ffmpeg", "-y", "-loglevel", "error", "-i",
        });
        conv.addFileArg(b.path(b.pathJoin(&.{ audio_src, b.fmt("{s}.ogg", .{stem}) })));
        conv.addArgs(&.{
            "-ac",     "1",
            "-ar",     "22050",
            "-acodec", "pcm_s16le",
            "-f",      "wav",
        });
        const wav: Builder.LazyPath = conv.addOutputFileArg(b.fmt("{s}.wav", .{stem}));
        conv.step.dependOn(&assets.step);
        const install_wav: *Builder.Step.InstallFile = b.addInstallFile(
            wav,
            b.fmt("bin/ps2/fnwf/classic/assets/audio/{s}.wav", .{stem}),
        );
        b.getInstallStep().dependOn(&install_wav.step);
    }

    // audsrv's IOP modules, loaded at runtime with SifLoadModule("host:...").
    inline for (.{ "libsd.irx", "audsrv.irx" }) |irx| {
        const inst = b.addInstallFile(.{
            .cwd_relative = b.fmt("{s}/iop/irx/{s}", .{ ps2sdk, irx }),
        }, b.fmt("bin/ps2/{s}", .{irx}));
        b.getInstallStep().dependOn(&inst.step);
    }
}

/// Desktop C-backend pipeline (Zig → C → `zig cc`, used for testing).
fn build_c_backend(b: *Builder, game_exe: *Builder.Step.Compile) void {
    const zig_lib: Builder.LazyPath = Builder.LazyPath.zig_lib;

    const install_zig_h: *Builder.Step.InstallFile = b.addInstallHeaderFile(
        zig_lib.path(b, "zig.h"),
        "zig.h",
    );
    b.getInstallStep().dependOn(&install_zig_h.step);

    const cc_cmd: *Builder.Step.Run = b.addSystemCommand(&.{
        b.graph.zig_exe, "cc",
    });
    cc_cmd.addDirectoryArg2(zig_lib, .{ .prefix = "-I" });
    cc_cmd.addFileArg(game_exe.getEmittedBin());
    cc_cmd.addArgs(&.{
        "-O2",
        "-lSDL2",
        "-lSDL2_ttf",
        "-lSDL2_image",
        "-lSDL2_mixer",
        "-o",
    });
    const native_exe: Builder.LazyPath = cc_cmd.addOutputFileArg("fnwf");
    cc_cmd.step.dependOn(b.getInstallStep());

    const cc_step: *Builder.Step = b.step("cc", "Compile the emitted C with zig cc");
    cc_step.dependOn(&cc_cmd.step);

    const run_cmd: *Builder.Step.Run = b.addRunFile(native_exe);
    run_cmd.step.dependOn(&cc_cmd.step);

    const run_step: *Builder.Step = b.step("run", "Build and run the game");
    run_step.dependOn(&run_cmd.step);
}
