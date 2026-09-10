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

# === Common flags (all architectures) ===
common_flags = [
  '-D_FORTIFY_SOURCE=3',
  '-fstack-protector-strong',
  '-fstack-clash-protection',
  '-fPIE',
  '-Wformat',
  '-Wformat-security',
  '-Werror=format-security',
  '-O3',
  '-flto=auto',
  '-fwhole-program',
  '-fno-exceptions',
  '-DNDEBUG',
  '-finline-functions',
  '-finline-limit=300',
  '-fvisibility-inlines-hidden',
  '-fdevirtualize',
  '-fdevirtualize-at-ltrans',
  '-ftree-vectorize',
  '-ftree-loop-vectorize',
  '-ftree-loop-distribute-patterns',
  '-funroll-loops',
  '-floop-nest-optimize',
  '-floop-parallelize-all',
  '-fomit-frame-pointer',
  '-ffunction-sections',
  '-fdata-sections',
  '-fmerge-all-constants',
  '-fno-math-errno',
  '-fno-signed-zeros',
  '-fno-trapping-math',
  '-ffinite-math-only',
  '-funsafe-math-optimizations',
  '-freciprocal-math',
  '-fipa-pta',
  '-fipa-cp',
  '-fipa-sra',
  '-fipa-profile',
  '-frename-registers',
  '-fmodulo-sched',
  '-ftree-pre',
  '-ftree-partial-pre',
  '-ftree-sra',
  '-fstore-merging',
  '-faggressive-loop-optimizations',
]

# === x86-only flags ===
x86_flags = [
  '-march=x86-64-v2',
  '-mtune=generic',
  '-fcf-protection=full',
]

# === ARM64-only flags ===
arm64_flags = [
  '-march=armv8-a',
]

# === Select arch flags ===
if host_machine.cpu_family() == 'aarch64'
  arch_flags = arm64_flags
else
  arch_flags = x86_flags
endif

# === Linker flags (Linux only — Windows/MinGW doesn't support -z flags) ===
linker_flags = []
if host_machine.system() == 'linux'
  linker_flags = [
    '-Wl,-z,relro',
    '-Wl,-z,now',
    '-Wl,-z,noexecstack',
    '-Wl,--gc-sections',
    '-Wl,--as-needed',
    '-flto=auto',
    '-fuse-linker-plugin',
    '-Wl,-O3',
    '-Wl,--hash-style=both',
    '-Wl,--compress-debug-sections=zlib',
  ]
elif host_machine.system() == 'windows'
  linker_flags = [
    '-static-libgcc',
    '-static-libstdc++',
    '-Wl,--gc-sections',
    '-Wl,-O3',
  ]
endif

# === Debug sanitizer flags ===
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
  add_project_arguments(common_flags + arch_flags, language : 'cpp')
  add_project_link_arguments(linker_flags, language : 'cpp')
  message('BUILD: Release + aggressive optimizations (cpu_family=@0@)'.format(host_machine.cpu_family()))
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
  cpp_pch : meson.is_cross_build() ? '' : 'src/pch.hpp',
  install : true
)

# === Release packaging (Linux only — Windows packages via CI workflow) ===
if host_machine.system() == 'linux'
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
endif
