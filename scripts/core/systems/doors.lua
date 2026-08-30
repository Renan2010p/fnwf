local doors = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")

local DoorSystem = {}
DoorSystem.__index = DoorSystem

function DoorSystem.new(eng)
    local self = setmetatable({}, DoorSystem)
    self.eng = eng
    self.left_closed = false
    self.right_closed = false
    self.left_light = false
    self.right_light = false
    self.left_anim, self.right_anim = 0.0, 0.0
    self.anim_speed = 4.0
    self.button_rects = {}
    return self
end

function DoorSystem:toggle_left_door()
    self.left_closed = not self.left_closed
    -- Sound handling later
end

function DoorSystem:toggle_right_door()
    self.right_closed = not self.right_closed
end

function DoorSystem:toggle_left_light()
    self.left_light = not self.left_light
    if self.left_light then
        self.right_light = false
    end
end

function DoorSystem:toggle_right_light()
    self.right_light = not self.right_light
    if self.right_light then
        self.left_light = false
    end
end

function DoorSystem:update(dt)
    local target_l = self.left_closed and 1.0 or 0.0
    if self.left_anim < target_l then
        self.left_anim = math.min(target_l, self.left_anim + self.anim_speed * dt)
    elseif self.left_anim > target_l then
        self.left_anim = math.max(target_l, self.left_anim - self.anim_speed * dt)
    end

    local target_r = self.right_closed and 1.0 or 0.0
    if self.right_anim < target_r then
        self.right_anim = math.min(target_r, self.right_anim + self.anim_speed * dt)
    elseif self.right_anim > target_r then
        self.right_anim = math.max(target_r, self.right_anim - self.anim_speed * dt)
    end
end

function DoorSystem:get_power_usage()
    local usage = 0
    if self.left_closed then usage = usage + 1 end
    if self.right_closed then usage = usage + 1 end
    if self.left_light then usage = usage + 1 end
    if self.right_light then usage = usage + 1 end
    return usage
end

function DoorSystem:draw_buttons(eng, camera_open)
    if camera_open then return end
    self.button_rects = {}
    local panel_w, panel_h = 96, 106
    local bw, bh, gap = 78, 34, 8
    local panel_y = math.floor(settings.SCREEN_HEIGHT * 0.50) - math.floor(panel_h / 2)

    local lx = 14
    eng:draw_rect(lx, panel_y, panel_w, panel_h, 12, 12, 16, 210)
    eng:draw_rect(lx, panel_y, panel_w, panel_h, 60, 60, 70, 255, false)
    draw.text(eng, "PORTA E", lx + panel_w / 2, panel_y - 12, 11, settings.LIGHT_GRAY, 255, true)
    local l_btn_x, l_btn_y = lx + 9, panel_y + 10
    local left_door_label = self.left_closed and "ABRIR" or "FECHAR"
    draw.button_box(eng, l_btn_x, l_btn_y, bw, bh, left_door_label, self.left_closed, settings.BUTTON_RED, settings.BUTTON_OFF)
    self.button_rects["left_door"] = { l_btn_x, l_btn_y, bw, bh }
    draw.button_box(eng, l_btn_x, l_btn_y + bh + gap, bw, bh, "LUZ", self.left_light, settings.BUTTON_GREEN, settings.BUTTON_OFF)
    self.button_rects["left_light"] = { l_btn_x, l_btn_y + bh + gap, bw, bh }

    local rx = settings.SCREEN_WIDTH - panel_w - 14
    eng:draw_rect(rx, panel_y, panel_w, panel_h, 12, 12, 16, 210)
    eng:draw_rect(rx, panel_y, panel_w, panel_h, 60, 60, 70, 255, false)
    draw.text(eng, "PORTA D", rx + panel_w / 2, panel_y - 12, 11, settings.LIGHT_GRAY, 255, true)
    local r_btn_x, r_btn_y = rx + 9, panel_y + 10
    local right_door_label = self.right_closed and "ABRIR" or "FECHAR"
    draw.button_box(eng, r_btn_x, r_btn_y, bw, bh, right_door_label, self.right_closed, settings.BUTTON_RED, settings.BUTTON_OFF)
    self.button_rects["right_door"] = { r_btn_x, r_btn_y, bw, bh }
    draw.button_box(eng, r_btn_x, r_btn_y + bh + gap, bw, bh, "LUZ", self.right_light, settings.BUTTON_GREEN, settings.BUTTON_OFF)
    self.button_rects["right_light"] = { r_btn_x, r_btn_y + bh + gap, bw, bh }
end

function DoorSystem:handle_click(pos)
    for name, rect in pairs(self.button_rects) do
        local bx, by, bw, bh = table.unpack(rect)
        if pos[1] >= bx and pos[1] <= bx + bw and pos[2] >= by and pos[2] <= by + bh then
            if string.find(name, "door") then
                if string.find(name, "left") then
                    self:toggle_left_door()
                else
                    self:toggle_right_door()
                end
                return "door"
            end
            if string.find(name, "light") then
                if string.find(name, "left") then
                    self:toggle_left_light()
                else
                    self:toggle_right_light()
                end
                return "light"
            end
        end
    end
    return nil
end

doors.DoorSystem = DoorSystem
return doors