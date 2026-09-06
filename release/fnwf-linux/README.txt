===========================================
  Five Nights With Friends 1 - v2.0.0
===========================================

A survival horror game inspired by Five Nights at Freddy's,
featuring 4 animatronics with unique AI behaviors.

License: GNU General Public License v3.0 (GPL-3.0)
All code and assets are free and open source.

CONTROLS:
  Mouse       - Look around the office
  Left Click  - Interact with doors, buttons, cameras
  Q / E       - Toggle left/right door
  A / D       - Toggle left/right light
  L           - Toggle vent light
  Space       - Put on / take off Freddy mask
  1-9         - Switch camera (when monitor is open)
  ESC         - Return to menu
  P           - Skip to 6 AM (debug)

GAMEPLAY:
  Survive from 12 AM to 6 AM across 7 nights.
  Manage your power carefully - once it's out, you're vulnerable.
  Use doors, lights, and the Freddy mask to keep animatronics away.
  Each animatronic has a unique movement pattern:
    - Cedro: Attacks from the left
    - Eser: Attacks from the right
    - Alice: Comes through the ventilation
    - Sonk: Rushes when you stare too long

REQUIREMENTS:
  - SDL2, SDL2_ttf, SDL2_image, SDL2_mixer
  - On Linux: sudo apt install libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev libsdl2-mixer-dev
  - On Windows: DLLs should be included in the bin/ folder

RUNNING:
  Linux:   ./run.sh   or   ./bin/fnwf
  Windows: run.bat    or   bin\fnwf.exe

OPTIONS:
  --office, -o    Jump straight to the office (test mode)

BUILD FROM SOURCE:
  Requires: Meson build system, C++23 compiler, SDL2 dev libraries
  1. meson setup build
  2. meson compile -C build
  3. ./build/fnwf

GENERATE SOUND EFFECTS:
  ./generate_sounds.sh
  This creates free placeholder sounds using ffmpeg synthesis.
  All generated sounds are 100% original (no copyrighted material).

REPLACING SOUND EFFECTS:
  Sound files are in assets/audio/ (OGG Vorbis format).
  You can replace any sound with your own. Free sources:
    https://pixabay.com/sound-effects/search/horror/
    https://freesound.org/search/?f=license:%22Creative+Commons+0%22
    https://opengameart.org/

ASSETS:
  All character sprites (cedro.png, eser.png, alice.png, Sonk.png,
  renan.png) are original artwork for this project.
  Font: FiraCode Nerd Font Mono (SIL Open Font License).
  Office and camera views are rendered procedurally in code.
  No copyrighted material is used in this project.

===========================================
  Enjoy the game!
===========================================
