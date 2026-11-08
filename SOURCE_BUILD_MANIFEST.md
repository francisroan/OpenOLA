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
- the DBC and live-parameter catalogs included in the public app
- `tool/oladiag/config/live_parameters.json` and both S1X phase maps used by the read-only signal/reference catalog

The staged desktop source includes the current tool modules. S1X CAN entries are compared with already-decoded live rows; UDS map rows without an explicit DID remain reference-only. The external ODX data extracted from the factory app is not redistributed. Without an authorized local ODX copy, ODX-backed UDS catalog rows, repair definitions, and related demo responses are unavailable; the desktop GUI still launches and its other bundled functions remain available. The source workspace's older full GUI guide is not part of the public package; the current feature inventory and open issues are summarized in `RESEARCH_COMPARISON.md` and `VALIDATION_PLAN.md`.

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

The older Kotlin app release has no embedded client identity. Its separate credential policy remains unchanged.

## 3. Flutter OpenOLA

Copy:

- mobile/pubspec.yaml and mobile/pubspec.lock
- mobile/analysis_options.yaml
- mobile/lib/
- mobile/proto/ and mobile/lib/generated/
- mobile/assets/ required by pubspec.yaml, including diagnostic certificate/key assets in Public 0.5.19 as explicitly chosen by the project owner
- mobile/android/ and its Gradle wrapper/configuration
- mobile/ios/ and workspace/project files when offering iOS
- mobile/test/
- mobile/tools/ required for generation or identity preparation
- mobile/BUILD.md, mobile/DESKTOP_PARITY.md, and mobile/THIRD_PARTY.md
- mobile/MODEL_DIAGNOSTICS.md and the included S1X Phase 1/2 read-only parameter maps

Build prerequisites: Flutter 3.47.6 and Dart 3.13.5 per the recorded validation, JDK 17, Android SDK Platform 37, Android NDK 28.2.13676358, and the pinned dependencies. The project README records Flutter build fixes and platform notes. iOS builds require macOS and Xcode.

Android build from the extracted `mobile/` directory: run `flutter pub get`, then `flutter build apk --release`. The output is under `build/app/outputs/flutter-apk/`. iOS requires macOS/Xcode and a development team configured in Xcode.

The current APK is `source/apk/OpenOLA-0.5.19-public-arm64-v8a.apk`; 0.4.2 is retained as a previous preview. Version 0.5.19 bundles the client identity needed for mTLS, including a private key that can be extracted and reused by APK recipients. This is an intentional owner decision for this release. Verify the artifact hash in `source/apk/README.md` before installation.

The 0.5.19 APK was built from the current Flutter source archive. It is debug-signed for community distribution, not a store release. Its owner installed it on a OnePlus CPH2573IN; scooter-side validation of this exact build is not recorded.

Do not add personal captures, personal vehicle identifiers, Wi-Fi passwords, signing keys, or account credentials. The shared diagnostic client identity in 0.5.19 is a documented exception explicitly requested by the project owner; it can be reused by people who download the public package.

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
