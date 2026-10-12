#!/usr/bin/env bash
set -Eeuo pipefail
if [ "$#" -ne 3 ]; then echo "Usage: $0 SOURCE BUILD PREFIX" >&2; exit 2; fi
SOURCE="$(realpath "$1")"
BUILD="$(realpath -m "$2")"
PREFIX="$(realpath -m "$3")"
: "${ANDROID_NDK_ROOT:?missing Android NDK}"
LLVM="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"
TOOLCHAIN="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake"
export CC="$LLVM/aarch64-linux-android24-clang"
export CXX="$LLVM/aarch64-linux-android24-clang++"
export AR="$LLVM/llvm-ar"
export RANLIB="$LLVM/llvm-ranlib"
export CFLAGS="-O2 -fPIC"
export CXXFLAGS="-O2 -fPIC"
mkdir -p "$BUILD" "$PREFIX/lib/pkgconfig" "$PREFIX/include"
export PKG_CONFIG_PATH=
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"
export PKG_CONFIG_SYSROOT_DIR=
echo "Cross-compiling bundled LZ4 for Android ARM64"
LZ4="$SOURCE/thirdparty/Lz4/Lz4_131/lib"
mkdir -p "$BUILD/lz4"
objs=()
for unit in lz4 lz4hc lz4frame xxhash; do
    "$CC" -O2 -fPIC -DXXH_NAMESPACE=LZ4_ -I"$LZ4" -c "$LZ4/$unit.c" -o "$BUILD/lz4/$unit.o"
    objs+=("$BUILD/lz4/$unit.o")
done
"$AR" rcs "$PREFIX/lib/liblz4.a" "${objs[@]}"
"$RANLIB" "$PREFIX/lib/liblz4.a"
install -m 644 "$LZ4/"*.h "$PREFIX/include/"
printf 'prefix=%s\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\nName: liblz4\nDescription: Tahoma2D bundled LZ4\nVersion: 1.7.1\nLibs: -L${libdir} -llz4\nCflags: -I${includedir}\n' "$PREFIX" > "$PREFIX/lib/pkgconfig/liblz4.pc"

for tool in "$CC" "$CXX" "$AR" "$RANLIB" "$LLVM/llvm-readelf"; do
    test -x "$tool" || { echo "Missing NDK tool: $tool" >&2; exit 2; }
done
test -f "$TOOLCHAIN"
clone_tag() {
    if [ ! -d "$3/.git" ]; then
        git clone --depth 1 --branch "$2" "$1" "$3"
    fi
}
cmake_android() {
    cmake "$@" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 \
        -DCMAKE_BUILD_TYPE=Release -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib
}
echo "Cross-compiling bundled LZO 2.03 for Android ARM64"
test -f "$SOURCE/thirdparty/lzo/2.03/configure"
cp -a "$SOURCE/thirdparty/lzo/2.03" "$BUILD/lzo-source"
(
    cd "$BUILD/lzo-source"
    ./configure --host=aarch64-linux-android --prefix="$PREFIX" \
        --libdir="$PREFIX/lib" --disable-shared --enable-static
    make --jobs=2
    make install
)
test -s "$PREFIX/lib/liblzo2.a"
test -f "$PREFIX/include/lzo/lzoconf.h"
echo "Cross-compiling FreeType 2.13.3 for Android ARM64"
clone_tag https://github.com/freetype/freetype.git VER-2-13-3 "$BUILD/freetype-src"
cmake_android -S "$BUILD/freetype-src" -B "$BUILD/freetype-build" \
    -DBUILD_SHARED_LIBS=OFF -DFT_DISABLE_ZLIB=ON -DFT_DISABLE_BZIP2=ON \
    -DFT_DISABLE_PNG=ON -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_BROTLI=ON
cmake --build "$BUILD/freetype-build" --parallel 2
cmake --install "$BUILD/freetype-build"
test -s "$PREFIX/lib/libfreetype.a"
test -f "$PREFIX/lib/pkgconfig/freetype2.pc"
echo "Cross-compiling json-c 0.17 for Android ARM64"
clone_tag https://github.com/json-c/json-c.git json-c-0.17-20230812 "$BUILD/json-src"
cmake_android -S "$BUILD/json-src" -B "$BUILD/json-build" \
    -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -DBUILD_APPS=OFF \
    -DBUILD_TESTING=OFF -DDISABLE_WERROR=ON -DDISABLE_EXTRA_LIBS=ON
cmake --build "$BUILD/json-build" --parallel 2
cmake --install "$BUILD/json-build"
test -s "$PREFIX/lib/libjson-c.a"
test -f "$PREFIX/lib/pkgconfig/json-c.pc"
pkg-config --exists json-c
echo "Cross-compiling libmypaint 1.6.1 for Android ARM64"
clone_tag https://github.com/mypaint/libmypaint.git v1.6.1 "$BUILD/mypaint-src"
(
    cd "$BUILD/mypaint-src"
    PYTHON=python3 ./autogen.sh
)
mkdir -p "$BUILD/mypaint-build"
(
    cd "$BUILD/mypaint-build"
    "$BUILD/mypaint-src/configure" --host=aarch64-linux-android \
        --prefix="$PREFIX" --libdir="$PREFIX/lib" \
        --enable-static --disable-shared --disable-i18n \
        --disable-introspection --without-glib --disable-gegl
    make --jobs=2
    make install
)
test -s "$PREFIX/lib/libmypaint.a"
test -f "$PREFIX/lib/pkgconfig/libmypaint.pc"
echo "Checking ARM64 .pc modules and archive architectures"
for pc in liblz4 freetype2 json-c libmypaint; do
    pkg-config --exists "$pc"
    echo "$pc: $(pkg-config --modversion "$pc")"
done
for name in lz4 lzo2 freetype json-c mypaint; do
    archive="$PREFIX/lib/lib$name.a"
    test -s "$archive"
    "$LLVM/llvm-readelf" -h "$archive" | grep AArch64 >/dev/null || {
        echo "Not an AArch64 archive: $archive" >&2
        exit 3
    }
done
echo "PASS: ARM64 LZ4, LZO, FreeType, json-c and libmypaint"
