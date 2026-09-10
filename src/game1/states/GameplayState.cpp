#include "game1/states/GameplayState.hpp"
#include "core/DrawUtils.hpp"
#include "core/Localization.hpp"
#include "core/Rng.hpp"
#include "core/SoundManager.hpp"
#include "game1/GameSettings.hpp"
#include <algorithm>
#include <cmath>

namespace fnwf {

GameplayState::GameplayState(Engine& eng, int night_, const std::vector<int>* custom_ai_)
    : m_eng(eng), night(night_), custom_ai(custom_ai_), office(eng), cameras(eng), doors(), power(),
      animatronics(night_, custom_ai_), jumpscare() {
    secret_mode = animatronics.is_secret_mode();
    night_duration = GameSettings::HOUR_DURATION * 6;
    SoundManager::set_engine(&eng);
}

auto GameplayState::is_done() const -> bool {
    return !m_result.empty() && fade_alpha >= 255;
}

auto GameplayState::update(double dt) -> void {
    fx_timer += dt;

    if (fading_in) {
        fade_alpha = std::max(0, fade_alpha - (int)(fade_speed * dt));
        if (fade_alpha <= 0) {
            fading_in = false;
            if (!ambient_started) {
                SoundManager::play_ambient_loop();
                ambient_started = true;
            }
        }
        return;
    }
    if (fading_out) {
        fade_alpha = std::min(255, fade_alpha + (int)(fade_speed * dt));
        return;
    }
    if (jumpscare.active) {
        jumpscare.update(dt);
        if (jumpscare.is_done()) {
            m_result = "jumpscare";
            fading_out = true;
            fade_alpha = 0;
            SoundManager::stop_all_sounds();
        }
        return;
    }
    if (power.is_dead) {
        update_power_out(dt);
        return;
    }

    time_elapsed += dt;
    int new_hour = 12 + (int)((time_elapsed / night_duration) * 6);
    if (new_hour > 12)
        new_hour %= 12;
    if (new_hour == 0)
        new_hour = 12;
    if (new_hour != prev_hour) {
        prev_hour = new_hour;
        SoundManager::play_sound("clock");
    }
    current_hour = new_hour;

    if (time_elapsed >= night_duration) {
        if (!_win_triggered) {
            _win_triggered = true;
            SoundManager::stop_all_sounds();
            SoundManager::play_sound("win");
            m_result = "win";
            fading_out = true;
            fade_alpha = 0;
        }
        return;
    }

    auto [mouse_x, mouse_y] = m_eng.mouse_pos();
    if (!cameras.is_animating)
        cameras.check_mouse_trigger(mouse_x, mouse_y);

    if (!cameras.is_visible())
        office.update(mouse_x, dt);
    cameras.update(dt);
    doors.update(dt);
    mask_on = cameras.is_mask_open || cameras.is_mask_animating;
    power.update(dt, doors.get_power_usage(), cameras.is_open);

    const std::string* cam_looking = cameras.is_fully_open() ? &cameras.current_cam : nullptr;
    animatronics.update(dt, cam_looking, doors.left_closed, doors.right_closed, mask_on);

    if (mask_on) {
        oxygen = std::max(0.0, oxygen - oxygen_depletion_rate * dt);
        if (oxygen <= 0) {
            cameras.force_remove_mask();
            mask_on = cameras.is_mask_open || cameras.is_mask_animating;
        }
    } else
        oxygen = std::min(max_oxygen, oxygen + oxygen_recovery_rate * dt);

    if (animatronics.check_alice_just_left()) {
        is_blackout = true;
        blackout_alpha = 255.0;
        blackout_timer = 0.5;
    }

    if (is_blackout) {
        if (blackout_timer > 0)
            blackout_timer -= dt;
        else {
            blackout_alpha = std::max(0.0, blackout_alpha - 250.0 * dt);
            if (blackout_alpha <= 0)
                is_blackout = false;
        }
    }

    auto attacker = animatronics.get_attacker();
    if (!attacker.empty()) {
        SoundManager::stop_all_sounds();
        SoundManager::play_sound("jumpscare");
        jumpscare.trigger(attacker);
    }

    double danger = 0.0;
    if (!animatronics.get_at_left_door().empty())
        danger += 0.22;
    if (!animatronics.get_at_right_door().empty())
        danger += 0.22;
    if (!animatronics.get_at_vent().empty())
        danger += 0.18;
    if (!animatronics.get_in_office().empty())
        danger += 0.35;
    if (power.power <= 25)
        danger += 0.15;
    if (oxygen <= 35)
        danger += 0.1;
    danger_level = std::max(0.0, std::min(1.0, danger));
}

auto GameplayState::update_power_out(double dt) -> void {
    if (!_power_out_snd) {
        SoundManager::stop_ambient();
        SoundManager::play_sound("power_out");
        _power_out_snd = true;
    }
    power_out_timer += dt;

    if (power_out_phase == 0) {
        doors.left_closed = false;
        doors.right_closed = false;
        doors.left_light = false;
        doors.right_light = false;
        office.vent_light = false;
        cameras.is_open = false;
        mask_on = false;
        if (power_out_timer > 3.0) {
            power_out_phase = 1;
            power_out_delay = 0.0;
        }
    } else if (power_out_phase == 1) {
        power_out_delay += dt;
        if (power_out_delay > 5.0 + Rng::float_range(0.0f, 10.0f)) {
            if (time_elapsed >= night_duration) {
                m_result = "win";
                fading_out = true;
            } else
                power_out_phase = 2;
        }
    } else if (power_out_phase == 2) {
        jumpscare.trigger("cedro");
    }
}

auto GameplayState::handle_event(const Event& ev) -> void {
    if (jumpscare.active || power.is_dead || fading_in || fading_out)
        return;

    if (ev.type == EventType::MouseButtonDown) {
        int mx = ev.x, my = ev.y;
        if (cameras.check_toggle_click(mx, my)) {
            SoundManager::play_sound("camera");
            return;
        }
        if (cameras.check_mask_toggle_click(mx, my)) {
            SoundManager::play_sound("camera");
            return;
        }
        if (cameras.is_fully_open()) {
            if (cameras.handle_click(mx, my))
                SoundManager::play_sound("camera");
            return;
        }
        if (!cameras.is_visible()) {
            auto action = doors.handle_click(mx, my);
            if (!action.empty()) {
                SoundManager::play_sound(action);
                if (action == "light" &&
                    ((doors.left_light && !animatronics.get_at_left_door().empty()) ||
                     (doors.right_light && !animatronics.get_at_right_door().empty())))
                    SoundManager::play_sound("animatronic_door");
                return;
            }
        }
    }

    if (ev.type == EventType::KeyDown) {
        int key = ev.key;
        if (!cameras.is_visible()) {
            if (key == 'q') {
                doors.left_closed = !doors.left_closed;
                SoundManager::play_sound("door");
            } else if (key == 'e') {
                doors.right_closed = !doors.right_closed;
                SoundManager::play_sound("door");
            } else if (key == 'a') {
                doors.left_light = !doors.left_light;
                SoundManager::play_sound("light");
                if (doors.left_light && !animatronics.get_at_left_door().empty())
                    SoundManager::play_sound("animatronic_door");
            } else if (key == 'd') {
                doors.right_light = !doors.right_light;
                SoundManager::play_sound("light");
                if (doors.right_light && !animatronics.get_at_right_door().empty())
                    SoundManager::play_sound("animatronic_door");
            } else if (key == 'l') {
                office.vent_light = !office.vent_light;
                SoundManager::play_sound("light");
                if (office.vent_light && !animatronics.get_at_vent().empty())
                    SoundManager::play_sound("animatronic_door");
            }
        }

        if (cameras.is_fully_open()) {
            auto cams_map = std::unordered_map<int, std::string>{{'1', "1A"},
                                                                 {'2', "1B"},
                                                                 {'3', "1C"},
                                                                 {'4', "2A"},
                                                                 {'5', "2B"},
                                                                 {'6', "3"},
                                                                 {'7', "4A"},
                                                                 {'8', "4B"},
                                                                 {'9', "5"}};
            auto it = cams_map.find(key);
            if (it != cams_map.end()) {
                cameras.switch_camera(it->second);
                SoundManager::play_sound("camera");
            }
        }

        if (key == ' ' && !cameras.is_open)
            cameras.toggle_mask();
        if (key == 27) {
            SoundManager::stop_all_sounds();
            m_result = "menu";
            fading_out = true;
            fade_alpha = 0;
        }
        if (key == 'p')
            time_elapsed = night_duration;
    }
}

auto GameplayState::draw(Engine& eng) -> void {
    using namespace GameSettings;
    bool high_fx = (DrawUtils::get_render_quality() == "high");

    if (jumpscare.active) {
        jumpscare.draw(eng);
        draw_fade(eng);
        return;
    }
    if (power.is_dead) {
        draw_power_out(eng);
        draw_fade(eng);
        return;
    }

    office.draw(eng,
                doors.left_anim,
                doors.right_anim,
                doors.left_light,
                doors.right_light,
                animatronics.get_at_left_door(),
                animatronics.get_at_right_door(),
                animatronics.get_at_vent(),
                animatronics.get_in_office());

    if (!cameras.is_visible())
        doors.draw_buttons(eng, false);
    cameras.draw(eng, animatronics.get_positions(), animatronics.get_foxy_stage());

    if (high_fx && !cameras.is_visible()) {
        double light_pulse = 0.55 + 0.45 * std::sin(fx_timer * 8.0);
        if (doors.left_light)
            for (int i = 1; i <= 5; ++i) {
                int w = 100 + i * 58;
                int a = (int)((50 - i * 7) * light_pulse);
                eng.draw_rect(0, 0, w, SCREEN_HEIGHT, 205, 210, 235, a);
            }
        if (doors.right_light)
            for (int i = 1; i <= 5; ++i) {
                int w = 100 + i * 58;
                int a = (int)((50 - i * 7) * light_pulse);
                eng.draw_rect(SCREEN_WIDTH - w, 0, w, SCREEN_HEIGHT, 205, 210, 235, a);
            }
        if (office.vent_light)
            for (int i = 1; i <= 4; ++i) {
                int h = 70 + i * 30;
                int a = 38 - i * 6;
                eng.draw_rect(0, 0, SCREEN_WIDTH, h, 185, 210, 230, a);
            }
    }

    if (secret_mode) {
        double pulse = 0.5 + 0.5 * std::sin(time_elapsed * 2.4);
        int alpha = (int)(36 + 24 * pulse);
        eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 120, 8, 8, alpha);
    }

    DrawUtils::tone_overlay(eng, 8, 18, 32, high_fx ? 12 : 8);
    if (high_fx)
        DrawUtils::vignette(eng, 0.20 + danger_level * 0.35, 0, 0, 0);

    if (high_fx) {
        double lp = 0.6 + 0.4 * std::sin(time_elapsed * 1.2);
        int cx = SCREEN_WIDTH / 2, cy = (int)(SCREEN_HEIGHT * 0.64);
        eng.draw_rect(cx - 320, cy - 150, 640, 300, 220, 200, 150, (int)(7 + 6 * lp));
        eng.draw_rect(cx - 140, cy - 78, 280, 156, 245, 235, 200, (int)(4 + 3 * lp));
    }
    eng.draw_rect(0, 0, 64, SCREEN_HEIGHT, 30, 45, 90, 22);
    eng.draw_rect(SCREEN_WIDTH - 64, 0, 64, SCREEN_HEIGHT, 30, 45, 90, 22);

    draw_hud(eng);

    if (!is_blackout || blackout_alpha < 150) {
        float noise =
            (high_fx ? 0.008f : 0.003f) + (float)(danger_level * (high_fx ? 0.02 : 0.008));
        int scan = (int)((high_fx ? 10 : 6) + danger_level * (high_fx ? 16 : 8));
        DrawUtils::apply_camera_effect(eng, noise, scan, 0);
    }

    if ((!animatronics.get_at_left_door().empty() || !animatronics.get_at_right_door().empty() ||
         !animatronics.get_at_vent().empty() || !animatronics.get_in_office().empty()) &&
        !is_blackout) {
        if (Rng::probability(0.08f))
            eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0, 0, 0, 50 + Rng::int_range(0, 130));
    }

    if (blackout_alpha > 0)
        eng.draw_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, 0, 0, 0, (int)blackout_alpha);

    draw_fade(eng);
}

auto GameplayState::draw_hud(Engine& eng) -> void {
    using namespace GameSettings;
    std::string suffix = Localization::get_text("am");
    std::string hour_str = std::to_string(current_hour) + " " + suffix;
    DrawUtils::text(eng, hour_str, SCREEN_WIDTH - 80, 20, 28, 255, 255, 255, 255, true);

    std::string night_label = (night == 7)
                                  ? Localization::get_text("custom_night")
                                  : Localization::get_text("night") + " " + std::to_string(night);
    DrawUtils::text(eng, night_label, SCREEN_WIDTH - 80, 52, 18, 180, 180, 180, 255, true);
    DrawUtils::text(eng,
                    "\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2\x94\x81\xe2"
                    "\x94\x81\xe2\x94\x81",
                    SCREEN_WIDTH - 80,
                    74,
                    10,
                    50,
                    50,
                    55,
                    255,
                    true);

    power.draw(eng);

    if (mask_on || oxygen < max_oxygen) {
        int bar_w = 200, bar_h = 12, x = 20, y = 100;
        eng.draw_rect(x, y, bar_w, bar_h, 40, 40, 45, 255);
        int cr = (oxygen >= 30) ? 100 : 255, cg = (oxygen >= 30) ? 200 : 100,
            cb = (oxygen >= 30) ? 255 : 100;
        eng.draw_rect(x, y, (int)(bar_w * (oxygen / max_oxygen)), bar_h, cr, cg, cb, 255);
        eng.draw_rect(x, y, bar_w, bar_h, 80, 80, 85, 255, false);
        DrawUtils::text(eng,
                        Localization::get_text("oxygen") + ": " + std::to_string((int)oxygen) + "%",
                        x,
                        y - 18,
                        14,
                        255,
                        255,
                        255);
    }
}

auto GameplayState::draw_power_out(Engine& eng) -> void {
    using namespace GameSettings;
    eng.clear(0, 0, 0, 255);
    if (power_out_phase >= 1) {
        if ((int)(m_eng.ticks() / 1000.0 * 2) % 3 != 0) {
            DrawUtils::animatronic_face(eng, "cedro", 50, SCREEN_HEIGHT / 2 - 120, 200, 250);
            eng.circle(120, SCREEN_HEIGHT / 2 - 20, 8, 255, 255, 255, 255);
            eng.circle(180, SCREEN_HEIGHT / 2 - 20, 8, 255, 255, 255, 255);
            eng.circle(120, SCREEN_HEIGHT / 2 - 20, 4, 30, 30, 200, 255);
            eng.circle(180, SCREEN_HEIGHT / 2 - 20, 4, 30, 30, 200, 255);
            DrawUtils::text(eng,
                            "\xe2\x99\xaa \xe2\x99\xab \xe2\x99\xaa",
                            150,
                            SCREEN_HEIGHT / 2 + 140,
                            20,
                            60,
                            60,
                            100,
                            255,
                            true);
        }
    }
}

auto GameplayState::draw_fade(Engine& eng) -> void {
    if (fade_alpha > 0)
        eng.draw_rect(
            0, 0, GameSettings::SCREEN_WIDTH, GameSettings::SCREEN_HEIGHT, 0, 0, 0, fade_alpha);
}

}  // namespace fnwf
