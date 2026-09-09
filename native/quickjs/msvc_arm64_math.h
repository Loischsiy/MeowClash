/*
 * MSVC compiles part of <math.h> as __forceinline wrappers around ARM64
 * instructions. QuickJS builds its Math table with a static initializer that
 * stores the address of those libm functions, and the MSVC C frontend does not
 * accept the address of such an inline function as a constant expression:
 *
 *   quickjs.c(41964,35): error C2099: initializer is not a constant
 *
 * The x64 build of the very same source succeeds, so this is a windows-arm64
 * only defect. This header is force-included (/FI) into the C sources of the
 * bridge and routes every libm symbol that table references through a real
 * function with a stable address. It expands to nothing on x64 MSVC, on the
 * C++ bridge file and on every non-MSVC toolchain, so no other target changes.
 */
#ifndef MEOW_QUICKJS_MSVC_ARM64_MATH_H
#define MEOW_QUICKJS_MSVC_ARM64_MATH_H

/* MEOW_QUICKJS_FORCE_MATH_SHIM exists so the wrappers can be compiled and
 * checked on a non-Windows host. The build system also force-includes this
 * header target-wide, so it must expand to nothing in the C++ bridge file:
 * redirecting <math.h> names there would break the C++ overloads. */
#if !defined(__cplusplus) &&                                                   \
    (defined(MEOW_QUICKJS_FORCE_MATH_SHIM) ||                                  \
     (defined(_MSC_VER) && (defined(_M_ARM64) || defined(_M_ARM64EC))))

#if defined(_MSC_VER)
/* quickjs.c includes <WinSock2.h> after <math.h>. Pull the platform headers in
 * first so that no Windows declaration is ever rewritten by the macros below. */
#include <WinSock2.h>
#pragma warning(disable : 4505) /* unreferenced local function was removed */
#endif

#include <math.h>

#define MEOW_QJS_MATH_WRAP1(fn)                                                \
  static double meow_qjs_##fn(double x) { return fn(x); }
#define MEOW_QJS_MATH_WRAP2(fn)                                                \
  static double meow_qjs_##fn(double x, double y) { return fn(x, y); }

MEOW_QJS_MATH_WRAP1(acos)
MEOW_QJS_MATH_WRAP1(acosh)
MEOW_QJS_MATH_WRAP1(asin)
MEOW_QJS_MATH_WRAP1(asinh)
MEOW_QJS_MATH_WRAP1(atan)
MEOW_QJS_MATH_WRAP1(atanh)
MEOW_QJS_MATH_WRAP1(cbrt)
MEOW_QJS_MATH_WRAP1(ceil)
MEOW_QJS_MATH_WRAP1(cos)
MEOW_QJS_MATH_WRAP1(cosh)
MEOW_QJS_MATH_WRAP1(exp)
MEOW_QJS_MATH_WRAP1(expm1)
MEOW_QJS_MATH_WRAP1(fabs)
MEOW_QJS_MATH_WRAP1(floor)
MEOW_QJS_MATH_WRAP1(log)
MEOW_QJS_MATH_WRAP1(log10)
MEOW_QJS_MATH_WRAP1(log1p)
MEOW_QJS_MATH_WRAP1(log2)
MEOW_QJS_MATH_WRAP1(sin)
MEOW_QJS_MATH_WRAP1(sinh)
MEOW_QJS_MATH_WRAP1(sqrt)
MEOW_QJS_MATH_WRAP1(tan)
MEOW_QJS_MATH_WRAP1(tanh)
MEOW_QJS_MATH_WRAP1(trunc)
MEOW_QJS_MATH_WRAP2(atan2)

/* Redirect the names only after every wrapper is defined, so the wrappers
 * themselves keep calling the real libm implementation. */
#define acos meow_qjs_acos
#define acosh meow_qjs_acosh
#define asin meow_qjs_asin
#define asinh meow_qjs_asinh
#define atan meow_qjs_atan
#define atanh meow_qjs_atanh
#define cbrt meow_qjs_cbrt
#define ceil meow_qjs_ceil
#define cos meow_qjs_cos
#define cosh meow_qjs_cosh
#define exp meow_qjs_exp
#define expm1 meow_qjs_expm1
#define fabs meow_qjs_fabs
#define floor meow_qjs_floor
#define log meow_qjs_log
#define log10 meow_qjs_log10
#define log1p meow_qjs_log1p
#define log2 meow_qjs_log2
#define sin meow_qjs_sin
#define sinh meow_qjs_sinh
#define sqrt meow_qjs_sqrt
#define tan meow_qjs_tan
#define tanh meow_qjs_tanh
#define trunc meow_qjs_trunc
#define atan2 meow_qjs_atan2

#endif /* windows-arm64 */
#endif /* MEOW_QUICKJS_MSVC_ARM64_MATH_H */
