package.path = package.path .. ";./?.lua"

local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")
local save_manager = require("scripts.core.utils.save_manager")
local settings_manager = require("scripts.core.utils.settings_manager")
local sounds = require("scripts.core.utils.sounds")
local localization = require("scripts.core.utils.localization")

-- Load States
local warning = require("scripts.game1.states.warning")
local menu = require("scripts.game1.states.menu")
local options = require("scripts.core.states.options")
local game_state = require("scripts.game1.states.game")
local transition = require("scripts.game1.states.night_transition")
local newspaper = require("scripts.game1.states.newspaper")
local paycheck = require("scripts.game1.states.paycheck")
local six_am = require("scripts.game1.states.six_am")
local story = require("scripts.game1.states.story")
local custom_night = require("scripts.game1.states.custom_night")
local loading = require("scripts.game1.states.loading")
local gameover = require("scripts.game1.states.gameover")
local conquistas = require("scripts.game1.states.conquistas")
local extras = require("scripts.game1.states.extras")

-- Engine Initialization
local initial_settings = settings_manager.pm.settings
local eng = Engine.new("Five Nights With Friends 1",
    initial_settings.resolution[1],
    initial_settings.resolution[2],
    initial_settings.fullscreen,
    initial_settings.vsync)
eng:set_logical_size(1280, 720)
draw.set_fonts(eng)
draw.set_render_quality(initial_settings.quality)
eng:set_discord_enabled(initial_settings.discord_rpc)
sounds.set_engine(eng)

-- Game Flow Variables
local completed_nights, has_seen_story, achievements = save_manager.load_progress()
local cheats = save_manager.load_cheats()
local current_state = nil
local state_name = "warning"

local function has_achievement(id)
    for _, ach_id in ipairs(achievements) do
        if ach_id == id then
            return true
        end
    end
    return false
end

local function unlock_achievement(id)
    if not has_achievement(id) then
        table.insert(achievements, id)
        return true
    end
    return false
end

local function is_20_mode(ai_levels)
    if type(ai_levels) ~= "table" then
        return false
    end
    -- Night 7 achievement requires classic 20/20/20 minimum.
    for i = 1, 4 do
        if (ai_levels[i] or 0) < 20 then
            return false
        end
    end
    return true
end

local achievement_title_key = {
    survive_n1 = "night_1_ach_title",
    survive_n5 = "night_5_ach_title",
    survive_n6 = "night_6_ach_title",
    survive_n7 = "night_7_ach_title",
}

local achievement_notice_queue = {}
local current_achievement_notice = nil
local achievement_notice_timer = 0.0

local function queue_achievement_notice(id)
    table.insert(achievement_notice_queue, id)
end

local function get_achievement_title(id)
    local key = achievement_title_key[id]
    if key then
        return localization.get_text(key)
    end
    return id
end

local function switch_state(name, ...)
    print("Switching state to: " .. tostring(name))
    local prev_state_name = state_name
    state_name = name
    local args = { ... }
    if name == "warning" then
        eng:update_discord("No Menu", "Five Nights With Friends 1")
        current_state = warning.WarningState.new(eng)
    elseif name == "menu" then
        eng:update_discord("No Menu", "Menu Principal")
        current_state = menu.MenuState.new(completed_nights, has_seen_story, eng)
    elseif name == "options" then
        current_state = options.OptionsState.new(eng)
        current_state.return_to = args[1] or "menu"
    elseif name == "game" then
        local night = args[1] or 1
        local custom_ai = args[2] or nil
        eng:update_discord("Sobrevivendo", "Noite " .. tostring(night))
        current_state = game_state.GameState.new(eng, night, custom_ai)
    elseif name == "transition" then
        local night = args[1] or 1
        current_state = transition.NightTransitionState.new(night, eng)
    elseif name == "newspaper" then
        current_state = newspaper.NewspaperState.new(eng)
    elseif name == "paycheck" then
        current_state = paycheck.PaycheckState.new(eng)
    elseif name == "six_am" then
        local night = args[1] or 1
        current_state = six_am.SixAMState.new(eng, night)
    elseif name == "story" then
        local night = args[1] or 1
        current_state = story.StoryState.new(night, eng)
    elseif name == "custom_night" then
        eng:update_discord("Configurando", "Noite Customizada")
        current_state = custom_night.CustomNightState.new(eng)
    elseif name == "loading" then
        local factory = args[1]
        current_state = loading.LoadingState.new(factory, eng)
    elseif name == "gameover" then
        local is_win = args[1]
        local night = args[2]
        eng:update_discord("Fim de Jogo", "Noite " .. tostring(night))
        current_state = gameover.GameOverState.new(eng, is_win, night)
    elseif name == "conquistas" then
        current_state = conquistas.ConquistasState.new(achievements, eng)
    elseif name == "extras" then
        current_state = extras.ExtrasState.new(completed_nights, cheats, achievements, eng)
    end
end

-- Start: warning, or (fast test) straight to the office
if FNWF_TEST then
    switch_state("game", 1)
else
    switch_state("warning")
end

local last_time = eng:get_ticks() / 1000.0
local fps_timer = 0.0
local fps_frames = 0
local fps_value = 0

while eng:keeps_running() do
    local current_time = eng:get_ticks() / 1000.0
    local dt = current_time - last_time
    last_time = current_time
    fps_timer = fps_timer + dt
    fps_frames = fps_frames + 1
    if fps_timer >= 0.25 then
        fps_value = math.floor((fps_frames / fps_timer) + 0.5)
        fps_timer = 0.0
        fps_frames = 0
    end

    if not current_achievement_notice and #achievement_notice_queue > 0 then
        current_achievement_notice = table.remove(achievement_notice_queue, 1)
        achievement_notice_timer = 3.2
    elseif current_achievement_notice then
        achievement_notice_timer = achievement_notice_timer - dt
        if achievement_notice_timer <= 0 then
            current_achievement_notice = nil
            achievement_notice_timer = 0.0
        end
    end

    -- Event Handling
    local events = eng:get_events()
    for i = 1, #events do
        local ev = events[i]
        if ev.type == "QUIT" then
            eng:stop()
        end
        if current_state and current_state.handle_event then
            current_state:handle_event(ev)
        end
    end

    -- Update
    if current_state and current_state.update then
        current_state:update(dt)
    end

    -- State Transitions
    if current_state and current_state.is_done and current_state:is_done() then
        if state_name == "warning" then
            switch_state("menu")
        elseif state_name == "menu" then
            local res = current_state.result
            if res == "start" then
                switch_state("story", 1)
            elseif res == "continue" then
                local next_night = math.min(completed_nights + 1, 6)
                switch_state("story", next_night)
            elseif res == "night6" then
                switch_state("story", 6)
            elseif res == "night7" then
                switch_state("custom_night")
            elseif res == "more" then
                -- Already handled in MenuState update to more page
            elseif res == "extras" then
                switch_state("extras")
            elseif res == "conquistas" then
                switch_state("conquistas")
            elseif res == "quit" then
                eng:stop()
            end
        elseif state_name == "extras" or state_name == "conquistas" or state_name == "options" then
            local target = "menu"
            if state_name == "options" and current_state.return_to then
                target = current_state.return_to
            end
            switch_state(target)
        elseif state_name == "story" then
            local story_night = current_state.night
            switch_state("loading", function() return game_state.GameState.new(eng, story_night) end)
        elseif state_name == "transition" then
            print("Transition state done, moving to loading...")
            switch_state("loading", function() return game_state.GameState.new(eng, current_state.night) end)
        elseif state_name == "loading" then
            print("Loading state done, transitioning to game...")
            current_state = current_state.next_state
            state_name = "game"
        elseif state_name == "game" then
            local res = current_state.result
            if res == "win" then
                if current_state.night >= 1 then
                    if unlock_achievement("survive_n1") then queue_achievement_notice("survive_n1") end
                end
                if current_state.night >= 5 then
                    if unlock_achievement("survive_n5") then queue_achievement_notice("survive_n5") end
                end
                if current_state.night >= 6 then
                    if unlock_achievement("survive_n6") then queue_achievement_notice("survive_n6") end
                end
                if current_state.night == 7 and is_20_mode(current_state.custom_ai) then
                    if unlock_achievement("survive_n7") then queue_achievement_notice("survive_n7") end
                end

                completed_nights = math.max(completed_nights, current_state.night)
                has_seen_story = true
                save_manager.save_progress(completed_nights, has_seen_story, cheats, achievements)
                switch_state("six_am", current_state.night)
            elseif res == "jumpscare" then
                switch_state("gameover", false, current_state.night)
            elseif res == "menu" then
                switch_state("menu")
            end
        elseif state_name == "six_am" then
            if current_state.night == 5 then
                switch_state("paycheck")
            else
                switch_state("menu")
            end
        elseif state_name == "paycheck" then
            switch_state("newspaper")
        elseif state_name == "newspaper" then
            switch_state("menu")
        elseif state_name == "gameover" then
            if current_state.is_win then
                switch_state("menu")
            else
                switch_state("newspaper")
            end
        elseif state_name == "custom_night" then
            local res = current_state.result
            if res == "start" then
                switch_state("game", 7, current_state.ai_levels)
            else
                switch_state("menu")
            end
        end
    end

    -- Rendering
    if current_state and current_state.draw then
        current_state:draw(eng)
    end

    -- Global TEST watermark
    if FNWF_TEST then
        draw.text(eng, "TEST MODE", 60, 20, 20, { 255, 70, 70 }, 255, false)
        draw.text(eng, "FAST OFFICE — 3D BUILD", 60, 42, 12, { 255, 150, 150 }, 200, false)
    end

    if current_achievement_notice then
        local bw, bh = 560, 68
        local bx = settings.SCREEN_WIDTH / 2 - bw / 2
        local by = 18
        draw.text(eng, localization.get_text("new_ach_unlocked"), settings.SCREEN_WIDTH / 2, by + 22, 18,
            { 170, 220, 255 }, 255, true)
        draw.text(eng, get_achievement_title(current_achievement_notice), settings.SCREEN_WIDTH / 2, by + 46, 22,
            settings.WHITE, 255, true)
    end

    if settings_manager.pm.settings.show_fps then
        local fps_text = string.format(localization.get_text("fps_counter"), fps_value)
        local fx, fy = settings.SCREEN_WIDTH - 110, 16
        draw.text(eng, fps_text, fx + 1, fy + 1, 16, { 5, 20, 5 }, 255, false)
        draw.text(eng, fps_text, fx, fy, 16, { 130, 255, 170 }, 255, false)
    end

    eng:flip()
end

print("Game closed.")