# Validation plan and open issues

This is a checklist for future release validation, not a record of newly run tests. No app build or test was run while preparing this submission package.

## Current documentation mismatches

- The source workspace's detailed GUI guide is stale relative to the current feature inventory. Keep the public feature and repair claims tied to current source and explicit validation records.
- mobile/VALIDATION.md says no APK was built, while an arm64 release APK exists locally with an October 26 timestamp. Record which source revision created it and whether it was installed.
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

The project notes record 50 Flutter source tests and an older Kotlin/Desktop QA history. Those results apply to their recorded source revisions only. The current release candidate must be tied to a new source revision and build record before those results are reused.
