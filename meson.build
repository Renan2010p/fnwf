project('fnwf', 'cpp',
  version : '2.0.12',
  default_options : [
    'cpp_std=c++17',
    'warning_level=2',
    'optimization=3',
    'default_library=static',
    'buildtype=release',
    'cpp_args=-pipe',
  ]
)

# === Dependencies (static linking) ===
sdl2_dep = dependency('sdl2', required : false)
sdl2_ttf_dep = dependency('SDL2_ttf', required : false)
sdl2_image_dep = dependency('SDL2_image', required : false)
sdl2_mixer_dep = dependency('SDL2_mixer', required : false)
freetype2_dep = dependency('freetype2', required : false)

if not sdl2_dep.found() or not sdl2_ttf_dep.found() or not sdl2_image_dep.found() or not sdl2_mixer_dep.found()
  message('SDL2 not found or incomplete — building from source...')
  sdl2_proj = subproject('sdl2', default_options : ['tests=disabled'])
  sdl2_dep = sdl2_proj.get_variable('sdl2_dep')
  sdl2_ttf_dep = subproject('sdl2_ttf').get_variable('sdl2_ttf_dep')
  sdl2_image_dep = subproject('sdl2_image').get_variable('sdl2_image_dep')
  sdl2_mixer_dep = subproject('sdl2_mixer').get_variable('sdl2_mixer_dep')
endif

# === Platform-specific flags ===
if host_machine.system() == 'linux'
  add_project_arguments([
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
    '-frename-registers',
    '-fmodulo-sched',
    '-ftree-pre',
    '-ftree-partial-pre',
    '-ftree-sra',
    '-fstore-merging',
    '-faggressive-loop-optimizations',
  ], language : 'cpp')

  if host_machine.cpu_family() == 'aarch64'
    add_project_arguments(['-march=armv8-a'], language : 'cpp')
  else
    add_project_arguments(['-march=x86-64-v2', '-mtune=generic', '-fcf-protection=full'], language : 'cpp')
  endif

  add_project_link_arguments([
    '-Wl,-z,relro',
    '-Wl,-z,now',
    '-Wl,-z,noexecstack',
    '-Wl,--gc-sections',
    '-Wl,--as-needed',
    '-flto=auto',
    '-fuse-linker-plugin',
    '-Wl,-O3',
    '-Wl,--hash-style=both',
  ], language : 'cpp')

  message('BUILD: Linux static (cpu_family=@0@)'.format(host_machine.cpu_family()))

elif host_machine.system() == 'windows'
  add_project_arguments([
    '-O2',
    '-DNDEBUG',
    '-fomit-frame-pointer',
    '-ffunction-sections',
    '-fdata-sections',
  ], language : 'cpp')

  add_project_link_arguments([
    '-static-libgcc',
    '-static-libstdc++',
    '-static',
    '-Wl,--gc-sections',
    '-Wl,-O3',
  ], language : 'cpp')

  message('BUILD: Windows static (MinGW64)')

elif host_machine.system() == 'darwin'
  add_project_arguments([
    '-O2',
    '-DNDEBUG',
    '-fomit-frame-pointer',
    '-ffunction-sections',
    '-fdata-sections',
  ], language : 'cpp')

  message('BUILD: macOS static')
endif

# === Abstract sources (no platform code here) ===
fnwf_sources = files(
  'src/main.cpp',
  # Engine interface
  'src/engine/Engine.cpp',
  # Core abstractions (stubs — real impls live in platform/)
  'src/core/Platform.cpp',
  'src/core/InputManager.cpp',
  'src/core/DrawUtils.cpp',
  'src/core/Localization.cpp',
  'src/core/SaveManager.cpp',
  'src/core/SettingsManager.cpp',
  'src/core/StateMachine.cpp',
  'src/core/StateRegistry.cpp',
  'src/core/SoundManager.cpp',
  'src/core/MobileUI.cpp',
  # Game systems (all abstract, depend only on Engine interface)
  'src/systems/Office.cpp',
  'src/systems/CameraSystem.cpp',
  'src/systems/Doors.cpp',
  'src/systems/Animatronics.cpp',
  'src/systems/Power.cpp',
  'src/systems/Jumpscare.cpp',
  # Game states
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

# === Platform backend selection ===
# The game code is 100% abstract — only this section changes per platform.
# SDL2 backend (desktop: Linux, Windows, macOS, Web)
sdl2_backend = files(
  'src/platform/sdl2/EngineSDL2.cpp',
  'src/platform/sdl2/plat_sdl2.cpp',
  'src/platform/sdl2/plat_input.cpp',
)

# PS2 backend (PlayStation 2 via ps2sdk)
ps2_backend = files(
  'src/platform/ps2/EnginePS2.cpp',
  'src/platform/ps2/plat_ps2.cpp',
  'src/platform/ps2/plat_input_ps2.cpp',
)

# Select backend based on target platform
if host_machine.system() == 'ps2'
  platform_backend = ps2_backend
  platform_deps = []   # PS2 links via cross-file flags
else
  platform_backend = sdl2_backend
  platform_deps = [
    sdl2_dep,
    sdl2_ttf_dep,
    sdl2_image_dep,
    sdl2_mixer_dep,
    freetype2_dep,
  ]
endif

fnwf_inc = include_directories('src')

fnwf = executable('fnwf',
  fnwf_sources + platform_backend,
  include_directories : fnwf_inc,
  dependencies : platform_deps,
  install : true
)
