local settings = {}

settings.SCREEN_WIDTH = 1280
settings.SCREEN_HEIGHT = 720
settings.FPS = 60

settings.ASSETS_DIR = "assets"

-- experimental first-person 3D office (option A). false = 2D (stable)

settings.HOUR_DURATION = 60
settings.MAX_POWER = 100.0
settings.BASE_POWER_DRAIN = 0.12

settings.OFFICE_WIDTH = 1280
settings.PAN_SPEED = 8
settings.PAN_MARGIN = 200

settings.BLACK = {0, 0, 0}
settings.WHITE = {255, 255, 255}
settings.DARK_GRAY = {30, 30, 35}
settings.MED_GRAY = {50, 50, 58}
settings.LIGHT_GRAY = {80, 80, 90}
settings.WALL_COLOR = {45, 42, 50}
settings.WALL_ACCENT = {55, 52, 62}
settings.FLOOR_COLOR = {35, 30, 28}
settings.FLOOR_TILE_1 = {40, 35, 32}
settings.FLOOR_TILE_2 = {30, 26, 24}
settings.CEILING_COLOR = {25, 25, 30}
settings.DESK_COLOR = {60, 50, 45}
settings.DESK_TOP = {70, 60, 55}
settings.DOOR_COLOR = {80, 75, 70}
settings.DOOR_FRAME_COLOR = {55, 50, 48}
settings.BUTTON_GREEN = {30, 180, 60}
settings.BUTTON_RED = {200, 40, 40}
settings.BUTTON_OFF = {60, 60, 65}
settings.HALL_LIGHT = {180, 170, 140}
settings.MONITOR_GREEN = {20, 200, 80}
settings.MONITOR_BG = {10, 15, 10}
settings.STATIC_COLOR = {120, 120, 120}
settings.HUD_COLOR = {200, 200, 200}
settings.POWER_COLOR = {80, 200, 80}
settings.POWER_LOW = {200, 60, 60}
settings.CAM_OUTLINE = {60, 180, 60}
settings.TITLE_COLOR = {220, 220, 220}
settings.STAR_COLOR = {255, 255, 100}

settings.CEDRO_COLOR = {140, 110, 80}
settings.ESER_COLOR = {40, 60, 180}
settings.ALICE_COLOR = {255, 105, 180}

settings.NIGHT_AI_LEVELS = {
    [1] = {3, 2, 0, 0},
    [2] = {5, 4, 3, 0},
    [3] = {7, 6, 6, 5},
    [4] = {10, 9, 10, 8},
    [5] = {13, 12, 14, 12},
    [6] = {16, 15, 18, 15},
    [7] = {20, 20, 20, 20},
}

settings.MOVE_INTERVAL = 5.0

settings.CAMERA_NAMES = {
    ["1A"] = "Show Stage",
    ["1B"] = "Dining Area",
    ["1C"] = "Backstage",
    ["5"]  = "Pirate Cove",
    ["2A"] = "West Hall",
    ["2B"] = "West Hall Corner",
    ["3"]  = "Supply Closet",
    ["4A"] = "East Hall",
    ["4B"] = "East Hall Corner",
    ["V"]  = "Ventilation",
}

settings.CEDRO_PATH = {
    ["1A"] = {"1B"},
    ["1B"] = {"2A", "3", "1C"},
    ["1C"] = {"1B"},
    ["2A"] = {"2B", "1B", "3"},
    ["3"]  = {"2A"},
    ["2B"] = {"LEFT_DOOR"},
    ["LEFT_DOOR"] = {"1B"},
}

settings.ESER_PATH = {
    ["1A"] = {"1B"},
    ["1B"] = {"4A"},
    ["4A"] = {"4B", "1B"},
    ["4B"] = {"RIGHT_DOOR"},
    ["RIGHT_DOOR"] = {"1B"},
}

settings.ALICE_PATH = {
    ["1A"] = {"1B"},
    ["1B"] = {"4A", "2A"},
    ["4A"] = {"V"},
    ["2A"] = {"V"},
    ["V"] = {"OFFICE_VENT"},
    ["OFFICE_VENT"] = {"1B"},
}

return settings