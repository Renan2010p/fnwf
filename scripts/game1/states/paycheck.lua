local paycheck = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")
local localization = require("scripts.core.utils.localization")

local PaycheckState = {}
PaycheckState.__index = PaycheckState

function PaycheckState.new(eng)
    local self = setmetatable({}, PaycheckState)
    self.eng = eng
    self.timer = 0.0
    self.done = false
    self.fade_alpha = 255
    self.fading_in = true
    self.fading_out = false
    self.name = "Renan Lucas"
    self.amount = "1.621,00"
    self.date = "15/02/2026"
    return self
end

function PaycheckState:update(dt)
    self.timer = self.timer + dt
    if self.fading_in then
        self.fade_alpha = math.max(0, self.fade_alpha - 150 * dt)
        if self.fade_alpha <= 0 then self.fading_in = false end
    end
    if self.fading_out then
        self.fade_alpha = math.min(255, self.fade_alpha + 150 * dt)
        if self.fade_alpha >= 255 then self.done = true end
    end
end

function PaycheckState:handle_event(event)
    if event.type == "KEYDOWN" or event.type == "MOUSEBUTTONDOWN" then
        if not self.fading_in and not self.fading_out then
            self.fading_out = true
            sounds.play_sound("select")
        end
    end
end

function PaycheckState:draw(eng)
    eng:clear(20, 20, 25, 255)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.01)

    local cw, ch = 700, 350
    local cx, cy = (settings.SCREEN_WIDTH - cw) / 2, (settings.SCREEN_HEIGHT - ch) / 2
    eng:draw_rect(cx, cy, cw, ch, 245, 245, 230, 255)
    eng:draw_rect(cx, cy, cw, ch, 50, 50, 50, 255, false)

    draw.text(eng, "MÁFIA BRASILEIRA DOS TABACUDOS", cx + 30, cy + 30, 24, { 40, 40, 50 }, 255, false)
    draw.text(eng, localization.get_text("pay_services"), cx + 30, cy + 65, 14, { 60, 60, 70 }, 255, false)

    eng:draw_rect(cx + cw - 220, cy + 30, 190, 40, 255, 255, 255, 255)
    eng:draw_rect(cx + cw - 220, cy + 30, 190, 40, 0, 0, 0, 255, false)

    local prefix = (localization.get_text("language") == "Language") and "$" or "R$"
    draw.text(eng, prefix .. " " .. self.amount, cx + cw - 210, cy + 38, 22, { 0, 0, 0 }, 255, false)

    draw.text(eng, localization.get_text("pay_to"), cx + 30, cy + 130, 16, { 60, 60, 70 }, 255, false)
    draw.text(eng, string.upper(self.name), cx + 50, cy + 160, 38, { 20, 20, 30 }, 255, false)
    eng:draw_line(cx + 50, cy + 205, cx + cw - 50, cy + 205, 100, 100, 110, 255)

    draw.text(eng, string.format("%s %s", localization.get_text("pay_date"), self.date), cx + 30, cy + 250, 16,
        { 60, 60, 70 }, 255, false)
    draw.text(eng, localization.get_text("pay_signed"), cx + cw - 250, cy + 250, 14, { 60, 60, 70 }, 255, false)
    draw.text(eng, "Cedro (Big Boss)", cx + cw - 250, cy + 280, 22, { 30, 30, 40 }, 255, false)
    eng:draw_line(cx + cw - 260, cy + 275, cx + cw - 30, cy + 275, 0, 0, 0, 255)

    draw.text(eng, localization.get_text("pay_congrats_5"), settings.SCREEN_WIDTH / 2, cy + ch + 50, 20, settings.WHITE,
        255, true)
    draw.text(eng, localization.get_text("click_continue"), settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 40, 14,
        settings.LIGHT_GRAY, 255, true)

    if self.fade_alpha > 0 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0, 0, 0, math.floor(self.fade_alpha))
    end
end

function PaycheckState:is_done()
    return self.done
end

paycheck.PaycheckState = PaycheckState
return paycheck