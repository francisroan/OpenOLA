# Source and build manifest

The source projects are published as ZIP archives under `source/`. Download the archive for the project you want, extract it, and build from the project folder listed below. These archives contain the curated source and build configuration; they do not contain compiled APKs, private signing keys, local vehicle captures, or dependency caches. Review the extracted files before building.

Use one source revision throughout a build. Record the repository commit, archive SHA-256, build command, OS/toolchain versions, APK/package hash, and validation device/build with each distributed artifact.

## Windows desktop GUI

Archive: `source/openola-windows-desktop-source.zip`

The archive contains `windows-desktop/`, including `30_scooter_gui.cmd`, PowerShell launcher, GUI/backend modules, `tool/oladiag/` and its requirements, glass UI modules, tests, build notes, and sanitized catalogs.

Prerequisites: Windows 10/11, Python 3.12 x64 with Tcl/Tk, plus the packages in `tool/oladiag/requirements.txt`. From `windows-desktop/`, run `30_scooter_gui.cmd`. See `BUILD.md`. Do not commit `tool/gui_vendor/` wheels as the dependency source of record.

## Kotlin Android app

Archive: `source/openola-android-kotlin-source.zip`

The archive contains `android-kotlin/apk/`: Gradle settings/properties, wrapper, app configuration, Kotlin source, manifest, resources/assets/proto, tests, setup notes, and third-party UI notes.

Prerequisites: JDK 17, Android Studio/Android SDK, and the Android Gradle Plugin/Kotlin versions pinned in Gradle. Open `apk/` in Android Studio and build a debug APK, or run `gradlew.bat assembleDebug` from `apk/` after configuring the Android SDK. Output: `app/build/outputs/apk/debug/`.

Inspect `app/src/main/assets/certs/` before contributing. Never publish `ecos.key`, private signing keys, account data, or live vehicle credentials. Any mTLS development identity must be separately authorized and kept outside the public repository.

## Flutter OpenOLA

Archive: `source/openola-flutter-mobile-source.zip`

The archive contains the active `mobile/` project: `pubspec.yaml` and lockfile, Dart sources, generated protocol files, assets, Android Gradle configuration, iOS project files, tests, and build/third-party documentation. The active phone source is 0.4.0+9.

Prerequisites recorded for the source: Flutter 3.47.6, Dart 3.13.5, JDK 17, Android SDK Platform 37, Android NDK 28.2.13676358. From `mobile/`, run `flutter pub get`, then `flutter build apk --release`. Output: `build/app/outputs/flutter-apk/`. iOS builds require macOS, Xcode, and a configured development team.

Inspect `assets/certs/`; do not publish private keys, local signing material, vehicle IDs, owner captures, or credentials. A successful build does not prove behavior on a physical scooter.

## Shared repair references

Archive: `source/openola-shared-source.zip`. It contains sanitized catalog/reference files used across the repair tools. Keep original provenance and license status with any updates.

## Exclusions and release evidence

Do not commit personal captures/logs, VINs or device addresses, Wi-Fi credentials, tokens, private endpoints, live certificates/keys, local.properties, IDE caches, generated build directories, or APKs unless each release artifact is separately reviewed and intentionally published.

For any APK or desktop package, record SHA-256, source commit, build command, operating system/toolchain, dependency status, signing fingerprint where applicable, exact scooter model/build, and the tests actually completed. Keep source inspection, protocol observations, ECU/service acceptance, physical effect, and independent replication labeled separately.
