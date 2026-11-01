# Android preview APK

`OpenOLA-0.4.2-preview-arm64-v8a.apk` is included in this folder. Cloning the
repository downloads it together with the Flutter and Windows GUI source archives.
It is a debug-signed preview for arm64-v8a devices running Android 8.0 (API 26) or
later.

## Integrity and signing

- SHA-256: `52EEB300ACECF14362A7F4FDE8CAE219014ED375D2AE5AF7B2E2E7A9411FE560`
- Signing certificate SHA-256: `F64A17D97F02A7B537AEB60DEE560EAE02DC13103DB5FB4B34E329A2445BB3BA`
- Application ID: `in.crossfire.s1diag`
- Version: `0.4.2` (version code `2011` for this ABI)
- Minimum Android API: `26`

This artifact was built from a clean extraction of the committed curated Flutter
source archive. Source commit: `b5ed7524e969aa7fb9b64b5a0f942caead3faaae` (1 Nov
2026). Build command:
`flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub`
with Flutter 3.47.6 / Dart 3.13.5, Android SDK Platform 37, and NDK 28.2.13676358.
The produced file was `app-arm64-v8a-release.apk`. `apksigner verify` succeeded
with APK Signature Scheme v2; one signer was present, with the fingerprint above.
The public source archive omits personal mTLS identity assets.

This is a debug-signed community preview, not a store release. It has not been
installed on a physical device or validated on a physical scooter. Secure vehicle
Wi-Fi diagnostics require an authorized identity configured locally. Installing
a build signed with a different key over this APK may require uninstalling the
preview first.

## Install

1. Clone this repository, then open `source/apk/` and copy the APK to your Android
   device, or download the APK file directly from GitHub.
2. On the device, allow the browser or file manager to install unknown apps when
   Android prompts you.
3. Open the APK and follow the installation prompt.

Verify the SHA-256 and signing certificate above before installing. Confirm that
the app supports your exact scooter and firmware before using it for a repair
action.
