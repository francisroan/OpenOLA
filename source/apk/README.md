# Android preview APK

`OpenOLA-0.4.0-preview-arm64-v8a.apk` is committed in this folder. `git clone` downloads the APK and the Windows GUI source archive together. It is a debug-signed preview for arm64-v8a devices running Android 8.0 (API 26) or later.

## Integrity and signing

- SHA-256: `5A03D9AF17DD686CF14DD42AE150AFD6E322684AD8128B2D1E124F66CCD579F9`
- Signing certificate SHA-256: `F64A17D97F02A7B537AEB60DEE560EAE02DC13103DB5FB4B34E329A2445BB3BA`
- Application ID: `in.crossfire.s1diag`
- Version: `0.4.0` (version code `2009` for this ABI)
- Minimum Android API: `26`

This preview was **built from a clean extraction of the curated public Flutter
source archive**, not derived from a prior binary. Source commit:
`e3913a6739fdd6f00f0a6fb39b1918c01ade9e78` (1 Nov 2026). Build command:
`flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub`
with Flutter 3.47.6 / Dart 3.13.5, Android SDK Platform 37 and NDK 28.2.13676358,
producing `app-arm64-v8a-release.apk`. Signature verification passed with APK
Signature Scheme v2; it is signed with the local Android debug key (certificate
above). The source archive excludes local mTLS identity assets, so secure vehicle
Wi-Fi diagnostics require an authorized identity configured locally.

This is a debug-signed community preview, not a store release. It has not been validated on a physical scooter. Secure vehicle Wi-Fi diagnostics need an authorized identity configured locally. Installing a build signed with a different key over this APK may require uninstalling the preview first.

## Install

1. After cloning the repository, open `source/apk/` and copy the APK to your Android device, or download the APK file from that folder on GitHub.
2. On the Android device, allow the browser or file manager to install unknown apps when prompted.
3. Open the downloaded APK and follow Android's installation prompt.

Verify the SHA-256 and signing certificate above before installing. Do not use the preview for a repair action unless you have independently confirmed support for the exact scooter and firmware build.
