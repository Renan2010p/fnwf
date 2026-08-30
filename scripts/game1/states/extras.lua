local extras = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")
local localization = require("scripts.core.utils.localization")

local ExtrasState = {}
ExtrasState.__index = ExtrasState

function ExtrasState.new(completed_nights, cheats, achievements, eng)
    local self = setmetatable({}, ExtrasState)
    self.eng = eng
    self.completed_nights = completed_nights or 0
    self.cheats = cheats or { infinite_power = false, fast_nights = false }
    self.achievements = achievements or {}
    self.timer = 0.0
    self.result = nil
    self.done = false
    self.category = 1
    self.anim_idx = 1
    self.selected = 1

    self.categories = {
        localization.get_text("cat_animatronics"),
        localization.get_text("cat_credits"),
        localization.get_text("cat_cheats"),
        localization.get_text("cat_achievements")
    }

    self.animatronics = {
        { name = "Cedro", sprite = "cedro", desc = localization.get_text("cedro_desc") },
        { name = "Eser",  sprite = "eser",  desc = localization.get_text("eser_desc") },
        { name = "Alice", sprite = "alice", desc = localization.get_text("alice_desc") },
        { name = "Renan", sprite = "renan", desc = "O heroi local." }
    }

    self.achievements_list = {
        { id = "survive_n1", name = localization.get_text("night_1_ach_title"), desc = localization.get_text("night_1_ach_desc") },
        { id = "survive_n5", name = localization.get_text("night_5_ach_title"), desc = localization.get_text("night_5_ach_desc") },
        { id = "survive_n6", name = localization.get_text("night_6_ach_title"), desc = localization.get_text("night_6_ach_desc") },
        { id = "survive_n7", name = localization.get_text("night_7_ach_title"), desc = localization.get_text("night_7_ach_desc") }
    }

    self.sprites = {}
    for _, a in ipairs(self.animatronics) do
        self.sprites[a.sprite] = draw.load_sprite(eng, a.sprite)
    end

    return self
end

function ExtrasState:update(dt)
    self.timer = self.timer + dt
end

function ExtrasState:handle_event(event)
    if event.type == "KEYDOWN" then
        local k = event.key
        if k == 27 then
            self.result = "menu"
            self.done = true
            sounds.play_sound("select")
        elseif k == 1073741904 or k == string.byte('a') then
            self.category = (self.category - 2) % #self.categories + 1
            self.selected = 1
            sounds.play_sound("blip")
        elseif k == 1073741903 or k == string.byte('d') then
            self.category = (self.category % #self.categories) + 1
            self.selected = 1
            sounds.play_sound("blip")
        end

        if self.category == 1 then
            if k == 1073741906 or k == string.byte('w') then
                self.anim_idx = (self.anim_idx - 2) % #self.animatronics + 1
                sounds.play_sound("blip")
            elseif k == 1073741905 or k == string.byte('s') then
                self.anim_idx = (self.anim_idx % #self.animatronics) + 1
                sounds.play_sound("blip")
            end
        elseif self.category == 3 then
            if k == 1073741906 or k == string.byte('w') then
                self.selected = (self.selected - 2) % 2 + 1
                sounds.play_sound("blip")
            elseif k == 1073741905 or k == string.byte('s') then
                self.selected = (self.selected % 2) + 1
                sounds.play_sound("blip")
            elseif k == 13 or k == 32 then
                local keys = { "infinite_power", "fast_nights" }
                local key = keys[self.selected]
                self.cheats[key] = not self.cheats[key]
                sounds.play_sound("select")
            end
        end
    end
end

function ExtrasState:draw(eng)
    eng:clear(5, 5, 10, 255)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.01)

    for i, cat in ipairs(self.categories) do
        local is_sel = (i == self.category)
        local color = is_sel and settings.WHITE or { 100, 100, 110 }
        draw.text(eng, cat, 80 + (i - 1) * 230, 40, 20, color, 255, false)
        if is_sel then
            eng:draw_rect(80 + (i - 1) * 230, 65, 80, 2, 255, 255, 255, 255)
        end
    end

    if self.category == 1 then
        self:_draw_animatronics(eng)
    elseif self.category == 2 then
        self:_draw_credits(eng)
    elseif self.category == 3 then
        self:_draw_cheats(eng)
    elseif self.category == 4 then
        self:_draw_achievements(eng)
    end

    draw.text(eng, localization.get_text("extras_help"), 80, settings.SCREEN_HEIGHT - 40, 14, { 150, 150, 160 }, 255,
        false)
    draw.scanlines(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 10)
end

function ExtrasState:_wrap_text(text, max_width, size)
    local words = {}
    for word in tostring(text):gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local current = ""
    local font_idx = draw.get_font_by_size(self.eng, size)

    for _, word in ipairs(words) do
        local candidate = (current == "") and word or (current .. " " .. word)
        local tw = self.eng:get_text_size(candidate, size, font_idx)
        if tw <= max_width then
            current = candidate
        else
            if current ~= "" then
                table.insert(lines, current)
                current = word
            else
                table.insert(lines, word)
            end
        end
    end

    if current ~= "" then
        table.insert(lines, current)
    end
    return lines
end

function ExtrasState:_draw_animatronics(eng)
    local a = self.animatronics[self.anim_idx]
    local s = self.sprites[a.sprite]
    local img_x, img_y = 90, 140
    local img_w, img_h = 520, 520
    local text_x = 660
    local text_w = settings.SCREEN_WIDTH - text_x - 80

    eng:draw_rect(img_x - 8, img_y - 8, img_w + 16, img_h + 16, 65, 80, 110, 255, false)
    if s then
        draw.rounded_texture(eng, s, img_x, img_y, img_w, img_h, 20, { 10, 10, 16 }, 255)
    end
    draw.text(eng, string.upper(a.name), text_x, 160, 56, settings.TITLE_COLOR, 255, false)

    local lines = self:_wrap_text(a.desc, text_w, 20)
    for i = 1, math.min(8, #lines) do
        draw.text(eng, lines[i], text_x, 250 + (i - 1) * 34, 20, settings.WHITE, 255, false)
    end

    draw.text(eng, string.format("%d / %d", self.anim_idx, #self.animatronics), img_x, img_y + img_h + 18, 16,
        settings.LIGHT_GRAY, 255,
        false)
end

function ExtrasState:_draw_credits(eng)
    local y = 200
    draw.text(eng, "FIVE NIGHTS WITH FRIENDS", settings.SCREEN_WIDTH / 2, y, 40, settings.TITLE_COLOR, 255, true)
    draw.text(eng, localization.get_text("created_by"), settings.SCREEN_WIDTH / 2, y + 60, 24, settings.WHITE, 255, true)
    draw.text(eng, "Renan Lucas", settings.SCREEN_WIDTH / 2, y + 110, 50, { 100, 200, 255 }, 255, true)
    draw.text(eng, localization.get_text("special_thanks"), settings.SCREEN_WIDTH / 2, y + 300, 18, settings.LIGHT_GRAY,
        255, true)
    draw.text(eng, "Scott Cawthon (FNAF Original)", settings.SCREEN_WIDTH / 2, y + 330, 18, settings.WHITE, 255, true)
end

function ExtrasState:_draw_cheats(eng)
    local cl = {
        { label = localization.get_text("cheat_energy"), key = "infinite_power" },
        { label = localization.get_text("cheat_fast"),   key = "fast_nights" }
    }
    for i, item in ipairs(cl) do
        local is_sel = (i == self.selected)
        local color = is_sel and settings.WHITE or { 120, 120, 130 }
        local prefix = is_sel and ">> " or "   "
        draw.text(eng, prefix .. item.label, 100, 250 + (i - 1) * 60, 28, color, 255, false)

        local st = self.cheats[item.key] and localization.get_text("on") or localization.get_text("off")
        local sc = self.cheats[item.key] and { 100, 255, 100 } or { 255, 100, 100 }
        draw.text(eng, st, 450, 250 + (i - 1) * 60, 28, is_sel and sc or color, 255, false)
    end
end

function ExtrasState:_draw_achievements(eng)
    for i, ach in ipairs(self.achievements_list) do
        local y = 220 + (i - 1) * 80
        local un = false
        for _, id in ipairs(self.achievements) do
            if id == ach.id then
                un = true
                break
            end
        end
        draw.text(eng, un and "★" or "☆", 80, y, 30, un and settings.STAR_COLOR or { 50, 50, 60 }, 255, false)
        draw.text(eng, ach.name, 130, y, 24, un and settings.WHITE or { 60, 60, 70 }, 255, false)
        draw.text(eng, ach.desc, 130, y + 30, 16, un and { 120, 120, 130 } or { 40, 40, 45 }, 255, false)
    end
end

function ExtrasState:is_done()
    return self.done
end

extras.ExtrasState = ExtrasState
return extras