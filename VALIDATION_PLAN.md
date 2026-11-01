# Validation plan and open issues

This file records validation of the public Flutter source and lists checks that still require follow-up. The public source archive and preview APK were rebuilt from a clean extraction on 1 Nov 2026.

## Current documentation mismatches

- The source workspace's detailed GUI guide is stale relative to the current feature inventory. Keep the public feature and repair claims tied to current source and explicit validation records.
- The internal workspace's `mobile/VALIDATION.md` may describe personal builds and credentials; it is not part of the public archive. Public APK provenance and hashes belong in `source/apk/README.md`.
- android/ is the legacy Android project, apk/ is the Kotlin OpenOLA project, and mobile/ is the active Flutter project. Name these consistently.
- The Gen 1, Gen 2, and Gen 3 evidence must stay separate. Do not infer one platform's behavior from another.

## Build and packaging checks

- Clean desktop setup on Windows with Python 3.12 x64 and Tcl/Tk.
- Clean Kotlin build from the Gradle wrapper using JDK 17 and Android SDK.
- Clean Flutter Android build with the recorded Flutter/Dart, SDK, NDK, and lockfile.
- Confirm source revision, artifact SHA-256, package ID/version, permissions, signing identity, and included assets.
- Scan staged files for private keys, certificates, personal captures, local addresses, device identifiers, and account data.
- Confirm that demo mode runs without a scooter or radio/network connection.

## App behavior checks

- Demo startup, navigation, themes, large text, rotation, and cancellation.
- Live connection unavailable, timeout, disconnect, and reconnect; stale data must not be presented as current.
- Reports must exclude personal identifiers by default and clearly distinguish missing data from zero.
- Native save/share, camera permission, Android install/update, and app restart on a supported phone.
- Physical scooter checks only on an owner-provided unit with the owner present; record exact model/year/software and separate source-level claims from observed effects.
- iOS build and device checks on a Mac/Xcode before claiming iPhone support.
- Confirm all active controls are gated, outcomes are shown as unknown after timeout, and no uncertain action is replayed automatically.

## Existing documented checks

## Public Flutter validation, 1 Nov 2026

- Validation used a clean extraction of the curated public source archive, with no personal mTLS identity, local SDK paths, caches, or generated Xcode environment files.
- `flutter pub get` completed from the clean extraction.
- `flutter analyze --no-pub` completed with no issues.
- Focused decoder and protocol tests: 15 passed, 1 skipped. The skipped test requires a personal PKCS#12 identity intentionally absent from the public source.
- Full test suite: 30 passed, 25 failed, 1 skipped. Failures include stale navigation/sidebar expectations, golden image differences, and widget taps that do not reach the expected page. The complete UI suite is not green.
- The clean-source desktop-parity test initially attempted to copy a generated session into the excluded QA evidence tree. That unnecessary copy was removed; the generated session remains in its temporary test folder and is fully exercised there.
- The arm64 preview APK was built from this clean public source. It is debug-signed, contains no personal mTLS identity, and has not been validated on a physical scooter. See `source/apk/README.md` for the exact artifact hash, signing fingerprint, and source revision.
- No physical vehicle behavior, repair outcome, iOS build, or desktop GUI clean-machine setup is claimed as validated by these checks.

The project notes record older Flutter and Kotlin/Desktop QA results. Those results apply only to their recorded source revisions and must not be carried forward as current validation.
