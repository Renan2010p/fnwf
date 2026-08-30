local jumpscare = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")

local JumpscareSystem = {}
JumpscareSystem.__index = JumpscareSystem

function JumpscareSystem.new(eng)
    local self = setmetatable({}, JumpscareSystem)
    self.eng = eng
    self.active = false
    self.animatronic = nil
    self.timer = 0.0
    self.duration = 1.2
    self.shake_intensity = 20
    self.done = false
    return self
end

function JumpscareSystem:trigger(animatronic_name)
    if self.active then return end
    self.active = true
    self.animatronic = animatronic_name
    self.timer = 0.0
    self.done = false
end

function JumpscareSystem:update(dt)
    if not self.active then return end
    self.timer = self.timer + dt
    if self.timer >= self.duration then
        self.done = true
    end
end

function JumpscareSystem:draw(eng)
    if not self.active then return end
    local prog = math.min(1.0, self.timer / self.duration)
    eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0, 0, 0, 255)

    local sx = math.random(-20, 20)
    local sy = math.random(-20, 20)
    sx = math.floor(sx * (1.0 - prog * 0.5))
    sy = math.floor(sy * (1.0 - prog * 0.5))

    if prog < 0.1 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 255, 255, 255,
            math.floor(255 * (1.0 - prog / 0.1)))
    end

    local fw = math.floor(settings.SCREEN_WIDTH * 0.6 * (1.0 + prog * 0.3))
    local fh = math.floor(settings.SCREEN_HEIGHT * 0.7 * (1.0 + prog * 0.3))

    draw.animatronic_face(eng, self.animatronic, math.floor(settings.SCREEN_WIDTH / 2 - fw / 2 + sx),
        math.floor(settings.SCREEN_HEIGHT / 2 - fh / 2 + sy - 30), fw, fh)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.1 + prog * 0.2)

    eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 200, 0, 0,
        math.floor(80 * math.sin(self.timer * 20) ^ 2))
end

function JumpscareSystem:is_done()
    return self.done
end

function JumpscareSystem:reset()
    self.active = false
    self.animatronic = nil
    self.timer = 0.0
    self.done = false
end

jumpscare.JumpscareSystem = JumpscareSystem
return jumpscare