#include "game1/states/CustomNightState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>

namespace fnwf {

static float lerp_f(float a, float b, float t) { return a + (b - a) * std::min(1.0f, std::max(0.0f, t)); }

static int digit_from_event(const Event& ev)
{
    int k = ev.key;
    if (k >= '0' && k <= '9') return k - '0';
    auto kp_map = std::unordered_map<int,int>{
        {1073741922,0},{1073741913,1},{1073741914,2},{1073741915,3},{1073741916,4},
        {1073741917,5},{1073741918,6},{1073741919,7},{1073741920,8},{1073741921,9}
    };
    auto it = kp_map.find(k);
    return (it != kp_map.end()) ? it->second : -1;
}

CustomNightState::CustomNightState(Engine& eng) : m_eng(eng)
{
    animatronics = {{"Cedro","cedro",220,220}, {"Eser","eser",220,220}, {"Alice","alice",220,220}, {"Sonk","Sonk",220,220}};
    for (auto& a : animatronics) { DrawUtils::load_sprite(eng, a.sprite); sprites[a.sprite] = *DrawUtils::get_sprite(a.sprite); }

    presets = {
        {"Custom", {}, false},
        {Localization::get_text("preset_1"), {5,5,20,8}, true},
        {Localization::get_text("preset_2"), {10,20,10,10}, true},
        {Localization::get_text("preset_3"), {20,20,20,20}, true}
    };
    current_preset = 0;
    card_scales.resize(4, 1.0);
    card_glows.resize(4, 0.0);
    if (!card_scales.empty()) card_scales[0] = 1.02;
    if (!card_glows.empty()) card_glows[0] = 1.0;
    rebuild_layout();
}

auto CustomNightState::get_ai_cap() const -> int { return secret_mode_unlocked ? 40 : 20; }

void CustomNightState::unlock_secret_mode()
{
    if (!secret_mode_unlocked)
    {
        secret_mode_unlocked = true;
        presets.push_back({Localization::get_text("preset_secret"), {40,40,40,40}, true});
    }
    current_preset = (int)presets.size() - 1;
    const_cast<CustomNightState*>(this)->apply_preset(current_preset);
}

void CustomNightState::apply_preset(int index)
{
    if (index >= 0 && index < (int)presets.size())
    {
        current_preset = index;
        if (presets[index].has_levels)
        {
            for (int i = 0; i < 4 && i < (int)presets[index].levels.size(); ++i)
                ai_levels[i] = presets[index].levels[i];
        }
        SoundManager::play_sound("blip");
    }
}

void CustomNightState::cycle_preset(int direction)
{
    int new_idx = ((current_preset + direction) % (int)presets.size() + (int)presets.size()) % (int)presets.size();
    apply_preset(new_idx);
}

void CustomNightState::rebuild_layout()
{
    int card_w = 280, card_h = 430, gap = 42;
    int total_w = 4 * card_w + 3 * gap;
    int start_x = GameSettings::SCREEN_WIDTH / 2 - total_w / 2;
    int y = 120;

    card_rects.clear(); up_rects.clear(); down_rects.clear();
    for (int i = 0; i < 4; ++i)
    {
        int x = start_x + i * (card_w + gap);
        card_rects.push_back({x, y, card_w, card_h});
        up_rects.push_back({x + card_w/2 - 32, y + 300, 64, 44});
        down_rects.push_back({x + card_w/2 - 32, y + 380, 64, 44});
    }

    int cx = GameSettings::SCREEN_WIDTH / 2;
    preset_prev = {cx - 250, 580, 80, 48};
    preset_next = {cx + 170, 580, 80, 48};
    preset_label = {cx - 160, 580, 320, 48};
    ready_rect = {cx - 180, 642, 360, 54};
}

void CustomNightState::update(double dt)
{
    timer += dt;
    for (int i = 0; i < 4; ++i)
    {
        bool is_sel = (i + 1 == selected);
        double target_scale = is_sel ? 1.02 : 1.0;
        double target_glow = is_sel ? 1.0 : 0.0;
        card_scales[i] = card_scales[i] + (target_scale - card_scales[i]) * std::min(1.0, 8.0 * dt);
        card_glows[i] = card_glows[i] + (target_glow - card_glows[i]) * std::min(1.0, 6.0 * dt);
    }
}

void CustomNightState::handle_event(const Event& ev)
{
    if (ev.type == EventType::KeyDown)
    {
        int k = ev.key;
        int digit = digit_from_event(ev);
        if (digit >= 0)
        {
            secret_code_buffer += std::to_string(digit);
            if ((int)secret_code_buffer.size() > 4) secret_code_buffer = secret_code_buffer.substr(secret_code_buffer.size() - 4);
            if (secret_code_buffer == "2025")
            {
                secret_code_pending = true;
                selected = 5;
                SoundManager::play_sound("notification");
                secret_code_buffer.clear();
            }
        }

        if (k == 27) { m_result = "menu"; done = true; SoundManager::play_sound("select"); }
        else if (k == 1073741904 || k == 'a') { selected = ((selected - 2) % 5 + 5) % 5 + 1; SoundManager::play_sound("blip"); }
        else if (k == 1073741903 || k == 'd') { selected = (selected % 5) + 1; SoundManager::play_sound("blip"); }

        if (selected <= 4)
        {
            int change = 0;
            if (k == 1073741906 || k == 'w') change = 1;
            else if (k == 1073741905 || k == 's') change = -1;
            if (change != 0)
            {
                int cap = get_ai_cap();
                ai_levels[selected - 1] = std::max(0, std::min(cap, ai_levels[selected - 1] + change));
                current_preset = 0;
                SoundManager::play_sound("blip");
            }
        }

        if (k == 13 || k == 32)
        {
            if (selected == 5)
            {
                if (secret_code_pending) { secret_code_pending = false; unlock_secret_mode(); SoundManager::play_sound("select"); }
                else { m_result = "start"; done = true; SoundManager::play_sound("select"); }
            }
            else { selected = 5; SoundManager::play_sound("blip"); }
        }
    }
    if (ev.type == EventType::MouseButtonDown)
    {
        int mx = ev.x, my = ev.y;
        for (int i = 0; i < 4; ++i)
        {
            auto& r = card_rects[i];
            if (mx >= r[0] && mx <= r[0]+r[2] && my >= r[1] && my <= r[1]+r[3]) selected = i + 1;
        }
        for (int i = 0; i < 4; ++i)
        {
            auto& r = up_rects[i];
            if (mx >= r[0] && mx <= r[0]+r[2] && my >= r[1] && my <= r[1]+r[3])
            { int cap = get_ai_cap(); ai_levels[i] = std::max(0, std::min(cap, ai_levels[i]+1)); current_preset = 0; selected = i+1; SoundManager::play_sound("blip"); }
            auto& d = down_rects[i];
            if (mx >= d[0] && mx <= d[0]+d[2] && my >= d[1] && my <= d[1]+d[3])
            { int cap = get_ai_cap(); ai_levels[i] = std::max(0, std::min(cap, ai_levels[i]-1)); current_preset = 0; selected = i+1; SoundManager::play_sound("blip"); }
        }
        if (mx >= preset_prev[0] && mx <= preset_prev[0]+preset_prev[2] && my >= preset_prev[1] && my <= preset_prev[1]+preset_prev[3]) cycle_preset(-1);
        if (mx >= preset_next[0] && mx <= preset_next[0]+preset_next[2] && my >= preset_next[1] && my <= preset_next[1]+preset_next[3]) cycle_preset(1);
        if (mx >= ready_rect[0] && mx <= ready_rect[0]+ready_rect[2] && my >= ready_rect[1] && my <= ready_rect[1]+ready_rect[3])
        {
            if (secret_code_pending) { secret_code_pending = false; unlock_secret_mode(); SoundManager::play_sound("select"); }
            else { m_result = "start"; done = true; SoundManager::play_sound("select"); }
        }
    }
}

void CustomNightState::draw(Engine& eng)
{
    using namespace GameSettings;
    eng.clear(6, 9, 18, 255);
    for (int i = 0; i < SCREEN_HEIGHT; i += 90)
    {
        int a = ((i / 90) % 2 == 0) ? 12 : 7;
        eng.draw_rect(0, i, SCREEN_WIDTH, 90, 10, 14, 26, a);
    }
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.01f);
    eng.draw_rect(24, 24, SCREEN_WIDTH - 48, 76, 80, 110, 160, 70, false);
    DrawUtils::text(eng, Localization::get_text("custom_night"), SCREEN_WIDTH / 2, 38, 54, TITLE_COLOR.r, TITLE_COLOR.g, TITLE_COLOR.b, 255, true);

    for (int i = 0; i < 4; ++i)
    {
        auto& a = animatronics[i];
        auto& r = card_rects[i];
        int cx = r[0] + r[2] / 2;
        double glow = card_glows[i];
        double scale = card_scales[i];
        int dw = (int)(r[2] * scale), dh = (int)(r[3] * scale);
        int dx = r[0] - (dw - r[2]) / 2, dy = r[1] - (dh - r[3]) / 2;

        if (glow > 0.05)
        {
            double pulse = 0.5 + 0.5 * std::sin(timer * 6.0);
            int edge = (int)lerp_f(120, 230, (float)glow);
            int blue = (int)(130 + pulse * 110 * glow);
            eng.draw_rect(dx - 3, dy - 3, dw + 6, dh + 6, 90, 120, blue, 255, false);
            eng.draw_rect(dx, dy, dw, dh, edge, edge, std::min(255, edge + 45), 255, false);
        }
        else eng.draw_rect(dx, dy, dw, dh, 70, 85, 115, 255, false);

        int img_x = dx + 18, img_y = dy + 18, img_w = dw - 36, img_h = 220;
        auto it = sprites.find(a.sprite);
        if (it != sprites.end())
        {
            int sw = std::min(a.size_w, img_w - 8);
            int sh = std::min(a.size_h, img_h - 8);
            int sx = img_x + (img_w - sw) / 2;
            int sy = img_y + (img_h - sh) / 2;
            DrawUtils::rounded_texture(eng, it->second, sx, sy, sw, sh, 12, 12, 12, 16);
        }

        DrawUtils::text(eng, a.name, cx, r[1] + 260, 30, 255, 255, 255, 255, true);

        auto& up = up_rects[i];
        auto& dn = down_rects[i];
        int btn_r = (glow > 0.2) ? 150 : 90, btn_g = (glow > 0.2) ? 170 : 90, btn_b = (glow > 0.2) ? 210 : 105;
        eng.draw_rect(up[0], up[1], up[2], up[3], btn_r, btn_g, btn_b, 255, false);
        DrawUtils::text(eng, "\xe2\x96\xb2", up[0] + up[2]/2, up[1] + up[3]/2 + 1, 26, 255, 255, 255, 255, true);

        int lvl = ai_levels[i];
        int val_r = (lvl >= 20) ? 255 : ((lvl == 0) ? 80 : 255);
        int val_g = (lvl >= 20) ? 60 : ((lvl == 0) ? 220 : 255);
        int val_b = (lvl >= 20) ? 60 : ((lvl == 0) ? 110 : 255);
        DrawUtils::text(eng, std::to_string(lvl), cx, r[1] + 360, 52, val_r, val_g, val_b, 255, true);

        eng.draw_rect(dn[0], dn[1], dn[2], dn[3], btn_r, btn_g, btn_b, 255, false);
        DrawUtils::text(eng, "\xe2\x96\xbc", dn[0] + dn[2]/2, dn[1] + dn[3]/2 + 1, 26, 255, 255, 255, 255, true);
    }

    double pulse = 0.5 + 0.5 * std::sin(timer * 4.0);
    int arrow_r = 200, arrow_g = 200, arrow_b = (int)(140 + 70 * pulse);

    eng.draw_rect(preset_prev[0], preset_prev[1], preset_prev[2], preset_prev[3], 120, 120, 140, 255, false);
    DrawUtils::text(eng, "<<", preset_prev[0] + preset_prev[2]/2, preset_prev[1] + preset_prev[3]/2, 28, arrow_r, arrow_g, arrow_b, 255, true);

    eng.draw_rect(preset_label[0], preset_label[1], preset_label[2], preset_label[3], 100, 100, 120, 255, false);
    std::string p_name = presets[current_preset].name;
    int label_size = (p_name.size() >= 22) ? 20 : ((p_name.size() >= 16) ? 24 : 30);
    DrawUtils::text(eng, p_name, preset_label[0] + preset_label[2]/2, preset_label[1] + preset_label[3]/2, label_size, 255, 255, 120, 255, true);

    eng.draw_rect(preset_next[0], preset_next[1], preset_next[2], preset_next[3], 120, 120, 140, 255, false);
    DrawUtils::text(eng, ">>", preset_next[0] + preset_next[2]/2, preset_next[1] + preset_next[3]/2, 28, arrow_r, arrow_g, arrow_b, 255, true);

    bool rs = (selected == 5);
    if (rs)
    {
        int glow = (int)(100 + 100 * (0.5 + 0.5 * std::sin(timer * 7.0)));
        eng.draw_rect(ready_rect[0], ready_rect[1], ready_rect[2], ready_rect[3], glow, glow, 80, 255, false);
    }
    else eng.draw_rect(ready_rect[0], ready_rect[1], ready_rect[2], ready_rect[3], 120, 120, 130, 255, false);

    std::string ready_label = secret_code_pending ? Localization::get_text("apply_code") : Localization::get_text("ready");
    std::string prefix = rs ? ">> " : "";
    DrawUtils::text(eng, prefix + ready_label, ready_rect[0] + ready_rect[2]/2, ready_rect[1] + ready_rect[3]/2, 40,
        rs ? 255 : 150, rs ? 255 : 150, rs ? 255 : 160, 255, true);

    DrawUtils::text(eng, Localization::get_text("custom_controls_help"), SCREEN_WIDTH / 2, SCREEN_HEIGHT - 22, 14, 100, 100, 110, 255, true);
    DrawUtils::scanlines(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 15);
}

} // namespace fnwf
