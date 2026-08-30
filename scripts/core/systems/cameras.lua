local cameras = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")

local CameraSystem = {}
CameraSystem.__index = CameraSystem

function CameraSystem.new(eng)
    local self = setmetatable({}, CameraSystem)
    self.eng = eng
    self.is_open = false
    self.current_cam = "1A"
    self.static_timer = 0.0
    self.static_duration = 0.4

    self.anim_progress = 0.0
    self.anim_speed = 5.0
    self.is_animating = false

    self.is_mask_open = false
    self.mask_anim_progress = 0.0
    self.mask_anim_speed = 4.0
    self.is_mask_animating = false

    self.mouse_trigger_zone = 60
    self.mouse_in_cam_zone = false
    self.mouse_in_mask_zone = false

    self.cam_buttons = {}

    self.map_w = 260
    self.map_h = 300
    self.map_x = settings.SCREEN_WIDTH - self.map_w - 20
    self.map_y = settings.SCREEN_HEIGHT - self.map_h - 60

    self.monitor_tex = eng:create_target_texture(settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT)
    self.map_tex = eng:create_target_texture(self.map_w, self.map_h)
    self.map_base_tex = eng:create_target_texture(self.map_w, self.map_h)
    self.mask_tex = eng:create_target_texture(settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT)
    self._map_base_dirty = true

    self.toggle_btn_rect = nil
    self.mask_btn_rect = nil

    return self
end

function CameraSystem:_ease_out_cubic(value)
    value = math.max(0.0, math.min(1.0, value))
    return 1 - (1 - value) ^ 3
end

function CameraSystem:toggle()
    if self.is_mask_open or self.is_mask_animating then
        return
    end
    self.is_open = not self.is_open
    self.is_animating = true
    if self.is_open then
        self.static_timer = self.static_duration
    end
end

function CameraSystem:toggle_mask()
    if self.is_open or self.is_animating or self.is_mask_animating then
        return
    end
    self.is_mask_open = not self.is_mask_open
    self.is_mask_animating = true

    if self.is_mask_open then
        sounds.play_sound("mask_on")
        sounds.play_mask_breathing()
    else
        sounds.play_sound("mask_off")
        sounds.stop_mask_breathing()
    end
end

function CameraSystem:force_remove_mask()
    if not self.is_mask_open and self.mask_anim_progress <= 0.0 then
        return
    end
    if self.is_mask_animating and not self.is_mask_open then
        return
    end

    self.is_mask_open = false
    self.is_mask_animating = true
end

function CameraSystem:_get_bottom_toggle_rects()
    local btn_w, btn_h = 300, 28
    local gap = 16
    local total_w = btn_w * 2 + gap
    local start_x = math.floor(settings.SCREEN_WIDTH / 2 - total_w / 2)
    local btn_y = settings.SCREEN_HEIGHT - btn_h - 4
    local mask_rect = { start_x, btn_y, btn_w, btn_h }
    local monitor_rect = { start_x + btn_w + gap, btn_y, btn_w, btn_h }
    return mask_rect, monitor_rect
end

function CameraSystem:check_mouse_trigger(mouse_x, mouse_y)
    local mask_rect, monitor_rect = self:_get_bottom_toggle_rects()

    local mx, my, mw, mh = table.unpack(mask_rect)
    local cx, cy, cw, ch = table.unpack(monitor_rect)

    local gesture_h = math.max(mh + 18, self.mouse_trigger_zone)
    local in_mask_zone = mouse_x >= mx and mouse_x <= mx + mw and mouse_y >= my - 14 and mouse_y <= my - 14 + gesture_h
    local in_cam_zone = mouse_x >= cx and mouse_x <= cx + cw and mouse_y >= cy - 14 and mouse_y <= cy - 14 + gesture_h

    if in_cam_zone and not self.mouse_in_cam_zone then
        if not self.is_animating and not self.is_mask_open and not self.is_mask_animating then
            self:toggle()
            self.mouse_in_cam_zone = true
            return true
        end
    elseif not in_cam_zone then
        self.mouse_in_cam_zone = false
    end

    if in_mask_zone and not self.mouse_in_mask_zone then
        if not self.is_mask_animating and not self.is_open and not self.is_animating then
            self:toggle_mask()
            self.mouse_in_mask_zone = true
            return true
        end
    elseif not in_mask_zone then
        self.mouse_in_mask_zone = false
    end

    return false
end

function CameraSystem:switch_camera(cam_id)
    if cam_id ~= self.current_cam and settings.CAMERA_NAMES[cam_id] then
        self.current_cam = cam_id
        self.static_timer = self.static_duration
    end
end

function CameraSystem:update(dt)
    if self.static_timer > 0 then
        self.static_timer = self.static_timer - dt
    end

    local target = self.is_open and 1.0 or 0.0
    if self.anim_progress ~= target then
        self.is_animating = true
        if self.anim_progress < target then
            self.anim_progress = math.min(target, self.anim_progress + self.anim_speed * dt)
        else
            self.anim_progress = math.max(target, self.anim_progress - self.anim_speed * dt)
        end
    else
        self.is_animating = false
    end

    local mask_target = self.is_mask_open and 1.0 or 0.0
    if self.mask_anim_progress ~= mask_target then
        self.is_mask_animating = true
        if self.mask_anim_progress < mask_target then
            self.mask_anim_progress = math.min(mask_target, self.mask_anim_progress + self.mask_anim_speed * dt)
        else
            self.mask_anim_progress = math.max(mask_target, self.mask_anim_progress - self.mask_anim_speed * dt)
        end
    else
        self.is_mask_animating = false
    end
end

function CameraSystem:is_fully_open()
    return self.is_open and self.anim_progress >= 0.99
end

function CameraSystem:is_visible()
    return self.anim_progress > 0.01
end

function CameraSystem:handle_click(pos)
    if not self:is_fully_open() then
        return false
    end

    local px, py = pos[1], pos[2]
    for cam_id, rect in pairs(self.cam_buttons) do
        local rx, ry, rw, rh = table.unpack(rect)
        if px >= rx and px <= rx + rw and py >= ry and py <= ry + rh then
            self:switch_camera(cam_id)
            return true
        end
    end

    if self.toggle_btn_rect then
        local tx, ty, tw, th = table.unpack(self.toggle_btn_rect)
        if px >= tx and px <= tx + tw and py >= ty and py <= ty + th then
            if not self.is_animating and not self.is_mask_open then
                self:toggle()
            end
            return true
        end
    end
    return false
end

function CameraSystem:check_toggle_click(pos)
    local _, monitor_rect = self:_get_bottom_toggle_rects()
    local px, py = pos[1], pos[2]
    local rx, ry, rw, rh = table.unpack(monitor_rect)
    if px >= rx and px <= rx + rw and py >= ry and py <= ry + rh then
        if not self.is_animating and not self.is_mask_open and not self.is_mask_animating then
            self:toggle()
        end
        return true
    end
    return false
end

function CameraSystem:check_mask_toggle_click(pos)
    local mask_rect, _ = self:_get_bottom_toggle_rects()
    local px, py = pos[1], pos[2]
    local rx, ry, rw, rh = table.unpack(mask_rect)
    if px >= rx and px <= rx + rw and py >= ry and py <= ry + rh then
        if not self.is_mask_animating and not self.is_open and not self.is_animating then
            self:toggle_mask()
        end
        return true
    end
    return false
end

function CameraSystem:draw(eng, animatronic_positions, foxy_stage)
    self.mask_btn_rect, self.toggle_btn_rect = self:_get_bottom_toggle_rects()
    local mask_x, btn_y, btn_w, btn_h = table.unpack(self.mask_btn_rect)
    local monitor_x, _, _, _ = table.unpack(self.toggle_btn_rect)

    if not self.is_mask_open and not self:is_visible() then
        local pulse = 0.5 + 0.5 * math.sin(os.clock() * 5.0)
        local glow = math.floor(80 + 70 * pulse)
        eng:draw_rect(mask_x, btn_y, btn_w, btn_h, 28, 22, 18, 230)
        eng:draw_rect(mask_x, btn_y, btn_w, btn_h, 220, glow, 60, 255, false)
        draw.text(eng, "MASK", mask_x + btn_w / 2, btn_y + btn_h / 2, 12, { 230, 160, 80 }, 255, true)
    end

    if not self:is_visible() and not self.is_mask_open then
        local pulse = 0.5 + 0.5 * math.sin(os.clock() * 4.0)
        local edge_g = math.floor(160 + 60 * pulse)
        eng:draw_rect(monitor_x, btn_y, btn_w, btn_h, 12, 18, 12, 220)
        eng:draw_rect(monitor_x, btn_y, btn_w, btn_h, 40, edge_g, 90, 255, false)
        draw.text(eng, "MONITOR", monitor_x + btn_w / 2, btn_y + btn_h / 2, 12, { 120, edge_g, 160 }, 255, true)
    end

    if self.mask_anim_progress > 0.01 then
        self:_draw_mask_overlay(eng)
    end

    if self:is_visible() then
        if self:is_fully_open() then
            self:_draw_monitor(eng, animatronic_positions, foxy_stage)
        else
            self:_draw_monitor_animation(eng)
        end
    end
end

function CameraSystem:_draw_mask_overlay(eng)
    local eased = self:_ease_out_cubic(self.mask_anim_progress)
    local slide_offset = math.floor((1.0 - eased) * -settings.SCREEN_HEIGHT)

    local mask_r, mask_g, mask_b, mask_a = 44, 33, 22, 185
    local y_top = slide_offset
    local y_bottom = slide_offset + settings.SCREEN_HEIGHT

    local eye_w, eye_h = 210, 170
    local eye_gap = 90
    local eye_y = slide_offset + settings.SCREEN_HEIGHT / 2 - 88
    local left_eye_x = settings.SCREEN_WIDTH / 2 - eye_gap / 2 - eye_w
    local right_eye_x = settings.SCREEN_WIDTH / 2 + eye_gap / 2

    eng:draw_rect(0, y_top, settings.SCREEN_WIDTH, math.max(0, eye_y - y_top), mask_r, mask_g, mask_b, mask_a)
    eng:draw_rect(0, eye_y + eye_h, settings.SCREEN_WIDTH, math.max(0, y_bottom - (eye_y + eye_h)), mask_r, mask_g,
        mask_b, mask_a)

    eng:draw_rect(0, eye_y, math.max(0, left_eye_x), eye_h, mask_r, mask_g, mask_b, mask_a)
    local middle_x = left_eye_x + eye_w
    local middle_w = right_eye_x - middle_x
    eng:draw_rect(middle_x, eye_y, math.max(0, middle_w), eye_h, mask_r, mask_g, mask_b, mask_a)
    eng:draw_rect(right_eye_x + eye_w, eye_y, math.max(0, settings.SCREEN_WIDTH - (right_eye_x + eye_w)), eye_h, mask_r,
        mask_g, mask_b, mask_a)

    local nose_x = settings.SCREEN_WIDTH / 2 - 34
    local nose_y = eye_y + eye_h - 10
    eng:draw_rect(nose_x, nose_y, 68, 120, 48, 36, 24, 210)

    local border = { 100, 78, 50 }
    eng:draw_rect(left_eye_x, eye_y, eye_w, eye_h, border[1], border[2], border[3], 255, false)
    eng:draw_rect(right_eye_x, eye_y, eye_w, eye_h, border[1], border[2], border[3], 255, false)
end

function CameraSystem:_draw_monitor(eng, animatronic_positions, foxy_stage)
    local btn_w, btn_h = 400, 30
    local btn_x = settings.SCREEN_WIDTH / 2 - btn_w / 2
    local eased = self:_ease_out_cubic(self.anim_progress)
    local slide_offset = math.floor((1.0 - eased) * (settings.SCREEN_HEIGHT - 40))

    eng:set_render_target(self.monitor_tex)
    eng:clear(5, 10, 5, 230)

    if self.static_timer > 0 then
        draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.5)
    else
        self:_draw_camera_view(eng, animatronic_positions, foxy_stage)
        self:_draw_map(eng, animatronic_positions)
        draw.text(eng, "CAM " .. self.current_cam, 30, 30, 20, settings.CAM_OUTLINE)

        draw.scanlines(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 20)
        draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.02)

        if math.floor(os.clock()) % 2 == 0 then
            eng:draw_rect(settings.SCREEN_WIDTH - 50, 35, 12, 12, 200, 30, 30)
            draw.text(eng, "REC", settings.SCREEN_WIDTH - 35, 28, 14, { 200, 30, 30 })
        end
    end

    eng:reset_render_target()
    eng:draw_texture(self.monitor_tex, 0, slide_offset)

    local close_btn_y = slide_offset + settings.SCREEN_HEIGHT - 30
    eng:draw_rect(btn_x, close_btn_y, btn_w, 30, 20, 25, 20)
    eng:draw_rect(btn_x, close_btn_y, btn_w, 30, 200, 60, 60, 255, false)
    draw.text(eng, "CLOSE", btn_x + btn_w / 2, close_btn_y + 15, 12, { 200, 60, 60 }, 255, true)
end

function CameraSystem:_draw_monitor_animation(eng)
    local progress = self:_ease_out_cubic(self.anim_progress)
    local slide_offset = math.floor((1.0 - progress) * (settings.SCREEN_HEIGHT - 40))

    eng:draw_rect(16, slide_offset, settings.SCREEN_WIDTH - 32, settings.SCREEN_HEIGHT, 42, 42, 48, 245)
    eng:draw_rect(16, slide_offset, settings.SCREEN_WIDTH - 32, settings.SCREEN_HEIGHT, 180, 180, 180, 255, false)

    local bar_alpha = math.floor(120 + 100 * (1.0 - progress))
    for i = 0, 5 do
        local y = slide_offset + 40 + i * 90 + math.floor((1.0 - progress) * 24)
        eng:draw_rect(28, y, settings.SCREEN_WIDTH - 56, 18, 20, 30, 20, bar_alpha)
    end
end

function CameraSystem:_draw_camera_view(eng, animatronic_positions, foxy_stage)
    local cam = self.current_cam
    local cx, cy = settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT / 2 - 30
    if cam == "1A" then
        self:_draw_show_stage(eng, cx, cy, animatronic_positions)
    elseif cam == "1B" then
        self:_draw_dining_area(eng, cx, cy, animatronic_positions)
    elseif cam == "1C" then
        self:_draw_backstage(eng, cx, cy, animatronic_positions)
    elseif cam == "5" then
        self:_draw_sonk_cove(eng, cx, cy, foxy_stage)
    elseif cam == "2A" or cam == "4A" then
        self:_draw_hallway(eng, cx, cy, "Hall", animatronic_positions, cam)
    elseif cam == "2B" or cam == "4B" then
        self:_draw_hall_corner(eng, cx, cy, "Hall Corner", animatronic_positions, cam)
    elseif cam == "3" then
        self:_draw_supply_closet(eng, cx, cy, animatronic_positions)
    end
end

function CameraSystem:_draw_sonk_cove(eng, cx, cy, foxy_stage)
    eng:draw_rect(cx - 300, cy - 150, 600, 350, 15, 12, 20)
    eng:draw_rect(cx - 280, cy - 130, 560, 310, 35, 30, 45, 120)

    local label = "EMPTY"
    if foxy_stage == 1 then
        label = "RUSTLING..."
    elseif foxy_stage == 2 then
        label = "MOVING..."
    elseif foxy_stage >= 3 then
        label = "GONE"
    end
    draw.text(eng, "SONK COVE", cx - 240, cy - 120, 22, { 170, 170, 190 }, 255, false)
    draw.text(eng, label, cx - 240, cy - 86, 16, { 120, 120, 140 }, 255, false)

    if foxy_stage <= 2 then
        local face_w = 220 + foxy_stage * 30
        local face_h = 250 + foxy_stage * 20
        local fx = cx + 40 - face_w / 2
        local fy = cy + 10 - face_h / 2
        local alpha = 145 + foxy_stage * 40
        draw.animatronic_face(eng, "Sonk", fx, fy, face_w, face_h)
        eng:draw_rect(fx, fy, face_w, face_h, 0, 0, 0, math.max(0, 240 - alpha))
    end
end

function CameraSystem:_draw_show_stage(eng, cx, cy, anim_positions)
    eng:draw_rect(cx - 300, cy - 150, 600, 350, 40, 30, 35)
    if anim_positions["cedro"] == "1A" then
        draw.animatronic_face(eng, "cedro", cx - 130, cy - 40, 100, 120)
    end
    if anim_positions["eser"] == "1A" then
        draw.animatronic_face(eng, "eser", cx + 30, cy - 40, 100, 120)
    end
end

function CameraSystem:_draw_dining_area(eng, cx, cy, anim_positions)
    eng:draw_rect(cx - 300, cy - 150, 600, 350, 30, 28, 32)
    for _, name in ipairs({ "cedro", "eser" }) do
        if anim_positions[name] == "1B" then
            draw.animatronic_face(eng, name, cx - 50, cy - 60, 100, 120)
            break
        end
    end
end

function CameraSystem:_draw_backstage(eng, cx, cy, anim_positions)
    eng:draw_rect(cx - 300, cy - 150, 600, 350, 25, 20, 28)
    if anim_positions["cedro"] == "1C" then
        draw.animatronic_face(eng, "cedro", cx - 60, cy - 40, 120, 150)
    end
end

function CameraSystem:_draw_hallway(eng, cx, cy, name, anim_positions, cam_id)
    eng:draw_rect(cx - 300, cy - 150, 600, 350, 35, 32, 38)
    for _, anim_name in ipairs({ "cedro", "eser" }) do
        if anim_positions[anim_name] == cam_id then
            draw.animatronic_face(eng, anim_name, cx - 50, cy - 50, 100, 130)
            break
        end
    end
end

function CameraSystem:_draw_hall_corner(eng, cx, cy, name, anim_positions, cam_id)
    eng:draw_rect(cx - 300, cy - 150, 600, 350, 20, 18, 22)
    for _, anim_name in ipairs({ "cedro", "eser" }) do
        if anim_positions[anim_name] == cam_id then
            draw.animatronic_face(eng, anim_name, cx - 80, cy - 100, 160, 200)
            break
        end
    end
end

function CameraSystem:_draw_supply_closet(eng, cx, cy, anim_positions)
    eng:draw_rect(cx - 300, cy - 150, 600, 350, 28, 25, 30)
    if anim_positions["cedro"] == "3" then
        draw.animatronic_face(eng, "cedro", cx - 60, cy - 40, 120, 150)
    end
end

function CameraSystem:_draw_map(eng, anim_positions)
    local mx, my = self.map_x, self.map_y
    local mw, mh = self.map_w, self.map_h

    local cam_positions = {
        ["1A"] = { mw / 2, 40 },
        ["1B"] = { mw / 2, 80 },
        ["1C"] = { 60, 100 },
        ["5"]  = { 145, 105 },
        ["2A"] = { 90, 150 },
        ["2B"] = { 90, 210 },
        ["3"]  = { 50, 160 },
        ["4A"] = { mw - 90, 150 },
        ["4B"] = { mw - 90, 210 },
    }

    local connections = {
        { "1A", "1B" }, { "1B", "1C" }, { "1C", "5" }, { "1B", "2A" }, { "2A", "2B" }, { "2A", "3" }, { "1B", "4A" },
        { "4A", "4B" }
    }

    if self._map_base_dirty then
        eng:set_render_target(self.map_base_tex)
        eng:clear(10, 20, 10, 180)
        eng:draw_rect(0, 0, mw, mh, settings.CAM_OUTLINE[1], settings.CAM_OUTLINE[2], settings.CAM_OUTLINE[3], 255, false)
        for _, conn in ipairs(connections) do
            local p1 = cam_positions[conn[1]]
            local p2 = cam_positions[conn[2]]
            eng:draw_line(math.floor(p1[1]), math.floor(p1[2]), math.floor(p2[1]), math.floor(p2[2]), 0, 255, 0, 255)
        end
        self._map_base_dirty = false
    end

    eng:set_render_target(self.map_tex)
    eng:clear(0, 0, 0, 0)
    eng:draw_texture(self.map_base_tex, 0, 0)

    self.cam_buttons = {}
    for cam_id, pos in pairs(cam_positions) do
        local px, py = pos[1], pos[2]
        local btn_w, btn_h = 36, 22
        self.cam_buttons[cam_id] = { mx + px - btn_w / 2, my + py - btn_h / 2, btn_w, btn_h }

        local is_active = (cam_id == self.current_cam)
        local color = { 0, 255, 0 }
        local bg_color = is_active and { 20, 80, 20 } or { 5, 20, 5 }

        eng:draw_rect(px - btn_w / 2, py - btn_h / 2, btn_w, btn_h, bg_color[1], bg_color[2], bg_color[3])
        eng:draw_rect(px - btn_w / 2, py - btn_h / 2, btn_w, btn_h, color[1], color[2], color[3], 255, false)
        draw.text(eng, cam_id, px, py, 11, color, 255, true)
    end

    draw.text(eng, "YOU", mw / 2, mh - 30, 12, { 0, 255, 0 }, 255, true)
    eng:draw_line(math.floor(mw / 2), mh - 45, math.floor(mw / 2), mh - 55, 0, 255, 0, 255)

    eng:set_render_target(self.monitor_tex)
    eng:draw_texture(self.map_tex, mx, my)
end

cameras.CameraSystem = CameraSystem
return cameras