# Wrapper around ps2dev.cmake that adds -msoft-float
# to prevent GCC R5900 backend from generating VU COP2 instructions
# (vdiv/vmulq) which have a missing vwaitq pipeline hazard.

include("$ENV{PS2SDK}/ps2dev.cmake")

string(APPEND CMAKE_C_FLAGS " -msoft-float")
string(APPEND CMAKE_CXX_FLAGS " -msoft-float")
