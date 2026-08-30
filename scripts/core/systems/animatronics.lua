local animatronics = {}
local settings = require("scripts.game1.settings")
local sounds = require("scripts.core.utils.sounds")

local Animatronic = {}
Animatronic.__index = Animatronic

function Animatronic.new(name, ai_level, start_pos, path_map, color)
    local self = setmetatable({}, Animatronic)
    self.name = name
    self.ai_level = ai_level
    self.position = start_pos
    self.path_map = path_map
    self.color = color
    self.move_timer = 0.0
    self.active = ai_level > 0
    self.at_door = nil
    self.at_vent = false
    self.attacking = false
    self.in_office = false
    self.just_left_office = false
    self.stare_timer = 0.0
    self.max_stare = 4.0

    return self
end

function Animatronic:update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on)
    if not self.active or self.attacking then
        return
    end

    self.just_left_office = false
    self.move_timer = self.move_timer + dt

    if self.at_door or self.at_vent or self.in_office then
        self.stare_timer = self.stare_timer + dt
        local target_max = self.in_office and 3.0 or self.max_stare

        if self.stare_timer >= target_max then
            if self.position == "OFFICE_VENT" or self.in_office then
                if not mask_on then
                    self.attacking = true
                else
                    self.position = self.path_map["OFFICE_VENT"][1] or "1A"
                    self.at_vent = false
                    self.in_office = false
                    self.just_left_office = true
                    self.stare_timer = 0.0
                end
            end
        end
    end

    local move_interval = self.move_interval or settings.MOVE_INTERVAL
    if self.move_timer >= move_interval then
        self.move_timer = 0.0
        self:_try_move(camera_looking_at, left_door_closed, right_door_closed, mask_on)
    end
end

function Animatronic:_try_move(camera_looking_at, left_door_closed, right_door_closed, mask_on)
    local roll = math.random(1, 20)
    if roll > self.ai_level then
        return
    end

    if self.position == "LEFT_DOOR" then
        if not left_door_closed then
            self.attacking = true
        else
            self.position = self.path_map["LEFT_DOOR"][1] or "1A"
            self.at_door = nil
        end
        return
    end

    if self.position == "RIGHT_DOOR" then
        if not right_door_closed then
            self.attacking = true
        else
            self.position = self.path_map["RIGHT_DOOR"][1] or "1A"
            self.at_door = nil
        end
        return
    end

    if self.position == "OFFICE_VENT" then
        return
    end

    if self.path_map[self.position] then
        local possible = self.path_map[self.position]
        local next_pos = possible[math.random(1, #possible)]
        local old_pos = self.position
        self.position = next_pos

        -- Movement sounds
        if old_pos ~= next_pos then
            if self.name == "alice" then
                -- Alice: vent sounds when entering vent stages
                if next_pos == "V" or next_pos == "OFFICE_VENT" then
                    sounds.play_sound("vent")
                else
                    sounds.play_footstep_random()
                end
            else
                -- Cedro/Eser: footstep sounds on any movement
                sounds.play_footstep_random()
            end
        end

        if next_pos == "LEFT_DOOR" or next_pos == "RIGHT_DOOR" then
            self.at_door = next_pos
            self.at_vent = false
        elseif next_pos == "V" then
            self.at_vent = false
        elseif next_pos == "OFFICE_VENT" then
            self.at_vent = true
            self.in_office = true
            self.at_door = nil
            self.stare_timer = 0.0
        else
            self.at_door = nil
            self.at_vent = false
            self.in_office = false
            self.stare_timer = 0.0
        end
    end
end

function Animatronic:is_at_left_door()
    return self.position == "LEFT_DOOR"
end

function Animatronic:is_at_right_door()
    return self.position == "RIGHT_DOOR"
end

local Sonk = {}
Sonk.__index = Sonk

function Sonk.new(ai_level)
    local self = setmetatable({}, Sonk)
    self.name = "Sonk"
    self.ai_level = ai_level or 0
    self.active = self.ai_level > 0
    self.position = "5"
    self.stage = 0
    self.move_timer = 0.0
    self.at_door = nil
    self.at_vent = false
    self.in_office = false
    self.attacking = false
    self.stare_timer = 0.0
    self.is_charging = false
    self.charge_timer = 0.0
    self.charge_duration = 1.1
    return self
end

function Sonk:update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on)
    if not self.active or self.attacking then
        return
    end

    if self.is_charging then
        self.charge_timer = self.charge_timer + dt
        if self.charge_timer >= self.charge_duration then
            self.is_charging = false
            self.position = "LEFT_DOOR"
            self.at_door = "LEFT_DOOR"
            self.stare_timer = 0.0
            sounds.play_sound("animatronic_door")
        end
        return
    end

    self.move_timer = self.move_timer + dt

    if self.position == "LEFT_DOOR" then
        self.stare_timer = self.stare_timer + dt
        if self.stare_timer >= 1.0 then
            -- Sonk bate na esquerda e sempre recua para o Pirate Cove.
            self.position = "5"
            self.stage = 0
            self.at_door = nil
            self.stare_timer = 0.0
        end
        return
    end

    local move_interval = self.move_interval or settings.MOVE_INTERVAL
    if self.move_timer < move_interval then
        return
    end
    self.move_timer = 0.0

    -- Sonk (Foxy-like): watching his camera slows his advance.
    local effective_ai = self.ai_level
    if camera_looking_at == "5" then
        effective_ai = math.max(0, effective_ai - 7)
    end

    if math.random(1, 20) > effective_ai then
        return
    end

    if self.stage < 3 then
        self.stage = self.stage + 1
    else
        -- Ao sair do cove, primeiro ouvimos os passos da corrida.
        self.is_charging = true
        self.charge_timer = 0.0
        sounds.play_sound("footstep")
    end
end

function Sonk:is_at_left_door()
    return self.position == "LEFT_DOOR"
end

function Sonk:is_at_right_door()
    return false
end

local AnimatronicManager = {}
AnimatronicManager.__index = AnimatronicManager

local function is_secret_custom_night(custom_ai)
    if type(custom_ai) ~= "table" then
        return false
    end
    for i = 1, 4 do
        if (custom_ai[i] or 0) < 40 then
            return false
        end
    end
    return true
end

local function build_any_door_path()
    return {
        ["1A"] = { "1B" },
        ["1B"] = { "2A", "4A", "3", "1C" },
        ["1C"] = { "1B" },
        ["2A"] = { "2B", "1B", "3", "4A" },
        ["2B"] = { "LEFT_DOOR", "RIGHT_DOOR", "2A" },
        ["3"] = { "2A", "1B" },
        ["4A"] = { "4B", "1B", "2A" },
        ["4B"] = { "RIGHT_DOOR", "LEFT_DOOR", "4A" },
        ["LEFT_DOOR"] = { "1B" },
        ["RIGHT_DOOR"] = { "1B" },
    }
end

function AnimatronicManager.new(night, custom_ai)
    local self = setmetatable({}, AnimatronicManager)
    local ai_levels = custom_ai or settings.NIGHT_AI_LEVELS[night] or settings.NIGHT_AI_LEVELS[1]
    self.secret_mode = (night == 7) and is_secret_custom_night(custom_ai)
    local move_interval = self.secret_mode and 1.6 or settings.MOVE_INTERVAL
    local cedro_path = settings.CEDRO_PATH
    local eser_path = settings.ESER_PATH
    if self.secret_mode then
        cedro_path = build_any_door_path()
        eser_path = build_any_door_path()
    end

    self.cedro = Animatronic.new("cedro", ai_levels[1], "1A", cedro_path, settings.CEDRO_COLOR)
    self.eser = Animatronic.new("eser", ai_levels[2], "1A", eser_path, settings.ESER_COLOR)
    self.alice = Animatronic.new("alice", ai_levels[3], "1A", settings.ALICE_PATH, settings.ALICE_COLOR)
    self.cedro.move_interval = move_interval
    self.eser.move_interval = move_interval
    self.alice.move_interval = move_interval
    if self.secret_mode then
        self.cedro.max_stare = 2.3
        self.eser.max_stare = 2.3
        self.alice.max_stare = 2.3
    end

    local sonk_ai = ai_levels[4] or 0
    if not custom_ai and night >= 3 and sonk_ai <= 0 then
        sonk_ai = 5
    end
    self.sonk = Sonk.new(sonk_ai)
    self.sonk.move_interval = self.secret_mode and 1.25 or settings.MOVE_INTERVAL
    if self.secret_mode then
        self.sonk.charge_duration = 0.65
    end

    self.all = { self.cedro, self.eser, self.alice, self.sonk }
    return self
end

function AnimatronicManager:update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on)
    for _, anim in ipairs(self.all) do
        anim:update(dt, camera_looking_at, left_door_closed, right_door_closed, mask_on)
    end
end

function AnimatronicManager:get_positions()
    return {
        cedro = self.cedro.position,
        eser = self.eser.position,
        alice = self.alice.position,
        sonk = self.sonk.position,
    }
end

function AnimatronicManager:get_attacker()
    for _, anim in ipairs(self.all) do
        if anim.attacking then
            return anim.name
        end
    end
    return nil
end

function AnimatronicManager:get_at_left_door()
    for _, anim in ipairs(self.all) do
        if anim:is_at_left_door() and not anim.attacking then
            return anim.name
        end
    end
    return nil
end

function AnimatronicManager:get_at_right_door()
    for _, anim in ipairs(self.all) do
        if anim:is_at_right_door() and not anim.attacking then
            return anim.name
        end
    end
    return nil
end

function AnimatronicManager:get_at_vent()
    for _, anim in ipairs(self.all) do
        if anim.at_vent and not anim.attacking then
            return anim.name
        end
    end
    return nil
end

function AnimatronicManager:get_in_office()
    for _, anim in ipairs(self.all) do
        if anim.in_office and not anim.attacking then
            return anim.name
        end
    end
    return nil
end

function AnimatronicManager:check_alice_just_left()
    return self.alice.just_left_office
end

function AnimatronicManager:get_foxy_stage()
    return self.sonk.stage or 0
end

function AnimatronicManager:is_secret_mode()
    return self.secret_mode == true
end

animatronics.AnimatronicManager = AnimatronicManager
return animatronics