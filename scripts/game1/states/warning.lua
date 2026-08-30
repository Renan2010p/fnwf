local warning = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local localization = require("scripts.core.utils.localization")

local WarningState = {}
WarningState.__index = WarningState

function WarningState.new(eng)
    local self = setmetatable({}, WarningState)
    self.eng = eng
    self.timer = 0.0
    self.duration = 5.0
    self.alpha = 0.0
    self.phase = 0
    self.done = false
    return self
end

function WarningState:handle_event(event)
    if event.type == "KEYDOWN" or event.type == "MOUSEBUTTONDOWN" then
        if self.phase < 2 then
            self.phase = 2
            self.alpha = 255.0
        end
    end
end

function WarningState:update(dt)
    self.timer = self.timer + dt
    if self.phase == 0 then
        self.alpha = self.alpha + 600 * dt
        if self.alpha >= 255 then
            self.alpha = 255.0
            self.phase = 1
            self.timer = 0.0
        end
    elseif self.phase == 1 then
        if self.timer >= 1.0 then
            self.phase = 2
        end
    elseif self.phase == 2 then
        self.alpha = self.alpha - 600 * dt
        if self.alpha <= 0 then
            self.alpha = 0.0
            self.done = true
        end
    end
end

function WarningState:is_done()
    return self.done
end

function WarningState:draw(eng)
    eng:clear(0, 0, 0, 255)
    local cx, cy = settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT / 2
    local a = math.floor(self.alpha)

    draw.text(eng, localization.get_text("warning_title"), cx, cy - 80, 40, { 200, 50, 50 }, a, true)

    local lines = {
        localization.get_text("warning_line1"),
        localization.get_text("warning_line2"),
        "",
        localization.get_text("warning_line3"),
        localization.get_text("warning_line4")
    }

    for i, line in ipairs(lines) do
        draw.text(eng, line, cx, cy - 20 + ((i - 1) * 30), 24, settings.WHITE, a, true)
    end
end

warning.WarningState = WarningState
return warning