# Windows desktop build (MinGW-w64 / MSVC).
add_executable(fnwf ${FNWF_ABSTRACT_SOURCES} ${FNWF_SDL2_SOURCES})
include(cmake/dependencies.cmake)
fnwf_link_sdl()

# main.cpp is platform-abstract and never includes SDL.h, so the SDL_main
# rename that libSDL2main expects has to be done here.
target_compile_definitions(fnwf PRIVATE main=SDL_main)
target_include_directories(fnwf PRIVATE src/platform/sdl2)
target_link_libraries(fnwf PRIVATE SDL2::SDL2main)

if(MINGW)
    target_link_options(fnwf PRIVATE -static-libgcc -static-libstdc++ -static)
endif()
