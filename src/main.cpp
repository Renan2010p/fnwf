// Five Nights With Friends — C++26 entry point. Boots Lua, registers the engine,
// then runs the recovered game loop (main.lua).
#include "engine/Engine.hpp"

#include <lua.hpp>

#include <cstdio>
#include <string>

auto main(int argc, char** argv) -> int
{
    auto* L = luaL_newstate();
    if (L == nullptr)
    {
        std::fprintf(stderr, "failed to create lua state\n");
        return 1;
    }
    luaL_openlibs(L);

    // `-o`/`--office` jumps straight to the office (fast test)
    bool test_office = false;
    for (int i = 1; i < argc; ++i)
    {
        const std::string a = argv[i];
        if (a == "-o" || a == "--office") { test_office = true; }
    }
    lua_pushboolean(L, test_office);
    lua_setglobal(L, "FNWF_TEST");

    fnwf::register_engine(L);

    if (luaL_dofile(L, "main.lua") != LUA_OK)
    {
        const char* msg = lua_tostring(L, -1);
        std::fprintf(stderr, "Lua error: %s\n", msg != nullptr ? msg : "(unknown)");
        lua_close(L);
        return 1;
    }

    lua_close(L);
    return 0;
}
