@echo off
REM Build Five Nights With Friends for Windows (MinGW + pkg-config).
REM Produces bin\fnwf-Windows.exe
setlocal
cd /d "%~dp0"
cmake -S . -B build -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release %*
mingw32-make -C build -j
echo.
echo ==> binario: %~dp0bin\fnwf-Windows.exe
endlocal
