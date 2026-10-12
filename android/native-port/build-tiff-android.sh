#!/usr/bin/env bash
# Build the exact patched libTIFF shipped with Tahoma2D for Android ARM64.
# Upstream libTIFF lacks the Tahoma2D-specific 64-bit RGBA read APIs.
# This is an interim port dependency: libTIFF 4.2.0 needs security review
# and an updated/compatible implementation before a production release.
set -Eeuo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 /path/to/tahoma2d-source /path/to/tiff-build /path/to/tiff-prefix" >&2
    exit 2
fi

SOURCE="$(realpath "$1")"
TIFF_BUILD="$(realpath -m "$2")"
TIFF_PREFIX="$(realpath -m "$3")"
TIFF_SOURCE="$SOURCE/thirdparty/tiff-4.2.0"
: "${ANDROID_NDK_ROOT:?Android NDK required}"
: "${ANDROID_SDK_ROOT:?Android SDK required}"

if [ ! -f "$TIFF_SOURCE/libtiff/tiffio.h" ] || \
   [ ! -f "$TIFF_SOURCE/CMakeLists.txt" ]; then
    echo "ERROR: Tahoma2D's modified thirdparty/tiff-4.2.0 source is missing." >&2
    exit 2
fi
if ! grep -q 'TIFFReadRGBATile_64' "$TIFF_SOURCE/libtiff/tiffio.h"; then
    echo "ERROR: libTIFF lacks Tahoma2D-specific 64-bit RGBA API." >&2
    exit 2
fi

echo "=== Building Tahoma2D bundled modified libTIFF 4.2.0 for arm64-v8a ==="
cmake -S "$TIFF_SOURCE" -B "$TIFF_BUILD" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -Dld-version-script=OFF \
    -Dzlib=ON \
    -Dlibdeflate=OFF \
    -Djpeg=OFF \
    -Dold-jpeg=OFF \
    -Djpeg12=OFF \
    -Djbig=OFF \
    -Dlzma=OFF \
    -Dzstd=OFF \
    -Dwebp=OFF \
    -Dcxx=OFF

# Build only the library: legacy libTIFF 4.2.0 also defines desktop tools,
# tests and viewers which must not be built for the Android target.
cmake --build "$TIFF_BUILD" --target tiff --parallel 2

TIFF_ARCHIVE="$TIFF_BUILD/libtiff/libtiff.a"
if [ ! -s "$TIFF_ARCHIVE" ]; then
    echo "ERROR: expected Android libtiff.a at $TIFF_ARCHIVE" >&2
    exit 3
fi

# Stage the original Tahoma2D TIFF headers and CMake-generated tiffconf.h.
# No host-system TIFF headers or x86_64 libraries are used.
install -d "$TIFF_PREFIX/lib" "$TIFF_PREFIX/include"
install -m 644 "$TIFF_ARCHIVE" "$TIFF_PREFIX/lib/libtiff.a"
install -m 644 \
    "$TIFF_SOURCE/libtiff/tiff.h" \
    "$TIFF_SOURCE/libtiff/tiffio.h" \
    "$TIFF_SOURCE/libtiff/tiffvers.h" \
    "$TIFF_BUILD/libtiff/tiffconf.h" \
    "$TIFF_PREFIX/include/"

# Confirm at least one object inside the static archive targets AArch64.
NDK_READ_ELF="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"
if ! "$NDK_READ_ELF" -h "$TIFF_PREFIX/lib/libtiff.a" | grep -q AArch64; then
    echo "ERROR: compiled libTIFF archive is not Android AArch64." >&2
    exit 3
fi
echo "PASS: Tahoma2D-specific ARM64 libTIFF: $TIFF_PREFIX/lib/libtiff.a"
echo "Note: JPEG-in-TIFF codec is not yet enabled; Android libjpeg is a separate port task."
