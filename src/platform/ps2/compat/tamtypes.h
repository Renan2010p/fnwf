/*
 * PS2SDK tamtypes.h compatibility header
 *
 * Workaround for GCC 15 + -mgp32: __attribute__((mode(TI))) is not available
 * when compiling with -mgp32 (128-bit integers can't be emulated).
 *
 * This header replaces the PS2SDK's tamtypes.h and uses 64-bit fallbacks
 * for u128/s128 types. Q-precision operations are emulated with 64-bit loads.
 */

#ifndef __TAMTYPES_H__
#define __TAMTYPES_H__

#if !defined(_EE) && !defined(_IOP)
#error Either _EE or _IOP must be defined!
#endif

typedef unsigned char u8;
typedef unsigned short u16;

typedef volatile u8 vu8;
typedef volatile u16 vu16;

#ifdef _EE
typedef unsigned int u32;
typedef unsigned long long u64;

/*
 * NOTE: GCC with -mgp32 cannot emulate __attribute__((mode(TI))) (128-bit).
 * We use u64 (64-bit) as a fallback. Q-precision load/store operations
 * are emulated with 4x u32 loads/stores in the inline functions below.
 */
typedef unsigned long long u128;

typedef volatile u32 vu32;
typedef volatile u64 vu64;
typedef volatile u128 vu128;
#endif

#ifdef _IOP
typedef unsigned long u32;
typedef unsigned long long u64;

typedef volatile u32 vu32;
typedef volatile u64 vu64;
#endif

typedef signed char s8;
typedef signed short s16;

typedef volatile s8 vs8;
typedef volatile s16 vs16;

#ifdef _EE
typedef signed int s32;
typedef signed long long s64;

typedef signed long long s128;

typedef volatile s32 vs32;
typedef volatile s64 vs64;
typedef volatile s128 vs128;
#endif

#ifdef _IOP
typedef signed long s32;
typedef signed long long s64;

typedef volatile s32 vs32;
typedef volatile s64 vs64;
#endif

/* Pointers are 32-bit on both EE and IOP. */
typedef u32 uiptr;
typedef s32 siptr;

typedef volatile u32 vuiptr;
typedef volatile s32 vsiptr;

#ifdef _EE
typedef union
{
    u128 qw;
    u8 b[16];
    u16 hw[8];
    u32 sw[4];
    u64 dw[2];
} qword_t;

#endif

#ifndef NULL
#define NULL (void *)0
#endif

static inline u8 _lb(u32 addr)
{
    return *(vu8 *)addr;
}
static inline u16 _lh(u32 addr) { return *(vu16 *)addr; }
static inline u32 _lw(u32 addr) { return *(vu32 *)addr; }

static inline void _sb(u8 val, u32 addr) { *(vu8 *)addr = val; }
static inline void _sh(u16 val, u32 addr) { *(vu16 *)addr = val; }
static inline void _sw(u32 val, u32 addr) { *(vu32 *)addr = val; }

#ifdef _EE
static inline u64 _ld(u32 addr)
{
    return *(vu64 *)addr;
}

/*
 * Emulated Q-precision load/store using 4x u32 operations.
 * Since u128 is only 64-bit with -mgp32, we load all 16 bytes
 * into a qword_t structure for maximum compatibility.
 */
static inline u128 _lq(u32 addr)
{
    u128 val;
    u32 *dst = (u32 *)&val;
    dst[0] = *(vu32 *)(addr);
    dst[1] = *(vu32 *)(addr + 4);
    dst[2] = *(vu32 *)(addr + 8);
    dst[3] = *(vu32 *)(addr + 12);
    return val;
}
static inline void _sd(u64 val, u32 addr) { *(vu64 *)addr = val; }
static inline void _sq(u128 val, u32 addr)
{
    u32 *src = (u32 *)&val;
    *(vu32 *)(addr)      = src[0];
    *(vu32 *)(addr + 4)  = src[1];
    *(vu32 *)(addr + 8)  = src[2];
    *(vu32 *)(addr + 12) = src[3];
}
#endif

#endif /* __TAMTYPES_H__ */
