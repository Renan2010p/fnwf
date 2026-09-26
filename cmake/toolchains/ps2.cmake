# CMake toolchain for the PlayStation 2 (EE, mips64r5900el).
#
#   cmake -S . -B build-ps2 -DCMAKE_TOOLCHAIN_FILE=cmake/toolchains/ps2.cmake
#
# Expects PS2DEV (e.g. /usr/local/ps2dev) in the environment.

set(CMAKE_SYSTEM_NAME PS2)
set(CMAKE_SYSTEM_PROCESSOR mips)

if(NOT DEFINED PS2DEV AND DEFINED ENV{PS2DEV})
    set(PS2DEV "$ENV{PS2DEV}")
endif()
if(NOT PS2DEV)
    message(FATAL_ERROR "PS2DEV is not set (e.g. export PS2DEV=/usr/local/ps2dev)")
endif()

set(CMAKE_C_COMPILER   "${PS2DEV}/ee/bin/mips64r5900el-ps2-elf-gcc")
set(CMAKE_CXX_COMPILER "${PS2DEV}/ee/bin/mips64r5900el-ps2-elf-g++")
set(CMAKE_AR           "${PS2DEV}/ee/bin/mips64r5900el-ps2-elf-ar")
set(CMAKE_RANLIB       "${PS2DEV}/ee/bin/mips64r5900el-ps2-elf-ranlib")
set(CMAKE_STRIP        "${PS2DEV}/ee/bin/mips64r5900el-ps2-elf-strip")

set(CMAKE_FIND_ROOT_PATH "${PS2DEV}/ps2sdk" "${PS2DEV}/gsKit")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# There is no way to run target binaries on the host.
set(CMAKE_CROSSCOMPILING_EMULATOR "")
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
