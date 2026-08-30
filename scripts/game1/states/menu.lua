local menu = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local localization = require("scripts.core.utils.localization")
local sounds = require("scripts.core.utils.sounds")

local MenuState = {}
MenuState.__index = MenuState

local function lerp(a, b, t)
    return a + (b - a) * math.min(1.0, math.max(0.0, t))
end

function MenuState.new(completed_nights, has_seen_story, eng)
    local self = setmetatable({}, MenuState)
    self.completed_nights = completed_nights or 0
    self.has_seen_story = has_seen_story or false
    self.eng = eng
    self.timer = 0.0
    self.menu_page = "main"
    self.options = self:_build_options()
    self.selected = 1
    self.max_options = #self.options
    self.cedro_sprite = draw.load_sprite(eng, "cedro")
    self.eser_sprite = draw.load_sprite(eng, "eser")
    self.alice_sprite = draw.load_sprite(eng, "alice")
    self.sonk_sprite = draw.load_sprite(eng, "Sonk")
    self.menu_animatronics = {
        self.eser_sprite,
        self.cedro_sprite,
        self.alice_sprite,
        self.sonk_sprite
    }
    self.current_anim_idx = math.random(1, #self.menu_animatronics)
    self.mafia_logo = draw.load_sprite(eng, "mafia")
    self.option_rects = {}
    self._layout_dirty = true
    self._menu_y = 300
    self._menu_spacing = 62
    self._menu_x = 54

    -- PS5-style animation state
    self.highlight_y = self._menu_y - 17 -- Current Y of the sliding highlight
    self.highlight_target_y = self.highlight_y
    self.item_scales = {}                -- Per-item scale (1.0 = normal, grows to ~1.06 when selected)
    self.item_glows = {}                 -- Per-item glow intensity (0.0 to 1.0)
    self.item_bar_widths = {}            -- Per-item left accent bar width
    self.accent_pulse = 0.0              -- Global accent pulse for selected glow

    for i = 1, self.max_options do
        self.item_scales[i] = (i == 1) and 1.0 or 1.0
        self.item_glows[i] = (i == 1) and 1.0 or 0.0
        self.item_bar_widths[i] = (i == 1) and 4.0 or 0.0
    end

    sounds.set_engine(eng)
    sounds.play_menu_ambient()
    return self
end

function MenuState:_build_options()
    local opts = {}
    if self.menu_page == "main" then
        table.insert(opts, { label = localization.get_text("new_game"), action = "start" })
        if self.has_seen_story or self.completed_nights > 0 then
            local next_night = math.min(self.completed_nights + 1, 6)
            table.insert(opts,
                {
                    label = string.format("%s (%s %d)", localization.get_text("continue"), localization.get_text("night"),
                        next_night),
                    action = "continue"
                })
        end
        if self.completed_nights >= 5 then
            table.insert(opts, { label = string.format("%s 6", localization.get_text("night")), action = "night6" })
        end
        if self.completed_nights >= 5 then
            table.insert(opts, { label = localization.get_text("more"), action = "more" })
        end
        table.insert(opts, { label = localization.get_text("quit"), action = "quit" })
    elseif self.menu_page == "more" then
        if self.completed_nights >= 5 then
            table.insert(opts, { label = localization.get_text("extras"), action = "extras" })
            table.insert(opts, { label = localization.get_text("custom_night"), action = "night7" })
        end
        table.insert(opts, { label = localization.get_text("achievements"), action = "conquistas" })
        table.insert(opts, { label = localization.get_text("back"), action = "back_menu" })
    end
    return opts
end

function MenuState:update(dt)
    self.timer = self.timer + dt

    -- PS5 animation: smooth lerp for highlight bar position
    local speed = 12.0 * dt
    self.highlight_target_y = self._menu_y + (self.selected - 1) * self._menu_spacing - 17
    self.highlight_y = lerp(self.highlight_y, self.highlight_target_y, speed)

    -- Keep only selection animation.
    self.accent_pulse = 1.0
    for i = 1, self.max_options do
        local is_sel = (i == self.selected)
        local target_scale = is_sel and 1.05 or 1.0
        local target_glow = is_sel and 1.0 or 0.0
        local target_bar = is_sel and 4.0 or 0.0
        self.item_scales[i] = lerp(self.item_scales[i] or 1.0, target_scale, 8.0 * dt)
        self.item_glows[i] = lerp(self.item_glows[i] or 0.0, target_glow, 6.0 * dt)
        self.item_bar_widths[i] = lerp(self.item_bar_widths[i] or 0.0, target_bar, 10.0 * dt)
    end
end

function MenuState:handle_event(event)
    if event.type == "KEYDOWN" then
        local key = event.key
        if key == 1073741906 or key == string.byte('w') then
            self.selected = (self.selected - 2) % self.max_options + 1
            sounds.play_sound("blip")
        elseif key == 1073741905 or key == string.byte('s') then
            self.selected = (self.selected % self.max_options) + 1
            sounds.play_sound("blip")
        elseif key == 13 or key == 32 then
            return self:_handle_action(self.options[self.selected].action)
        end
    end

    if event.type == "MOUSEMOTION" then
        local mx, my = event.x, event.y
        for i, rect in ipairs(self.option_rects) do
            local rx, ry, rw, rh = table.unpack(rect)
            if mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh then
                if self.selected ~= i then
                    self.selected = i
                    sounds.play_sound("blip")
                end
                break
            end
        end
    end

    if event.type == "MOUSEBUTTONDOWN" then
        local mx, my = event.x, event.y
        for i, rect in ipairs(self.option_rects) do
            local rx, ry, rw, rh = table.unpack(rect)
            if mx >= rx and mx <= rx + rw and my >= ry and my <= ry + rh then
                self.selected = i
                return self:_handle_action(self.options[i].action)
            end
        end
    end
    return nil
end

function MenuState:_handle_action(action)
    sounds.play_sound("select")
    if action == "more" then
        self.menu_page = "more"
        self.selected = 1
        self.options = self:_build_options()
        self.max_options = #self.options
        self._layout_dirty = true
        self:_reset_anim_state()
        return nil
    elseif action == "back_menu" then
        self.menu_page = "main"
        self.selected = 1
        self.options = self:_build_options()
        self.max_options = #self.options
        self._layout_dirty = true
        self:_reset_anim_state()
        return nil
    end
    self.result = action
    self.done = true
    return action
end

function MenuState:_reset_anim_state()
    self.highlight_y = self._menu_y - 17
    self.highlight_target_y = self.highlight_y
    self.item_scales = {}
    self.item_glows = {}
    self.item_bar_widths = {}
    for i = 1, self.max_options do
        self.item_scales[i] = (i == 1) and 1.0 or 1.0
        self.item_glows[i] = (i == 1) and 1.0 or 0.0
        self.item_bar_widths[i] = (i == 1) and 4.0 or 0.0
    end
end

function MenuState:_rebuild_option_rects()
    self.option_rects = {}
    for i, opt in ipairs(self.options) do
        local y = self._menu_y + (i - 1) * self._menu_spacing
        local text_width = string.len(opt.label) * 15 + 54
        local box_width = math.max(360, text_width)
        table.insert(self.option_rects, { self._menu_x, y - 17, box_width, 48 })
    end
    self._layout_dirty = false
end

function MenuState:draw(eng)
    if self._layout_dirty then
        self:_rebuild_option_rects()
    end

    self:_draw_background(eng)

    -- Title block (VHS OSD style)
    local mx, ty = 60, 64
    draw.vhs_osd(eng, "FIVE NIGHTS", mx, ty, { 220, 240, 220 }, 46)
    draw.vhs_osd(eng, "WITH FRIENDS 1", mx, ty + 52, { 220, 240, 220 }, 46)
    draw.text(eng, "v1.3", mx + 2, ty + 112, 15, { 140, 170, 200 }, 220, false)

    -- divider
    eng:draw_rect(mx, ty + 140, 360, 2, 100, 180, 255, math.floor(120 + 40 * math.sin(self.timer * 2)))

    -- watermark
    draw.text(eng, "AUTH: RENAN // PROJECT: FNWF", settings.SCREEN_WIDTH - 290, 30, 10, { 100, 150, 200 }, 130, false)
    draw.text(eng, "PROPRIETARY BUILD - v1.3", settings.SCREEN_WIDTH - 290, 14, 11, { 255, 100, 100 }, 180, false)

    -- Menu Options (modern)
    for i, opt in ipairs(self.options) do
        local rect = self.option_rects[i]
        local rx, ry, rw, rh = table.unpack(rect)
        local glow = self.item_glows[i] or 0.0
        local bar_w = self.item_bar_widths[i] or 0.0
        local selected = (i == self.selected)
        local bri = math.floor(lerp(140, 255, glow))
        local color = { bri, bri, bri + math.floor(20 * glow) }

        if selected then
            eng:draw_rect(rx - 6, ry, 6, rh, 100, 180, 255, 255) -- thin accent bar
        end
        draw.text(eng, opt.label, rx + 14, ry + 12, 22, color, 255, false)
    end

    -- Footer
    local fy = settings.SCREEN_HEIGHT - 58
    draw.text(eng, "[ UP / DOWN ] SELECT     [ ENTER ] PLAY     [ ESC ] BACK",
        60, fy, 13, { 110, 130, 160 }, 200, false)
    draw.text(eng, "Five Nights With Friends 1", 60, fy + 20, 11, { 80, 90, 110 }, 140, false)
end

function MenuState:_draw_background(eng)
    -- clean cinematic base (no panel frame -> no visible square around the character)
    eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 4, 5, 9, 255)

    local current_anim = self.menu_animatronics[self.current_anim_idx]
    if current_anim then
        local bounce = 5 * math.sin(self.timer * 0.8)
        -- character with rounded corners, matching the menu background
        draw.rounded_texture(eng, current_anim, settings.SCREEN_WIDTH - 640, 70 + bounce, 560, 560, 34, { 4, 5, 9 }, 255)
    end
end

function MenuState:is_done()
    return self.done
end

menu.MenuState = MenuState
return menu