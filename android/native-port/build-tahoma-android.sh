#!/usr/bin/env bash
# This script builds genuine Tahoma2D C++ source. It never invokes the Java
# Peg Bar preview, and it never publishes a stub APK.
set -Eeuo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 /path/to/tahoma2d-source /path/to/android-build" >&2
    exit 2
fi

SRC="$(realpath "$1")"
BUILD="$(realpath -m "$2")"
REPORT="$REPORT_DIR"
mkdir -p "$REPORT" "$BUILD"
exec > >(tee "$REPORT/native-build.log") 2>&1

finish() {
    code="$?"
    {
        echo "# Android ARM64: native Tahoma2D build report"
        echo
        echo "Source: $SRC"
        echo "Build directory: $BUILD"
        echo "Exit code: $code"
        echo
        echo "Only the real C++ editor is built. Check native-build.log and"
        echo "CMakeCache.txt for Android dependency and GLES port blockers."
    } > "$REPORT/result.md"
    if [ -n "$GITHUB_STEP_SUMMARY" ]; then
        cat "$REPORT/result.md" >> "$GITHUB_STEP_SUMMARY"
    fi
}
trap finish EXIT

echo "=== Native Tahoma2D ARM64 cross-build, no Java demonstration ==="
echo "Source: $SRC"
echo "Android SDK: $ANDROID_SDK_ROOT"
echo "Android NDK: $ANDROID_NDK_ROOT"
echo "Qt Android: $QT_ANDROID_PREFIX"
echo "Build: $BUILD"

if [ ! -f "$SRC/toonz/sources/toonz/main.cpp" ] || \
   [ ! -f "$SRC/toonz/sources/CMakeLists.txt" ]; then
    echo "ERROR: the original native Tahoma2D editor sources are absent."
    exit 2
fi
if [ ! -f "$QT_ANDROID_PREFIX/lib/cmake/Qt5/Qt5Config.cmake" ] || \
   [ ! -f "$QT_ANDROID_PREFIX/lib/cmake/Qt5Script/Qt5ScriptConfig.cmake" ]; then
    echo "ERROR: Qt 5.15 Android with required QtScript module is absent."
    exit 2
fi
if [ ! -f "$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" ]; then
    echo "ERROR: Android NDK CMake toolchain is absent."
    exit 2
fi

echo "=== Installed Qt Android modules ==="
find "$QT_ANDROID_PREFIX/lib/cmake" -maxdepth 1 -mindepth 1 \
     -type d -name 'Qt5*' -printf '%f\n' | sort

# The Android NDK toolchain limits CMake package searches to the target
# sysroot. Explicit Qt5 module directories keep host Qt libraries out while
# allowing target Qt Android CMake packages to be discovered.
QT_CMAKE_ROOT="$QT_ANDROID_PREFIX/lib/cmake"
QT_MODULES=(
    Core Gui Network OpenGL Svg Xml Script Widgets PrintSupport
    LinguistTools Multimedia MultimediaWidgets SerialPort UiTools
)
QT_CMAKE_ARGS=()
missing=0
for module in "${QT_MODULES[@]}"; do
    module_dir="$QT_CMAKE_ROOT/Qt5$module"
    config="$module_dir/Qt5${module}Config.cmake"
    if [ ! -f "$config" ]; then
        echo "ERROR: missing Android Qt module: Qt5$module ($config)"
        missing=1
    else
        QT_CMAKE_ARGS+=("-DQt5${module}_DIR=$module_dir")
    fi
done
if [ "$missing" -ne 0 ]; then
    echo "ERROR: Qt Android installation is missing required Tahoma2D modules."
    exit 2
fi
QT_CMAKE_ARGS+=("-DQt5_DIR=$QT_CMAKE_ROOT/Qt5")

# The OpenCV Android SDK is a target-specific prebuilt distribution.
# Do not accidentally pick up Ubuntu's x86_64 OpenCV during cross-compile.
if [ -z "${OpenCV_DIR:-}" ] || [ ! -f "$OpenCV_DIR/OpenCVConfig.cmake" ]; then
    echo "ERROR: OpenCV_DIR must point to the Android OpenCVConfig.cmake directory."
    echo "Install the official OpenCV Android SDK for arm64-v8a first."
    exit 2
fi
echo "OpenCV Android package: $OpenCV_DIR"

# The custom FindTIFF.cmake only searches thirdparty desktop paths.
# Supply the compiled Tahoma2D-specific Android library and matching headers
# directly; never fall back to Ubuntu's host libTIFF.
if [ -z "${TIFF_ANDROID_PREFIX:-}" ] || \
   [ ! -s "$TIFF_ANDROID_PREFIX/lib/libtiff.a" ] || \
   [ ! -f "$TIFF_ANDROID_PREFIX/include/tiffio.h" ] || \
   [ ! -f "$TIFF_ANDROID_PREFIX/include/tiffconf.h" ]; then
    echo "ERROR: missing Tahoma2D modified libTIFF ARM64 build."
    echo "Cross-compile thirdparty/tiff-4.2.0 with build-tiff-android.sh first."
    exit 2
fi
echo "Tahoma2D Android libTIFF: $TIFF_ANDROID_PREFIX/lib/libtiff.a"

echo "=== Known unfinished native-port dependencies ==="
echo "The desktop editor still needs Android ARM64 builds of GLEW,"
echo "GLU/GLUT replacements, PNG, JPEG, SuperLU, libmypaint and"
echo "other external libraries. Legacy glMatrixMode/glBegin calls still"
echo "need a GLES3 implementation. The CMake errors show actual blockers."
echo "No preview APK will be substituted if configure/compile fails."

set -x
cmake -S "$SRC/toonz/sources" -B "$BUILD" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI=arm64-v8a \
    -DANDROID_PLATFORM=android-24 \
    -DANDROID_NATIVE_API_LEVEL=24 \
    -DANDROID_NDK="$ANDROID_NDK_ROOT" \
    -DANDROID_SDK="$ANDROID_SDK_ROOT" \
    -DANDROID_SDK_PLATFORM=android-30 \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_PREFIX_PATH="$QT_ANDROID_PREFIX" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=BOTH \
    -DOpenCV_DIR="$OpenCV_DIR" \
    -DTIFF_LIBRARY="$TIFF_ANDROID_PREFIX/lib/libtiff.a" \
    -DTIFF_INCLUDE_DIR="$TIFF_ANDROID_PREFIX/include" \
    "${QT_CMAKE_ARGS[@]}" \
    -DQT_PATH="$QT_ANDROID_PREFIX" \
    -DWITH_TRANSLATION=OFF \
    -DWITH_CANON=OFF \
    -DWITH_GPHOTO2=OFF
cmake --build "$BUILD" --target Tahoma2D --parallel 2
set +x

native="$(find "$BUILD" -type f -name 'libTahoma2D*.so' -print -quit)"
if [ -z "$native" ]; then
    echo "ERROR: genuine libTahoma2D*.so was not produced."
    exit 3
fi

"$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf" \
    -h "$native" | tee "$REPORT/native-elf-header.txt"
if ! grep -q AArch64 "$REPORT/native-elf-header.txt"; then
    echo "ERROR: native Tahoma2D library is not AArch64."
    exit 3
fi

# Qt 5 AndroidSupport's apk target runs androiddeployqt with the real
# linked Qt/C++ library. Do not call the old Gradle preview.
cmake --build "$BUILD" --target apk --parallel 2

apk="$(find "$BUILD/android-build" -type f -name '*.apk' -print -quit)"
if [ -z "$apk" ]; then
    echo "ERROR: Qt androiddeployqt did not produce an APK."
    exit 4
fi
if ! unzip -Z1 "$apk" | grep -Eq '^lib/arm64-v8a/libTahoma2D.*\.so$'; then
    echo "ERROR: APK is missing the actual ARM64 libTahoma2D shared library."
    exit 4
fi
echo "PASS: full-editor native Android APK: $apk"
