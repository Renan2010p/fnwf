project('fnwf', 'cpp',
  version : '2.0.9',
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

# === Hardening flags ===
hardening_flags = [
  '-D_FORTIFY_SOURCE=3',
  '-fstack-protector-strong',
  '-fstack-clash-protection',
  '-fcf-protection=full',
  '-fPIE',
  '-Wformat',
  '-Wformat-security',
  '-Werror=format-security',
]

# === Aggressive optimization flags (x86-64-v2 baseline) ===
opt_flags = [
  # --- Architecture: x86-64-v2 (SSE4.2, SSSE3, POPCNT, CMPXCHG16B) ---
  '-march=x86-64-v2',
  '-mtune=generic',

  # --- Core optimizations ---
  '-O3',
  '-flto=auto',                     # Link-time optimization (parallel)
  '-fwhole-program',                 # WPO for static binary
  '-fno-exceptions',                 # Smaller binary, no unwind tables
  '-DNDEBUG',                        # Disable assert()

  # --- Inlining ---
  '-finline-functions',
  '-finline-limit=300',              # Aggressive inlining threshold
  '-fvisibility-inlines-hidden',     # Hide inline symbols
  '-fdevirtualize',                  # Devirtualize indirect calls
  '-fdevirtualize-at-ltrans',        # Devirtualize during LTO

  # --- Loop optimizations ---
  '-ftree-vectorize',                # Auto-vectorization (SSE/AVX)
  '-ftree-loop-vectorize',           # Vectorize loops
  '-ftree-loop-distribute-patterns', # Optimize loop patterns (memcpy, memset)
  '-funroll-loops',                  # Unroll loops
  '-floop-nest-optimize',            # Graphite loop optimizer
  '-floop-parallelize-all',          # Parallelize all loops

  # --- Code generation ---
  '-fomit-frame-pointer',            # Free up RBP register
  '-ffunction-sections',             # Each function in own section
  '-fdata-sections',                 # Each data item in own section
  '-fmerge-all-constants',           # Merge identical constants
  '-fno-math-errno',                 # Skip errno on math funcs (faster sqrt, etc)
  '-fno-signed-zeros',               # Ignore signed zero (-0.0 == 0.0)
  '-fno-trapping-math',              # Assume no FP traps
  '-ffinite-math-only',              # Assume no NaN/Inf (faster FP)
  '-funsafe-math-optimizations',     # Reorder FP ops (faster, less IEEE)
  '-freciprocal-math',               # Use 1/x instead of division

  # --- Interprocedural ---
  '-fipa-pta',                       # Interprocedural pointer analysis
  '-fipa-cp',                        # Interprocedural constant propagation
  '-fipa-sra',                       # Scalar replacement of aggregates
  '-fipa-profile',                   # Use profile data for inlining

  # --- Register allocation ---
  '-frename-registers',              # Rename registers for better pipelining
  '-fmodulo-sched',                  # Software pipelining

  # --- Memory ---
  '-ftree-pre',                      # Partial redundancy elimination
  '-ftree-partial-pre',              # Aggressive PRE
  '-ftree-sra',                      # Scalar replacement of aggregates
  '-fstore-merging',                 # Merge adjacent stores
  '-faggressive-loop-optimizations', # Assume no loop vectorization problems

  # '-fprofile-use' can be enabled after PGO training for +10-15% speedup
]

# === Linker flags ===
linker_flags = [
  '-Wl,-z,relro',
  '-Wl,-z,now',
  '-Wl,-z,noexecstack',
  '-Wl,--gc-sections',
  '-Wl,--as-needed',
  '-flto=auto',                      # LTO at link stage
  '-fuse-linker-plugin',             # Use linker plugin for better WPO
  '-Wl,-O3',                         # Linker optimization level
  '-Wl,--hash-style=both',           # Faster symbol lookup
  '-Wl,--compress-debug-sections=zlib', # Smaller debug info
]

# === Debug build with sanitizers ===
sanitizer_flags = [
  '-fsanitize=address',
  '-fsanitize=undefined',
  '-fsanitize=leak',
  '-fsanitize=alignment',
  '-fsanitize=float-cast-overflow',
  '-fsanitize=float-divide-by-zero',
  '-fsanitize=integer-divide-by-zero',
  '-fsanitize=nonnull-attribute',
  '-fsanitize=return',
  '-fsanitize=signed-integer-overflow',
  '-fsanitize=unreachable',
  '-fno-omit-frame-pointer',
  '-g',
  '-O1',
]

# === Apply flags ===
if get_option('buildtype') == 'debug'
  add_project_arguments(sanitizer_flags, language : 'cpp')
  add_project_link_arguments(sanitizer_flags, language : 'cpp')
  message('BUILD: Debug + sanitizers (ASan + UBSan + LSan)')
else
  add_project_arguments(hardening_flags + opt_flags, language : 'cpp')
  add_project_link_arguments(linker_flags, language : 'cpp')
  message('BUILD: Release + aggressive x86-64-v2 optimizations + LTO')
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

fnwf = executable('fnwf',
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

# === Release packaging ===
release_name = 'fnwf-classic-v@0@-linux-x86_64'.format(meson.project_version())

custom_target('package',
  input : fnwf,
  output : release_name + '.tar.gz',
  command : [
    find_program('scripts/package.sh'),
    '@INPUT@',
    '@OUTDIR@',
    meson.project_version(),
    meson.project_source_root(),
    'linux-x86_64',
  ],
  build_by_default : true,
)
