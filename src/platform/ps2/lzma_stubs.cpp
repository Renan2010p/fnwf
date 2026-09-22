// lzma_stubs.cpp — link-time stubs for liblzma (xz).
//
// ps2sdk-ports ships libSDL_image.a as an amalgamation that embeds libtiff.a.
// SDL_image's loader table always references the TIFF loader (IMG.c), which
// pulls in libtiff, whose LZMA codec object (tif_lzma.c.obj) references six
// liblzma symbols — and ps2sdk-ports does not build liblzma for the EE at
// all. Resolving those references from anywhere else is impossible, so we
// define them here.
//
// The game only ever decodes PNG (BMP as fallback): the TIFF codec is never
// invoked, so these functions are dead code that exists purely to satisfy
// the linker. They must have C linkage; the parameter types only need to be
// link-compatible (they are never called).

extern "C" {

// lzma_ret: LZMA_OK = 0, LZMA_STREAM_END = 1. Report "finished" — if the
// codec were ever reached, callers would take their error path.
int lzma_code(void* strm, int action) {
    (void)strm;
    (void)action;
    return 1;
}

void lzma_end(void* strm) {
    (void)strm;
}

int lzma_stream_encoder(void* strm, const void* filters, int check) {
    (void)strm;
    (void)filters;
    (void)check;
    return 1;
}

int lzma_stream_decoder(void* strm, unsigned long long memlimit, unsigned int flags) {
    (void)strm;
    (void)memlimit;
    (void)flags;
    return 1;
}

int lzma_lzma_preset(void* options, unsigned int preset) {
    (void)options;
    (void)preset;
    return 1;
}

unsigned long long lzma_memusage(const void* strm) {
    (void)strm;
    return 0;
}

}  // extern "C"
