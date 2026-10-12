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
