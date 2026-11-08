# Android preview APK

## Current Public build: 0.5.19

`OpenOLA-0.5.19-public-arm64-v8a.apk` is the current Public build. It is a
debug-signed arm64 APK for Android 8.0+ (API 26+), application ID
`in.crossfire.s1diag`, version code 2059. SHA-256:
`AD9A5619E110ADABBD1AA2D919DA5896906A4DF9DE57ED2AFB8A525C8E455C2B`.
It was built from the Flutter source archive in this repository using Flutter
3.47.6 / Dart 3.13.5 and Android SDK 37 / NDK 28.2.13676358.

This build includes the diagnostic client identity assets (`ecos.crt`,
`ecos.key`, `ecos-ios.p12`, and the diagnostic root certificate) for secure
local gRPC. The private key is extractable from the APK and is intentionally
included at the project owner's request. Do not treat it as a personal or
per-user credential. It may be reused by anyone who obtains this APK.

The owner installed this version on a OnePlus CPH2573IN. Android reported
version 0.5.19 / code 2059 and accepted a launch command. No scooter-side test
of this exact build is recorded.

The 0.4.2 artifact below is retained as the previous credential-free preview.

`OpenOLA-0.4.2-preview-arm64-v8a.apk` is included in this folder. Cloning the
repository downloads it together with the Flutter and Windows GUI source archives.
It is a debug-signed preview for arm64-v8a devices running Android 8.0 (API 26) or
later.

## Integrity and signing

- SHA-256: `0E53D4DF4C5693ED276CE4039C1EC2DABB4C44E776E5E185E581607F68FFE042`
- Signing certificate SHA-256: `F64A17D97F02A7B537AEB60DEE560EAE02DC13103DB5FB4B34E329A2445BB3BA`
- Application ID: `in.crossfire.s1diag`
- Version: `0.4.2` (version code `2028` for this ABI)
- Minimum Android API: `26`

This artifact was rebuilt on 4 Nov 2026 from the curated Flutter source archive
(Phases 1-5). Source commit: `bbb49364d6fc2b19c2caf2fd10431cfcbc58b800`.
Build command:
`flutter build apk --release --split-per-abi --target-platform android-arm64 --no-pub`
with Flutter 3.47.6 / Dart 3.13.5, Android SDK Platform 37, and NDK 28.2.13676358.
The produced file was `app-arm64-v8a-release.apk`. `apksigner verify` succeeded
with APK Signature Scheme v2; one signer was present, with the fingerprint above.
The public source archive and this APK omit local mTLS identity assets; the APK
archive scan found no certificate, private-key, or keystore entries.

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
