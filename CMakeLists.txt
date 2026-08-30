cmake_minimum_required(VERSION 3.25)
project(fnwf LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 26)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

add_compile_options(-O2)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    add_compile_options(-Wall -Wextra -flto)
    add_link_options(-flto)
endif()

find_package(PkgConfig REQUIRED)
pkg_check_modules(SDL2 REQUIRED sdl2)
pkg_check_modules(SDL2_TTF REQUIRED SDL2_ttf)
pkg_check_modules(SDL2_IMG REQUIRED SDL2_image)
pkg_check_modules(SDL2_MIX REQUIRED SDL2_mixer)
pkg_check_modules(LUA REQUIRED lua5.4)

add_executable(fnwf
    src/main.cpp
    src/engine/Engine.cpp
    src/engine/LuaBindings.cpp
)

set_target_properties(fnwf PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/bin"
    RUNTIME_OUTPUT_NAME "fnwf-${CMAKE_SYSTEM_NAME}"
)

target_include_directories(fnwf PRIVATE
    ${SDL2_INCLUDE_DIRS}
    ${SDL2_TTF_INCLUDE_DIRS}
    ${SDL2_IMG_INCLUDE_DIRS}
    ${SDL2_MIX_INCLUDE_DIRS}
    ${LUA_INCLUDE_DIRS}
    src
)
target_link_libraries(fnwf PRIVATE
    ${SDL2_LIBRARIES}
    ${SDL2_TTF_LIBRARIES}
    ${SDL2_IMG_LIBRARIES}
    ${SDL2_MIX_LIBRARIES}
    ${LUA_LIBRARIES}
    ${SDL2_LDFLAGS_OTHER}
    ${LUA_LDFLAGS_OTHER}
    m
)
