#!/usr/bin/env bash
# Build the bundled SuperLU 4.1 C sources and its reference CBLAS
# for Android ARM64. No host Linux or prebuilt Windows libraries.
set -Eeuo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 /path/to/tahoma2d-source /path/to/superlu-build /path/to/superlu-prefix" >&2
    exit 2
fi

SOURCE="$(realpath "$1")"
BUILD="$(realpath -m "$2")"
PREFIX="$(realpath -m "$3")"
SUPERLU_SOURCE="$SOURCE/thirdparty/superlu/SuperLU_4.1"
: "${ANDROID_NDK_ROOT:?Android NDK required}"

if [ ! -f "$SUPERLU_SOURCE/SRC/Makefile" ] || \
   [ ! -f "$SUPERLU_SOURCE/CBLAS/Makefile" ] || \
   [ ! -f "$SUPERLU_SOURCE/include/slu_Cnames.h" ]; then
    echo "ERROR: bundled SuperLU 4.1 sources are missing." >&2
    exit 2
fi

# Legacy SuperLU Makefiles generate .o files inside their source directories.
# Work on a private copy so the checked-out feature branch stays unmodified.
mkdir -p "$BUILD" "$PREFIX/lib" "$PREFIX/include"
cp -a "$SUPERLU_SOURCE" "$BUILD/source"
WORK="$BUILD/source"
mkdir -p "$WORK/lib"

LLVM_BIN="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
CC="$LLVM_BIN/aarch64-linux-android24-clang"
AR="$LLVM_BIN/llvm-ar"
RANLIB="$LLVM_BIN/llvm-ranlib"
READELF="$LLVM_BIN/llvm-readelf"
for executable in "$CC" "$AR" "$RANLIB" "$READELF"; do
    if [ ! -x "$executable" ]; then
        echo "ERROR: NDK tool missing: $executable" >&2
        exit 2
    fi
done

# Bundled SuperLU 4.1 has no modern CMake project. Its Makefiles can
# compile all four numeric precisions with Clang. Disable USE_VENDOR_BLAS
# so the bundled reference CBLAS provides the necessary Level 1/2 routines.
COMMON=(
    "CC=$CC"
    "ARCH=$AR"
    "ARCHFLAGS=cr"
    "RANLIB=$RANLIB"
    "BLASDEF="
    "CDEFS=-DAdd_"
    "CFLAGS=-O2 -fPIC -DPRNTlevel=0 -I../include -I../SRC"
    "NOOPTS=-O0 -fPIC -I../include -I../SRC"
    "SUPERLULIB=$WORK/lib/libsuperlu_4.1.a"
    "BLASLIB=$WORK/lib/libblas.a"
)

echo "=== Cross-compiling SuperLU 4.1 and reference CBLAS for Android arm64-v8a ==="
# Each precision updates the same .a file; serialize the four targets
# to avoid concurrent llvm-ar writes while retaining parallel object builds.
for precision in single double complex complex16; do
    make -C "$WORK/CBLAS" --jobs=2 "${COMMON[@]}" "$precision"
done
for precision in single double complex complex16; do
    make -C "$WORK/SRC" --jobs=2 "${COMMON[@]}" "$precision"
done

SUPERLU_ARCHIVE="$WORK/lib/libsuperlu_4.1.a"
BLAS_ARCHIVE="$WORK/lib/libblas.a"
if [ ! -s "$SUPERLU_ARCHIVE" ] || [ ! -s "$BLAS_ARCHIVE" ]; then
    echo "ERROR: expected SuperLU or CBLAS archive was not generated." >&2
    exit 3
fi

install -m 644 "$SUPERLU_ARCHIVE" "$PREFIX/lib/libsuperlu_4.1.a"
install -m 644 "$BLAS_ARCHIVE" "$PREFIX/lib/libblas.a"
find "$SUPERLU_SOURCE/include" -maxdepth 1 -type f -name '*.h' \
    -exec install -m 644 {} "$PREFIX/include/" \;

for archive in "$PREFIX/lib/libsuperlu_4.1.a" "$PREFIX/lib/libblas.a"; do
    if ! "$READELF" -h "$archive" | grep AArch64 > /dev/null; then
        echo "ERROR: $archive is not an Android ARM64 archive." >&2
        exit 3
    fi
done
echo "PASS: ARM64 SuperLU and bundled reference CBLAS built."
echo "Note: SuperLU 4.1 is legacy code and needs an upgrade/security review."
