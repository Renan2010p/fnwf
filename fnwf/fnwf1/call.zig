// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Renan Lucas Vieira Hilário

//! FNWF 1 — the nightly phone call from Cedro.
//!
//! Cedro, the guard who worked the office before you, leaves a message every
//! night (the Phone Guy role). The text types out; ENTER reveals/skips a line.

const std: type = @import("std");
const neko: type = @import("neko");
const common: type = @import("common");

const screen: type = @import("screen.zig");
const config: type = @import("config.zig");

const Allocator: type = std.mem.Allocator;
const TYPING_CPS: f32 = 46.0;

const N1: []const []const u8 = &.{
    "Alô? Alô, alô?",
    "Eu queria gravar uma mensagem pra te ajudar no seu primeiro turno.",
    "Na verdade eu trabalhei nessa sala antes de você. Tô terminando minha última semana agora.",
    "Deixa eu ler o aviso da empresa... é coisa jurídica, sabe como é.",
    "\"Bem-vindo à Pizzaria Máfia dos Tabacudos, um lugar mágico para crianças e adultos...\" blá blá blá.",
    "Enfim. Os animatrônicos ficam meio... \"ativos\" de noite. E eu não culpo eles.",
    "Só uma coisa: eles tentam te enfiar dentro de uma fantasia. Sabe, contra as regras daqui.",
    "Mas o primeiro dia deve ser tranquilo. Eu falo com você amanhã.",
    "Olha as câmeras. E só feche as portas se for absolutamente necessário. Economiza energia.",
    "Boa noite.",
};

const N2: []const []const u8 = &.{
    "Alô? Alô?",
    "Se você tá ouvindo isso e chegou ao segundo dia, parabéns!",
    "O Eser e a Alice ficam mais ativos conforme a semana passa.",
    "Ah, e usa as luzes das portas. Tem pontos cegos nas câmeras — bem na sua porta.",
    "Às vezes você tem só alguns segundos pra reagir. Não que você corra perigo, claro. Não tô insinuando nada.",
    "E dá uma olhada na Pirate Cove de vez em quando. O Sonk não gosta muito de ser observado.",
    "Enfim, tenho certeza que você tem tudo sob controle. Até logo!",
};

const N3: []const []const u8 = &.{
    "Alô, alô?",
    "Você tá indo bem! Pouca gente aguenta tanto tempo.",
    "Quer dizer, a maioria já arrumou outra coisa pra fazer. Não tô dizendo que morreram. Não foi isso.",
    "Hoje as coisas começam a ficar sérias de verdade.",
    "Escuta, tive uma ideia: se você for pego, tenta se fingir de morto. Fica mole.",
    "Aí talvez eles pensem que você é uma fantasia vazia. Mas se pensarem isso, podem tentar enfiar um esqueleto de metal dentro de você...",
    "É, deixa pra lá. Melhor não ser pego.",
    "Te vejo do outro lado!",
};

const N4: []const []const u8 = &.{
    "Alô, alô?",
    "Ei, dia quatro! Eu sabia que você conseguia.",
    "Olha, é capaz de eu não estar por aqui amanhã pra te mandar mensagem.",
    "Tá sendo uma noite ruim pra mim aqui. Ainda bem que eu gravei essas mensagens quando dava.",
    "Faz um favor: dá uma olhada dentro daquelas fantasias no quarto dos fundos?",
    "Vou tentar aguentar até alguém checar. Talvez não seja tão ruim assim.",
    "Sempre tive curiosidade de saber o que tem dentro daquelas cabeças vazias...",
    "Você sabe...",
    "Ah, não —",
};

const N5: []const []const u8 = &.{
    "...",
    "(o telefone chia, a voz sai distorcida)",
    "…você ainda… está… aí?",
    "…não devia… ter… olhado…",
    "…cuida… da… porta… direita…",
    "(estática)",
};

const N6: []const []const u8 = &.{
    "Alô?",
    "Você voltou. Eu sabia que ia voltar.",
    "O turno extra é o pior de todos. Todo mundo já sabe que você tá aí.",
    "Sem mensagens amanhã. Só sobreviva até as 6.",
    "E olha... obrigado por ter checado aquelas fantasias.",
};

fn lines_for(night: i32) []const []const u8 {
    return switch (night) {
        1 => N1,
        2 => N2,
        3 => N3,
        4 => N4,
        5 => N5,
        6 => N6,
        else => N1,
    };
}

/// The phone-call screen.
pub const Call: type = struct {
    node: neko.scene.Node,
    night: i32,

    ringing: f32 = 1.8,
    line: usize = 0,
    chars: f32 = 0,
    done: bool = false,
    result: []const u8 = "",
    rang: bool = false,

    pub fn create(allocator: Allocator, night: i32) !*neko.scene.Node {
        const self: *Call = try allocator.create(Call);
        self.* = Call{
            .node = neko.scene.Node{
                .ptr = @ptrCast(self),
                .vtable = &vtable,
                .allocator = allocator,
                .name = "call",
            },
            .night = night,
        };
        screen.attach(self, &screen_vtable);
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

const screen_vtable: screen.VTable = .{ .is_done = is_done, .result = result };

fn process(ptr: *anyopaque, dt: f32) void {
    const self: *Call = @ptrCast(@alignCast(ptr));
    if (self.ringing > 0) {
        self.ringing -= dt;
        if (self.ringing <= 0) self.rang = true;
        return;
    }
    const lines = lines_for(self.night);
    if (self.line < lines.len) {
        self.chars = @min(@as(f32, @floatFromInt(lines[self.line].len)), self.chars + TYPING_CPS * dt);
    }
}

fn advance(self: *Call) void {
    if (self.ringing > 0) {
        self.ringing = 0;
        return;
    }
    const lines = lines_for(self.night);
    if (self.line >= lines.len) {
        self.done = true;
        self.result = "play";
        return;
    }
    const full: f32 = @floatFromInt(lines[self.line].len);
    if (self.chars < full) {
        self.chars = full;
        return;
    }
    self.line += 1;
    self.chars = 0;
    if (self.line >= lines.len) {
        self.done = true;
        self.result = "play";
    }
}

fn input(ptr: *anyopaque, ev: neko.Event) void {
    const self: *Call = @ptrCast(@alignCast(ptr));
    switch (ev) {
        .key_down => |k| {
            if (k.code == 13 or k.code == 32 or k.code == 27) advance(self);
        },
        .mouse_button_down => advance(self),
        else => {},
    }
}

fn draw(ptr: *anyopaque, at: neko.Point) void {
    _ = at;
    const self: *Call = @ptrCast(@alignCast(ptr));
    neko.draw.clear(config.BLACK);
    neko.effect.scanlines(0, 0, config.SCREEN_W, config.SCREEN_H, 12);

    const cx: i32 = config.SCREEN_W / 2;

    // A simple phone handset.
    neko.draw.rect(neko.Rect{ .x = cx - 70, .y = 70, .w = 140, .h = 34 }, neko.Color{ .r = 40, .g = 40, .b = 46 }, true);
    neko.draw.rect(neko.Rect{ .x = cx - 78, .y = 62, .w = 26, .h = 50 }, neko.Color{ .r = 52, .g = 52, .b = 58 }, true);
    neko.draw.rect(neko.Rect{ .x = cx + 52, .y = 62, .w = 26, .h = 50 }, neko.Color{ .r = 52, .g = 52, .b = 58 }, true);

    if (self.ringing > 0) {
        const pulse: bool = @mod(@as(i32, @intFromFloat(@as(f32, @floatFromInt(neko.time.ticks_ms())) / 250.0)), 2) == 0;
        neko.sprite.text(if (pulse) "CHAMADA RECEBIDA" else "CHAMANDO...", cx, 150, .{ .size = 30, .center = true, .color = config.ACCENT });
        neko.sprite.text("Cedro está ligando", cx, 190, .{ .size = 18, .center = true, .color = config.MUTED });
        neko.sprite.text("Pressione ENTER para atender", cx, config.SCREEN_H - 60, .{ .size = 16, .center = true, .color = config.MUTED });
        return;
    }

    neko.sprite.text("EM CHAMADA — CEDRO", cx, 150, .{ .size = 22, .center = true, .color = config.ACCENT });

    const lines = lines_for(self.night);
    const panel_x: i32 = 260;
    const panel_y: i32 = 220;
    const panel_w: i32 = config.SCREEN_W - 520;
    neko.draw.rect(neko.Rect{ .x = panel_x, .y = panel_y, .w = panel_w, .h = 360 }, config.PANEL, true);
    neko.draw.rect(neko.Rect{ .x = panel_x, .y = panel_y, .w = panel_w, .h = 360 }, config.LINE, false);

    const visible: usize = 8;
    const start: usize = if (self.line + 1 > visible) self.line + 1 - visible else 0;
    var drawn: i32 = 0;
    var i: usize = start;
    while (i <= self.line and i < lines.len) : (i += 1) {
        const text = if (i < self.line)
            lines[i]
        else
            lines[i][0..@intFromFloat(self.chars)];
        const bright: bool = i == self.line;
        neko.sprite.text(text, panel_x + 24, panel_y + 20 + drawn * 40, .{
            .size = 18,
            .color = if (bright) config.WHITE else neko.Color{ .r = 150, .g = 150, .b = 158 },
        });
        drawn += 1;
    }

    neko.sprite.text("ENTER para avançar", cx, config.SCREEN_H - 60, .{ .size = 16, .center = true, .color = config.MUTED });
}

fn is_done(ptr: *anyopaque) bool {
    const self: *Call = @ptrCast(@alignCast(ptr));
    return self.done;
}

fn result(ptr: *anyopaque) []const u8 {
    const self: *Call = @ptrCast(@alignCast(ptr));
    return self.result;
}

fn deinit(ptr: *anyopaque, allocator: Allocator) void {
    const self: *Call = @ptrCast(@alignCast(ptr));
    allocator.destroy(self);
}
