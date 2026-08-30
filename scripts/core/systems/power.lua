local power = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local localization = require("scripts.core.utils.localization")

local PowerSystem = {}
PowerSystem.__index = PowerSystem

function PowerSystem.new(eng)
    local self = setmetatable({}, PowerSystem)
    self.eng = eng
    self.power = settings.MAX_POWER
    self.usage_level = 1
    self.is_dead = false
    self.dead_timer = 0.0
    self.freddy_music_playing = false
    return self
end

function PowerSystem:update(dt, door_usage, camera_open, vent_usage)
    vent_usage = vent_usage or 0
    if self.is_dead then
        self.dead_timer = self.dead_timer + dt
        return
    end

    self.usage_level = math.min(5, 1 + door_usage + (camera_open and 1 or 0) + vent_usage)
    local drain_mul = ({ 1.0, 1.55, 2.35, 3.4, 4.8 })[self.usage_level] or 1.0
    self.power = self.power - (settings.BASE_POWER_DRAIN * drain_mul) * dt
    if self.power <= 0 then
        self.power = 0
        self.is_dead = true
        self.dead_timer = 0.0
    end
end

function PowerSystem:draw(eng)
    local x, y = 24, settings.SCREEN_HEIGHT - 78
    local power_pct = math.max(0, math.floor(self.power))
    local color = (self.power > 20) and settings.POWER_COLOR or settings.POWER_LOW

    local text = string.format(localization.get_text("power_left"), power_pct)
    draw.text(eng, text, x, y, 18, settings.WHITE, 255, false)

    local uy = y + 28
    draw.text(eng, localization.get_text("usage"), x, uy, 16, settings.HUD_COLOR, 255, false)
    for i = 0, 4 do
        local ux = x + 78 + i * 16
        local c = (i < self.usage_level) and settings.MONITOR_GREEN or { 40, 40, 45 }
        eng:draw_rect(ux, uy + 4, 10, 16, c[1], c[2], c[3], 255)
        eng:draw_rect(ux, uy + 4, 10, 16, 75, 75, 80, 255, false)
    end
end

power.PowerSystem = PowerSystem
return power