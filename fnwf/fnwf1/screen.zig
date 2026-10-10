// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! The screen contract the main loop uses to know when a state is finished and
//! what it decided (same bridge the classic game uses).

const std: type = @import("std");

/// The completion hooks a state provides.
pub const VTable: type = struct {
    is_done: *const fn (*anyopaque) bool,
    result: *const fn (*anyopaque) []const u8,
};

var ptr: *anyopaque = undefined;
var vtable: *const VTable = undefined;

/// Publishes the active state's completion hooks.
pub fn attach(p: *anyopaque, vt: *const VTable) void {
    ptr = p;
    vtable = vt;
}

/// True when the active state is finished.
pub fn is_done() bool {
    return vtable.is_done(ptr);
}

/// The active state's outcome.
pub fn result() []const u8 {
    return vtable.result(ptr);
}
