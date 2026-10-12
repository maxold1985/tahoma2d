# Android APK - Japanese Registration Peg Bar preview

The ONLY active GitHub Actions workflow is .github/workflows/android-apk.yml.
It builds a small Android Peg Bar interaction **preview app** (not the full
Tahoma2D editor). The APK supports 1-finger and S Pen translation, two-finger
rotation, three registration bars, Undo/Redo, reset and ghost overlays.

Use GitHub Actions -> Android APK - Peg Bar Preview -> Run workflow, or commit
the files in this directory to master. After a successful run, download the
artifact Tahoma2D-PegBar-Android-Preview-APK (app-debug.apk).
The debug APK is suitable for local device testing, not a signed release.

Locally: install JDK 17, Android SDK platform 35 and build tools 35,
plus Gradle 8.10.2; run Gradle task :app:assembleDebug in this directory.

Original desktop/test/cleanup workflow files are retained under
.github/workflows-disabled so GitHub Actions no longer recognizes them.

A full Tahoma2D Android port is NOT complete. Its legacy desktop OpenGL,
Qt/C++ UI and dependencies require separate Android/GLES adaptation. The
independent prototype does not build the Tahoma2D editor.
