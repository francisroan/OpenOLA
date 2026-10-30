# Android preview APK

`OpenOLA-0.4.0-preview-arm64-v8a.apk` is committed in this folder. `git clone` downloads the APK and the Windows GUI source archive together. It is a debug-signed preview for arm64-v8a devices running Android 8.0 (API 26) or later.

## Integrity and signing

- SHA-256: `AEA69E03AAAEFBDD857B684908CF52E8030E47364D514B7F89D5B0E39E47680B`
- Signing certificate SHA-256: `F64A17D97F02A7B537AEB60DEE560EAE02DC13103DB5FB4B34E329A2445BB3BA`
- Application ID: `in.crossfire.s1diag`
- Version: `0.4.0` (version code `2009` for this ABI)
- Minimum Android API: `26`

This preview was **built directly from the curated public Flutter source** in this
repository (`source/flutter-mobile/mobile/`), not derived from a prior binary.
The source archive was published in commit `a7e50b66b3a729857e43bd1db1433013d144b639`.
Build: `flutter build apk --release --split-per-abi --target-platform android-arm64`
with Flutter 3.47.6 / Dart 3.13.5, Android SDK Platform 37 and NDK 28.2.13676358,
producing `app-arm64-v8a-release.apk`. It is signed with the local Android debug
key (certificate above). The source archive excludes local mTLS identity assets,
so secure vehicle Wi-Fi diagnostics require an authorized identity configured
locally.

This is a debug-signed community preview, not a store release. It has not been validated on a physical scooter. Secure vehicle Wi-Fi diagnostics need an authorized identity configured locally. Installing a build signed with a different key over this APK may require uninstalling the preview first.

## Install

1. After cloning the repository, open `source/apk/` and copy the APK to your Android device, or download the APK file from that folder on GitHub.
2. On the Android device, allow the browser or file manager to install unknown apps when prompted.
3. Open the downloaded APK and follow Android's installation prompt.

Verify the SHA-256 and signing certificate above before installing. Do not use the preview for a repair action unless you have independently confirmed support for the exact scooter and firmware build.
