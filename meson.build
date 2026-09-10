project('fnwf', 'cpp',
  version : '2.0.6',
  default_options : [
    'cpp_std=c++23',
    'warning_level=2',
    'optimization=3',
    'default_library=static',
    'buildtype=release',
    'cpp_args=-pipe',
  ]
)

# === Dependencies ===
sdl2_dep = dependency('sdl2', required : true)
sdl2_ttf_dep = dependency('SDL2_ttf', required : true)
sdl2_image_dep = dependency('SDL2_image', required : true)
sdl2_mixer_dep = dependency('SDL2_mixer', required : true)

# === Hardening flags (release) ===
hardening_flags = [
  '-D_FORTIFY_SOURCE=3',          # Buffer overflow detection at runtime
  '-fstack-protector-strong',     # Stack canary protection
  '-fstack-clash-protection',     # Stack clash attack prevention
  '-fcf-protection=full',         # Control-flow enforcement (CET)
  '-fPIE',                        # Position-independent executable
  '-Wformat',                     # Format string warnings
  '-Wformat-security',            # Format string security checks
  '-Werror=format-security',      # Treat format security as error
]

# === Extra optimization flags ===
opt_flags = [
  '-ftree-vectorize',             # Auto-vectorization
  '-fomit-frame-pointer',         # Free up a register
  '-ffunction-sections',          # Dead code elimination
  '-fdata-sections',              # Dead data elimination
  '-DNDEBUG',                     # Disable assert()
]

# === Linker hardening flags ===
linker_flags = [
  '-Wl,-z,relro',                 # Read-only relocations
  '-Wl,-z,now',                   # Full RELRO (lazy binding disabled)
  '-Wl,-z,noexecstack',           # Non-executable stack
  '-Wl,--gc-sections',            # Garbage collect unused sections
  '-Wl,--as-needed',              # Only link needed libraries
]

# === Debug build with sanitizers (meson setup build/debug -Dbuildtype=debug) ===
sanitizer_flags = [
  '-fsanitize=address',           # Memory errors (buffer overflow, use-after-free)
  '-fsanitize=undefined',         # Undefined behavior detection
  '-fsanitize=leak',              # Memory leak detection
  '-fsanitize=alignment',         # Alignment checking
  '-fsanitize=float-cast-overflow', # Float cast overflow
  '-fsanitize=float-divide-by-zero', # Float divide by zero
  '-fsanitize=integer-divide-by-zero', # Int divide by zero
  '-fsanitize=nonnull-attribute', # Nonnull argument violation
  '-fsanitize=return',            # Return value mismatch
  '-fsanitize=signed-integer-overflow', # Signed overflow
  '-fsanitize=unreachable',       # Unreachable code
  '-fno-omit-frame-pointer',      # Keep frame pointers for better stack traces
  '-g',                           # Debug symbols for sanitizer output
]

# === Apply flags based on buildtype ===
if get_option('buildtype') == 'debug'
  add_project_arguments(sanitizer_flags, language : 'cpp')
  add_project_link_arguments(sanitizer_flags, language : 'cpp')
  message('BUILD MODE: Debug with sanitizers (ASan + UBSan + LSan)')
else
  add_project_arguments(hardening_flags + opt_flags, language : 'cpp')
  add_project_link_arguments(linker_flags, language : 'cpp')
  message('BUILD MODE: Release with hardening + optimizations')
endif

# === Sources ===
fnwf_sources = files(
  'src/main.cpp',
  'src/engine/Engine.cpp',
  'src/core/DrawUtils.cpp',
  'src/core/Localization.cpp',
  'src/core/SaveManager.cpp',
  'src/core/SettingsManager.cpp',
  'src/core/StateMachine.cpp',
  'src/core/StateRegistry.cpp',
  'src/core/SoundManager.cpp',
  'src/systems/Office.cpp',
  'src/systems/CameraSystem.cpp',
  'src/systems/Doors.cpp',
  'src/systems/Animatronics.cpp',
  'src/systems/Power.cpp',
  'src/systems/Jumpscare.cpp',
  'src/game1/states/WarningState.cpp',
  'src/game1/states/MenuState.cpp',
  'src/game1/states/GameplayState.cpp',
  'src/game1/states/OptionsState.cpp',
  'src/game1/states/CustomNightState.cpp',
  'src/game1/states/StoryState.cpp',
  'src/game1/states/LoadingState.cpp',
  'src/game1/states/NightTransitionState.cpp',
  'src/game1/states/SixAMState.cpp',
  'src/game1/states/PaycheckState.cpp',
  'src/game1/states/NewspaperState.cpp',
  'src/game1/states/GameOverState.cpp',
  'src/game1/states/ExtrasState.cpp',
  'src/game1/states/ConquistasState.cpp',
  'src/game1/states/ArcadeState.cpp',
)

fnwf_inc = include_directories('src')

executable('fnwf',
  fnwf_sources,
  include_directories : fnwf_inc,
  dependencies : [
    sdl2_dep,
    sdl2_ttf_dep,
    sdl2_image_dep,
    sdl2_mixer_dep,
  ],
  cpp_pch : 'src/pch.hpp',
  install : true
)
