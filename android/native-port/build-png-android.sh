#!/usr/bin/env bash
# Build Tahoma2D's bundled libpng as an Android ARM64 static library.
# This is a compatibility step; bundled libpng 1.6.21 is not current.
set -Eeuo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 /path/to/tahoma2d-source /path/to/png-build /path/to/png-prefix" >&2
    exit 2
fi

SOURCE="$(realpath "$1")"
PNG_BUILD="$(realpath -m "$2")"
PNG_PREFIX="$(realpath -m "$3")"
PNG_SOURCE="$SOURCE/thirdparty/libpng-1.6.21"
: "${ANDROID_NDK_ROOT:?Android NDK required}"

if [ ! -f "$PNG_SOURCE/CMakeLists.txt" ] || \
   [ ! -f "$PNG_SOURCE/scripts/pnglibconf.h.prebuilt" ]; then
    echo "ERROR: bundled libpng-1.6.21 source or generated header template missing." >&2
    exit 2
fi

echo "=== Cross-compiling bundled libpng 1.6.21 for Android arm64-v8a ==="
cmake -S "$PNG_SOURCE" -B "$PNG_BUILD" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DPNG_SHARED=OFF \
    -DPNG_STATIC=ON \
    -DPNG_TESTS=OFF \
    -DSKIP_INSTALL_ALL=ON \
    -DPNG_FRAMEWORK=OFF

cmake --build "$PNG_BUILD" --target png16_static --parallel 2

PNG_ARCHIVE="$PNG_BUILD/libpng16.a"
if [ ! -s "$PNG_ARCHIVE" ]; then
    echo "ERROR: Android libpng16.a not generated: $PNG_ARCHIVE" >&2
    exit 3
fi
if [ ! -f "$PNG_BUILD/pnglibconf.h" ]; then
    echo "ERROR: generated pnglibconf.h missing." >&2
    exit 3
fi

install -d "$PNG_PREFIX/lib" "$PNG_PREFIX/include"
install -m 644 "$PNG_ARCHIVE" "$PNG_PREFIX/lib/libpng16.a"
install -m 644 \
    "$PNG_SOURCE/png.h" \
    "$PNG_SOURCE/pngconf.h" \
    "$PNG_BUILD/pnglibconf.h" \
    "$PNG_PREFIX/include/"

NDK_READ_ELF="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"
if ! "$NDK_READ_ELF" -h "$PNG_PREFIX/lib/libpng16.a" | grep AArch64 > /dev/null; then
    echo "ERROR: libpng archive is not compiled for Android AArch64." >&2
    exit 3
fi

echo "PASS: Android ARM64 libpng: $PNG_PREFIX/lib/libpng16.a"
