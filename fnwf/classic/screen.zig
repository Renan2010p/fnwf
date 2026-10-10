// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The screen contract the main loop uses to know when a state is finished and
//! what it decided.
//!
//! Neko's `scene.Node` only carries the lifecycle hooks (`ready`/`process`/
//! `draw`/`input`/`deinit`); it no longer has completion/result hooks. Each
//! state therefore publishes its own two hooks here, and `main.zig` reads them
//! through `is_done()` / `result()`.

const std: type = @import("std");

/// The completion hooks a state provides.
pub const VTable: type = struct {
    /// True when the state is finished and the main loop should switch away.
    is_done: *const fn (*anyopaque) bool,
    /// The outcome string the main loop dispatches on ("" when there is none).
    result: *const fn (*anyopaque) []const u8,
};

var ptr: *anyopaque = undefined;
var vtable: *const VTable = undefined;

/// Publishes the active state's completion hooks. Call it from each state's
/// `create`, right after it is allocated.
pub fn attach(p: *anyopaque, vt: *const VTable) void {
    ptr = p;
    vtable = vt;
}

/// True when the active state is finished.
pub fn is_done() bool {
    return vtable.is_done(ptr);
}

/// The active state's outcome ("" when it has none).
pub fn result() []const u8 {
    return vtable.result(ptr);
}

/// A `result` hook for states that do not use one (splash, warning).
pub fn no_result(_: *anyopaque) []const u8 {
    return "";
}
