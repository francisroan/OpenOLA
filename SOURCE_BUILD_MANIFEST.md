# Source and build manifest

This file describes the source archives published under `source/` and how to build each project after extraction. The source archives preserve the project directories; markdown alone does not make an app buildable.

Download and extract the archive for the project you want to build. Paths below are relative to the extracted project directory unless stated otherwise:

- Windows desktop: `source/openola-windows-desktop-source.zip` → `windows-desktop/`
- Kotlin Android: `source/openola-android-kotlin-source.zip` → `android-kotlin/`
- Flutter mobile: `source/openola-flutter-mobile-source.zip` → `mobile/`
- Shared references: `source/openola-shared-source.zip` → `shared/`

Use the source from the same workspace revision as the build. Record the commit ID and artifact hash for every published build.

## 1. Windows desktop GUI

Copy:

- 30_scooter_gui.cmd
- tools/start_scooter_gui.ps1
- tool/scooter_gui.py
- tool/scooter_backend.py
- tool/scooter_glass.py
- tool/status_monitor.py
- tool/command_trace.py
- tool/learning_gui.py
- tool/signal_learning.py
- tool/health_dashboard.py
- tool/diagnostic_pages.py
- tool/hmi_commands.py
- tool/oladiag/ source modules and its requirements file
- tool/glass/ source modules used by the GUI
- tool/tests/ mock and GUI tests
- BUILD.md
- the sanitized DTC/DBC/ODX catalogs required by the app

The staged desktop source includes the current tool modules. The source workspace's older full GUI guide is not part of the public package; the current feature inventory and open issues are summarized in the repository root `RESEARCH_COMPARISON.md` and `VALIDATION_PLAN.md`.

Build prerequisites: Windows 10/11, Python 3.12 x64 with Tcl/Tk, and internet access for first-run dependency installation. From the extracted `windows-desktop/` directory, double-click `SETUP_AND_LAUNCH.cmd`; it creates a local virtual environment, installs `tool/oladiag/requirements.txt`, and starts the glass GUI. Later, double-click `30_scooter_gui.cmd`. See `GUI_README.md` and `BUILD.md`; do not commit `tool/gui_vendor/` wheels as the dependency source of record.

## 2. Kotlin Android app

Copy the complete Gradle project structure:

- apk/settings.gradle.kts
- apk/build.gradle.kts
- apk/gradle.properties
- apk/gradlew and apk/gradlew.bat
- apk/gradle/wrapper/
- apk/app/build.gradle.kts
- apk/app/proguard-rules.pro
- apk/app/src/main/ including Kotlin source, AndroidManifest.xml, resources, assets, and proto/
- apk/app/src/test/ and apk/app/src/androidTest/
- apk/SETUP.md and apk/THIRD_PARTY_UI.md

Build prerequisites: JDK 17, Android Studio/Android SDK, Android Gradle Plugin and Kotlin versions pinned in Gradle, plus network access for the first dependency resolution. Use the Gradle wrapper so the project selects its pinned Gradle version.

Windows build: open the extracted `android-kotlin/apk/` in Android Studio and build the debug APK, or run `gradlew.bat assembleDebug` from that directory after Android Studio has configured the local Android SDK. The output is under `app/build/outputs/apk/debug/`.

Before committing, inspect app/src/main/assets/certs/. Do not publish ecos.key, any private signing key, account material, or vehicle credentials. A build using mTLS must receive an explicitly authorized development identity outside the public repository; never substitute a live/vendor identity.

## 3. Flutter OpenOLA

Copy:

- mobile/pubspec.yaml and mobile/pubspec.lock
- mobile/analysis_options.yaml
- mobile/lib/
- mobile/proto/ and mobile/lib/generated/
- mobile/assets/ required by pubspec.yaml, with approved non-secret data only
- mobile/android/ and its Gradle wrapper/configuration
- mobile/ios/ and workspace/project files when offering iOS
- mobile/test/
- mobile/tools/ required for generation or identity preparation
- mobile/BUILD.md, mobile/DESKTOP_PARITY.md, and mobile/THIRD_PARTY.md

Build prerequisites: Flutter 3.47.6 and Dart 3.13.5 per the recorded validation, JDK 17, Android SDK Platform 37, Android NDK 28.2.13676358, and the pinned dependencies. The project README records Flutter build fixes and platform notes. iOS builds require macOS and Xcode.

Android build from the extracted `mobile/` directory: run `flutter pub get`, then `flutter build apk --release`. The output is under `build/app/outputs/flutter-apk/`. iOS requires macOS/Xcode and a development team configured in Xcode.

The APK is committed at `source/apk/OpenOLA-0.4.0-preview-arm64-v8a.apk`, so `git clone` downloads it with the source archives. It is a debug-signed preview for Android 8.0+ (API 26+), arm64-v8a. It excludes local mTLS identity assets; secure vehicle Wi-Fi diagnostics therefore require an authorized identity configured locally before use. The preview is not a store-ready release and has not been validated on a physical scooter. Verify its SHA-256 and signing certificate against `source/apk/README.md` before installation.

The original local artifact is not published because it contained private identity material. The public preview is built from the curated source archive after removing the private asset declaration; record its build provenance and signing fingerprint in `source/apk/README.md`.

Inspect mobile/assets/certs/ before committing. Never publish private keys, local signing material, vehicle IDs, personal captures, or credentials.

## 4. Legacy Android source

Keep android/ outside the active build sections unless the contribution explicitly documents history. If included, label it LEGACY and provide its own pinned source revision and build prerequisites. Do not mix its app ID/version with apk/ or mobile/.

## 5. Shared files and exclusions

Include only files needed to build or review the selected project. Do not copy the entire workspace.

Exclude:

- captures/ and any personal logs/screenshots/recordings
- private keys, signing keys, certificates that grant live access, and account data
- local.properties, IDE caches, generated build/ directories, installed APKs unless they are reviewed release artifacts
- VINs, device addresses, Wi-Fi SSIDs/passwords, tokens, private endpoints, or raw logs with identifying data
- dependency vendor caches such as tool/gui_vendor/ unless separately audited and intentionally vendored

For debug/release artifacts, record SHA-256, signing certificate fingerprint, source revision, build command, OS/toolchain, and exact device/model/build used to validate.

## 6. Artifact choices

- Source-only: include source, Gradle/Flutter files, manifests, dependency locks, synthetic demo data, and validation docs. This is the recommended first GitHub contribution.
- Debug APK: attach only after checking the exact APK, package permissions, signing key, bundled assets, dependency licenses, and physical-device behavior.
- Release APK: requires a project-owned release key and a source/build provenance record. Never distribute an APK signed with a personal or vendor key.
- Desktop package: provide source plus a clean install recipe; do not bundle private captures or a preconfigured vehicle address.
