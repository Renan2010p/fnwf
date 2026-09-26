# Web build (Emscripten). Uses the emsdk SDL2 ports, so nothing is fetched.

set(FNWF_WEB_SOURCES ${FNWF_ABSTRACT_SOURCES})
list(REMOVE_ITEM FNWF_WEB_SOURCES
    src/core/Platform.cpp
    src/core/InputManager.cpp
    src/core/MobileUI.cpp)

add_executable(fnwf ${FNWF_WEB_SOURCES} ${FNWF_SDL2_SOURCES})
target_include_directories(fnwf PRIVATE src/platform/sdl2)

set(_sdl_opts -sUSE_SDL=2 -sUSE_SDL_TTF=2 -sUSE_SDL_IMAGE=2 -sUSE_SDL_MIXER=2)
set(_web_flags
    ${_sdl_opts}
    "-sSDL2_IMAGE_FORMATS=['png']"
    "-sSDL2_MIXER_FORMATS=['ogg']"
    -sALLOW_MEMORY_GROWTH=1
    -sINITIAL_MEMORY=134217728
    -sMAXIMUM_MEMORY=536870912
    -sFORCE_FILESYSTEM=1)

target_compile_options(fnwf PRIVATE ${_sdl_opts})
target_link_options(fnwf PRIVATE
    ${_web_flags}
    --preload-file "${CMAKE_SOURCE_DIR}/assets@assets"
    --shell-file "${CMAKE_SOURCE_DIR}/web/shell.html")

target_compile_definitions(fnwf PRIVATE main=SDL_main)
set_target_properties(fnwf PROPERTIES SUFFIX ".html" OUTPUT_NAME "index")
