#include "game1/states/OptionsState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SettingsManager.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>

namespace fnwf {

static float lerp_f(float a, float b, float t) { return a + (b - a) * std::min(1.0f, std::max(0.0f, t)); }

OptionsState::OptionsState(Engine& eng) : m_eng(eng)
{
    auto modes = eng.get_display_modes();
    std::vector<std::pair<int,int>> seen;
    for (auto& m : modes)
    {
        bool dup = false;
        for (auto& s : seen) { if (s.first == m[0] && s.second == m[1]) { dup = true; break; } }
        if (!dup) seen.push_back({m[0], m[1]});
    }
    if (seen.empty()) { seen.push_back({1280,720}); seen.push_back({1920,1080}); }
    std::sort(seen.begin(), seen.end(), [](auto& a, auto& b){ return a.first < b.first; });
    resolutions = seen;

    auto& s = SettingsManager::instance();
    current_res_idx = 0;
    for (int i = 0; i < (int)resolutions.size(); ++i)
    {
        if (resolutions[i].first == s.resolution_w && resolutions[i].second == s.resolution_h)
        { current_res_idx = i; break; }
    }
    is_fullscreen = s.fullscreen;
    show_fps = s.show_fps;
    vsync = s.vsync;
    vsync_at_start = s.vsync;
    lang = s.language;
    discord_rpc = s.discord_rpc;
    master_volume = s.master_volume;
    sfx_volume = s.sfx_volume;
    music_volume = s.music_volume;

    rebuild_options();
    item_glows.resize(max_options, 0.0);
    if (!item_glows.empty()) item_glows[0] = 1.0;
}

void OptionsState::rebuild_options()
{
    options.clear();
    std::vector<std::string> res_vals;
    for (auto& r : resolutions) res_vals.push_back(std::to_string(r.first) + "x" + std::to_string(r.second));
    std::vector<std::string> quality_vals = {Localization::get_text("low"), Localization::get_text("high")};

    options.push_back({"resolution", Localization::get_text("resolution"), OptionItem::Toggle, res_vals, current_res_idx, false, 0, 100, ""});
    options.push_back({"fullscreen", Localization::get_text("fullscreen"), OptionItem::Bool, {}, 0, is_fullscreen, 0, 100, ""});
    options.push_back({"language", Localization::get_text("language"), OptionItem::Toggle, {"Português", "English"}, (lang == "pt") ? 0 : 1, false, 0, 100, ""});
    options.push_back({"master_volume", Localization::get_text("master_volume"), OptionItem::Slider, {}, 0, false, master_volume, 100, ""});
    options.push_back({"sfx_volume", Localization::get_text("sfx_volume"), OptionItem::Slider, {}, 0, false, sfx_volume, 100, ""});
    options.push_back({"music_volume", Localization::get_text("music_volume"), OptionItem::Slider, {}, 0, false, music_volume, 100, ""});
    options.push_back({"show_fps", Localization::get_text("show_fps"), OptionItem::Bool, {}, 0, show_fps, 0, 100, ""});
    options.push_back({"vsync", Localization::get_text("vsync"), OptionItem::Bool, {}, 0, vsync, 0, 100, ""});
    options.push_back({"quality", Localization::get_text("quality"), OptionItem::Toggle, quality_vals, (SettingsManager::instance().quality == "low") ? 0 : 1, false, 0, 100, ""});
    options.push_back({"discord_rpc", Localization::get_text("discord_rpc"), OptionItem::Bool, {}, 0, discord_rpc, 0, 100, ""});
    options.push_back({"back", Localization::get_text("back"), OptionItem::Action, {}, 0, false, 0, 100, "back"});
    max_options = (int)options.size();
    item_glows.resize(max_options, 0.0);
    if (selected > max_options) selected = max_options;
}

void OptionsState::update(double dt)
{
    timer += dt;
    bg_scroll += dt * 35.0;

    int item_h = 50;
    int visible_h = GameSettings::SCREEN_HEIGHT - 200;
    int content_h = max_options * item_h;
    int target_item_y = (selected - 1) * item_h;

    if (content_h > visible_h)
    {
        int max_scroll = content_h - visible_h;
        if (target_item_y < (int)scroll_offset) scroll_target = target_item_y;
        else if (target_item_y + item_h > (int)scroll_offset + visible_h) scroll_target = target_item_y - visible_h + item_h;
        scroll_target = std::max(0.0, std::min((double)max_scroll, scroll_target));
    }
    else { scroll_target = 0; }

    scroll_offset = scroll_offset + (scroll_target - scroll_offset) * std::min(1.0, 12.0 * dt);

    highlight_y = 150 + (selected - 1) * item_h - 9 - scroll_offset;

    for (int i = 0; i < max_options; ++i)
    {
        double target = (i + 1 == selected) ? 1.0 : 0.0;
        item_glows[i] = item_glows[i] + (target - item_glows[i]) * std::min(1.0, 8.0 * dt);
    }
}

void OptionsState::handle_event(const Event& ev)
{
    if (ev.type == EventType::KeyDown)
    {
        int key = ev.key;
        if (key == 1073741906 || key == 'w')
        {
            selected = ((selected - 2 + max_options) % max_options) + 1;
            SoundManager::play_sound("blip");
        }
        else if (key == 1073741905 || key == 's')
        {
            selected = (selected % max_options) + 1;
            SoundManager::play_sound("blip");
        }
        else if (key == 1073741904 || key == 'a' || key == 1073741903 || key == 'd')
        {
            auto& opt = options[selected - 1];
            int dir = (key == 1073741903 || key == 'd') ? 1 : -1;
            if (opt.type == OptionItem::Toggle)
            {
                opt.current = ((opt.current + dir) % (int)opt.values.size() + (int)opt.values.size()) % (int)opt.values.size();
                if (opt.id == "language")
                {
                    lang = (opt.current == 0) ? "pt" : "en";
                    Localization::set_language(lang);
                    rebuild_options();
                }
                SoundManager::play_sound("blip");
            }
            else if (opt.type == OptionItem::Bool)
            {
                opt.value = !opt.value;
                SoundManager::play_sound("blip");
            }
            else if (opt.type == OptionItem::Slider)
            {
                opt.slider_value = std::max(0, std::min(opt.slider_max, opt.slider_value + dir * 5));
                SoundManager::play_sound("blip");
            }
        }
        else if (key == 13 || key == 32)
        {
            auto& opt = options[selected - 1];
            if (opt.type == OptionItem::Action && opt.action == "back")
            {
                SoundManager::play_sound("select");
                apply_settings();
                m_result = "back";
                done = true;
            }
            else if (opt.type == OptionItem::Bool)
            {
                opt.value = !opt.value;
                SoundManager::play_sound("blip");
            }
            else if (opt.type == OptionItem::Toggle)
            {
                opt.current = (opt.current + 1) % (int)opt.values.size();
                if (opt.id == "language")
                {
                    lang = (opt.current == 0) ? "pt" : "en";
                    Localization::set_language(lang);
                    rebuild_options();
                }
                SoundManager::play_sound("blip");
            }
        }
        else if (key == 27)
        {
            SoundManager::play_sound("select");
            apply_settings();
            m_result = "back";
            done = true;
        }
    }
    if (ev.type == EventType::MouseButtonDown)
    {
        handle_click(ev.x, ev.y);
    }
}

void OptionsState::handle_click(int mx, int my)
{
    int panel_x = 40;
    int panel_w = GameSettings::SCREEN_WIDTH - 80;

    for (int i = 0; i < max_options; ++i)
    {
        int y = 150 + i * 50 - (int)scroll_offset;
        if (my >= y - 9 && my <= y + 40 && mx >= panel_x + 25 && mx <= panel_x + panel_w - 25)
        {
            selected = i + 1;
            auto& opt = options[i];

            if (opt.type == OptionItem::Action && opt.action == "back")
            {
                SoundManager::play_sound("select");
                apply_settings();
                m_result = "back";
                done = true;
                return;
            }

            int value_x = 500;
            if (opt.type == OptionItem::Toggle)
            {
                if (mx < value_x)
                {
                    opt.current = ((opt.current - 1) % (int)opt.values.size() + (int)opt.values.size()) % (int)opt.values.size();
                }
                else
                {
                    opt.current = (opt.current + 1) % (int)opt.values.size();
                }
                if (opt.id == "language")
                {
                    lang = (opt.current == 0) ? "pt" : "en";
                    Localization::set_language(lang);
                    rebuild_options();
                }
                SoundManager::play_sound("blip");
            }
            else if (opt.type == OptionItem::Bool)
            {
                opt.value = !opt.value;
                SoundManager::play_sound("blip");
            }
            else if (opt.type == OptionItem::Slider)
            {
                int bar_x = value_x - 10;
                int bar_w = 200;
                float ratio = std::max(0.0f, std::min(1.0f, (float)(mx - bar_x) / (float)bar_w));
                opt.slider_value = (int)(ratio * opt.slider_max);
                SoundManager::play_sound("blip");
            }
            return;
        }
    }
}

void OptionsState::apply_settings()
{
    auto& s = SettingsManager::instance();
    for (auto& opt : options)
    {
        if (opt.id == "resolution")
        {
            auto& res = resolutions[opt.current];
            s.resolution_w = res.first;
            s.resolution_h = res.second;
            m_eng.set_resolution(res.first, res.second);
            m_eng.set_logical_size(1280, 720);
        }
        else if (opt.id == "fullscreen") { s.fullscreen = opt.value; m_eng.set_fullscreen(opt.value); }
        else if (opt.id == "language") s.language = (opt.current == 0) ? "pt" : "en";
        else if (opt.id == "show_fps") s.show_fps = opt.value;
        else if (opt.id == "vsync") { s.vsync = opt.value; if (opt.value != vsync_at_start) vsync_changed = true; else vsync_changed = false; }
        else if (opt.id == "quality") { s.quality = (opt.current == 0) ? "low" : "high"; DrawUtils::set_render_quality(s.quality); }
        else if (opt.id == "discord_rpc") s.discord_rpc = opt.value;
        else if (opt.id == "master_volume") { s.master_volume = opt.slider_value; SoundManager::set_master_volume(opt.slider_value); }
        else if (opt.id == "sfx_volume") { s.sfx_volume = opt.slider_value; SoundManager::set_sfx_volume(opt.slider_value); }
        else if (opt.id == "music_volume") { s.music_volume = opt.slider_value; SoundManager::set_music_volume(opt.slider_value); }
    }
    SettingsManager::save();
}

void OptionsState::draw(Engine& eng)
{
    using namespace GameSettings;
    eng.clear(5, 5, 12, 255);

    int grid_size = 80;
    int off_x = (int)std::fmod(bg_scroll, (double)grid_size);
    int off_y = (int)std::fmod(bg_scroll * 0.4, (double)grid_size);

    for (int y = off_y; y < SCREEN_HEIGHT; y += grid_size)
    {
        int a = (int)(12 + 8 * std::sin(timer * 0.5 + y * 0.01));
        eng.line(0, y, SCREEN_WIDTH, y, 90, 130, 255, a);
    }
    for (int x = off_x; x < SCREEN_WIDTH; x += grid_size)
    {
        int a = (int)(12 + 8 * std::cos(timer * 0.5 + x * 0.01));
        eng.line(x, 0, x, SCREEN_HEIGHT, 90, 130, 255, a);
    }

    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.006f);

    int panel_x = 40, panel_y = 30;
    int panel_w = SCREEN_WIDTH - 80, panel_h = SCREEN_HEIGHT - 70;
    eng.draw_rect(panel_x, panel_y, panel_w, panel_h, 20, 25, 45, 180);
    double border_pulse = 0.5 + 0.5 * std::sin(timer * 1.2);
    int border_a = (int)(30 + 15 * border_pulse);
    eng.draw_rect(panel_x - 2, panel_y - 2, panel_w + 4, panel_h + 4, 100, 180, 255, border_a, false);

    DrawUtils::text(eng, Localization::get_text("options"), 70, 56, 42, 255, 255, 255);
    DrawUtils::text(eng, "SYSTEM CONFIGURATION", 72, 98, 12, 100, 180, 255, 180);

    int hl_y = (int)highlight_y;
    double hl_pulse = 0.8 + 0.2 * std::sin(timer * 5.0);
    eng.draw_rect(65, hl_y, panel_w - 50, 46, 100, 180, 255, (int)(35 * hl_pulse), false);
    eng.draw_rect(65, hl_y, 4, 46, 100, 180, 255, 255);

    for (int i = 0; i < max_options; ++i)
    {
        auto& opt = options[i];
        int y = 150 + i * 50 - (int)scroll_offset;

        if (y < 130 || y > SCREEN_HEIGHT - 80) continue;

        double glow = item_glows[i];

        int tc = (int)lerp_f(140, 255, (float)glow);

        DrawUtils::text(eng, opt.label, 80, y, 24, tc, tc, tc + (int)(20 * glow));

        if (opt.type == OptionItem::Toggle)
        {
            std::string val_text = "< " + opt.values[opt.current] + " >";
            int val_r = 100, val_g = 220, val_b = 255;
            if (i + 1 != selected) { val_r = 70; val_g = 150; val_b = 180; }
            DrawUtils::text(eng, val_text, 500, y + 2, 22, val_r, val_g, val_b);
        }
        else if (opt.type == OptionItem::Bool)
        {
            int val_r = opt.value ? 100 : 255;
            int val_g = opt.value ? 255 : 100;
            int val_b = opt.value ? 150 : 120;
            if (i + 1 != selected) { val_r = (int)(val_r * 0.6); val_g = (int)(val_g * 0.6); val_b = (int)(val_b * 0.6); }
            std::string val_text = opt.value ? Localization::get_text("on") : Localization::get_text("off");
            DrawUtils::text(eng, val_text, 500, y + 2, 22, val_r, val_g, val_b);
        }
        else if (opt.type == OptionItem::Slider)
        {
            int bar_x = 500;
            int bar_w = 200;
            int bar_h = 10;
            int bar_y = y + 12;

            eng.draw_rect(bar_x, bar_y, bar_w, bar_h, 40, 50, 70);
            int fill_w = (int)((float)bar_w * (float)opt.slider_value / (float)opt.slider_max);
            int sel_r = (i + 1 == selected) ? 140 : 100;
            int sel_g = (i + 1 == selected) ? 230 : 180;
            int sel_b = (i + 1 == selected) ? 255 : 220;
            eng.draw_rect(bar_x, bar_y, fill_w, bar_h, sel_r, sel_g, sel_b);

            int knob_x = bar_x + fill_w - 4;
            eng.draw_rect(knob_x, bar_y - 3, 8, 16, 255, 255, 255);

            char vol_buf[8];
            std::snprintf(vol_buf, sizeof(vol_buf), "%d%%", opt.slider_value);
            DrawUtils::text(eng, vol_buf, bar_x + bar_w + 15, y + 2, 20, tc, tc, tc + (int)(20 * glow));
        }
    }

    DrawUtils::text(eng, Localization::get_text("help_input"), 70, SCREEN_HEIGHT - 55, 14, 90, 110, 140, 180);

    if (vsync_changed)
    {
        std::string notice = (lang == "pt") ? Localization::get_text("vsync_restart_pt") : Localization::get_text("vsync_restart_en");
        DrawUtils::text(eng, notice, SCREEN_WIDTH / 2, SCREEN_HEIGHT - 30, 13, 255, 200, 80, 200, true);
    }

    DrawUtils::scanlines(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 14);
}

} // namespace fnwf
