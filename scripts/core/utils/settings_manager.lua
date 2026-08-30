local settings_manager = {}

local CONFIG_FILE = "config.lua"

local DEFAULT_SETTINGS = {
    language = "pt",
    show_fps = false,
    vsync = true,
    resolution = { 1280, 720 },
    fullscreen = false,
    quality = "high",
    discord_rpc = true
}

local SettingsManager = {}
SettingsManager.__index = SettingsManager

local function serialize(t)
    local s = "{"
    for k, v in pairs(t) do
        local key = (type(k) == "string") and ("[\"" .. k .. "\"]") or ("[" .. k .. "]")
        local val
        if type(v) == "table" then
            val = serialize(v)
        elseif type(v) == "string" then
            val = "\"" .. v .. "\""
        else
            val = tostring(v)
        end
        s = s .. key .. "=" .. val .. ","
    end
    return s .. "}"
end

function SettingsManager.new()
    local self = setmetatable({}, SettingsManager)
    self.settings = {}
    for k, v in pairs(DEFAULT_SETTINGS) do
        self.settings[k] = v
    end
    self:load()
    return self
end

function SettingsManager:load()
    local f = io.open(CONFIG_FILE, "r")
    if f then
        local content = f:read("*all")
        f:close()
        local chunk = load("return " .. content)
        if chunk then
            local data = chunk()
            if type(data) == "table" then
                for k, v in pairs(data) do
                    self.settings[k] = v
                end
            end
        end
    end
end

function SettingsManager:save()
    local f = io.open(CONFIG_FILE, "w")
    if f then
        f:write(serialize(self.settings))
        f:close()
    end
end

settings_manager.pm = SettingsManager.new()
return settings_manager