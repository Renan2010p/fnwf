local six_am = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")

local SixAMState = {}
SixAMState.__index = SixAMState

function SixAMState.new(eng, night)
    local self = setmetatable({}, SixAMState)
    self.eng = eng
    self.night = night or 1
    self.timer = 0.0
    self.done = false
    self.hour = 5
    self.show_six = false
    self.played_chime = false
    return self
end

function SixAMState:update(dt)
    self.timer = self.timer + dt
    if not self.show_six and self.timer > 2.0 then
        self.hour = 6
        self.show_six = true
    end
    if self.show_six and not self.played_chime then
        sounds.play_sound("noite_concluida")
        self.played_chime = true
    end
    if self.timer > 10.0 then
        self.done = true
    end
end

function SixAMState:handle_event(event)
    if self.timer > 2.0 and (event.type == "KEYDOWN" or event.type == "MOUSEBUTTONDOWN") then
        self.done = true
    end
end

function SixAMState:draw(eng)
    eng:clear(0, 0, 0, 255)
    local cx, cy = settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT / 2
    draw.text(eng, tostring(self.hour), cx - 40, cy - 20, 120, settings.WHITE, 255, true)
    draw.text(eng, "AM", cx + 80, cy - 10, 50, settings.WHITE, 255, true)

    if self.timer > 8.0 and math.floor(self.timer * 2) % 2 == 1 then
        draw.text(eng, "Pressione qualquer tecla", cx, settings.SCREEN_HEIGHT - 50, 16, { 150, 150, 150 }, 255, true)
    end
end

function SixAMState:is_done()
    return self.done
end

six_am.SixAMState = SixAMState
return six_am