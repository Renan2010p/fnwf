local sounds = {}
local settings = require("scripts.game1.settings")

local _sound_cache = {}
local _eng = nil
local _menu_ambient_channel = -1
local _breathing_channel = -1

local AUDIO_DIR = settings.ASSETS_DIR .. "/audio"

local filename_map = {
    door_open = "portas.ogg",
    door_close = "portas.ogg",
    door = "portas.ogg",
    light = "trocar_camera.ogg",
    footstep = "passos.ogg",
    footsteps_1 = "passos.ogg",
    footsteps_2 = "passos.ogg",
    footsteps_3 = "passos.ogg",
    footsteps_4 = "passos.ogg",
    breathing = "usando_a_mascara.ogg",
    mask_on = "colocar_mascara.ogg",
    mask_off = "retirar_mascara.ogg",
    blip = "trocar_camera.ogg",
    select = "trocar_camera.ogg",
    notification = "trocar_camera.ogg",
    camera = "trocar_camera.ogg",
    clock = "trocar_camera.ogg",
    win = "noite_concluida.ogg",
    noite_concluida = "noite_concluida.ogg",
    vent = "ventilação.ogg",
    window_scare = "animatronic_na_porta.ogg",
    animatronic_door = "animatronic_na_porta.ogg",
    jumpscare = "animatronic_na_porta.ogg",
    stinger = "animatronic_na_porta.ogg",
    power_out = "animatronic_na_porta.ogg",
}

function sounds.set_engine(eng)
    _eng = eng
end

local function load_audio(name)
    if not _eng then return nil end

    local fname = filename_map[name] or name
    if not string.find(fname, "%.ogg$") then
        fname = fname .. ".ogg"
    end

    local path = AUDIO_DIR .. "/" .. fname
    -- In Lua we can't easily check for exists without io.open
    local f = io.open(path, "r")
    if f then
        f:close()
        return _eng:load_sound(path)
    end
    return nil
end

function sounds.play_sound(name, loops, channel, volume)
    if not _eng then return end
    loops = loops or 0
    channel = channel or -1
    volume = volume or 1.0

    local sound = _sound_cache[name]
    if not sound then
        sound = load_audio(name)
        if sound then
            _sound_cache[name] = sound
        else
            -- print("[AUDIO] Som nao encontrado: " .. name)
            return
        end
    end

    _eng:play_sound(sound, loops, channel)
end

function sounds.stop_channel(channel)
    if _eng then _eng:stop_channel(channel) end
end

function sounds.stop_all_sounds()
    if _eng then _eng:stop_all_sounds() end
end

function sounds.play_menu_ambient()
    _menu_ambient_channel = 0
    sounds.play_sound("menu_ambient", -1, 0)
end

function sounds.stop_menu_ambient()
    if _menu_ambient_channel ~= -1 then
        sounds.stop_channel(_menu_ambient_channel)
    end
end

function sounds.play_ambient_loop()
    sounds.play_sound("ambient", -1, 1)
end

function sounds.stop_ambient()
    sounds.stop_channel(1)
end

function sounds.play_scary_stinger()
    sounds.play_sound("stinger", 0, -1, 0.8)
end

function sounds.play_camera_switch()
    sounds.play_sound("blip", 0, -1, 0.2)
end

function sounds.play_door_sound()
    sounds.play_sound("door")
end

function sounds.play_light_sound()
    sounds.play_sound("light")
end

function sounds.play_jumpscare_sound()
    sounds.play_sound("jumpscare")
end

function sounds.play_footstep_random()
    local idx = math.random(1, 4)
    sounds.play_sound("footsteps_" .. idx, 0, -1, 0.4)
end

function sounds.play_door_open()
    sounds.play_sound("door_open")
end

function sounds.play_door_close()
    sounds.play_sound("door_close")
end

function sounds.play_window_scare()
    sounds.play_sound("window_scare")
end

function sounds.toggle_breathing(on)
    if on then
        if _breathing_channel == -1 then
            _breathing_channel = 5
            sounds.play_sound("breathing", -1, 5)
        end
    else
        if _breathing_channel ~= -1 then
            sounds.stop_channel(_breathing_channel)
            _breathing_channel = -1
        end
    end
end

function sounds.play_mask_breathing()
    sounds.toggle_breathing(true)
end

function sounds.stop_mask_breathing()
    sounds.toggle_breathing(false)
end

return sounds