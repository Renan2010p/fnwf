local story = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")
local localization = require("scripts.core.utils.localization")

local StoryState = {}
StoryState.__index = StoryState

function StoryState.new(night, eng)
    print("Initializing StoryState for night: " .. tostring(night))
    local self = setmetatable({}, StoryState)
    self.eng = eng
    self.night = night or 1
    self.current_msg = 0
    self.msg_timer = 0.0
    self.done = false
    self.phase = 0
    self.fade_alpha = 255
    self.cedro_avatar = draw.load_sprite(eng, "cedro")
    self.renan_avatar = draw.load_sprite(eng, "renan")
    self.unknown_avatar = draw.load_sprite(eng, "mafia")
    self.messages = self:_build_messages()
    self.scroll_y = 0.0
    self.target_scroll = 0.0
    self.visible_messages = 0
    self.timer = 0.0

    return self
end

function StoryState:_build_messages()
    local function m(k)
        return localization.get_text(string.format("story_n%d_%s", self.night, k))
    end
    local function has_msg(k)
        local key = string.format("story_n%d_%s", self.night, k)
        return localization.get_text(key) ~= key
    end
    local function row(user, avatar, color, key)
        return { user = user, avatar = avatar, color = color, text = m(key) }
    end

    local msgs = {}
    if self.night == 1 then
        msgs = {
            row("Cedro", "cedro", { 140, 110, 80 }, "m0"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m1"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m2"),
            row("Cientista", "renan", { 100, 180, 255 }, "m3"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m4"),
            { type = "title",     text = localization.get_text("night"):upper() .. " 1" },
            row("Cedro", "cedro", { 140, 110, 80 }, "m5"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m6"),
            row("Cientista", "renan", { 100, 180, 255 }, "m7"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m8"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m9"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m10"),
            row("Cientista", "renan", { 100, 180, 255 }, "m11"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m12"),
            row("Cientista", "renan", { 100, 180, 255 }, "m13"),
        }
    elseif self.night >= 2 and self.night <= 5 then
        msgs = {
            row("Cedro", "cedro", { 140, 110, 80 }, "m0"),
            row("Cientista", "renan", { 100, 180, 255 }, "m1"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m2"),
            { type = "title", text = localization.get_text("night"):upper() .. " " .. tostring(self.night) },
        }
        local i = 3
        while has_msg("m" .. tostring(i)) do
            local speaker = ((i % 2) == 0) and "Cientista" or "Cedro"
            local avatar = (speaker == "Cedro") and "cedro" or "renan"
            local color = (speaker == "Cedro") and { 140, 110, 80 } or { 100, 180, 255 }
            table.insert(msgs, row(speaker, avatar, color, "m" .. tostring(i)))
            i = i + 1
        end
    elseif self.night == 6 then
        msgs = {
            row("Cedro", "cedro", { 140, 110, 80 }, "m0"),
            row("Cientista", "renan", { 100, 180, 255 }, "m1"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m2"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m3"),
            row("Cientista", "renan", { 100, 180, 255 }, "m4"),
            { type = "title",     text = localization.get_text("night"):upper() .. " 6" },
            row("Cedro", "cedro", { 140, 110, 80 }, "m5"),
        }
    elseif self.night == 7 then
        msgs = {
            row("Cedro", "cedro", { 140, 110, 80 }, "m0"),
            row("Cientista", "renan", { 100, 180, 255 }, "m1"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m2"),
            { type = "title", text = localization.get_text("custom_night"):upper() },
            row("Cedro", "cedro", { 140, 110, 80 }, "m3"),
            row("Cientista", "renan", { 100, 180, 255 }, "m4"),
            row("Cedro", "cedro", { 140, 110, 80 }, "m5"),
        }
    else
        msgs = {
            { type = "title", text = localization.get_text("night"):upper() .. " " .. tostring(self.night) }
        }
    end
    return msgs
end

function StoryState:update(dt)
    self.timer = self.timer + dt
    if self.phase == 0 then
        self.fade_alpha = math.max(0, self.fade_alpha - 250 * dt)
        if self.fade_alpha <= 0 then self.phase = 1 end
    elseif self.phase == 1 and self.visible_messages == 0 then
        self.visible_messages = 1
        self:_update_scroll_target()
    elseif self.phase == 2 then
        self.fade_alpha = math.min(255, self.fade_alpha + 200 * dt)
        if self.fade_alpha >= 255 then self.done = true end
    end
    self.scroll_y = self.scroll_y + (self.target_scroll - self.scroll_y) * 6.0 * dt
end

function StoryState:_wrap_text(text, mw, fs)
    local words = {}
    for word in text:gmatch("%S+") do
        table.insert(words, word)
    end

    local lines = {}
    local cur = {}
    for _, w in ipairs(words) do
        local test_table = {}
        for _, cw in ipairs(cur) do table.insert(test_table, cw) end
        table.insert(test_table, w)
        local test = table.concat(test_table, " ")
        local f_idx = draw.get_font_by_size(self.eng, fs)
        local tw, _ = self.eng:get_text_size(test, fs, f_idx)
        if tw <= mw then
            table.insert(cur, w)
        else
            if #cur > 0 then
                table.insert(lines, table.concat(cur, " "))
                cur = { w }
            else
                -- Avoid creating an empty line when one word is wider than max width.
                table.insert(lines, w)
                cur = {}
            end
        end
    end
    if #cur > 0 then
        table.insert(lines, table.concat(cur, " "))
    end
    return lines
end

function StoryState:_update_scroll_target()
    local cwl = settings.SCREEN_WIDTH - 240 - 100
    local th = 15
    local prev = nil
    for i = 1, self.visible_messages do
        local msg = self.messages[i]
        if not msg then break end
        if msg.type == "title" then
            th = th + 50
            prev = nil
        else
            local lines = self:_wrap_text(msg.text, cwl, 14)
            if prev == msg.user then
                th = th + 24 * #lines
            else
                th = th + (prev and 8 or 0) + 22 + (24 * #lines)
            end
            prev = msg.user
        end
    end
    local va = settings.SCREEN_HEIGHT - 48 - 80
    if th > va then
        self.target_scroll = th - va
    end
end

function StoryState:handle_event(event)
    if event.type == "KEYDOWN" then
        if event.key == 13 or event.key == 32 then
            if self.phase == 0 then
                self.phase = 1
                self.fade_alpha = 0
            elseif self.phase == 1 then
                if self.visible_messages < #self.messages then
                    self.visible_messages = self.visible_messages + 1
                    self:_update_scroll_target()
                    sounds.play_sound("notification")
                else
                    self.phase = 2
                    self.fade_alpha = 0
                end
            end
        end
    elseif event.type == "MOUSEBUTTONDOWN" then
        if self.phase == 0 then
            self.phase = 1
            self.fade_alpha = 0
        elseif self.phase == 1 then
            if self.visible_messages < #self.messages then
                self.visible_messages = self.visible_messages + 1
                self:_update_scroll_target()
                sounds.play_sound("notification")
            else
                self.phase = 2
                self.fade_alpha = 0
            end
        end
    elseif event.type == "MOUSEWHEEL" then
        self.target_scroll = math.max(0, self.target_scroll - event.y * 40)
    end
end

function StoryState:draw(eng)
    eng:clear(54, 57, 63, 255)
    if self.phase >= 1 then self:_draw_discord_ui(eng) end
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.005)

    if self.phase == 1 then
        local blink = math.floor(self.timer * 2) % 2 == 0
        if blink then
            local txt = (self.visible_messages < #self.messages) and localization.get_text("story_skip") or
                localization.get_text("story_start_night")
            draw.text(eng, txt, settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 20, 12, { 130, 130, 140 }, 255, true)
        end
    end

    if self.fade_alpha > 0 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 54, 57, 63, math.floor(self.fade_alpha))
    end
end

function StoryState:_draw_discord_ui(eng)
    local sw = 240
    eng:draw_rect(0, 0, sw, settings.SCREEN_HEIGHT, 47, 49, 54, 255)
    eng:draw_rect(0, 0, sw, 48, 40, 43, 48, 255)
    draw.text(eng, localization.get_text("discord_server"), 15, 14, 14, { 220, 220, 220 }, 255, false)
    eng:draw_line(0, 48, sw, 48, 30, 33, 36, 255)

    local chans = {
        localization.get_text("chan_general"),
        localization.get_text("chan_announcements"),
        localization.get_text("chan_security"),
        localization.get_text("chan_cameras")
    }

    for i, ch in ipairs(chans) do
        local y = 65 + (i - 1) * 32
        local color = (i == 3) and { 220, 220, 220 } or { 130, 130, 140 }
        if i == 3 then eng:draw_rect(8, y - 4, sw - 16, 28, 60, 63, 69, 255) end
        draw.text(eng, ch, 18, y, 13, color, 255, false)
    end

    local cx, cw = sw, settings.SCREEN_WIDTH - sw
    eng:draw_rect(cx, 0, cw, 48, 54, 57, 63, 255)
    draw.text(eng, localization.get_text("discord_channel"), cx + 18, 14, 15, { 220, 220, 220 }, 255, false)
    eng:draw_line(cx, 48, settings.SCREEN_WIDTH, 48, 40, 43, 48, 255)

    local my = 63 - math.floor(self.scroll_y)
    local prev = nil
    for i = 1, self.visible_messages do
        local msg = self.messages[i]
        if not msg then break end

        if msg.type == "title" then
            eng:draw_line(cx + 20, my + 10, settings.SCREEN_WIDTH - 20, my + 10, 72, 75, 81, 255)
            draw.text(eng, msg.text, cx + cw / 2, my + 10, 12, { 130, 130, 140 }, 255, true)
            my = my + 50
            prev = nil
        else
            local lines = self:_wrap_text(msg.text, cw - 100, 14)
            if prev == msg.user then
                for _, line in ipairs(lines) do
                    draw.text(eng, line, cx + 75, my, 14, { 220, 220, 220 }, 255, false)
                    my = my + 24
                end
            else
                my = my + (prev and 8 or 0)
                local av_size = 40
                eng:draw_circle(cx + 20 + av_size / 2, my + av_size / 2, av_size / 2, 80, 80, 90, 255, true)
                local av = (msg.avatar == "cedro") and self.cedro_avatar or self.renan_avatar
                if av then eng:draw_texture(av, cx + 20, my, av_size, av_size) end
                draw.text(eng, msg.user, cx + 75, my, 14, msg.color, 255, false)
                my = my + 22
                for _, line in ipairs(lines) do
                    draw.text(eng, line, cx + 75, my, 14, { 220, 220, 220 }, 255, false)
                    my = my + 24
                end
            end
            prev = msg.user
        end
    end

    local iy = settings.SCREEN_HEIGHT - 65
    eng:draw_rect(cx + 16, iy, cw - 32, 44, 64, 68, 75, 255)
    draw.text(eng, localization.get_text("discord_input"), cx + 30, iy + 13, 13, { 100, 100, 110 }, 255, false)
end

function StoryState:is_done()
    return self.done
end

story.StoryState = StoryState
return story