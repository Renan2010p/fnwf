local custom_night = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")
local localization = require("scripts.core.utils.localization")

local CustomNightState = {}
CustomNightState.__index = CustomNightState

local function lerp(a, b, t)
    return a + (b - a) * math.min(1.0, math.max(0.0, t))
end

local function digit_from_event(event)
    local scan_name = event.scan_name
    if type(scan_name) == "string" then
        if #scan_name == 1 and scan_name >= "0" and scan_name <= "9" then
            return scan_name
        end
        local kp_digit = scan_name:match("^KP%s*(%d)$")
        if kp_digit then
            return kp_digit
        end
    end

    local key_name = event.key_name
    if type(key_name) == "string" then
        if #key_name == 1 and key_name >= "0" and key_name <= "9" then
            return key_name
        end
    end

    local k = event.key
    if type(k) ~= "number" then
        return nil
    end

    if k >= string.byte('0') and k <= string.byte('9') then
        return string.char(k)
    end

    -- SDL numpad keycodes (SDLK_KP_0 ... SDLK_KP_9)
    local kp_map = {
        [1073741922] = "0",
        [1073741913] = "1",
        [1073741914] = "2",
        [1073741915] = "3",
        [1073741916] = "4",
        [1073741917] = "5",
        [1073741918] = "6",
        [1073741919] = "7",
        [1073741920] = "8",
        [1073741921] = "9",
    }
    return kp_map[k]
end

function CustomNightState.new(eng)
    local self = setmetatable({}, CustomNightState)
    self.eng = eng
    self.timer = 0.0
    self.selected = 1
    self.done = false
    self.result = nil
    self.ai_levels = { 0, 0, 0, 0 }
    self.animatronics = {
        { name = "Cedro", sprite = "cedro", size = { 220, 220 } },
        { name = "Eser",  sprite = "eser",  size = { 220, 220 } },
        { name = "Alice", sprite = "alice", size = { 220, 220 } },
        { name = "Sonk",  sprite = "Sonk",  size = { 220, 220 } },
    }

    self.sprites = {}
    for _, a in ipairs(self.animatronics) do
        self.sprites[a.sprite] = draw.load_sprite(eng, a.sprite)
    end

    self.presets = {
        { name = "Custom",            levels = nil },
        { name = "BUAAA",             levels = { 5, 5, 20, 8 } },
        { name = "E pq vejemos",      levels = { 10, 20, 10, 10 } },
        { name = "Não força a barra", levels = { 20, 20, 20, 20 } },
    }
    self.current_preset = 1
    self.secret_code_buffer = ""
    self.secret_code_pending = false
    self.secret_mode_unlocked = false

    self.card_rects = {}
    self.up_rects = {}
    self.down_rects = {}
    self.preset_rects = {}
    self.ready_rect = { 0, 0, 0, 0 }
    self.card_scales = {}
    self.card_glows = {}
    for i = 1, #self.animatronics do
        self.card_scales[i] = (i == self.selected) and 1.02 or 1.0
        self.card_glows[i] = (i == self.selected) and 1.0 or 0.0
    end
    self:_rebuild_layout()

    return self
end

function CustomNightState:_get_ai_cap()
    return self.secret_mode_unlocked and 40 or 20
end

function CustomNightState:_unlock_secret_mode()
    if not self.secret_mode_unlocked then
        self.secret_mode_unlocked = true
        table.insert(self.presets, { name = "Nao me chame de ditador", levels = { 40, 40, 40, 40 } })
    end
    self.current_preset = #self.presets
    self:apply_preset(self.current_preset)
end

function CustomNightState:update(dt)
    self.timer = self.timer + dt
    for i = 1, #self.animatronics do
        local is_sel = (i == self.selected)
        local target_scale = is_sel and 1.02 or 1.0
        local target_glow = is_sel and 1.0 or 0.0
        self.card_scales[i] = lerp(self.card_scales[i] or 1.0, target_scale, 8.0 * dt)
        self.card_glows[i] = lerp(self.card_glows[i] or 0.0, target_glow, 6.0 * dt)
    end
end

function CustomNightState:_rebuild_layout()
    local card_w, card_h = 280, 430
    local gap = 42
    local total_w = #self.animatronics * card_w + (#self.animatronics - 1) * gap
    local start_x = settings.SCREEN_WIDTH / 2 - total_w / 2
    local y = 120

    self.card_rects = {}
    self.up_rects = {}
    self.down_rects = {}
    for i = 1, #self.animatronics do
        local x = start_x + (i - 1) * (card_w + gap)
        table.insert(self.card_rects, { x, y, card_w, card_h })
        table.insert(self.up_rects, { x + card_w / 2 - 32, y + 300, 64, 44 })
        table.insert(self.down_rects, { x + card_w / 2 - 32, y + 380, 64, 44 })
    end

    local cx = settings.SCREEN_WIDTH / 2
    self.preset_rects.prev = { cx - 250, 580, 80, 48 }
    self.preset_rects.next = { cx + 170, 580, 80, 48 }
    self.preset_rects.label = { cx - 160, 580, 320, 48 }
    self.ready_rect = { cx - 180, 642, 360, 54 }
end

function CustomNightState:apply_preset(index)
    if index >= 1 and index <= #self.presets then
        self.current_preset = index
        local levels = self.presets[index].levels
        if levels then
            self.ai_levels = {}
            for i, l in ipairs(levels) do
                self.ai_levels[i] = l
            end
        end
        sounds.play_sound("blip")
    end
end

function CustomNightState:cycle_preset(direction)
    local new_idx = (self.current_preset + direction - 1) % #self.presets + 1
    self:apply_preset(new_idx)
end

function CustomNightState:handle_event(event)
    if event.type == "KEYDOWN" then
        local k = event.key

        local digit = digit_from_event(event)
        if digit then
            self.secret_code_buffer = self.secret_code_buffer .. digit
            if #self.secret_code_buffer > 4 then
                self.secret_code_buffer = self.secret_code_buffer:sub(-4)
            end
            if self.secret_code_buffer == "2025" then
                self.secret_code_pending = true
                self.selected = #self.animatronics + 1
                sounds.play_sound("notification")
                self.secret_code_buffer = ""
            end
        end

        if k == 27 then
            self.result = "menu"
            self.done = true
            sounds.play_sound("select")
        elseif k == 1073741904 or k == string.byte('a') then
            self.selected = (self.selected - 2) % (#self.animatronics + 1) + 1
            sounds.play_sound("blip")
        elseif k == 1073741903 or k == string.byte('d') then
            self.selected = (self.selected % (#self.animatronics + 1)) + 1
            sounds.play_sound("blip")
        end

        if self.selected <= #self.animatronics then
            local change = 0
            if k == 1073741906 or k == string.byte('w') then
                change = 1
            elseif k == 1073741905 or k == string.byte('s') then
                change = -1
            end

            if change ~= 0 then
                local cap = self:_get_ai_cap()
                self.ai_levels[self.selected] = math.max(0, math.min(cap, self.ai_levels[self.selected] + change))
                self.current_preset = 1 -- Reset to Custom
                sounds.play_sound("blip")
            end
        end

        if k == 13 or k == 32 then
            if self.selected == #self.animatronics + 1 then
                if self.secret_code_pending then
                    self.secret_code_pending = false
                    self:_unlock_secret_mode()
                    sounds.play_sound("select")
                else
                    self.result = "start"
                    self.done = true
                    sounds.play_sound("select")
                end
            else
                self.selected = #self.animatronics + 1
                sounds.play_sound("blip")
            end
        end
    end

    if event.type == "MOUSEMOTION" then
        local mx, my = event.x, event.y
        for i, r in ipairs(self.card_rects) do
            if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then
                if self.selected ~= i then
                    self.selected = i
                end
                break
            end
        end
    end

    if event.type == "MOUSEBUTTONDOWN" then
        local mx, my = event.x, event.y
        for i, r in ipairs(self.card_rects) do
            if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then
                self.selected = i
            end
        end

        for i, r in ipairs(self.up_rects) do
            if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then
                local cap = self:_get_ai_cap()
                self.ai_levels[i] = math.max(0, math.min(cap, self.ai_levels[i] + 1))
                self.current_preset = 1
                self.selected = i
                sounds.play_sound("blip")
            end
        end

        for i, r in ipairs(self.down_rects) do
            if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then
                local cap = self:_get_ai_cap()
                self.ai_levels[i] = math.max(0, math.min(cap, self.ai_levels[i] - 1))
                self.current_preset = 1
                self.selected = i
                sounds.play_sound("blip")
            end
        end

        local r = self.preset_rects.prev
        if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then
            self:cycle_preset(-1)
        end
        r = self.preset_rects.next
        if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then
            self:cycle_preset(1)
        end

        r = self.ready_rect
        if mx >= r[1] and mx <= r[1] + r[3] and my >= r[2] and my <= r[2] + r[4] then
            if self.secret_code_pending then
                self.secret_code_pending = false
                self:_unlock_secret_mode()
                sounds.play_sound("select")
            else
                self.result = "start"
                self.done = true
                sounds.play_sound("select")
            end
        end
    end
end

function CustomNightState:draw(eng)
    eng:clear(6, 9, 18, 255)
    for i = 0, settings.SCREEN_HEIGHT - 1, 90 do
        local a = (math.floor(i / 90) % 2 == 0) and 12 or 7
        eng:draw_rect(0, i, settings.SCREEN_WIDTH, 90, 10, 14, 26, a)
    end
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.01)
    eng:draw_rect(24, 24, settings.SCREEN_WIDTH - 48, 76, 80, 110, 160, 70, false)
    draw.text(eng, localization.get_text("custom_night"), settings.SCREEN_WIDTH / 2, 38, 54, settings.TITLE_COLOR, 255,
        true)

    for i, a in ipairs(self.animatronics) do
        local r = self.card_rects[i]
        local x, y, w, h = table.unpack(r)
        local cx = x + w / 2
        local glow = self.card_glows[i] or 0.0
        local scale = self.card_scales[i] or 1.0

        local draw_w = math.floor(w * scale)
        local draw_h = math.floor(h * scale)
        local draw_x = math.floor(x - (draw_w - w) / 2)
        local draw_y = math.floor(y - (draw_h - h) / 2)

        if glow > 0.05 then
            local pulse = 0.5 + 0.5 * math.sin(self.timer * 6.0)
            local edge = math.floor(lerp(120, 230, glow))
            local blue = math.floor(130 + pulse * 110 * glow)
            eng:draw_rect(draw_x - 3, draw_y - 3, draw_w + 6, draw_h + 6, 90, 120, blue, 255, false)
            eng:draw_rect(draw_x, draw_y, draw_w, draw_h, edge, edge, math.min(255, edge + 45), 255, false)
        else
            eng:draw_rect(draw_x, draw_y, draw_w, draw_h, 70, 85, 115, 255, false)
        end

        local img_x, img_y, img_w, img_h = draw_x + 18, draw_y + 18, draw_w - 36, 220
        local s = self.sprites[a.sprite]
        if s then
            local sw, sh = table.unpack(a.size)
            local draw_w = math.min(sw, img_w - 8)
            local draw_h = math.min(sh, img_h - 8)
            local sx = img_x + (img_w - draw_w) / 2
            local sy = img_y + (img_h - draw_h) / 2
            draw.rounded_texture(eng, s, sx, sy, draw_w, draw_h, 12, { 12, 12, 16 }, 255)
        end

        draw.text(eng, a.name, cx, y + 260, 30, settings.WHITE, 255, true)

        local up = self.up_rects[i]
        local down = self.down_rects[i]
        local btn_col = (glow > 0.2) and { 150, 170, 210 } or { 90, 90, 105 }

        eng:draw_rect(up[1], up[2], up[3], up[4], btn_col[1], btn_col[2], btn_col[3], 255, false)
        draw.text(eng, "▲", up[1] + up[3] / 2, up[2] + up[4] / 2 + 1, 26, settings.WHITE, 255, true)

        local lvl = self.ai_levels[i]
        local val_col = (lvl >= 20) and { 255, 60, 60 } or ((lvl == 0) and { 80, 220, 110 } or settings.WHITE)
        draw.text(eng, tostring(lvl), cx, y + 360, 52, val_col, 255, true)

        eng:draw_rect(down[1], down[2], down[3], down[4], btn_col[1], btn_col[2], btn_col[3], 255, false)
        draw.text(eng, "▼", down[1] + down[3] / 2, down[2] + down[4] / 2 + 1, 26, settings.WHITE, 255, true)
    end

    local prev = self.preset_rects.prev
    local next_r = self.preset_rects.next
    local label = self.preset_rects.label
    local pulse = 0.5 + 0.5 * math.sin(self.timer * 4.0)
    local arrow_col = { 200, 200, math.floor(140 + 70 * pulse) }

    eng:draw_rect(prev[1], prev[2], prev[3], prev[4], 120, 120, 140, 255, false)
    draw.text(eng, "<<", prev[1] + prev[3] / 2, prev[2] + prev[4] / 2, 28, arrow_col, 255, true)

    eng:draw_rect(label[1], label[2], label[3], label[4], 100, 100, 120, 255, false)
    local p_name = self.presets[self.current_preset].name
    local label_size = 30
    if string.len(p_name) >= 22 then
        label_size = 20
    elseif string.len(p_name) >= 16 then
        label_size = 24
    end
    draw.text(eng, p_name, label[1] + label[3] / 2, label[2] + label[4] / 2, label_size, { 255, 255, 120 }, 255, true)

    eng:draw_rect(next_r[1], next_r[2], next_r[3], next_r[4], 120, 120, 140, 255, false)
    draw.text(eng, ">>", next_r[1] + next_r[3] / 2, next_r[2] + next_r[4] / 2, 28, arrow_col, 255, true)

    local rs = (self.selected == #self.animatronics + 1)
    local rr = self.ready_rect
    if rs then
        local glow = math.floor(100 + 100 * (0.5 + 0.5 * math.sin(self.timer * 7.0)))
        eng:draw_rect(rr[1], rr[2], rr[3], rr[4], glow, glow, 80, 255, false)
    else
        eng:draw_rect(rr[1], rr[2], rr[3], rr[4], 120, 120, 130, 255, false)
    end
    local ready_label = self.secret_code_pending and "APLICAR CODIGO" or localization.get_text("ready")
    draw.text(eng, (rs and ">> " or "") .. ready_label, rr[1] + rr[3] / 2, rr[2] + rr[4] / 2, 40,
        rs and settings.WHITE or { 150, 150, 160 }, 255, true)

    draw.text(eng, localization.get_text("custom_controls_help"), settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 22,
        14, { 100, 100, 110 }, 255, true)
    draw.scanlines(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 15)
end

function CustomNightState:is_done()
    return self.done
end

custom_night.CustomNightState = CustomNightState
return custom_night