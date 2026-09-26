# macOS desktop build (SDL2).
add_executable(fnwf ${FNWF_ABSTRACT_SOURCES} ${FNWF_SDL2_SOURCES})
include(cmake/dependencies.cmake)
fnwf_link_sdl()

target_compile_options(fnwf PRIVATE -O2 -fomit-frame-pointer)
