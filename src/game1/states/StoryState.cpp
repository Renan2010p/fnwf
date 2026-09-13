#include "game1/states/StoryState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <sstream>

namespace fnwf {

StoryState::StoryState(int night_, Engine& eng) : m_eng(eng), night(night_) {
    DrawUtils::load_sprite(eng, "cedro");
    cedro_avatar = *DrawUtils::get_sprite("cedro");
    DrawUtils::load_sprite(eng, "renan");
    renan_avatar = *DrawUtils::get_sprite("renan");
    DrawUtils::load_sprite(eng, "mafia");
    unknown_avatar = *DrawUtils::get_sprite("mafia");
    build_messages();
}

auto StoryState::build_messages() -> void {
    messages.clear();
    auto m = [&](const std::string& k) -> std::string {
        std::string key = "story_n" + std::to_string(night) + "_" + k;
        return Localization::get_text(key);
    };
    auto has_msg = [&](const std::string& k) -> bool {
        std::string key = "story_n" + std::to_string(night) + "_" + k;
        return Localization::get_text(key) != key;
    };
    auto row = [&](const std::string& user,
                   const std::string& avatar,
                   std::array<int, 3> color,
                   const std::string& key) -> Message {
        return {"", user, avatar, color, m(key)};
    };

    if (night == 1) {
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m0"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m1"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m2"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m3"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m4"));
        messages.push_back({"title", "", {}, {}, Localization::get_text("night") + " 1"});
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m5"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m6"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m7"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m8"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m9"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m10"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m11"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m12"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m13"));
    } else if (night >= 2 && night <= 5) {
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m0"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m1"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m2"));
        messages.push_back(
            {"title", "", {}, {}, Localization::get_text("night") + " " + std::to_string(night)});
        int i = 3;
        while (has_msg("m" + std::to_string(i))) {
            std::string speaker = ((i % 2) == 0) ? "Cientista" : "Cedro";
            std::string avatar = (speaker == "Cedro") ? "cedro" : "renan";
            auto color = (speaker == "Cedro") ? std::array<int, 3>{140, 110, 80}
                                              : std::array<int, 3>{100, 180, 255};
            messages.push_back(row(speaker, avatar, color, "m" + std::to_string(i)));
            ++i;
        }
    } else if (night == 6) {
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m0"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m1"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m2"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m3"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m4"));
        messages.push_back({"title", "", {}, {}, Localization::get_text("night") + " 6"});
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m5"));
    } else if (night == 7) {
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m0"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m1"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m2"));
        messages.push_back({"title", "", {}, {}, Localization::get_text("custom_night")});
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m3"));
        messages.push_back(row("Cientista", "renan", {100, 180, 255}, "m4"));
        messages.push_back(row("Cedro", "cedro", {140, 110, 80}, "m5"));
    } else {
        messages.push_back(
            {"title", "", {}, {}, Localization::get_text("night") + " " + std::to_string(night)});
    }
}

auto StoryState::wrap_text(const std::string& text, int max_width, int font_size)
    -> std::vector<std::string> {
    std::vector<std::string> words;
    std::istringstream iss(text);
    std::string word;
    while (iss >> word)
        words.push_back(word);

    std::vector<std::string> lines;
    std::string current;
    for (auto& w : words) {
        std::string test = current.empty() ? w : current + " " + w;
        auto sz = m_eng.font_text_size(test, font_size);
        int tw = sz ? (*sz)[0] : (int)test.size() * 10;
        if (tw <= max_width)
            current = test;
        else {
            if (!current.empty()) {
                lines.push_back(current);
                current = w;
            } else {
                lines.push_back(w);
                current.clear();
            }
        }
    }
    if (!current.empty())
        lines.push_back(current);
    return lines;
}

auto StoryState::update_scroll_target() -> void {
    int cwl = GameSettings::SCREEN_WIDTH - 240 - 100;
    int th = 15;
    std::string prev;
    for (int i = 0; i < visible_messages && i < (int)messages.size(); ++i) {
        auto& msg = messages[i];
        if (msg.type == "title") {
            th += 50;
            prev.clear();
        } else {
            auto lines = wrap_text(msg.text, cwl, 14);
            if (prev == msg.user)
                th += 24 * (int)lines.size();
            else
                th += (prev.empty() ? 0 : 8) + 22 + 24 * (int)lines.size();
            prev = msg.user;
        }
    }
    int va = GameSettings::SCREEN_HEIGHT - 48 - 80;
    if (th > va)
        target_scroll = th - va;
}

auto StoryState::update(double dt) -> void {
    timer += dt;
    if (phase == 0) {
        fade_alpha = std::max(0, fade_alpha - (int)(250 * dt));
        if (fade_alpha <= 0)
            phase = 1;
    } else if (phase == 1 && visible_messages == 0) {
        visible_messages = 1;
        update_scroll_target();
    } else if (phase == 2) {
        fade_alpha = std::min(255, fade_alpha + (int)(200 * dt));
        if (fade_alpha >= 255)
            done = true;
    }
    scroll_y = scroll_y + (target_scroll - scroll_y) * 6.0 * dt;
}

auto StoryState::handle_event(const Event& ev) -> void {
    if (ev.type == EventType::KeyDown || ev.type == EventType::MouseButtonDown) {
        if (ev.type == EventType::KeyDown && ev.key != 13 && ev.key != 32)
            return;
        if (phase == 0) {
            phase = 1;
            fade_alpha = 0;
        } else if (phase == 1) {
            if (visible_messages < (int)messages.size()) {
                visible_messages++;
                update_scroll_target();
                SoundManager::play_sound("notification");
            } else {
                phase = 2;
                fade_alpha = 0;
            }
        }
    }
}

auto StoryState::draw(Engine& eng) -> void {
    using namespace GameSettings;
    eng.clear(54, 57, 63, 255);
    if (phase >= 1)
        draw_discord_ui(eng);
    DrawUtils::static_noise(eng, 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0.005f);

    if (phase == 1) {
        bool blink = ((int)(timer * 2) % 2) == 0;
        if (blink) {
            std::string txt = (visible_messages < (int)messages.size())
                                  ? Localization::get_text("story_skip")
                                  : Localization::get_text("story_start_night");
            DrawUtils::text(
                eng, txt, SCREEN_WIDTH / 2, SCREEN_HEIGHT - 20, 12, 130, 130, 140, 255, true);
        }
    }
    if (fade_alpha > 0)
        eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 54, 57, 63, fade_alpha);
}

auto StoryState::draw_discord_ui(Engine& eng) -> void {
    using namespace GameSettings;
    int sw = 240;
    eng.draw_rect(0, 0, sw, SCREEN_HEIGHT, 47, 49, 54, 255);
    eng.draw_rect(0, 0, sw, 48, 40, 43, 48, 255);
    DrawUtils::text(eng, Localization::get_text("discord_server"), 15, 14, 14, 220, 220, 220);
    eng.line(0, 48, sw, 48, 30, 33, 36, 255);

    auto chans = {Localization::get_text("chan_general"),
                  Localization::get_text("chan_announcements"),
                  Localization::get_text("chan_security"),
                  Localization::get_text("chan_cameras")};
    int idx = 0;
    for (auto& ch : chans) {
        ++idx;
        int y = 65 + (idx - 1) * 32;
        int r = (idx == 3) ? 220 : 130, g = (idx == 3) ? 220 : 130, b = (idx == 3) ? 220 : 140;
        if (idx == 3)
            eng.draw_rect(8, y - 4, sw - 16, 28, 60, 63, 69, 255);
        DrawUtils::text(eng, ch, 18, y, 13, r, g, b);
    }

    int cx = sw, cw = SCREEN_WIDTH - sw;
    eng.draw_rect(cx, 0, cw, 48, 54, 57, 63, 255);
    DrawUtils::text(eng, Localization::get_text("discord_channel"), cx + 18, 14, 15, 220, 220, 220);
    eng.line(cx, 48, SCREEN_WIDTH, 48, 40, 43, 48, 255);

    int my = 63 - (int)scroll_y;
    std::string prev_user;
    for (int i = 0; i < visible_messages && i < (int)messages.size(); ++i) {
        auto& msg = messages[i];
        if (msg.type == "title") {
            eng.line(cx + 20, my + 10, SCREEN_WIDTH - 20, my + 10, 72, 75, 81, 255);
            DrawUtils::text(eng, msg.text, cx + cw / 2, my + 10, 12, 130, 130, 140, 255, true);
            my += 50;
            prev_user.clear();
        } else {
            auto lines = wrap_text(msg.text, cw - 100, 14);
            if (prev_user == msg.user) {
                for (auto& line : lines) {
                    DrawUtils::text(eng, line, cx + 75, my, 14, 220, 220, 220);
                    my += 24;
                }
            } else {
                my += prev_user.empty() ? 0 : 8;
                int av_size = 40;
                eng.circle(
                    cx + 20 + av_size / 2, my + av_size / 2, av_size / 2, 80, 80, 90, 255, true);
                auto av = (msg.avatar == "cedro") ? cedro_avatar : renan_avatar;
                eng.draw_texture(av, cx + 20, my, av_size, av_size);
                DrawUtils::text(
                    eng, msg.user, cx + 75, my, 14, msg.color[0], msg.color[1], msg.color[2]);
                my += 22;
                for (auto& line : lines) {
                    DrawUtils::text(eng, line, cx + 75, my, 14, 220, 220, 220);
                    my += 24;
                }
            }
            prev_user = msg.user;
        }
    }

    int iy = SCREEN_HEIGHT - 65;
    eng.draw_rect(cx + 16, iy, cw - 32, 44, 64, 68, 75, 255);
    DrawUtils::text(
        eng, Localization::get_text("discord_input"), cx + 30, iy + 13, 13, 100, 100, 110);
}

}  // namespace fnwf
