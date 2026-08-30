local draw = {}
local settings = require("scripts.game1.settings")

local sprite_cache = {}
local scanline_rows_cache = {}
local render_quality = "high"
local FONT_MAIN = 0
local font_cache = {}

function draw.load_sprite(eng, name)
    if sprite_cache[name] then return sprite_cache[name] end
    print("Loading sprite: " .. name)
    local path = settings.ASSETS_DIR .. "/" .. name .. ".png"
    local tex = eng:load_texture(path)
    sprite_cache[name] = tex
    return tex
end

function draw.set_fonts(eng)
    FONT_MAIN = eng:load_font(settings.ASSETS_DIR .. "/font/font.ttf", 16)
    if FONT_MAIN == -1 then FONT_MAIN = 0 end
    font_cache[16] = FONT_MAIN
end

function draw.get_font_by_size(eng, size)
    if font_cache[size] then return font_cache[size] end
    local path = settings.ASSETS_DIR .. "/font/font.ttf"
    local idx = eng:load_font(path, size)
    if idx == -1 then return FONT_MAIN end
    font_cache[size] = idx
    return idx
end

function draw.set_render_quality(level)
    render_quality = (level == "high") and "high" or "low"
end

function draw.get_render_quality()
    return render_quality
end

function draw.text(eng, text, x, y, size, color, alpha, center, font_idx)
    size = size or 24
    color = color or settings.WHITE
    alpha = alpha or 255
    if center == nil then center = false end

    local f_idx = font_idx or draw.get_font_by_size(eng, size)
    eng:draw_text(text, x, y, size, color[1], color[2], color[3], alpha, center, f_idx)
end

function draw.static_noise(eng, x, y, w, h, intensity, color_range)
    intensity = intensity or 0.3
    local current_intensity = intensity
    if render_quality == "low" then
        current_intensity = current_intensity * 0.55
    end
    if math.random() < current_intensity then
        eng:draw_rect(x, y, w, h, 100, 100, 100, 20)
    end
end

function draw.scanlines(eng, x, y, w, h, alpha)
    alpha = alpha or 30
    local current_alpha = alpha
    local step = 4
    if render_quality == "low" then
        current_alpha = math.floor(current_alpha * 0.6)
        step = 6
    elseif alpha < 20 then
        step = 5
    end

    local key = string.format("%d_%d_%d_%d", x, y, h, step)
    local rows = scanline_rows_cache[key]
    if not rows then
        rows = {}
        for py = y, y + h, step do
            table.insert(rows, py)
        end
        scanline_rows_cache[key] = rows
    end

    for _, py in ipairs(rows) do
        eng:draw_rect(x, py, w, 1, 0, 0, 0, current_alpha)
    end
end

function draw.button_box(eng, x, y, w, h, text, active, color_on, color_off)
    local color = active and color_on or color_off
    eng:draw_rect(x, y, w, h, color[1], color[2], color[3])
    eng:draw_rect(x, y, w, h, 255, 255, 255, 255, false)
    draw.text(eng, text, x + w / 2, y + h / 2, 14, settings.WHITE, 255, true)
end

function draw.animatronic_sprite(eng, name, x, y, w, h)
    local tex = draw.load_sprite(eng, name)
    if tex then
        eng:draw_texture(tex, x, y, w, h)
    else
        eng:draw_rect(x, y, w, h, 100, 100, 100)
        draw.text(eng, string.upper(name), x + w / 2, y + h / 2, 14, settings.WHITE, 255, true)
    end
end

function draw.trapezoid(eng, color, p1, p2, p3, p4)
    local y_min = math.floor(math.min(p1[2], p2[2]))
    local y_max = math.floor(math.max(p3[2], p4[2]))

    if y_max == y_min then return end

    for y = y_min, y_max do
        local prog = (y - y_min) / (y_max - y_min)
        local x_left = p1[1] + (p4[1] - p1[1]) * prog
        local x_right = p2[1] + (p3[1] - p2[1]) * prog

        local xl = math.floor(x_left)
        local xr = math.floor(x_right)
        if xr > xl then
            eng:draw_line(xl, y, xr, y, color[1], color[2], color[3])
        end
    end
end

function draw.star(eng, cx, cy, outer_r, inner_r, color)
    outer_r = outer_r or 10
    color = color or settings.STAR_COLOR
    local size = outer_r
    eng:draw_rect(cx - size / 4, cy - size / 2, size / 2, size, color[1], color[2], color[3])
    eng:draw_rect(cx - size / 2, cy - size / 4, size, size / 2, color[1], color[2], color[3])
end

function draw.animatronic_face(eng, name, x, y, w, h)
    local tex = draw.load_sprite(eng, name)
    if tex then
        eng:draw_texture(tex, x, y, w, h)
    end
end

function draw.rounded_texture(eng, tex, x, y, w, h, radius, bg_color, alpha)
    if not tex then return end
    radius = math.max(1, math.floor(radius or 14))
    bg_color = bg_color or { 4, 5, 9 }
    alpha = alpha or 255

    eng:draw_texture(tex, x, y, w, h, -1, -1, -1, -1, 0, alpha)

    -- properly round the corners: cut each sharp corner with the background
    -- colour following the arc (no more misplaced "bola" circles).
    local r, g, b = bg_color[1], bg_color[2], bg_color[3]
    local R = radius
    for i = 0, R do
        local off = math.floor(R - math.sqrt(R * R - (R - i) * (R - i)))
        if off > 0 then
            -- top-left
            eng:draw_rect(x, y + i, off, 1, r, g, b, 255)
            -- top-right
            eng:draw_rect(x + w - off, y + i, off, 1, r, g, b, 255)
            -- bottom-left
            eng:draw_rect(x, y + h - i - 1, off, 1, r, g, b, 255)
            -- bottom-right
            eng:draw_rect(x + w - off, y + h - i - 1, off, 1, r, g, b, 255)
        end
    end
end

function draw.apply_camera_effect(eng, noise_intensity, scanline_alpha, scanline_spacing)
    noise_intensity = noise_intensity or 0.02
    scanline_alpha = scanline_alpha or 30
    scanline_spacing = scanline_spacing or 4

    draw.scanlines(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, scanline_alpha)
    draw.static_noise(eng, 0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, noise_intensity)
end

function draw.vignette(eng, intensity, r, g, b)
    intensity = math.max(0.0, math.min(1.0, intensity or 0.3))
    r = r or 0
    g = g or 0
    b = b or 0

    local layers = (render_quality == "high") and 22 or 10
    local max_a = math.floor(150 * intensity)
    local w, h = settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT

    for i = 1, layers do
        local t = i / layers
        local inset = math.floor(t * 64)
        local a = math.floor((1.0 - t) * max_a)
        eng:draw_rect(inset, inset, w - inset * 2, h - inset * 2, r, g, b, a, false)
    end
end

function draw.tone_overlay(eng, r, g, b, alpha)
    alpha = math.max(0, math.min(255, math.floor(alpha or 0)))
    if alpha <= 0 then
        return
    end
    eng:draw_rect(0, 0, settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT, r or 0, g or 0, b or 0, alpha)
end

-- ============================================================
-- VHS aesthetic helpers (Phase 2)
-- ============================================================

function draw.vhs_osd(eng, text, x, y, color, scale)
    color = color or { 210, 255, 210 }
    scale = scale or 14
    draw.text(eng, text, x + 1, y + 1, scale, { 0, 0, 0 }, 255, false)
    draw.text(eng, text, x, y, scale, color, 255, false)
end

return draw