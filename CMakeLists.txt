cmake_minimum_required(VERSION 3.24)

project(fnwf
    VERSION 2.0.12
    DESCRIPTION "Five Nights With Friends - Classic Edition"
    LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "" FORCE)
endif()

option(FNWF_BUILD_TESTS "Build tests" OFF)

# ── Platform selection ───────────────────────────────────────────────────────
# FNWF_PLATFORM can be "desktop", "web" or "ps2". Default: detect.
if(NOT DEFINED FNWF_PLATFORM)
    if(CMAKE_SYSTEM_NAME STREQUAL "PS2")
        set(FNWF_PLATFORM "ps2")
    elseif(EMSCRIPTEN)
        set(FNWF_PLATFORM "web")
    else()
        set(FNWF_PLATFORM "desktop")
    endif()
endif()
message(STATUS "FNWF: building for '${FNWF_PLATFORM}' (${CMAKE_BUILD_TYPE})")

# ── Shared (platform-agnostic) sources ───────────────────────────────────────
set(FNWF_ABSTRACT_SOURCES
    src/main.cpp
    src/engine/Engine.cpp
    src/core/Platform.cpp
    src/core/InputManager.cpp
    src/core/DrawUtils.cpp
    src/core/Localization.cpp
    src/core/SaveManager.cpp
    src/core/SettingsManager.cpp
    src/core/StateMachine.cpp
    src/core/StateRegistry.cpp
    src/core/SoundManager.cpp
    src/core/MobileUI.cpp
    src/systems/Office.cpp
    src/systems/CameraSystem.cpp
    src/systems/Doors.cpp
    src/systems/Animatronics.cpp
    src/systems/Power.cpp
    src/systems/Jumpscare.cpp
    src/game1/states/WarningState.cpp
    src/game1/states/MenuState.cpp
    src/game1/states/GameplayState.cpp
    src/game1/states/OptionsState.cpp
    src/game1/states/CustomNightState.cpp
    src/game1/states/StoryState.cpp
    src/game1/states/LoadingState.cpp
    src/game1/states/NightTransitionState.cpp
    src/game1/states/SixAMState.cpp
    src/game1/states/PaycheckState.cpp
    src/game1/states/NewspaperState.cpp
    src/game1/states/GameOverState.cpp
    src/game1/states/ExtrasState.cpp
    src/game1/states/ConquistasState.cpp
    src/game1/states/ArcadeState.cpp)

set(FNWF_SDL2_SOURCES
    src/platform/sdl2/EngineSDL2.cpp
    src/platform/sdl2/plat_sdl2.cpp
    src/platform/sdl2/plat_input.cpp)

set(FNWF_PS2_SOURCES
    src/platform/ps2/EnginePS2.cpp
    src/platform/ps2/plat_ps2.cpp
    src/platform/ps2/plat_input_ps2.cpp
    src/platform/ps2/lzma_stubs.cpp)

# ── Platform backends ────────────────────────────────────────────────────────
if(FNWF_PLATFORM STREQUAL "ps2")
    include(cmake/platform/ps2.cmake)
elseif(FNWF_PLATFORM STREQUAL "web")
    include(cmake/platform/web.cmake)
elseif(WIN32)
    include(cmake/platform/windows.cmake)
elseif(APPLE)
    include(cmake/platform/macos.cmake)
else()
    include(cmake/platform/linux.cmake)
endif()

target_include_directories(fnwf PRIVATE src)
target_compile_features(fnwf PRIVATE cxx_std_17)

# Silence the (intentional) trimming of unused SDL features.
if(MSVC)
    target_compile_options(fnwf PRIVATE /W3)
else()
    target_compile_options(fnwf PRIVATE -Wall -Wextra -Wno-unused-parameter)
endif()

# ── Install / packaging ──────────────────────────────────────────────────────
install(TARGETS fnwf RUNTIME DESTINATION bin)
install(DIRECTORY assets/ DESTINATION assets)
