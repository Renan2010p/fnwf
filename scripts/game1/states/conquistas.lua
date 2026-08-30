local conquistas = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local sounds = require("scripts.core.utils.sounds")

local ConquistasState = {}
ConquistasState.__index = ConquistasState

function ConquistasState.new(achievements, eng)
    local self = setmetatable({}, ConquistasState)
    self.eng = eng
    self.achievements = achievements or {}
    self.done = false
    self.result = nil
    self.timer = 0.0
    self.achievements_list = {
        { id = "survive_n1", name = "Pela Primeira Vez", desc = "Sobreviva à primeira noite." },
        { id = "survive_n5", name = "Mestre da Mafia",   desc = "Sobreviva às 5 noites principais." },
        { id = "survive_n6", name = "Sem Saída",         desc = "Sobreviva à brutal Noite 6." },
        { id = "survive_n7", name = "Cérebro de Aço",    desc = "Vença o modo 20/20/20." }
    }
    return self
end

function ConquistasState:update(dt)
    self.timer = self.timer + dt
end

function ConquistasState:handle_event(event)
    if event.type == "KEYDOWN" then
        local key = event.key
        if key == 27 or key == 13 or key == 32 then
            self.done = true
            self.result = "menu"
            sounds.play_sound("select")
        end
    end
end

function ConquistasState:draw(eng)
    eng:clear(10, 10, 15, 255)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 0.01)
    draw.text(eng, "CONQUISTAS - FIVE NIGHTS WITH FRIENDS", 80, 60, 40, settings.TITLE_COLOR, 255, false)
    eng:draw_rect(80, 110, 600, 2, settings.STAR_COLOR[1], settings.STAR_COLOR[2], settings.STAR_COLOR[3], 255)

    for i, ach in ipairs(self.achievements_list) do
        local y = 180 + (i - 1) * 100
        local unlocked = false
        for _, id in ipairs(self.achievements) do
            if id == ach.id then
                unlocked = true
                break
            end
        end

        local color = unlocked and settings.WHITE or { 60, 60, 70 }
        local bg = unlocked and { 20, 20, 30 } or { 15, 15, 20 }

        eng:draw_rect(80, y - 10, settings.SCREEN_WIDTH - 160, 80, bg[1], bg[2], bg[3], 255)
        if unlocked then
            eng:draw_rect(80, y - 10, settings.SCREEN_WIDTH - 160, 80, 40, 40, 60, 255, false)
        end

        draw.text(eng, unlocked and "★" or "☆", 100, y + 10, 40, unlocked and settings.STAR_COLOR or { 40, 40, 50 }, 255,
            false)
        draw.text(eng, ach.name, 160, y, 28, color, 255, false)
        draw.text(eng, ach.desc, 160, y + 35, 18, unlocked and { 120, 120, 130 } or { 40, 40, 45 }, 255, false)
    end

    draw.text(eng, "Pressione ESC ou ESPAÇO para voltar", settings.SCREEN_WIDTH / 2, settings.SCREEN_HEIGHT - 60, 16,
        settings.LIGHT_GRAY, 255, true)
    draw.scanlines(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, 10)
end

function ConquistasState:is_done()
    return self.done
end

conquistas.ConquistasState = ConquistasState
return conquistas