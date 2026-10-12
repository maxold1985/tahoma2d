# Tahoma2D Android ARM64: actual C++ editor build

This is the native Tahoma2D C++ application build path, NOT the small Java
Peg Bar demonstration under android/pegbar-preview. The sole GitHub Actions
workflow at .github/workflows/android-apk.yml is manual-only on master.
It checks out feature/japanese-registration-pegbar-viewer by default so
the real C++ Peg Bar changes will be included when the native build works.

STATUS: Work in progress. A complete, working Tahoma2D Android APK
does not yet exist. Do not treat the Java preview as the full editor.

The Android CMake target now uses a Qt-loaded shared library built from
the actual sources, not a Java application. The build attempts to configure
and compile that native target for arm64-v8a and then calls androiddeployqt.
No APK artifact is published unless a real ELF AArch64 libTahoma2D is
linked and the generated APK contains that library.

Existing native build blockers include desktop-only dependencies such as
OpenCV, SuperLU, GLEW, libmypaint and GLU/GLUT, plus old fixed-function
OpenGL calls (glMatrixMode, glBegin, glOrtho) not available in GLES3.
Those require further code porting and arm64 third-party builds.

The manual workflow installs JDK 11, SDK 30, NDK r21e and Qt 5.15.2
Android including QtScript. It produces a diagnostic artifact even when
CMake fails. The Native-APK artifact is only produced on full success.

To run it: open GitHub Actions, choose Tahoma2D Android ARM64 -
Native C++ Port, select master and click Run workflow. The workflow
always checks out the Peg Bar feature branch as the real native source.
Never run the old Gradle project under android/pegbar-preview for a Tahoma2D APK.

Only one manually dispatched workflow exists; no push, PR or schedule
triggers. A constant concurrency group cancels older manual jobs if
another one is started.

Local invocation (after installing required tools and dependencies):

    export REPORT_DIR="$PWD/android-native-report"
    export QT_ANDROID_PREFIX="/path/to/Qt/5.15.2/android"
    export ANDROID_SDK_ROOT="/path/to/Android/sdk"
    export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/21.4.7075529"
    bash android/native-port/build-tahoma-android.sh . build/android-arm64

The script must be executed on Linux with CMake 3.30, Ninja,
Android Qt 5.15.2, QtScript, and arm64 third-party dependencies.
