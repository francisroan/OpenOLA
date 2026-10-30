# Flutter OpenOLA build

Requirements recorded by the project: Flutter 3.47.6, Dart 3.13.5, JDK 17, Android SDK Platform 37, and Android NDK 28.2.13676358. Resolve the pinned dependencies from this directory with `flutter pub get`; build Android with `flutter build apk --release`. The output is under `build/app/outputs/flutter-apk/` and is generated locally, not included here.

The public source excludes local mTLS identity files. Consequently, secure vehicle Wi-Fi diagnostics cannot be used until an authorized development identity is provisioned locally. Do not add identity or signing files to this source archive. The community APK is a debug-signed preview and has not been validated on a physical scooter.

Building iOS requires macOS and Xcode. Keep signing identities, local configuration, and generated build output outside version control. The repository root `SOURCE_BUILD_MANIFEST.md` and `VALIDATION_PLAN.md` record the source map and remaining checks.
