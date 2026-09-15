# PS2 EE CMake Toolchain File
# Standalone toolchain that explicitly sets all paths
# (ps2dev.cmake from pre-built releases doesn't propagate EE include paths)

if(NOT DEFINED ENV{PS2SDK})
  message(FATAL_ERROR "PS2SDK environment variable not set")
endif()

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_VERSION 1)
set(CMAKE_SYSTEM_PROCESSOR mips)

set(CMAKE_C_COMPILER mips64r5900el-ps2-elf-gcc)
set(CMAKE_CXX_COMPILER mips64r5900el-ps2-elf-g++)
set(CMAKE_AR mips64r5900el-ps2-elf-ar)
set(CMAKE_LINKER mips64r5900el-ps2-elf-ld)
set(CMAKE_RANLIB mips64r5900el-ps2-elf-ranlib)
set(CMAKE_STRIP mips64r5900el-ps2-elf-strip)

set(PS2SDK "$ENV{PS2SDK}")
set(PS2DEV "$ENV{PS2DEV}")

set(CMAKE_C_FLAGS "-D_EE -G0 -I${PS2SDK}/ee/include -I${PS2SDK}/common/include" CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS "-D_EE -G0 -I${PS2SDK}/ee/include -I${PS2SDK}/common/include" CACHE STRING "" FORCE)

set(CMAKE_EXE_LINKER_FLAGS "-L${PS2SDK}/ee/lib -L${PS2SDK}/ports/lib -L${PS2DEV}/gsKit/lib" CACHE STRING "" FORCE)

set(CMAKE_FIND_ROOT_PATH ${PS2SDK}/ee ${PS2SDK}/ports ${PS2SDK}/common)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
