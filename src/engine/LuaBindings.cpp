// fnam -> fnwf: SDL2 (C++26) <-> Lua bridge. Keeps the same `Engine` Lua API
// the recovered game scripts expect.
#include "engine/Engine.hpp"

#include <lua.hpp>

#include <cstdint>
#include <cstdlib>
#include <string>

using fnwf::Engine;
using fnwf::Ev;
using fnwf::SoundHandle;
using fnwf::TextureHandle;

namespace
{

auto get_engine(lua_State* L, int idx) -> Engine*
{
    auto** ud = static_cast<Engine**>(lua_touserdata(L, idx));
    return (ud != nullptr) ? *ud : nullptr;
}

auto push_field(lua_State* L, const char* k, std::int64_t v) -> void
{
    lua_pushinteger(L, v);
    lua_setfield(L, -2, k);
}
auto push_field(lua_State* L, const char* k, const char* v) -> void
{
    lua_pushstring(L, v);
    lua_setfield(L, -2, k);
}
auto clamp8(double v) -> std::uint8_t
{
    return v < 0 ? 0 : (v > 255 ? 255 : static_cast<std::uint8_t>(v));
}
auto opt_int(lua_State* L, int idx, std::int64_t def) -> std::int64_t
{
    if (lua_isnoneornil(L, idx)) { return def; }
    return static_cast<std::int64_t>(luaL_checknumber(L, idx));
}
auto opt_u8(lua_State* L, int idx, std::uint8_t def) -> std::uint8_t
{
    if (lua_isnoneornil(L, idx)) { return def; }
    return clamp8(luaL_checknumber(L, idx));
}
auto opt_bool(lua_State* L, int idx, bool def) -> bool
{
    if (lua_isnoneornil(L, idx)) { return def; }
    return lua_toboolean(L, idx) != 0;
}
template <typename T>
auto check_handle(lua_State* L, int idx) -> T
{
    auto* p = static_cast<T*>(lua_touserdata(L, idx));
    return *p;
}

// ---- methods -------------------------------------------------------------
auto l_engine_clear(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1))
    {
        e->clear(clamp8(luaL_checknumber(L, 2)), clamp8(luaL_checknumber(L, 3)), clamp8(luaL_checknumber(L, 4)), opt_u8(L, 5, 255));
    }
    return 0;
}
auto l_engine_flip(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->present(); }
    return 0;
}
auto l_engine_stop(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->request_stop(); }
    return 0;
}
auto l_engine_keeps_running(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    lua_pushboolean(L, e ? e->keeps_running() : false);
    return 1;
}
auto l_engine_get_ticks(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    lua_pushnumber(L, e ? e->ticks() : 0.0);
    return 1;
}
auto l_engine_set_logical_size(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->set_logical_size(static_cast<std::uint32_t>(opt_int(L, 2, 0)), static_cast<std::uint32_t>(opt_int(L, 3, 0))); }
    return 0;
}
auto l_engine_set_resolution(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->set_resolution(static_cast<std::uint32_t>(opt_int(L, 2, 0)), static_cast<std::uint32_t>(opt_int(L, 3, 0))); }
    return 0;
}
auto l_engine_set_fullscreen(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->set_fullscreen(lua_toboolean(L, 2) != 0); }
    return 0;
}
auto l_engine_set_vsync(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->set_vsync(lua_toboolean(L, 2) != 0); }
    return 0;
}
auto l_engine_get_mouse_pos(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto [x, y] = e ? e->mouse_pos() : std::pair<std::int32_t, std::int32_t>{ 0, 0 };
    lua_pushinteger(L, x);
    lua_pushinteger(L, y);
    return 2;
}
auto l_engine_get_display_modes(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto modes = e ? e->get_display_modes() : std::vector<std::array<std::int32_t, 3>>{};
    lua_createtable(L, static_cast<int>(modes.size()), 0);
    int i = 0;
    for (auto& m : modes)
    {
        lua_createtable(L, 0, 3);
        push_field(L, "w", m[0]);
        push_field(L, "h", m[1]);
        push_field(L, "refresh", m[2]);
        lua_rawseti(L, -2, ++i);
    }
    return 1;
}
auto l_engine_load_texture(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto h = e ? e->load_texture(luaL_checkstring(L, 2)) : std::nullopt;
    if (!h.has_value()) { lua_pushnil(L); return 1; }
    *static_cast<TextureHandle*>(lua_newuserdatauv(L, sizeof(TextureHandle), 0)) = *h;
    return 1;
}
auto l_engine_create_target_texture(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto h = e ? e->create_target(static_cast<std::uint32_t>(opt_int(L, 2, 0)), static_cast<std::uint32_t>(opt_int(L, 3, 0))) : std::nullopt;
    if (!h.has_value()) { lua_pushnil(L); return 1; }
    *static_cast<TextureHandle*>(lua_newuserdatauv(L, sizeof(TextureHandle), 0)) = *h;
    return 1;
}
auto l_engine_set_render_target(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1))
    {
        if (lua_isnoneornil(L, 2)) { e->reset_render_target(); }
        else { e->set_render_target(check_handle<TextureHandle>(L, 2)); }
    }
    return 0;
}
auto l_engine_reset_render_target(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->reset_render_target(); }
    return 0;
}
auto l_engine_draw_texture(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1))
    {
        auto tex = check_handle<TextureHandle>(L, 2);
        auto dx = static_cast<std::int32_t>(opt_int(L, 3, 0));
        auto dy = static_cast<std::int32_t>(opt_int(L, 4, 0));
        auto [tw, th] = e->texture_size(tex.id);
        auto dw = static_cast<std::uint32_t>(opt_int(L, 5, tw));
        auto dh = static_cast<std::uint32_t>(opt_int(L, 6, th));
        std::optional<std::array<std::int32_t, 4>> src;
        std::optional<std::uint8_t> alpha;
        const int n = lua_gettop(L);
        if (n == 10)
        {
            src = std::array<std::int32_t, 4>{ static_cast<std::int32_t>(opt_int(L, 7, 0)), static_cast<std::int32_t>(opt_int(L, 8, 0)),
                                               static_cast<std::int32_t>(opt_int(L, 9, 0)), static_cast<std::int32_t>(opt_int(L, 10, 0)) };
        }
        else if (n >= 12) { alpha = opt_u8(L, 12, 255); }
        e->draw_texture(tex, dx, dy, dw, dh, src, alpha);
    }
    return 0;
}
auto l_engine_draw_rect(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1))
    {
        e->draw_rect(static_cast<std::int32_t>(opt_int(L, 2, 0)), static_cast<std::int32_t>(opt_int(L, 3, 0)),
                     static_cast<std::uint32_t>(opt_int(L, 4, 0)), static_cast<std::uint32_t>(opt_int(L, 5, 0)),
                     clamp8(luaL_checknumber(L, 6)), clamp8(luaL_checknumber(L, 7)), clamp8(luaL_checknumber(L, 8)),
                     opt_u8(L, 9, 255), opt_bool(L, 10, true));
    }
    return 0;
}
auto l_engine_draw_line(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1))
    {
        e->line(static_cast<std::int32_t>(opt_int(L, 2, 0)), static_cast<std::int32_t>(opt_int(L, 3, 0)),
                static_cast<std::int32_t>(opt_int(L, 4, 0)), static_cast<std::int32_t>(opt_int(L, 5, 0)),
                clamp8(luaL_checknumber(L, 6)), clamp8(luaL_checknumber(L, 7)), clamp8(luaL_checknumber(L, 8)), opt_u8(L, 9, 255));
    }
    return 0;
}
auto l_engine_draw_circle(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1))
    {
        e->circle(static_cast<std::int32_t>(opt_int(L, 2, 0)), static_cast<std::int32_t>(opt_int(L, 3, 0)),
                  static_cast<std::int32_t>(opt_int(L, 4, 0)), clamp8(luaL_checknumber(L, 5)),
                  clamp8(luaL_checknumber(L, 6)), clamp8(luaL_checknumber(L, 7)), opt_u8(L, 8, 255), opt_bool(L, 9, true));
    }
    return 0;
}
auto l_engine_draw_text(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1))
    {
        const std::string text = luaL_checkstring(L, 2);
        SDL_Color color{ clamp8(luaL_checknumber(L, 6)), clamp8(luaL_checknumber(L, 7)), clamp8(luaL_checknumber(L, 8)), 255 };
        e->draw_text(text, static_cast<std::int32_t>(opt_int(L, 3, 0)), static_cast<std::int32_t>(opt_int(L, 4, 0)),
                     color, opt_u8(L, 9, 255), opt_bool(L, 10, false), static_cast<std::uint32_t>(opt_int(L, 11, 0)));
    }
    return 0;
}
auto l_engine_get_text_size(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto sz = e ? e->font_text_size(luaL_checkstring(L, 2), static_cast<std::uint32_t>(opt_int(L, 4, 0))) : std::nullopt;
    if (sz.has_value()) { lua_pushinteger(L, (*sz)[0]); lua_pushinteger(L, (*sz)[1]); }
    else { lua_pushinteger(L, 0); lua_pushinteger(L, 0); }
    return 2;
}
auto l_engine_load_font(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    const std::int64_t idx = e ? e->load_font(luaL_checkstring(L, 2), static_cast<std::uint16_t>(opt_int(L, 3, 0))) : -1;
    lua_pushinteger(L, idx);
    return 1;
}
auto l_engine_load_sound(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto h = e ? e->load_sound(luaL_checkstring(L, 2)) : std::nullopt;
    if (!h.has_value()) { lua_pushnil(L); return 1; }
    *static_cast<SoundHandle*>(lua_newuserdatauv(L, sizeof(SoundHandle), 0)) = *h;
    return 1;
}
auto l_engine_play_sound(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto snd = check_handle<SoundHandle>(L, 2);
    const std::int32_t ch = e ? e->play_sound(snd, static_cast<std::int32_t>(opt_int(L, 3, 0)), static_cast<std::int32_t>(opt_int(L, 4, -1))) : -1;
    lua_pushinteger(L, ch);
    return 1;
}
auto l_engine_stop_channel(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->stop_channel(static_cast<std::int32_t>(opt_int(L, 2, -1))); }
    return 0;
}
auto l_engine_stop_all_sounds(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->stop_all_sounds(); }
    return 0;
}
auto l_engine_get_events(lua_State* L) -> int
{
    auto* e = get_engine(L, 1);
    auto events = e ? e->poll_events() : std::vector<Ev>{};
    lua_createtable(L, static_cast<int>(events.size()), 0);
    int i = 0;
    for (auto& ev : events)
    {
        lua_createtable(L, 0, 6);
        push_field(L, "type", ev.type.c_str());
        if (ev.type == "KEYDOWN" || ev.type == "KEYUP")
        {
            push_field(L, "key", ev.key);
            push_field(L, "key_name", ev.key_name.c_str());
            push_field(L, "scan_name", ev.scan_name.c_str());
        }
        else if (ev.type.rfind("MOUSE", 0) == 0)
        {
            push_field(L, "x", ev.x);
            push_field(L, "y", ev.y);
        }
        lua_rawseti(L, -2, ++i);
    }
    return 1;
}
auto l_engine_update_discord(lua_State* L) -> int
{
    if (auto* e = get_engine(L, 1)) { e->update_discord(luaL_checkstring(L, 2), luaL_checkstring(L, 3)); }
    return 0;
}
auto l_engine_set_discord_enabled(lua_State* L) -> int
{
    (void)L;
    return 0;
}

auto l_engine_new(lua_State* L) -> int
{
    const std::string title = luaL_checkstring(L, 1);
    const auto w = static_cast<std::uint32_t>(opt_int(L, 2, 0));
    const auto h = static_cast<std::uint32_t>(opt_int(L, 3, 0));
    const bool fs = lua_toboolean(L, 4) != 0;
    const bool vs = lua_toboolean(L, 5) != 0;
    auto* e = new Engine();
    if (!e->new_instance(title, w, h, fs, vs).value_or(false))
    {
        delete e;
        return luaL_error(L, "engine init failed");
    }
    auto** ud = static_cast<Engine**>(lua_newuserdatauv(L, sizeof(Engine*), 0));
    *ud = e;
    luaL_setmetatable(L, "fnwf.Engine");
    return 1;
}
auto l_engine_gc(lua_State* L) -> int
{
    auto** ud = static_cast<Engine**>(lua_touserdata(L, 1));
    if (ud != nullptr && *ud != nullptr)
    {
        (*ud)->shutdown();
        delete *ud;
        *ud = nullptr;
    }
    return 0;
}

const luaL_Reg k_methods[] = {
    { "clear", l_engine_clear }, { "flip", l_engine_flip }, { "stop", l_engine_stop },
    { "keeps_running", l_engine_keeps_running }, { "get_ticks", l_engine_get_ticks },
    { "set_logical_size", l_engine_set_logical_size }, { "set_resolution", l_engine_set_resolution },
    { "set_fullscreen", l_engine_set_fullscreen }, { "set_vsync", l_engine_set_vsync },
    { "get_mouse_pos", l_engine_get_mouse_pos }, { "get_display_modes", l_engine_get_display_modes },
    { "load_texture", l_engine_load_texture }, { "create_target_texture", l_engine_create_target_texture },
    { "set_render_target", l_engine_set_render_target }, { "reset_render_target", l_engine_reset_render_target },
    { "draw_texture", l_engine_draw_texture }, { "draw_rect", l_engine_draw_rect },
    { "draw_line", l_engine_draw_line }, { "draw_circle", l_engine_draw_circle },
    { "draw_text", l_engine_draw_text }, { "get_text_size", l_engine_get_text_size },
    { "load_font", l_engine_load_font }, { "load_sound", l_engine_load_sound },
    { "play_sound", l_engine_play_sound }, { "stop_channel", l_engine_stop_channel },
    { "stop_all_sounds", l_engine_stop_all_sounds }, { "get_events", l_engine_get_events },
    { "update_discord", l_engine_update_discord }, { "set_discord_enabled", l_engine_set_discord_enabled },
    { nullptr, nullptr },
};

} // namespace

void fnwf::register_engine(lua_State* L)
{
    luaL_newmetatable(L, "fnwf.Engine");
    lua_pushcfunction(L, l_engine_gc);
    lua_setfield(L, -2, "__gc");
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_setfuncs(L, k_methods, 0);
    lua_setglobal(L, "fnwf.Engine_mt");

    lua_newtable(L);
    lua_pushcfunction(L, l_engine_new);
    lua_setfield(L, -2, "new");
    lua_setglobal(L, "Engine");
}
