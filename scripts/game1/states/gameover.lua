local gameover = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local localization = require("scripts.core.utils.localization")

local GameOverState = {}
GameOverState.__index = GameOverState

function GameOverState.new(eng, is_win, night)
    local self = setmetatable({}, GameOverState)
    self.eng = eng
    self.is_win = is_win or false
    self.night = night or 1
    self.timer = 0.0
    self.text_alpha = 0
    self.show_text = false
    return self
end

function GameOverState:update(dt)
    self.timer = self.timer + dt
    if self.timer > 0.5 then
        self.show_text = true
        self.text_alpha = math.min(255, self.text_alpha + math.floor(200 * dt))
    end
end

function GameOverState:handle_event(event)
    if self.timer < 2.0 then return nil end
    if event.type == "KEYDOWN" or event.type == "MOUSEBUTTONDOWN" then
        return self.is_win and "next" or "menu"
    end
    return nil
end

function GameOverState:draw(eng)
    if self.is_win then
        self:_draw_win(eng)
    else
        self:_draw_game_over(eng)
    end
end

function GameOverState:_draw_game_over(eng)
    eng:clear(5, 0, 0, 255)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.08)
    if not self.show_text then return end

    local pw, ph = 500, 350
    local px, py = settings.SCREEN_WIDTH / 2 - pw / 2, settings.SCREEN_HEIGHT / 2 - ph / 2 - 30
    eng:draw_rect(px, py, pw, ph, 180, 170, 150, math.floor(self.text_alpha))

    if self.text_alpha > 100 then
        draw.text(eng, localization.get_text("news_title"), settings.SCREEN_WIDTH / 2, py + 20, 18, { 40, 40, 40 }, 255,
            true)
        eng:draw_line(px + 20, py + 45, px + pw - 20, py + 45, 40, 40, 40, 255)
        draw.text(eng, localization.get_text("news_headline_1"), settings.SCREEN_WIDTH / 2, py + 70, 32, { 30, 30, 30 },
            255, true)
        draw.text(eng, localization.get_text("news_headline_2"), settings.SCREEN_WIDTH / 2, py + 110, 38, { 150, 20, 20 },
            255, true)

        local nl = string.format("%s %d", localization.get_text("night"), self.night)
        local lines = {
            localization.get_text("news_body_1"),
            localization.get_text("news_body_2"),
            localization.get_text("news_body_3"),
            "",
            string.format(localization.get_text("news_body_4"), nl),
            localization.get_text("news_body_5")
        }

        for i, line in ipairs(lines) do
            draw.text(eng, line, settings.SCREEN_WIDTH / 2, py + 165 + (i - 1) * 22, 13, { 50, 50, 50 }, 255, true)
        end
    end

    draw.scanlines(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 15)
    if self.timer > 3.0 and math.floor(self.timer * 2) % 2 == 1 then
        draw.text(eng, localization.get_text("press_any_key"), settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 50, 16,
            { 100, 100, 100 }, 255, true)
    end
end

function GameOverState:_draw_win(eng)
    eng:clear(0, 0, 0, 255)
    if not self.show_text then return end

    draw.text(eng, localization.get_text("gameover_win"), settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT / 2 - 40, 80,
        settings.WHITE, 255, true)

    if self.timer > 1.5 then
        eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 255, 255, 200,
            math.min(100, math.floor((self.timer - 1.5) * 80)))
    end

    if self.timer > 2.0 then
        local nl = string.format("%s %d", localization.get_text("night"), self.night)
        draw.text(eng, string.format(localization.get_text("night_complete"), nl), settings.SCREEN_WIDTH / 2,
            settings.SCREEN_HEIGHT / 2 + 50, 24, { 200, 200, 200 }, 255, true)
        for i = 1, math.min(self.night, 7) do
            draw.star(eng, settings.SCREEN_WIDTH / 2 - 75 + (i - 1) * 25, settings.SCREEN_HEIGHT / 2 + 100, 10, 5,
                settings.STAR_COLOR)
        end
    end

    if self.timer > 3.5 and math.floor(self.timer * 2) % 2 == 1 then
        draw.text(eng, localization.get_text("press_any_key_continue"), settings.SCREEN_WIDTH / 2,
            settings.SCREEN_HEIGHT - 50, 16, { 100, 100, 100 }, 255, true)
    end
end

function GameOverState:is_done()
    return self.timer > 3.0
end

gameover.GameOverState = GameOverState
return gameover