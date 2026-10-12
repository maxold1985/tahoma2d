# Japanese Registration Peg Bar: Android input and porting status

This branch adds touchscreen/stylus support to Tahoma2D's registration guides.
It does **not** yet produce a native Android APK for the entire editor.

## Available in the Qt 5 Viewer

- One-finger drag: translate a visible registration guide.
- Two-finger gesture: translate and rotate the guide; the gesture is committed once the fingers are released.
- Canceled gestures: restore the visual guide's previous position/angle without committing a scene transform.
- Stylus (QTabletEvent): pen tip drags the guide. Shift or a secondary pen button requests rotation when Qt maps it to Qt::RightButton.
- Mouse: original drag and Shift+drag input remains supported.
- Enlarged touch hit band on Android and a rotated hit mask avoid swallowing unrelated canvas touches.
- The Android Viewer shows a touch-sized Peg Bar menu button. It uses the existing SceneViewerContextMenu.

S Pen button mapping is provided by Qt/Android and varies with firmware; every device is not guaranteed to deliver a right-button QTabletEvent.

On a Linux/Termux:X11 build, set TAHOMA_PEG_TOUCH_UI=1 before launching the editor to show the larger touch hit band and a Peg Bar menu button even though Qt identifies the runtime as Linux. This does not solve dependencies or OpenGL compatibility needed to build the editor in Termux.

## Native Android application (not complete)

The main Tahoma2D CMake project currently configures Windows, macOS and generic Unix targets, not a packaged Android application. A complete Android port requires:

1. Qt 5 modules built for Android, Android SDK/NDK, CMake cross-build, androiddeployqt, Android manifest.
2. Audit of third-party dependencies and desktop-only components for Android ABI compatibility.
3. A GLES renderer or a validated OpenGL compatibility layer. SceneViewer::resizeGL calls glMatrixMode and glOrtho, which do not exist in OpenGL ES 2/3.
4. Android-compatible file storage, asset access and app lifecycle.
5. Device testing of rendering, touch, stylus, Undo/Redo and scene persistence.

**The current workflow does not build or distribute an APK.** It compiles Qt 5 Widgets tests on Linux and simulates touchscreen events. That validates input code, not Android driver compatibility.

## Run Qt5 input smoke test (Linux)

Run from the repository root with Qt5 Widgets development headers installed:

~~~bash
g++ -std=c++17 -fPIC -Wall -Wextra \
  toonz/tests/pegbar_android_input_smoke.cpp \
  -o /tmp/pegbar-input-smoke \
  $(pkg-config --cflags --libs Qt5Widgets)
QT_QPA_PLATFORM=offscreen /tmp/pegbar-input-smoke
~~~

See .github/workflows/pegbar-input.yml for the CI job.
