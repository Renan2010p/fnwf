# Shared SDL2 dependency handling for the desktop platforms.
#
# Dependencies are downloaded and built from source with FetchContent, so
# nothing is vendored in the repository. Set FNWF_USE_SYSTEM_DEPS=ON to prefer
# packages that are already installed.

include(FetchContent)

# The FreeType bundled by SDL2_ttf still declares cmake_minimum_required below
# 3.5; allow it so modern CMake can configure it.
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)

option(FNWF_USE_SYSTEM_DEPS "Use system SDL2 instead of fetching and building it" OFF)

function(fnwf_link_sdl)
    if(FNWF_USE_SYSTEM_DEPS)
        find_package(SDL2 CONFIG REQUIRED)
        find_package(SDL2_ttf CONFIG REQUIRED)
        find_package(SDL2_image CONFIG REQUIRED)
        find_package(SDL2_mixer CONFIG REQUIRED)
        message(STATUS "FNWF: using system SDL2")
        target_link_libraries(${PROJECT_NAME} PRIVATE
            SDL2::SDL2 SDL2_ttf::SDL2_ttf SDL2_image::SDL2_image SDL2_mixer::SDL2_mixer)
        return()
    endif()

    message(STATUS "FNWF: fetching SDL2 (SDL2 / SDL2_ttf / SDL2_image / SDL2_mixer)")

    set(SDL_SHARED OFF CACHE BOOL "" FORCE)
    set(SDL_STATIC ON CACHE BOOL "" FORCE)
    set(SDL_TEST OFF CACHE BOOL "" FORCE)
    set(SDL_TESTS OFF CACHE BOOL "" FORCE)
    # The system PipeWire headers can be newer than this SDL2 release expects;
    # ALSA/PulseAudio are enough for the game.
    set(SDL_PIPEWIRE OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(SDL2
        GIT_REPOSITORY https://github.com/libsdl-org/SDL.git
        GIT_TAG release-2.30.8 GIT_SHALLOW TRUE)

    set(SDL2TTF_VENDORED ON CACHE BOOL "" FORCE)
    set(SDL2TTF_SAMPLES OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(SDL2_ttf
        GIT_REPOSITORY https://github.com/libsdl-org/SDL_ttf.git
        GIT_TAG release-2.22.0 GIT_SHALLOW TRUE)

    set(SDL2IMAGE_VENDORED ON CACHE BOOL "" FORCE)
    set(SDL2IMAGE_SAMPLES OFF CACHE BOOL "" FORCE)
    set(SDL2IMAGE_PNG ON CACHE BOOL "" FORCE)
    set(SDL2IMAGE_JPG OFF CACHE BOOL "" FORCE)
    set(SDL2IMAGE_WEBP OFF CACHE BOOL "" FORCE)
    set(SDL2IMAGE_TIF OFF CACHE BOOL "" FORCE)
    set(SDL2IMAGE_AVIF OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(SDL2_image
        GIT_REPOSITORY https://github.com/libsdl-org/SDL_image.git
        GIT_TAG release-2.8.2 GIT_SHALLOW TRUE)

    set(SDL2MIXER_VENDORED ON CACHE BOOL "" FORCE)
    set(SDL2MIXER_SAMPLES OFF CACHE BOOL "" FORCE)
    set(SDL2MIXER_OGG ON CACHE BOOL "" FORCE)
    set(SDL2MIXER_MP3 OFF CACHE BOOL "" FORCE)
    set(SDL2MIXER_MOD OFF CACHE BOOL "" FORCE)
    set(SDL2MIXER_MIDI OFF CACHE BOOL "" FORCE)
    set(SDL2MIXER_OPUS OFF CACHE BOOL "" FORCE)
    set(SDL2MIXER_WAVPACK OFF CACHE BOOL "" FORCE)
    set(SDL2MIXER_FLAC OFF CACHE BOOL "" FORCE)
    FetchContent_Declare(SDL2_mixer
        GIT_REPOSITORY https://github.com/libsdl-org/SDL_mixer.git
        GIT_TAG release-2.8.0 GIT_SHALLOW TRUE)

    # We build SDL2 itself static, so the satellites must be static too (their
    # INTERFACE_SDL2_SHARED property has to match). BUILD_SHARED_LIBS drives
    # SDL2_ttf/image/mixer.
    set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(SDL2TTF_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(SDL2IMAGE_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
    set(SDL2MIXER_BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

    FetchContent_MakeAvailable(SDL2 SDL2_ttf SDL2_image SDL2_mixer)

    target_link_libraries(${PROJECT_NAME} PRIVATE
        SDL2::SDL2-static
        SDL2_ttf::SDL2_ttf-static
        SDL2_image::SDL2_image-static
        SDL2_mixer::SDL2_mixer-static)
endfunction()
