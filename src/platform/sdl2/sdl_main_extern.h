// Force-included on Windows and PS2 (see meson.build, windows/ps2 sections).
//
// libSDL2main.a is C code: its main()/WinMain() entry wrappers call
// SDL_main() with C language linkage. main.cpp is platform-abstract and
// never includes SDL_main.h — which normally provides both this extern "C"
// declaration and the main -> SDL_main rename — so the rename is done with
// -Dmain=SDL_main and this declaration is injected instead. It must precede
// main.cpp's renamed definition so the definition inherits C linkage
// instead of getting a mangled C++ symbol (_Z9SDL_mainiPPc).
//
// Signature must match SDL_main.h's:
//   extern SDLMAIN_DECLSPEC int SDL_main(int argc, char *argv[]);
// (SDLMAIN_DECLSPEC is empty on MinGW, so the declarations are identical
// and harmless in TUs that also include SDL.h.)
#ifndef FNWF_SDL_MAIN_EXTERN_H
#define FNWF_SDL_MAIN_EXTERN_H

#ifdef __cplusplus
extern "C" {
#endif

int SDL_main(int argc, char **argv);

#ifdef __cplusplus
}
#endif

#endif // FNWF_SDL_MAIN_EXTERN_H
