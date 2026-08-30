local save_manager = {}

local DEFAULT_CHEATS = { infinite_power = false, fast_nights = false }

local function save_file_path()
    return "save.lua" -- Using .lua for simplicity in Lua environment
end

function save_manager.load_data()
    local path = save_file_path()
    local f = io.open(path, "r")
    if not f then
        return {}
    end
    local content = f:read("*all")
    f:close()

    local chunk = load("return " .. content)
    if chunk then
        local data = chunk()
        if type(data) == "table" then
            return data
        end
    end
    return {}
end

function save_manager.load_progress()
    local data = save_manager.load_data()
    return
        tonumber(data.completed_nights or 0),
        data.has_seen_story == true,
        data.achievements or {}
end

function save_manager.load_cheats()
    local data = save_manager.load_data()
    local cheats = data.cheats or DEFAULT_CHEATS
    return {
        infinite_power = cheats.infinite_power == true,
        fast_nights = cheats.fast_nights == true
    }
end

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

function save_manager.save_progress(completed_nights, has_seen_story, cheats, achievements)
    local data = {
        completed_nights = completed_nights,
        has_seen_story = has_seen_story,
        cheats = cheats or DEFAULT_CHEATS,
        achievements = achievements or {}
    }
    local f = io.open(save_file_path(), "w")
    if f then
        f:write(serialize(data))
        f:close()
    end
end

return save_manager