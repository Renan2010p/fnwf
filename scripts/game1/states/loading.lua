local loading = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")

local LoadingState = {}
LoadingState.__index = LoadingState

LoadingState.TIPS = {
    "DICA: Use a luz para verificar os corredores.",
    "DICA: O Eser pode ser visto nas câmeras, mas ele é rápido.",
    "DICA: Se a Alice estiver na ventilação, use a máscara.",
    "DICA: Economize energia. A noite é longa.",
    "DICA: A porta só gasta energia se estiver fechada.",
    "DICA: O Cedro ataca pelo lado esquerdo.",
    "DICA: O Sonk odeia ser observado.",
    "DICA: O Eser ataca pelo lado direito",
    "DICA: Ouça atentamente os sons.",
    "DICA: Sobreviva até as 6 AM.",
    "CURIOSIDADE: A pizzaria foi fechada 3 vezes pela vigilância sanitária.",
    "CURIOSIDADE: Dizem que o animatrônico do dev nunca dorme.",
}

function LoadingState.new(next_state_factory, eng)
    local self = setmetatable({}, LoadingState)
    self.eng = eng
    self.next_state_factory = next_state_factory
    self.timer = 0.0
    self.duration = 4.0
    self.tip = LoadingState.TIPS[math.random(1, #LoadingState.TIPS)]
    self.done = false
    self.next_state = nil
    self.font_alpha = 0
    self.glitch_timer = 0.0
    self.loader_angle = 0.0
    return self
end

function LoadingState:handle_event(event)
end

function LoadingState:update(dt)
    self.timer = self.timer + dt
    self.glitch_timer = self.glitch_timer + dt
    self.loader_angle = self.loader_angle + 360 * dt

    if self.timer < 0.5 then
        self.font_alpha = math.floor((self.timer / 0.5) * 255)
    elseif self.duration - self.timer < 0.5 then
        self.font_alpha = math.floor(((self.duration - self.timer) / 0.5) * 255)
    else
        self.font_alpha = 255
    end

    if self.timer >= self.duration then
        self.done = true
        if self.next_state_factory then
            self.next_state = self.next_state_factory()
        end
    end
end

function LoadingState:is_done()
    return self.done
end

function LoadingState:draw(eng)
    eng:clear(3, 3, 5, 255)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.012)
    local cx, cy = settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT / 2
    local ox = (math.random() < 0.05) and math.random(-4, 4) or 0

    draw.text(eng, self.tip, cx + ox, cy, 18, { 160, 160, 170 }, self.font_alpha, true)

    local lx, ly, radius = settings.SCREEN_WIDTH - 80, settings.SCREEN_HEIGHT - 80, 20
    for i = 0, 7 do
        local angle = math.rad(self.loader_angle + (i * 45))
        local ex, ey = lx + math.cos(angle) * radius, ly + math.sin(angle) * radius
        eng:draw_line(lx, ly, math.floor(ex), math.floor(ey), 120, 120, 130, 255)
    end

    eng:draw_rect(lx - (radius - 6), ly - (radius - 6), (radius - 6) * 2, (radius - 6) * 2, 0, 0, 0, 255) -- Approximation of circle fill
    -- Actually draw_circle with fill=true is better if available
    eng:draw_circle(lx, ly, radius - 6, 0, 0, 0, 255, true)
    eng:draw_circle(lx, ly, radius - 10, 150, 150, 160, 255, false)

    draw.text(eng, "Carregando...", lx, ly + 35, 14, { 100, 100, 110 }, 255, true)
end

loading.LoadingState = LoadingState
return loading