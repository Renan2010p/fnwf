local newspaper = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")

local NewspaperState = {}
NewspaperState.__index = NewspaperState

function NewspaperState.new(eng)
    local self = setmetatable({}, NewspaperState)
    self.eng = eng
    self.timer = 0.0
    self.done = false
    self.fade_alpha = 255
    self.fading_in = true
    self.fading_out = false
    return self
end

function NewspaperState:update(dt)
    self.timer = self.timer + dt
    if self.fading_in then
        self.fade_alpha = math.max(0, self.fade_alpha - 100 * dt)
        if self.fade_alpha <= 0 then self.fading_in = false end
    end
    if self.fading_out then
        self.fade_alpha = math.min(255, self.fade_alpha + 150 * dt)
        if self.fade_alpha >= 255 then self.done = true end
    end
end

function NewspaperState:handle_event(event)
    if (event.type == "KEYDOWN" or event.type == "MOUSEBUTTONDOWN") and not self.fading_in and not self.fading_out and self.timer > 3.0 then
        self.fading_out = true
        sounds.play_sound("select")
    end
end

function NewspaperState:draw(eng)
    eng:clear(10, 10, 15, 255)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.015)

    local pw, ph = 600, 450
    local px, py = (settings.SCREEN_WIDTH - pw) / 2, (settings.SCREEN_HEIGHT - ph) / 2
    eng:draw_rect(px, py, pw, ph, 160, 155, 140, 255)
    eng:draw_rect(px, py, pw, ph, 30, 30, 30, 255, false)

    draw.text(eng, "A GAZETA DOS TABACUDOS", px + 30, py + 20, 20, { 40, 40, 40 }, 255, false)
    eng:draw_line(px + 20, py + 45, px + pw - 20, py + 45, 40, 40, 40, 255)
    draw.text(eng, "PIZZARIA FECHADA!", px + pw / 2, py + 80, 34, { 20, 20, 20 }, 255, true)
    draw.text(eng, "ESQUEMA DE CORRUPÇÃO REVELADO", px + pw / 2, py + 120, 16, { 50, 50, 50 }, 255, true)

    local txt = {
        "O ex-seguranca Renan Lucas entregou hoje",
        "as autoridades uma serie de logs confidenciais",
        "do Discord que comprovam que a Pizzaria era",
        "um centro de operacoes clandestinas da Mafia.",
        "",
        "O 'Big Boss' Cedro e seus cumplices fugiram",
        "antes da chegada da policia...",
        "",
        "Renan Lucas recebeu o titulo de heroi local."
    }

    for i, line in ipairs(txt) do
        draw.text(eng, line, px + pw / 2, py + 170 + (i - 1) * 22, 14, { 30, 30, 30 }, 255, true)
    end

    if self.timer > 3.0 and math.floor(self.timer * 2) % 2 == 1 then
        draw.text(eng, "Clique para terminar", settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 50, 16, settings
        .WHITE, 255, true)
    end

    if self.fade_alpha > 0 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0, 0, 0, math.floor(self.fade_alpha))
    end
end

function NewspaperState:is_done()
    return self.done
end

newspaper.NewspaperState = NewspaperState
return newspaper