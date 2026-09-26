# PlayStation 2 backend.
#
# Use the cross toolchain:  cmake -S . -B build-ps2 \
#     -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ps2.cmake
#
# Requires PS2DEV (ps2sdk + gsKit) in the environment or -DPS2DEV=...

add_executable(fnwf ${FNWF_ABSTRACT_SOURCES} ${FNWF_PS2_SOURCES})

if(NOT DEFINED PS2DEV AND DEFINED ENV{PS2DEV})
    set(PS2DEV "$ENV{PS2DEV}")
endif()
if(NOT DEFINED PS2SDK)
    set(PS2SDK "${PS2DEV}/ps2sdk")
endif()
if(NOT DEFINED GSKIT)
    set(GSKIT "${PS2DEV}/gsKit")
endif()

message(STATUS "FNWF PS2: PS2DEV=${PS2DEV} PS2SDK=${PS2SDK} GSKIT=${GSKIT}")

target_include_directories(fnwf PRIVATE
    src/platform/ps2/compat
    "${PS2SDK}/ee/include"
    "${PS2SDK}/common/include"
    "${PS2SDK}/ports/include"
    "${PS2SDK}/ports/include/SDL"
    "${GSKIT}/include")

target_compile_definitions(fnwf PRIVATE _EE __PS2__ PS2)
target_compile_options(fnwf PRIVATE
    -G0 -O2 -DNDEBUG -fno-exceptions -fno-rtti)
# PS2 SDL 1.2 provides `main` and calls SDL_main; our main.cpp is platform
# abstract, so rename it and force-include the C declaration (same as Meson).
target_compile_definitions(fnwf PRIVATE main=SDL_main)
target_compile_options(fnwf PRIVATE
    -include "${CMAKE_SOURCE_DIR}/src/platform/sdl2/sdl_main_extern.h")

target_link_directories(fnwf PRIVATE
    "${PS2SDK}/ee/lib" "${PS2SDK}/common/lib"
    "${PS2SDK}/ports/lib" "${GSKIT}/lib")
target_link_libraries(fnwf PRIVATE
    sdl sdlmixer SDL_ttf SDL_image freetype png z
    ogg vorbis vorbisfile audsrv pad gskit dmakit m)
target_link_options(fnwf PRIVATE
    -G0 -Wl,-zmax-page-size=128 -T"${PS2SDK}/ee/startup/linkfile")

set_target_properties(fnwf PROPERTIES SUFFIX ".elf")
