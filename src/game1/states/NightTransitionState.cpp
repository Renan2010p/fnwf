#include "game1/states/NightTransitionState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>

namespace fnwf {

NightTransitionState::NightTransitionState(int night_, Engine& eng) : m_eng(eng), night(night_)
{
    DrawUtils::load_sprite(eng, "cedro"); cedro_avatar = *DrawUtils::get_sprite("cedro");
    DrawUtils::load_sprite(eng, "renan"); renan_avatar = *DrawUtils::get_sprite("renan");

    struct RawMsg { std::string user; std::string text; };
    std::vector<RawMsg> raw;

    if (night == 2)
    {
        raw = {{Localization::get_text("discord_server"), Localization::get_text("transition_n2_m0")},
               {Localization::get_text("discord_server"), Localization::get_text("transition_n2_m1")},
               {Localization::get_text("discord_server"), Localization::get_text("transition_n2_m2")},
               {"Renan", Localization::get_text("transition_n2_m3")},
               {Localization::get_text("discord_server"), Localization::get_text("transition_n2_m4")},
               {Localization::get_text("discord_server"), Localization::get_text("transition_n2_m5")}};
    }
    else if (night == 3)
    {
        raw = {{Localization::get_text("discord_server"), Localization::get_text("transition_n3_m0")},
               {Localization::get_text("discord_server"), Localization::get_text("transition_n3_m1")},
               {Localization::get_text("discord_server"), Localization::get_text("transition_n3_m2")},
               {"Renan", Localization::get_text("transition_n3_m3")},
               {Localization::get_text("discord_server"), Localization::get_text("transition_n3_m4")}};
    }

    for (auto& r : raw)
    {
        Message m;
        m.user = r.user;
        m.avatar = (r.user != "Renan") ? "cedro" : "renan";
        m.color = (r.user != "Renan") ? std::array<int,3>{140,110,80} : std::array<int,3>{100,180,255};
        m.text = r.text;
        messages.push_back(m);
    }
}

void NightTransitionState::update_scroll()
{
    int th = 15;
    std::string prev;
    for (int i = 0; i < visible_messages && i < (int)messages.size(); ++i)
    {
        auto& m = messages[i];
        if (prev == m.user) th += 24;
        else th += prev.empty() ? 0 : 8, th += 48;
        prev = m.user;
    }
    int va = GameSettings::SCREEN_HEIGHT - 128;
    if (th > va) target_scroll = th - va;
}

void NightTransitionState::advance()
{
    if (phase == 0) { phase = 1; fade_alpha = 0; }
    else if (phase == 1)
    {
        if (visible_messages < (int)messages.size()) { visible_messages++; update_scroll(); SoundManager::play_sound("notification"); }
        else { phase = 2; fade_alpha = 0; }
    }
}

void NightTransitionState::update(double dt)
{
    timer += dt;
    if (phase == 0) { fade_alpha = std::max(0, fade_alpha - (int)(250 * dt)); if (fade_alpha <= 0) { phase = 1; SoundManager::play_sound("notification"); } }
    else if (phase == 1 && visible_messages == 0) { visible_messages = 1; update_scroll(); }
    else if (phase == 2) { fade_alpha = std::min(255, fade_alpha + (int)(250 * dt)); if (fade_alpha >= 255) done = true; }
    scroll_y = scroll_y + (target_scroll - scroll_y) * 6.0 * dt;
}

void NightTransitionState::handle_event(const Event& ev)
{
    if (ev.type == EventType::KeyDown && (ev.key == 13 || ev.key == 32)) advance();
    else if (ev.type == EventType::MouseButtonDown) advance();
}

void NightTransitionState::draw(Engine& eng)
{
    using namespace GameSettings;
    eng.clear(54, 57, 63, 255);
    if (phase >= 1) draw_discord(eng);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.005f);

    if (phase == 1)
    {
        bool blink = ((int)(timer * 2) % 2) == 0;
        if (blink)
        {
            std::string txt = (visible_messages < (int)messages.size()) ?
                Localization::get_text("story_skip") :
                Localization::get_text("story_start_night") + " " + std::to_string(night);
            DrawUtils::text(eng, txt, SCREEN_WIDTH / 2, SCREEN_HEIGHT - 20, 11, 130, 130, 140, 255, true);
        }
    }
    if (fade_alpha > 0) eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 54, 57, 63, fade_alpha);
}

void NightTransitionState::draw_discord(Engine& eng)
{
    using namespace GameSettings;
    int sw = 240;
    eng.draw_rect(0, 0, sw, SCREEN_HEIGHT, 47, 49, 54, 255);
    eng.draw_rect(0, 0, sw, 48, 40, 43, 48, 255);
    DrawUtils::text(eng, Localization::get_text("discord_server"), 15, 14, 14, 220, 220, 220);
    eng.line(0, 48, sw, 48, 30, 33, 36, 255);

    int cx = sw, cw = SCREEN_WIDTH - sw;
    eng.draw_rect(cx, 0, cw, 48, 54, 57, 63, 255);
    DrawUtils::text(eng, Localization::get_text("chan_security"), cx + 18, 14, 15, 220, 220, 220);

    int my = 63 - (int)scroll_y;
    DrawUtils::text(eng, "--- " + Localization::get_text("night") + " " + std::to_string(night) + " ---", cx + cw / 2, my, 12, 130, 130, 140, 255, true);
    my += 30;

    std::string prev_user;
    for (int i = 0; i < visible_messages && i < (int)messages.size(); ++i)
    {
        auto& m = messages[i];
        if (prev_user == m.user)
        {
            DrawUtils::text(eng, m.text, cx + 75, my, 14, 220, 220, 220);
            my += 24;
        }
        else
        {
            my += prev_user.empty() ? 0 : 8;
            eng.circle(cx + 40, my + 20, 20, 80, 80, 90, 255, true);
            auto av = (m.avatar == "cedro") ? cedro_avatar : renan_avatar;
            eng.draw_texture(av, cx + 20, my, 40, 40);
            DrawUtils::text(eng, m.user, cx + 75, my, 14, m.color[0], m.color[1], m.color[2]);
            my += 22;
            DrawUtils::text(eng, m.text, cx + 75, my, 14, 220, 220, 220);
            my += 24;
        }
        prev_user = m.user;
    }

    eng.draw_rect(cx + 16, SCREEN_HEIGHT - 65, cw - 32, 44, 64, 68, 75, 255);
    DrawUtils::text(eng, Localization::get_text("discord_input"), cx + 30, SCREEN_HEIGHT - 52, 13, 100, 100, 110);
}

} // namespace fnwf
