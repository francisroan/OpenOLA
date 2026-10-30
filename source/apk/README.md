# Android preview APK

`OpenOLA-0.4.0-preview-arm64-v8a.apk` is distributed as an asset on the repository's GitHub Release page. It is a debug-signed preview for arm64-v8a devices running Android 8.0 (API 26) or later.

## Integrity and signing

- SHA-256: `BE71A795344EF9259AA76945AA0622CA9B45EB0CA2580233D01F1BA9C25EFA97`
- Signing certificate SHA-256: `F64A17D97F02A7B537AEB60DEE560EAE02DC13103DB5FB4B34E329A2445BB3BA`
- Application ID: `in.crossfire.s1diag`
- Version: `0.4.0` (version code `2009` for this ABI)
- Minimum Android API: `26`

The preview was derived from the local 0.4.0+9 arm64 APK artifact dated 26 October 2026. Local mTLS identity assets were removed, the APK was realigned, then signed and verified with Android's `apksigner` using a local debug certificate. The original APK is not distributed. The artifact was not rebuilt from the curated source archive because this build environment could not resolve the Gradle wrapper over the network; therefore, an exact source revision for the compiled binary is not claimed. The public Flutter source archive excludes the same private assets.

This is a debug-signed community preview, not a store release. It has not been validated on a physical scooter. Secure vehicle Wi-Fi diagnostics need an authorized identity configured locally. Installing a build signed with a different key over this APK may require uninstalling the preview first.

## Install

1. Download the APK from the repository's Releases page.
2. On the Android device, allow the browser or file manager to install unknown apps when prompted.
3. Open the downloaded APK and follow Android's installation prompt.

Verify the SHA-256 and signing certificate above before installing. Do not use the preview for a repair action unless you have independently confirmed support for the exact scooter and firmware build.
