local options = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")
local localization = require("scripts.core.utils.localization")
local settings_manager = require("scripts.core.utils.settings_manager")
local pm = settings_manager.pm

local OptionsState = {}
OptionsState.__index = OptionsState

local function lerp(a, b, t)
    return a + (b - a) * math.min(1.0, math.max(0.0, t))
end

function OptionsState.new(eng)
    local self = setmetatable({}, OptionsState)
    self.eng = eng
    self.timer = 0.0
    self.selected = 1
    self.done = false
    self.result = nil

    -- Dynamic resolution detection
    self.resolutions = {}
    local seen = {}
    local modes = eng:get_display_modes()
    for _, m in ipairs(modes) do
        local key = m.w .. "x" .. m.h
        if not seen[key] then
            table.insert(self.resolutions, { m.w, m.h })
            seen[key] = true
        end
    end
    -- Fallback/Default if no modes detected (unlikely)
    if #self.resolutions == 0 then
        self.resolutions = { { 1280, 720 }, { 1920, 1080 } }
    end
    -- Sort by width
    table.sort(self.resolutions, function(a, b) return a[1] < b[1] end)

    self.current_res = pm.settings.resolution
    self.current_res_idx = 1
    for i, res in ipairs(self.resolutions) do
        if res[1] == self.current_res[1] and res[2] == self.current_res[2] then
            self.current_res_idx = i
            break
        end
    end

    self.is_fullscreen = pm.settings.fullscreen
    self.show_fps = pm.settings.show_fps
    self.vsync = pm.settings.vsync
    self.vsync_at_start = pm.settings.vsync -- track if vsync changed vs launch
    self.vsync_changed = false
    self.lang = pm.settings.language
    self.discord_rpc = pm.settings.discord_rpc

    self.bg_scroll = 0.0
    self:_rebuild_options()
    self.option_rects = {}
    self._layout_dirty = true
    self.highlight_y = 150
    self.highlight_target_y = 150
    self.item_glows = {}
    for i = 1, self.max_options do
        self.item_glows[i] = (i == self.selected) and 1.0 or 0.0
    end
    return self
end

function OptionsState:_rebuild_options()
    local res_values = {}
    for _, r in ipairs(self.resolutions) do
        table.insert(res_values, string.format("%dx%d", r[1], r[2]))
    end

    self.options = {
        { id = "resolution",  label = localization.get_text("resolution"),  type = "toggle", values = res_values,                 current = self.current_res_idx },
        { id = "fullscreen",  label = localization.get_text("fullscreen"),  type = "bool",   value = self.is_fullscreen },
        { id = "language",    label = localization.get_text("language"),    type = "toggle", values = { "Português", "English" }, current = (self.lang == "pt") and 1 or 2 },
        { id = "show_fps",    label = localization.get_text("show_fps"),    type = "bool",   value = self.show_fps },
        { id = "vsync",       label = localization.get_text("vsync"),       type = "bool",   value = self.vsync },
        { id = "discord_rpc", label = localization.get_text("discord_rpc"), type = "bool",   value = self.discord_rpc },
        { id = "back",        label = localization.get_text("back"),        type = "action", action = "back" }
    }
    self.max_options = #self.options
end

function OptionsState:update(dt)
    self.timer = self.timer + dt
    self.bg_scroll = self.bg_scroll + dt * 35
    self.highlight_target_y = 150 + (self.selected - 1) * 55 - 9
    self.highlight_y = lerp(self.highlight_y, self.highlight_target_y, 12.0 * dt)
    for i = 1, self.max_options do
        local target = (i == self.selected) and 1.0 or 0.0
        self.item_glows[i] = lerp(self.item_glows[i] or 0.0, target, 8.0 * dt)
    end
end

function OptionsState:handle_event(event)
    if event.type == "KEYDOWN" then
        local key = event.key
        if key == 1073741906 or key == string.byte('w') then
            self.selected = (self.selected - 2) % self.max_options + 1
            sounds.play_sound("blip")
        elseif key == 1073741905 or key == string.byte('s') then
            self.selected = (self.selected % self.max_options) + 1
            sounds.play_sound("blip")
        elseif key == 1073741904 or key == string.byte('a') or key == 1073741903 or key == string.byte('d') then
            local opt = self.options[self.selected]
            if opt.type == "toggle" then
                local dir = (key == 1073741903 or key == string.byte('d')) and 1 or -1
                opt.current = (opt.current + dir - 1) % #opt.values + 1

                if opt.id == "language" then
                    self.lang = (opt.current == 1) and "pt" or "en"
                    localization.set_language(self.lang)
                    self:_rebuild_options()
                end
                sounds.play_sound("blip")
            elseif opt.type == "bool" then
                opt.value = not opt.value
                sounds.play_sound("blip")
            end
        elseif key == 13 or key == 32 then
            local opt = self.options[self.selected]
            if opt.type == "action" then
                if opt.action == "back" then
                    sounds.play_sound("select")
                    self:_apply_settings()
                    self.result = "back"
                    self.done = true
                end
            elseif opt.type == "bool" then
                opt.value = not opt.value
                sounds.play_sound("blip")
            elseif opt.type == "toggle" then
                opt.current = (opt.current % #opt.values) + 1
                if opt.id == "language" then
                    self.lang = (opt.current == 1) and "pt" or "en"
                    localization.set_language(self.lang)
                    self:_rebuild_options()
                end
                sounds.play_sound("blip")
            end
        end
    end

    if event.type == "MOUSEBUTTONDOWN" then
        local opt = self.options[self.selected]
        if opt.type == "action" and opt.action == "back" then
            sounds.play_sound("select")
            self:_apply_settings()
            self.result = "menu"
            self.done = true
        elseif opt.type == "bool" then
            opt.value = not opt.value
            sounds.play_sound("blip")
        elseif opt.type == "toggle" then
            opt.current = (opt.current % #opt.values) + 1
            sounds.play_sound("blip")
        end
    end
end

function OptionsState:_apply_settings()
    for _, opt in ipairs(self.options) do
        if opt.id == "resolution" then
            local res = self.resolutions[opt.current]
            pm.settings.resolution = res
            self.eng:set_resolution(res[1], res[2])
            self.eng:set_logical_size(1280, 720)
        elseif opt.id == "fullscreen" then
            pm.settings.fullscreen = opt.value
            self.eng:set_fullscreen(opt.value)
        elseif opt.id == "language" then
            pm.settings.language = (opt.current == 1) and "pt" or "en"
        elseif opt.id == "show_fps" then
            pm.settings.show_fps = opt.value
        elseif opt.id == "vsync" then
            pm.settings.vsync = opt.value
            -- VSync cannot be toggled at runtime in SDL2 — save and require restart
            if opt.value ~= self.vsync_at_start then
                self.vsync_changed = true
            else
                self.vsync_changed = false
            end
        elseif opt.id == "discord_rpc" then
            pm.settings.discord_rpc = opt.value
            self.eng:set_discord_enabled(opt.value)
        end
    end
    draw.set_render_quality(pm.settings.quality)
    pm:save()
end

function OptionsState:draw(eng)
    -- Modern Background
    eng:clear(5, 5, 12, 255)

    local grid_size = 80
    local off_x = math.floor(self.bg_scroll % grid_size)
    local off_y = math.floor((self.bg_scroll * 0.4) % grid_size)

    for y = off_y, settings.SCREEN_HEIGHT, grid_size do
        local a = math.floor(12 + 8 * math.sin(self.timer * 0.5 + y * 0.01))
        eng:draw_line(0, y, settings.SCREEN_WIDTH, y, 90, 130, 255, a)
    end
    for x = off_x, settings.SCREEN_WIDTH, grid_size do
        local a = math.floor(12 + 8 * math.cos(self.timer * 0.5 + x * 0.01))
        eng:draw_line(x, 0, x, settings.SCREEN_HEIGHT, 90, 130, 255, a)
    end

    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.006)

    local panel_x, panel_y = 40, 30
    local panel_w, panel_h = settings.SCREEN_WIDTH - 80, settings.SCREEN_HEIGHT - 70

    -- Main Panel
    eng:draw_rect(panel_x, panel_y, panel_w, panel_h, 20, 25, 45, 180)
    -- Border Glow
    local border_pulse = 0.5 + 0.5 * math.sin(self.timer * 1.2)
    local border_a = math.floor(30 + 15 * border_pulse)
    eng:draw_rect(panel_x - 2, panel_y - 2, panel_w + 4, panel_h + 4, 100, 180, 255, border_a, false)

    -- Header
    draw.text(eng, localization.get_text("options"), 70, 56, 42, settings.WHITE, 255, false)
    draw.text(eng, "SYSTEM CONFIGURATION", 72, 98, 12, { 100, 180, 255 }, 180, false)

    -- Selection Highlight
    local hl_y = math.floor(self.highlight_y)
    local hl_pulse = 0.8 + 0.2 * math.sin(self.timer * 5)
    eng:draw_rect(65, hl_y, panel_w - 50, 50, 100, 180, 255, math.floor(35 * hl_pulse), false)
    eng:draw_rect(65, hl_y, 4, 50, 100, 180, 255, 255)

    for i, opt in ipairs(self.options) do
        local y = 150 + (i - 1) * 55
        local glow = self.item_glows[i] or 0.0

        local text_color = {
            math.floor(lerp(140, 255, glow)),
            math.floor(lerp(150, 255, glow)),
            math.floor(lerp(170, 255, glow))
        }

        local value_color = (i == self.selected) and { 100, 220, 255 } or { 150, 160, 180 }

        local value_text = ""
        if opt.type == "toggle" then
            value_text = string.format("< %s >", opt.values[opt.current])
        elseif opt.type == "bool" then
            value_text = opt.value and localization.get_text("on") or localization.get_text("off")
            value_color = opt.value and { 100, 255, 150 } or { 255, 100, 120 }
            if i ~= self.selected then
                value_color = { value_color[1] * 0.6, value_color[2] * 0.6, value_color[3] * 0.6 }
            end
        end

        draw.text(eng, opt.label, 80, y, 26, text_color, 255, false)

        if value_text ~= "" then
            draw.text(eng, value_text, 500, y + 2, 24, value_color, 255, false)
        end
    end

    draw.text(eng, localization.get_text("help_input"), 70, settings.SCREEN_HEIGHT - 55, 14, { 90, 110, 140 }, 180, false)

    -- Show restart notice if VSync was changed
    if self.vsync_changed then
        local notice = (self.lang == "pt") and "* Reinicie o jogo para aplicar VSync" or
        "* Restart the game to apply VSync"
        draw.text(eng, notice, settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 30, 13, { 255, 200, 80 }, 200, true)
    end

    draw.scanlines(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 14)
end

function OptionsState:is_done()
    return self.done
end

options.OptionsState = OptionsState
return options