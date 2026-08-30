local office = {}
local settings = require("scripts.game1.settings")
local draw = require("scripts.core.utils.draw")

local Office = {}
Office.__index = Office

function Office.new(eng)
    print("Initializing Office system...")
    local self = setmetatable({}, Office)
    self.eng = eng
    self.pan_x = 0.0
    self.target_pan = 0.0

    self.office_tex = eng:create_target_texture(settings.OFFICE_WIDTH, settings.SCREEN_HEIGHT)
    self.office_static_tex = eng:create_target_texture(settings.OFFICE_WIDTH, settings.SCREEN_HEIGHT)

    self.vp_x = settings.OFFICE_WIDTH / 2
    self.vp_y = settings.SCREEN_HEIGHT / 2 - 30

    self.bw_left = settings.OFFICE_WIDTH / 2 - 240
    self.bw_right = settings.OFFICE_WIDTH / 2 + 240
    self.bw_top = 80
    self.bw_bottom = settings.SCREEN_HEIGHT - 120

    self.hall_w = 100
    self.hall_depth = 250

    self.vent_light = false
    self.vent_pos = { self.vp_x - 60, self.bw_bottom - 110, 120, 80 }

    self._projection_data = {}
    self:precalculate_projection()
    self:build_static_layer()

    return self
end

function Office:shade(color, factor)
    local f = math.max(0.0, factor)
    return {
        math.max(0, math.min(255, math.floor(color[1] * f))),
        math.max(0, math.min(255, math.floor(color[2] * f))),
        math.max(0, math.min(255, math.floor(color[3] * f)))
    }
end

function Office:project_depth(nx, z, height)
    height = height or 0.0
    local zc = math.max(0.0, math.min(1.0, z))
    local scale = 0.40 + zc * 1.45
    local world_half = 320
    local sx = math.floor(self.vp_x + (nx * world_half * scale))
    local floor_y = self.bw_bottom + math.floor((settings.SCREEN_HEIGHT - self.bw_bottom) * (zc ^ 1.2))
    local sy = floor_y - math.floor(height * scale)
    return sx, sy, scale
end

function Office:precalculate_projection()
    local screen_w, screen_h = settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT
    local fov = math.rad(100)
    local focal_length = (screen_w / 2) / math.tan(fov / 2)
    local slice_w = 16
    local pixels_per_radian = settings.OFFICE_WIDTH / math.pi
    self._projection_data = {}

    for sx = 0, screen_w - 1, slice_w do
        local theta = math.atan((sx + slice_w / 2 - screen_w / 2) / focal_length)
        local scale_y = 1.0 / math.cos(theta)
        local src_w = slice_w * (pixels_per_radian * (math.cos(theta) ^ 2) / focal_length)
        table.insert(self._projection_data, {
            sx = sx,
            theta = theta,
            target_h = math.floor(screen_h * scale_y),
            src_w = math.max(1, math.floor(src_w)),
        })
    end
end

function Office:update(mouse_x, dt)
    local norm = mouse_x / settings.SCREEN_WIDTH
    self.target_pan = (norm - 0.5) * 2.0
    self.pan_x = self.pan_x + (self.target_pan - self.pan_x) * 4.0 * dt
end

function Office:draw(eng, left_door_anim, right_door_anim, left_light, right_light, anim_at_left, anim_at_right,
                     anim_at_vent, anim_in_office)
    local t = os.clock()
    eng:set_render_target(self.office_tex)
    eng:draw_texture(self.office_static_tex, 0, 0, settings.OFFICE_WIDTH, settings.SCREEN_HEIGHT)

    self:draw_back_wall_dynamic(eng, t)
    self:draw_hallways_dynamic(eng, left_light, right_light, anim_at_left, anim_at_right)
    self:draw_vent_dynamic(eng, anim_at_vent)
    self:draw_doors(eng, left_door_anim, right_door_anim)
    self:draw_fan(eng, t)
    self:draw_in_office(eng, anim_in_office)

    eng:reset_render_target()

    local screen_w, screen_h = settings.SCREEN_WIDTH, settings.SCREEN_HEIGHT
    local office_w = settings.OFFICE_WIDTH
    local pixels_per_radian = settings.OFFICE_WIDTH / math.pi
    local max_pan_angle = math.rad(45)
    local center_angle = math.rad(90) + self.pan_x * max_pan_angle

    for _, data in ipairs(self._projection_data) do
        local target_angle = center_angle + data.theta
        local source_x = target_angle * pixels_per_radian
        local src_w, target_h = data.src_w, data.target_h

        local src_x = math.floor(source_x - src_w / 2)
        if src_x + src_w > 0 and src_x < office_w then
            local final_src_x = math.max(0, src_x)
            local final_src_w = math.min(office_w - final_src_x, src_w - (final_src_x - src_x))
            if final_src_w > 0 then
                eng:draw_texture(
                    self.office_tex,
                    data.sx,
                    math.floor((screen_h - target_h) / 2),
                    -- dst width must cover the 16px slice spacing, else skipped
                    -- columns create vertical bars. 17 gives a 1px overlap.
                    17,
                    target_h,
                    final_src_x,
                    0,
                    final_src_w,
                    screen_h
                )
            end
        end
    end
end

function Office:build_static_layer()
    local eng = self.eng
    eng:set_render_target(self.office_static_tex)
    eng:clear(5, 5, 8)
    self:draw_ceiling(eng)
    self:draw_floor(eng)
    self:draw_back_wall_base(eng)
    self:draw_depth_structure(eng)
    self:draw_hallways_base(eng)
    self:draw_vent_base(eng)
    self:draw_side_walls(eng)
    self:draw_wall_dressing(eng)
    self:draw_office_elements(eng)
    self:draw_ambient(eng)
    eng:reset_render_target()
end

function Office:draw_ceiling(eng)
    local bw_l, bw_r, bw_t = self.bw_left, self.bw_right, self.bw_top
    draw.trapezoid(
        eng,
        { 22, 20, 25 },
        { 0, 0 },
        { settings.OFFICE_WIDTH, 0 },
        { bw_r + self.hall_depth, bw_t },
        { bw_l - self.hall_depth, bw_t }
    )

    local num_lines = 10
    for i = 1, num_lines - 1 do
        local prog = i / num_lines
        local y = math.floor(prog * bw_t)
        local lx = math.floor((bw_l - self.hall_depth) * prog)
        local rx = math.floor(settings.OFFICE_WIDTH - (settings.OFFICE_WIDTH - bw_r - self.hall_depth) * prog)
        local shade = math.max(0, 30 - math.floor(prog * 20))
        eng:draw_line(lx, y, rx, y, shade, shade, shade + 3)
    end

    for i = 0, 5 do
        local frac = (i + 1) / 7.0
        local top_x = math.floor(settings.OFFICE_WIDTH * frac)
        local bot_x = math.floor((bw_l - self.hall_depth) + frac * (bw_r + self.hall_depth - bw_l + self.hall_depth))
        eng:draw_line(top_x, 0, bot_x, bw_t, 18, 18, 22)
    end
end

function Office:draw_floor(eng)
    local bw_l, bw_r, bw_b = self.bw_left, self.bw_right, self.bw_bottom
    local floor_left_far, floor_right_far = bw_l - self.hall_depth, bw_r + self.hall_depth
    draw.trapezoid(
        eng,
        settings.FLOOR_COLOR,
        { floor_left_far, bw_b },
        { floor_right_far, bw_b },
        { settings.OFFICE_WIDTH + 100, settings.SCREEN_HEIGHT },
        { -100, settings.SCREEN_HEIGHT }
    )

    local rows, cols = 4, 8
    for r = 0, rows - 1 do
        local py0, py1 = r / rows, (r + 1) / rows
        local y0 = math.floor(bw_b + py0 * (settings.SCREEN_HEIGHT - bw_b))
        local y1 = math.floor(bw_b + py1 * (settings.SCREEN_HEIGHT - bw_b))
        local lx0 = math.floor(floor_left_far + (-100 - floor_left_far) * py0)
        local rx0 = math.floor(floor_right_far + (settings.OFFICE_WIDTH + 100 - floor_right_far) * py0)
        local lx1 = math.floor(floor_left_far + (-100 - floor_left_far) * py1)
        local rx1 = math.floor(floor_right_far + (settings.OFFICE_WIDTH + 100 - floor_right_far) * py1)
        for c = 0, cols - 1 do
            local px0 = lx0 + math.floor(c / cols * (rx0 - lx0))
            local px1 = lx0 + math.floor((c + 1) / cols * (rx0 - lx0))
            local px0b = lx1 + math.floor(c / cols * (rx1 - lx1))
            local px1b = lx1 + math.floor((c + 1) / cols * (rx1 - lx1))
            local color = ((r + c) % 2 == 0) and settings.FLOOR_TILE_1 or settings.FLOOR_TILE_2
            local fade = math.max(0.3, 1.0 - (1.0 - py0) * 0.6)
            local final_color = { math.floor(color[1] * fade), math.floor(color[2] * fade), math.floor(color[3] * fade) }
            draw.trapezoid(eng, final_color, { px0, y0 }, { px1, y0 }, { px1b, y1 }, { px0b, y1 })
        end
    end
end

function Office:draw_back_wall_base(eng)
    local bw_l, bw_r, bw_t, bw_b = self.bw_left, self.bw_right, self.bw_top, self.bw_bottom
    eng:draw_rect(bw_l, bw_t, bw_r - bw_l, bw_b - bw_t, settings.WALL_COLOR[1], settings.WALL_COLOR[2],
        settings.WALL_COLOR[3])
    eng:draw_rect(bw_l + 10, bw_t + 16, bw_r - bw_l - 20, 22, 34, 32, 40, 190)
    for i = 0, 6 do
        local yy = bw_t + 14 + i * 4
        eng:draw_line(bw_l + 16, yy, bw_r - 16, yy, 52, 48, 58, 70)
    end
    eng:draw_rect(bw_l, bw_b - 20, bw_r - bw_l, 20, 35, 30, 38)
    eng:draw_line(bw_l, bw_b - 20, bw_r, bw_b - 20, 50, 45, 55)

    local p1x, p1y = self.vp_x - 64, bw_t + 36
    eng:draw_rect(p1x, p1y, 128, 128, 40, 36, 46)
    eng:draw_rect(p1x + 2, p1y + 2, 124, 124, 22, 22, 24)
    eng:draw_rect(p1x + 8, p1y + 10, 112, 108, 14, 14, 18)
    eng:draw_rect(p1x, p1y, 128, 128, settings.WALL_ACCENT[1], settings.WALL_ACCENT[2], settings.WALL_ACCENT[3], 255,
        false)
    draw.text(eng, "MAFIA", p1x + 64, p1y + 52, 24, settings.STAR_COLOR, 255, true)
    draw.text(eng, "NIGHT SHIFT", p1x + 64, p1y + 82, 11, { 160, 150, 72 }, 220, true)
    for i = 0, 5 do
        eng:draw_line(p1x + 10, p1y + 96 + i * 3, p1x + 118, p1y + 90 + i * 3, 45, 42, 50, 120)
    end

    local flyer_x, flyer_y = bw_l + 42, bw_t + 70
    eng:draw_rect(flyer_x, flyer_y, 84, 104, 64, 58, 62)
    eng:draw_rect(flyer_x + 5, flyer_y + 8, 74, 88, 38, 34, 40)
    draw.text(eng, "RULES", flyer_x + 42, flyer_y + 26, 12, { 188, 182, 168 }, 245, true)
    for i = 0, 5 do
        eng:draw_line(flyer_x + 12, flyer_y + 40 + i * 9, flyer_x + 70, flyer_y + 40 + i * 9, 74, 70, 64, 180)
    end

    local clock_x, clock_y = self.vp_x + 120, bw_t + 30
    eng:draw_circle(clock_x, clock_y, 18, 50, 48, 55)
    eng:draw_circle(clock_x, clock_y, 18, settings.WALL_ACCENT[1], settings.WALL_ACCENT[2], settings.WALL_ACCENT[3], 255,
        false)

    for i = 0, 7 do
        local gx = bw_l + 40 + i * 58
        eng:draw_line(gx, bw_t + 44, gx + 8, bw_b - 26, 30, 26, 33, 90)
    end

    eng:draw_line(self.vp_x, bw_t, self.vp_x, bw_b, 60, 55, 65, 120)
end

function Office:draw_back_wall_dynamic(eng, t)
    t = t or os.clock()
    local clock_x, clock_y = self.vp_x + 120, self.bw_top + 30
    eng:draw_line(clock_x, clock_y, clock_x + math.floor(math.cos(t) * 10), clock_y + math.floor(math.sin(t) * 10), 140,
        130, 120)
    local pulse = 0.45 + 0.55 * math.sin(t * 2.8)
    local lamp_a = math.floor(26 + pulse * 38)
    eng:draw_rect(self.vp_x - 120, self.bw_top + 6, 240, 16, 220, 210, 165, lamp_a)
end

function Office:draw_depth_structure(eng)
    for _, z in ipairs({ 0.12, 0.24, 0.36, 0.50, 0.66, 0.82 }) do
        local lx, y, _ = self:project_depth(-1.0, z)
        local rx, _, _ = self:project_depth(1.0, z)
        local shade = math.floor(70 - z * 28)
        eng:draw_line(lx, y, rx, y, shade, shade, shade + 4, 120)
    end

    for _, side in ipairs({ -1, 1 }) do
        for _, z in ipairs({ 0.18, 0.42, 0.70 }) do
            local x0, y0, s0 = self:project_depth(0.82 * side, z, 0)
            local _, y1, _ = self:project_depth(0.82 * side, z, 150)
            local w = math.max(8, math.floor(16 * s0))
            local col = self:shade({ 48, 45, 52 }, 1.05 - z * 0.35)
            eng:draw_rect(x0 - w / 2, y1, w, math.max(8, y0 - y1), col[1], col[2], col[3], 150)
        end
    end
end

function Office:draw_side_walls(eng)
    local bw_l, bw_r, bw_t, bw_b, depth = self.bw_left, self.bw_right, self.bw_top, self.bw_bottom, self.hall_depth
    draw.trapezoid(eng, { 38, 35, 42 }, { bw_l - depth, 0 }, { bw_l, bw_t }, { bw_l, bw_b },
        { bw_l - depth, settings.SCREEN_HEIGHT })
    draw.trapezoid(eng, { 38, 35, 42 }, { bw_r, bw_t }, { bw_r + depth, 0 }, { bw_r + depth, settings.SCREEN_HEIGHT },
        { bw_r, bw_b })
end

function Office:draw_hallways_base(eng)
    local bw_l, bw_r, bw_t, bw_b, depth, hw = self.bw_left, self.bw_right, self.bw_top, self.bw_bottom, self.hall_depth,
        self.hall_w
    local ht, hb = bw_t + 15, bw_b - 15

    local lx, lw, lh = bw_l - depth - hw, hw + 10, hb - ht
    eng:draw_rect(lx, ht, lw, lh, 8, 8, 10)
    eng:draw_rect(lx, ht, lw, lh, settings.DOOR_FRAME_COLOR[1], settings.DOOR_FRAME_COLOR[2],
        settings.DOOR_FRAME_COLOR[3], 255, false)
    for i = 0, 8 do
        local y = ht + i * math.floor(lh / 9)
        local c = (i % 2 == 0) and { 168, 138, 42 } or { 35, 30, 28 }
        eng:draw_line(lx + lw - 10, y, lx + lw, y, c[1], c[2], c[3], 210)
    end

    local rx, rw = bw_r + depth - 10, hw + 10
    eng:draw_rect(rx, ht, rw, lh, 8, 8, 10)
    eng:draw_rect(rx, ht, rw, lh, settings.DOOR_FRAME_COLOR[1], settings.DOOR_FRAME_COLOR[2],
        settings.DOOR_FRAME_COLOR[3], 255, false)
    for i = 0, 8 do
        local y = ht + i * math.floor(lh / 9)
        local c = (i % 2 == 0) and { 168, 138, 42 } or { 35, 30, 28 }
        eng:draw_line(rx, y, rx + 10, y, c[1], c[2], c[3], 210)
    end
end

function Office:draw_hallways_dynamic(eng, left_light, right_light, anim_left, anim_right)
    local bw_l, bw_r, bw_t, bw_b, depth, hw = self.bw_left, self.bw_right, self.bw_top, self.bw_bottom, self.hall_depth,
        self.hall_w
    local ht, hb = bw_t + 15, bw_b - 15

    local lx, lw, lh = bw_l - depth - hw, hw + 10, hb - ht
    local rx, rw = bw_r + depth - 10, hw + 10

    if left_light then
        eng:draw_rect(lx, ht, lw, lh, settings.HALL_LIGHT[1], settings.HALL_LIGHT[2], settings.HALL_LIGHT[3], 70)
        eng:draw_rect(lx + 6, ht + 8, lw - 12, lh - 16, 226, 214, 170, 24)
        if anim_left then
            draw.animatronic_face(eng, anim_left, lx + 10, ht + 20, lw - 20, 160)
        end
    end

    if right_light then
        eng:draw_rect(rx, ht, rw, lh, settings.HALL_LIGHT[1], settings.HALL_LIGHT[2], settings.HALL_LIGHT[3], 70)
        eng:draw_rect(rx + 6, ht + 8, rw - 12, lh - 16, 226, 214, 170, 24)
        if anim_right then
            draw.animatronic_face(eng, anim_right, rx + 10, ht + 20, rw - 20, 160)
        end
    end
end

function Office:draw_vent_base(eng)
    local vx, vy, vw, vh = table.unpack(self.vent_pos)
    eng:draw_rect(vx, vy, vw, vh, 5, 5, 7)
    eng:draw_rect(vx, vy, vw, vh, 40, 40, 45, 255, false)
    for i = 1, 3 do
        local by = vy + i * math.floor(vh / 4)
        eng:draw_line(vx, by, vx + vw, by, 35, 35, 40)
    end
end

function Office:draw_vent_dynamic(eng, anim_vent)
    local vx, vy, vw, vh = table.unpack(self.vent_pos)
    if self.vent_light then
        eng:draw_rect(vx, vy, vw, vh, 200, 200, 220, 90)
        if anim_vent then
            draw.animatronic_face(eng, anim_vent, vx + 20, vy + 10, vw - 40, vh - 20)
        end
    elseif anim_vent then
        eng:draw_circle(vx + 45, vy + 30, 4, 255, 200, 220)
        eng:draw_circle(vx + 75, vy + 30, 4, 255, 200, 220)
    end
end

function Office:draw_doors(eng, left_anim, right_anim)
    local bw_l, bw_r, bw_t, bw_b, depth, hw = self.bw_left, self.bw_right, self.bw_top, self.bw_bottom, self.hall_depth,
        self.hall_w
    local ht, hb = bw_t + 15, bw_b - 15
    local door_h = hb - ht
    if left_anim > 0.01 then
        self:draw_single_door(eng, bw_l - depth - hw, ht, hw + 10, math.floor(door_h * left_anim))
    end
    if right_anim > 0.01 then
        self:draw_single_door(eng, bw_r + depth - 10, ht, hw + 10, math.floor(door_h * right_anim))
    end
end

function Office:draw_single_door(eng, x, y, w, v_h)
    eng:draw_rect(x, y, w, v_h, settings.DOOR_COLOR[1], settings.DOOR_COLOR[2], settings.DOOR_COLOR[3])
    for i = 0, v_h - 1, 14 do
        eng:draw_line(x, y + i, x + w, y + i, 85, 80, 78)
    end
    local sh = 12
    for i = 0, w + sh, sh do
        eng:draw_line(x + i, y, x + i - sh, y + math.min(sh, v_h), 200, 180, 40)
    end
    if v_h > 80 then
        eng:draw_rect(x + w / 2 - 18, y + 35, 36, 28, 15, 25, 15)
        eng:draw_rect(x + w / 2 - 18, y + 35, 36, 28, 95, 90, 85, 255, false)
    end
    eng:draw_rect(x, y, w, v_h, 95, 90, 85, 255, false)
end

function Office:draw_office_elements(eng)
    local bl_x, bl_y = self:project_depth(-0.70, 0.58, 0)
    local br_x, br_y = self:project_depth(0.70, 0.58, 0)
    local fl_x, fl_y = self:project_depth(-1.00, 0.92, 0)
    local fr_x, fr_y = self:project_depth(1.00, 0.92, 0)
    draw.trapezoid(eng, settings.DESK_TOP, { bl_x, bl_y }, { br_x, br_y }, { fr_x, fr_y }, { fl_x, fl_y })
    local col_desk = self:shade(settings.DESK_COLOR, 0.85)
    draw.trapezoid(eng, col_desk, { fl_x, fl_y }, { fr_x, fr_y }, { fr_x, fr_y + 46 }, { fl_x, fl_y + 46 })
    eng:draw_line(fl_x, fl_y, fr_x, fr_y, 120, 104, 86)
    eng:draw_rect(fl_x + 30, fl_y + 8, 120, 18, 72, 64, 60)
    eng:draw_rect(fr_x - 170, fr_y + 12, 145, 16, 74, 66, 62)
    for i = 0, 4 do
        eng:draw_line(fl_x + 36 + i * 7, fl_y + 11, fl_x + 130 + i * 7, fl_y + 11, 96, 90, 84, 160)
    end

    local mx, my, ms = self:project_depth(0.42, 0.64, 66)
    local mw = math.max(42, math.floor(85 * ms))
    local mh = math.max(28, math.floor(56 * ms))
    eng:draw_rect(mx - mw / 2, my - mh / 2, mw, mh, 18, 20, 24)
    eng:draw_rect(mx - mw / 2, my - mh / 2, mw, mh, 65, 70, 78, 255, false)
    eng:draw_rect(mx - 4, my + mh / 2, 8, math.floor(15 * ms), 45, 45, 48)
    eng:draw_rect(mx - math.floor(24 * ms), my + mh / 2 + math.floor(15 * ms), math.floor(48 * ms), math.floor(5 * ms),
        55, 55, 60)

    local cx, cy, cs = self:project_depth(-0.34, 0.70, 32)
    local cw = math.max(8, math.floor(14 * cs))
    local ch = math.max(12, math.floor(28 * cs))
    eng:draw_rect(cx - cw / 2, cy - ch, cw, ch, 180, 25, 25)
    eng:draw_rect(cx - cw / 2 - 1, cy - ch - 3, cw + 2, 5, 210, 45, 45)

    local mug_x, mug_y, mug_s = self:project_depth(0.08, 0.73, 28)
    local mug_w = math.max(10, math.floor(18 * mug_s))
    local mug_h = math.max(8, math.floor(12 * mug_s))
    eng:draw_rect(mug_x - mug_w / 2, mug_y - mug_h, mug_w, mug_h, 120, 115, 102)
    eng:draw_rect(mug_x + mug_w / 2 - 1, mug_y - mug_h + 2, 5, mug_h - 4, 120, 115, 102, 255, false)
end

function Office:draw_fan(eng, t)
    t = t or os.clock()
    local fx, fy, fs = self:project_depth(-0.46, 0.66, 34)
    local cx, cy = fx, fy
    local hub_r = math.max(3, math.floor(5 * fs))
    local ring_r = math.max(12, math.floor(24 * fs))
    eng:draw_rect(cx - 10, cy + 2, 20, 22, 55, 55, 60)
    eng:draw_rect(cx - 16, cy + 22, 32, 6, 65, 65, 70)
    eng:draw_circle(cx, cy - 5, ring_r, 70, 24, 24)
    eng:draw_circle(cx, cy - 5, math.max(8, ring_r - 2), 48, 48, 52)
    local t = os.clock() * 12.0
    for i = 0, 3 do
        local angle = t + i * (math.pi / 2)
        local ex, ey = cx + math.floor(math.cos(angle) * (ring_r - 5)),
            cy - 5 + math.floor(math.sin(angle) * (ring_r - 5))
        eng:draw_line(cx, cy - 5, ex, ey, 110, 110, 115)
    end
    eng:draw_circle(cx, cy - 5, hub_r, 80, 80, 85)
end

function Office:draw_wall_dressing(eng)
    local bw_l, bw_r, bw_t, bw_b = self.bw_left, self.bw_right, self.bw_top, self.bw_bottom
    for _, side in ipairs({ -1, 1 }) do
        local base_x = (side < 0) and (bw_l - self.hall_depth + 22) or (bw_r + self.hall_depth - 130)
        eng:draw_rect(base_x, bw_t + 44, 108, 30, 26, 24, 30)
        eng:draw_rect(base_x + 3, bw_t + 47, 102, 24, 56, 18, 18)
        draw.text(eng, "DOOR CTRL", base_x + 54, bw_t + 59, 11, { 220, 214, 194 }, 240, true)
    end

    for i = 0, 3 do
        local x0 = self.vp_x - 150 + i * 92
        local y0 = bw_b - 56 - i * 4
        eng:draw_line(x0, y0, x0 + 78, y0 - 8, 26, 24, 30, 180)
    end
end

function Office:draw_in_office(eng, anim_name)
    if not anim_name then return end
    local w, h = 400, 500
    local x, y = self.vp_x - w / 2, self.bw_bottom - h + 80
    if (math.floor(os.clock() * 7) % 3) ~= 0 then
        draw.animatronic_sprite(eng, anim_name, x, y, w, h)
    end
end

function Office:draw_ambient(eng)
    eng:draw_rect(0, 0, settings.OFFICE_WIDTH, settings.SCREEN_HEIGHT, 0, 0, 0, 24)
    eng:draw_rect(0, 0, settings.OFFICE_WIDTH, 120, 0, 0, 0, 40)
    eng:draw_rect(0, settings.SCREEN_HEIGHT - 90, settings.OFFICE_WIDTH, 90, 0, 0, 0, 32)
    for i = 0, 6 do
        local y = math.floor(i * (settings.SCREEN_HEIGHT / 7))
        local a = 20 - i * 2
        if a > 0 then
            eng:draw_rect(0, y, settings.OFFICE_WIDTH, math.floor(settings.SCREEN_HEIGHT / 7), 0, 0, 0, a)
        end
    end
end

office.Office = Office
return office