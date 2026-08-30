local game = {}
local settings = require("scripts.game1.settings")
local off = require("scripts.core.systems.office")
local cams = require("scripts.core.systems.cameras")
local doors = require("scripts.core.systems.doors")
local power = require("scripts.core.systems.power")
local anims = require("scripts.core.systems.animatronics")
local jumpscare = require("scripts.core.systems.jumpscare")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")
local localization = require("scripts.core.utils.localization")

local GameState = {}
GameState.__index = GameState

function GameState.new(eng, night, custom_ai)
    local self = setmetatable({}, GameState)
    self.eng = eng
    self.night = night or 1
    self.custom_ai = custom_ai

    self.office = off.Office.new(eng)
    self.power = power.PowerSystem.new(eng)
    self.doors = doors.DoorSystem.new(eng)
    self.cameras = cams.CameraSystem.new(eng)
    self.animatronics = anims.AnimatronicManager.new(self.night, custom_ai)
    self.secret_mode = self.animatronics:is_secret_mode()
    self.jumpscare = jumpscare.JumpscareSystem.new(eng)

    self.start_ticks = os.clock()
    self.time_elapsed = 0.0
    self.night_duration = settings.HOUR_DURATION * 6
    self.current_hour = 0
    self.prev_hour = 0

    self.fade_alpha = 255
    self.fade_speed = 300
    self.fading_in = true
    self.fading_out = false
    self.result = nil
    self.ambient_started = false

    self.mask_on = false
    self.oxygen = 100.0
    self.max_oxygen = 100.0
    self.oxygen_depletion_rate = 5.5
    self.oxygen_recovery_rate = 8.0

    self.is_blackout = false
    self.blackout_alpha = 0.0
    self.blackout_timer = 0.0

    self.power_out_phase = 0
    self.power_out_timer = 0.0
    self.power_out_delay = 0.0
    self.fx_timer = 0.0
    self.danger_level = 0.0

    sounds.set_engine(eng)
    return self
end

function GameState:update(dt)
    self.fx_timer = self.fx_timer + dt
    if self.fading_in then
        self.fade_alpha = math.max(0, self.fade_alpha - self.fade_speed * dt)
        if self.fade_alpha <= 0 then
            self.fading_in = false
            if not self.ambient_started then
                sounds.play_ambient_loop()
                self.ambient_started = true
            end
        end
        return
    end

    if self.fading_out then
        self.fade_alpha = math.min(255, self.fade_alpha + self.fade_speed * dt)
        return
    end

    if self.jumpscare.active then
        self.jumpscare:update(dt)
        if self.jumpscare:is_done() then
            self.result = "jumpscare"
            self.fading_out = true
            self.fade_alpha = 0
            sounds.stop_all_sounds()
        end
        return
    end

    if self.power.is_dead then
        self:_update_power_out(dt)
        return
    end

    self.time_elapsed = self.time_elapsed + dt
    local new_hour = 12 + math.floor((self.time_elapsed / self.night_duration) * 6)
    if new_hour > 12 then new_hour = new_hour % 12 end
    if new_hour == 0 then new_hour = 12 end
    if new_hour ~= self.prev_hour then
        self.prev_hour = new_hour
        sounds.play_sound("clock")
    end
    self.current_hour = new_hour

    if self.time_elapsed >= self.night_duration then
        if not self._win_triggered then
            self._win_triggered = true
            sounds.stop_all_sounds()
            sounds.play_sound("win")
            self.result = "win"
            self.fading_out = true
            self.fade_alpha = 0
        end
        return
    end

    local mouse_x, mouse_y = self.eng:get_mouse_pos()
    if not self.cameras.is_animating then
        self.cameras:check_mouse_trigger(mouse_x, mouse_y)
    end

    if not self.cameras:is_visible() then
        self.office:update(mouse_x, dt)
    end
    self.cameras:update(dt)
    self.doors:update(dt)
    self.mask_on = self.cameras.is_mask_open or self.cameras.is_mask_animating
    self.power:update(dt, self.doors:get_power_usage(), self.cameras.is_open)

    local cam_looking = self.cameras:is_fully_open() and self.cameras.current_cam or nil
    self.animatronics:update(dt, cam_looking, self.doors.left_closed, self.doors.right_closed, self.mask_on)

    if self.mask_on then
        self.oxygen = math.max(0.0, self.oxygen - self.oxygen_depletion_rate * dt)
        if self.oxygen <= 0 then
            self.cameras:force_remove_mask()
            self.mask_on = self.cameras.is_mask_open or self.cameras.is_mask_animating
        end
    else
        self.oxygen = math.min(self.max_oxygen, self.oxygen + self.oxygen_recovery_rate * dt)
    end

    if self.animatronics:check_alice_just_left() then
        self.is_blackout = true
        self.blackout_alpha = 255.0
        self.blackout_timer = 0.5
    end

    if self.is_blackout then
        if self.blackout_timer > 0 then
            self.blackout_timer = self.blackout_timer - dt
        else
            self.blackout_alpha = math.max(0, self.blackout_alpha - 250 * dt)
            if self.blackout_alpha <= 0 then self.is_blackout = false end
        end
    end

    local attacker = self.animatronics:get_attacker()
    if attacker then
        sounds.stop_all_sounds()
        sounds.play_sound("jumpscare")
        self.jumpscare:trigger(attacker)
    end

    local danger = 0.0
    if self.animatronics:get_at_left_door() then danger = danger + 0.22 end
    if self.animatronics:get_at_right_door() then danger = danger + 0.22 end
    if self.animatronics:get_at_vent() then danger = danger + 0.18 end
    if self.animatronics:get_in_office() then danger = danger + 0.35 end
    if self.power.power <= 25 then danger = danger + 0.15 end
    if self.oxygen <= 35 then danger = danger + 0.1 end
    self.danger_level = math.max(0.0, math.min(1.0, danger))
end

function GameState:_update_power_out(dt)
    if not self._power_out_snd then
        sounds.stop_ambient()
        sounds.play_sound("power_out")
        self._power_out_snd = true
    end
    self.power_out_timer = self.power_out_timer + dt
    if self.power_out_phase == 0 then
        self.doors.left_closed = false
        self.doors.right_closed = false
        self.doors.left_light = false
        self.doors.right_light = false
        self.office.vent_light = false
        self.cameras.is_open = false
        self.mask_on = false
        if self.power_out_timer > 3.0 then
            self.power_out_phase = 1
            self.power_out_delay = 0.0
        end
    elseif self.power_out_phase == 1 then
        self.power_out_delay = self.power_out_delay + dt
        if self.power_out_delay > 5.0 + math.random() * 10 then
            if self.time_elapsed >= self.night_duration then
                self.result = "win"
                self.fading_out = true
            else
                self.power_out_phase = 2
            end
        end
    elseif self.power_out_phase == 2 then
        self.jumpscare:trigger("cedro")
    end
end

function GameState:handle_event(event)
    if self.jumpscare.active or self.power.is_dead or self.fading_in or self.fading_out then return end

    if event.type == "MOUSEBUTTONDOWN" then
        local pos = { event.x, event.y }
        if self.cameras:check_toggle_click(pos) then
            sounds.play_sound("camera")
            return
        end
        if self.cameras:check_mask_toggle_click(pos) then
            sounds.play_sound("camera")
            return
        end
        if self.cameras:is_fully_open() then
            if self.cameras:handle_click(pos) then
                sounds.play_sound("camera")
            end
            return
        end
        if not self.cameras:is_visible() then
            local action = self.doors:handle_click(pos)
            if action then
                sounds.play_sound(action)
                if action == "light" and ((self.doors.left_light and self.animatronics:get_at_left_door()) or
                        (self.doors.right_light and self.animatronics:get_at_right_door())) then
                    sounds.play_sound("animatronic_door")
                end
                return
            end
        end
    end

    if event.type == "KEYDOWN" then
        local key = event.key
        if not self.cameras:is_visible() then
            if key == string.byte('q') then
                self.doors:toggle_left_door()
                sounds.play_sound("door")
            elseif key == string.byte('e') then
                self.doors:toggle_right_door()
                sounds.play_sound("door")
            elseif key == string.byte('a') then
                self.doors:toggle_left_light()
                sounds.play_sound("light")
                if self.doors.left_light and self.animatronics:get_at_left_door() then
                    sounds.play_sound("animatronic_door")
                end
            elseif key == string.byte('d') then
                self.doors:toggle_right_light()
                sounds.play_sound("light")
                if self.doors.right_light and self.animatronics:get_at_right_door() then
                    sounds.play_sound("animatronic_door")
                end
            elseif key == string.byte('l') then
                self.office.vent_light = not self.office.vent_light
                sounds.play_sound("light")
                if self.office.vent_light and self.animatronics:get_at_vent() then
                    sounds.play_sound("animatronic_door")
                end
            end
        end

        if self.cameras:is_fully_open() then
            local cams_map = {
                ['1'] = "1A",
                ['2'] = "1B",
                ['3'] = "1C",
                ['4'] = "2A",
                ['5'] = "2B",
                ['6'] = "3",
                ['7'] = "4A",
                ['8'] = "4B",
                ['9'] = "5"
            }
            local char = string.char(key)
            if cams_map[char] then
                self.cameras:switch_camera(cams_map[char])
                sounds.play_sound("camera")
            end
        end

        if key == 32 and not self.cameras.is_open then
            self.cameras:toggle_mask()
        end
        if key == 27 then -- ESC
            sounds.stop_all_sounds()
            self.result = "menu"
            self.fading_out = true
            self.fade_alpha = 0
        end
        if key == string.byte('p') then
            self.time_elapsed = self.night_duration
        end
    end
end

function GameState:draw(eng)
    local high_fx = draw.get_render_quality() == "high"
    if self.jumpscare.active then
        self.jumpscare:draw(eng)
        self:_draw_fade(eng)
        return
    end
    if self.power.is_dead then
        self:_draw_power_out(eng)
        self:_draw_fade(eng)
        return
    end

    self.office:draw(eng, self.doors.left_anim, self.doors.right_anim,
        self.doors.left_light, self.doors.right_light,
        self.animatronics:get_at_left_door(), self.animatronics:get_at_right_door(),
        self.animatronics:get_at_vent(), self.animatronics:get_in_office())

    if not self.cameras:is_visible() then
        self.doors:draw_buttons(eng, false)
    end

    self.cameras:draw(eng, self.animatronics:get_positions(), self.animatronics:get_foxy_stage())

    if high_fx and not self.cameras:is_visible() then
        local light_pulse = 0.55 + 0.45 * math.sin(self.fx_timer * 8.0)
        if self.doors.left_light then
            for i = 1, 5 do
                local w = 100 + i * 58
                local a = math.floor((50 - i * 7) * light_pulse)
                eng:draw_rect(0, 0, w, settings.SCREEN_HEIGHT, 205, 210, 235, a)
            end
        end
        if self.doors.right_light then
            for i = 1, 5 do
                local w = 100 + i * 58
                local a = math.floor((50 - i * 7) * light_pulse)
                eng:draw_rect(settings.SCREEN_WIDTH - w, 0, w, settings.SCREEN_HEIGHT, 205, 210, 235, a)
            end
        end
        if self.office.vent_light then
            for i = 1, 4 do
                local h = 70 + i * 30
                local a = math.floor(38 - i * 6)
                eng:draw_rect(0, 0, settings.SCREEN_WIDTH, h, 185, 210, 230, a)
            end
        end
    end

    if self.secret_mode then
        local pulse = 0.5 + 0.5 * math.sin(self.time_elapsed * 2.4)
        local alpha = math.floor(36 + 24 * pulse)
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 120, 8, 8, alpha)
    end

    draw.tone_overlay(eng, 8, 18, 32, high_fx and 12 or 8)
    if high_fx then
        draw.vignette(eng, 0.20 + self.danger_level * 0.35, 0, 0, 0)
    end

    -- cinematic light: warm desk spotlight + cool side light (v1.3)
    if high_fx then
        local lp = 0.6 + 0.4 * math.sin(self.time_elapsed * 1.2)
        local cx, cy = settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT * 0.64
        eng:draw_rect(cx - 320, cy - 150, 640, 300, 220, 200, 150, math.floor(7 + 6 * lp))
        eng:draw_rect(cx - 140, cy - 78, 280, 156, 245, 235, 200, math.floor(4 + 3 * lp))
    end
    eng:draw_rect(0, 0, 64, settings.SCREEN_HEIGHT, 30, 45, 90, 22)
    eng:draw_rect(settings.SCREEN_WIDTH - 64, 0, 64, settings.SCREEN_HEIGHT, 30, 45, 90, 22)

    self:_draw_hud(eng)

    if not self.is_blackout or self.blackout_alpha < 150 then
        local noise = (high_fx and 0.008 or 0.003) + self.danger_level * (high_fx and 0.02 or 0.008)
        local scan = math.floor((high_fx and 10 or 6) + self.danger_level * (high_fx and 16 or 8))
        draw.apply_camera_effect(eng, noise, scan, 0)
    end

    if (self.animatronics:get_at_left_door() or self.animatronics:get_at_right_door() or
            self.animatronics:get_at_vent() or self.animatronics:get_in_office()) and not self.is_blackout then
        if math.random() < 0.08 then
            eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0, 0, 0, math.random(50, 180))
        end
    end

    if self.blackout_alpha > 0 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0, 0, 0, math.floor(self.blackout_alpha))
    end

    self:_draw_fade(eng)
end

function GameState:_draw_hud(eng)
    local suffix = localization.get_text("am")
    local hour_str = string.format("%d %s", self.current_hour, suffix)
    draw.text(eng, hour_str, settings.SCREEN_WIDTH - 80, 20, 28, settings.WHITE, 255, true)

    local night_label = (self.night == 7) and localization.get_text("custom_night") or
        string.format("%s %d", localization.get_text("night"), self.night)
    draw.text(eng, night_label, settings.SCREEN_WIDTH - 80, 52, 18, settings.LIGHT_GRAY, 255, true)
    draw.text(eng, "━━━━━━━━", settings.SCREEN_WIDTH - 80, 74, 10, { 50, 50, 55 }, 255, true)

    self.power:draw(eng)

    if self.mask_on or self.oxygen < self.max_oxygen then
        local bar_w, bar_h, x, y = 200, 12, 20, 100
        eng:draw_rect(x, y, bar_w, bar_h, 40, 40, 45, 255)
        local color = (self.oxygen >= 30) and { 100, 200, 255 } or { 255, 100, 100 }
        eng:draw_rect(x, y, math.floor(bar_w * (self.oxygen / self.max_oxygen)), bar_h, color[1], color[2], color[3], 255)
        eng:draw_rect(x, y, bar_w, bar_h, 80, 80, 85, 255, false)
        draw.text(eng, string.format("%s: %d%%", localization.get_text("oxygen"), math.floor(self.oxygen)), x, y - 18, 14,
            settings.WHITE, 255, false)
    end
end

function GameState:_draw_power_out(eng)
    eng:clear(0, 0, 0, 255)
    if self.power_out_phase >= 1 then
        if (math.floor(os.clock() * 2) % 3 ~= 0) then
            draw.animatronic_face(eng, "cedro", 50, settings.SCREEN_HEIGHT / 2 - 120, 200, 250)
            eng:draw_circle(120, settings.SCREEN_HEIGHT / 2 - 20, 8, 255, 255, 255, 255)
            eng:draw_circle(180, settings.SCREEN_HEIGHT / 2 - 20, 8, 255, 255, 255, 255)
            eng:draw_circle(120, settings.SCREEN_HEIGHT / 2 - 20, 4, 30, 30, 200, 255)
            eng:draw_circle(180, settings.SCREEN_HEIGHT / 2 - 20, 4, 30, 30, 200, 255)
            draw.text(eng, "♪ ♫ ♪", 150, settings.SCREEN_HEIGHT / 2 + 140, 20, { 60, 60, 100 }, 255, true)
        end
    end
end

function GameState:_draw_fade(eng)
    if self.fade_alpha > 0 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0, 0, 0, math.floor(self.fade_alpha))
    end
end

function GameState:is_done()
    return self.result ~= nil and self.fade_alpha >= 255
end

game.GameState = GameState
return game