[BUILD.md](https://github.com/user-attachments/files/34189910/BUILD.md)
# Flutter OpenOLA build

Requirements recorded by the project: Flutter 3.47.6, Dart 3.13.5, JDK 17, Android SDK Platform 37, and Android NDK 28.2.13676358. Resolve the pinned dependencies from this directory with `flutter pub get`; build Android with `flutter build apk --release`. The output is under `build/app/outputs/flutter-apk/` and is generated locally, not included here.

Building iOS requires macOS and Xcode. Keep signing identities, local configuration, and generated build output outside version control. The repository root `SOURCE_BUILD_MANIFEST.md` and `VALIDATION_PLAN.md` record the source map and remaining checks.
