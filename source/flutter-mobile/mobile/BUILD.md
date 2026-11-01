# Flutter OpenOLA build

This archive contains the active Flutter Android/iOS source, generated protocol bindings, app tests, and build configuration. It does not contain personal mTLS identity files, local SDK paths, Flutter/Gradle caches, generated Xcode environment files, or local captures.

## Android build

Requirements: Flutter 3.47.6 / Dart 3.13.5, JDK 17, Android SDK Platform 37, and Android NDK 28.2.13676358.

From this `mobile/` directory, use a clean checkout or extraction and run:

```text
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi --target-platform android-arm64
```

The arm64 APK is written to `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`. The checked-in Gradle wrapper and dependency lockfiles pin the build inputs. iOS builds require macOS and Xcode.

## Credentials and validation

The public source intentionally omits the personal mTLS identity. Secure vehicle Wi-Fi diagnostics require a separately authorized identity provisioned locally; never add client keys, certificates, local signing keys, or personal vehicle data to a fork or pull request. The debug-signed preview APK is for community evaluation, not a store release, and has not been validated on a physical scooter.

Clean-extract validation on 1 Nov 2026: `flutter analyze --no-pub` completed with no issues. Focused decoder and protocol tests reported 15 passed and 1 skipped; the skipped test requires a personal PKCS#12 identity intentionally absent from this public source. The complete Flutter suite reported 30 passed, 25 failed, and 1 skipped. Remaining failures include stale navigation/sidebar expectations, golden image differences, and taps that do not reach the expected page. The desktop-parity test no longer writes into the excluded QA evidence tree. See the repository `VALIDATION_PLAN.md` for the failure categories and follow-up checks. Do not treat the full UI suite as green.
