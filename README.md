# OpenOLA: GUI, Android source, and repair research

OpenOLA is an independent community project for source-led diagnostics, repair research, and owner-authorized validation on Ola S1 scooters. This repository contains the current Windows GUI, Android app source/build files, research comparison, and a concrete validation plan.

**Bluetooth security note:** Our project has identified a Bluetooth security vulnerability. No technical detail is included here.

This is not affiliated with or supported by Ola Electric. Model, year, head-unit build, ECU firmware, and module firmware matter. A result on one scooter is not proof for every model. You confirm that we are not responsible for any issues, warranty, liability, dangers, bricking of scooter or any other issues you may or may not face and we are free from all obligations.

## What this repository contributes

- A comparison of related public Ola reverse-engineering work and the scope of the OpenOLA repair tools.
- The Windows GUI, separate Kotlin Android project, and active Flutter OpenOLA source, including the read-only S1X parameter reference.
- Reproducible build prerequisites and validation status for each project.
- A contribution format that keeps source evidence, captures, and interpretation separate.

The two recent posts describe different surfaces. The diagnostics post reports root command execution on an S1 Pro Gen 3, while the dashboard SDK is a separate experimental Gen 1 project with host-owned warnings and a constrained action interface. OpenOLA is a separate diagnostics/repair project; do not infer cross-generation compatibility from any one of these projects.

## Project options

| Project | Source archive | Extracted project directory | Build system | Status |
|---|---|---|---|
| Windows scooter GUI | [openola-windows-desktop-source.zip](source/openola-windows-desktop-source.zip) | `windows-desktop/` | One-time setup with `SETUP_AND_LAUNCH.cmd`, Python 3.12, Tk/Tcl | Glass GUI opens in Edge or Chrome. Public archive omits external ODX data; ODX-dependent catalog/actions are unavailable until an authorized local copy is supplied. |
| Kotlin Android app | [openola-android-kotlin-source.zip](source/openola-android-kotlin-source.zip) | `android-kotlin/apk/` | Gradle wrapper, Android SDK, JDK 17 | Separate OpenOLA Kotlin app source. Build this target independently from Flutter. |
| Flutter OpenOLA | [openola-flutter-mobile-source.zip](source/openola-flutter-mobile-source.zip) | `mobile/` | Flutter 3.47.6, Dart 3.13.5, Android Gradle/NDK; Xcode for iOS | Active phone source is 0.4.2+11. A debug-signed arm64 preview APK is available below; physical-device validation is pending. |
| Shared repair references | [openola-shared-source.zip](source/openola-shared-source.zip) | `shared/` | Reference data and catalogs | Sanitized shared data for repair research. |
| Legacy Android app | Not included in the curated source | Gradle, Android SDK, JDK 17 | Historical project; it is not the current phone build. |

## Evidence rule

Label every statement as one of:

1. Static source observation.
2. Protocol or transport observation.
3. ECU/service acceptance.
4. Physical effect observed on a named owner-provided test unit.
5. Replication by another researcher.

A source string, UI response, or successful compile is not proof of physical vehicle behavior. Preserve unknown units and unverified mappings as unknown.

## Build references

Download the relevant source archive from `source/` and extract it before building. See [SOURCE_BUILD_MANIFEST.md](SOURCE_BUILD_MANIFEST.md) for archive contents, toolchain versions, commands, and files that must not be committed. See [RESEARCH_COMPARISON.md](RESEARCH_COMPARISON.md) for public-source comparison, current discrepancies, and the repair test plan.

The source archives preserve their project folder structure. They exclude private credentials, local captures, external ODX data, and dependency caches. The checked-in debug-signed Android preview omits local mTLS identity assets and has not been validated on a physical scooter. Review the archive contents and verify exclusions before building or contributing.

## Prebuilt Android preview

The APK is included at [source/apk/OpenOLA-0.4.2-preview-arm64-v8a.apk](source/apk/OpenOLA-0.4.2-preview-arm64-v8a.apk), so cloning this repository downloads it together with the Windows GUI source archive. The Windows GUI archive is at [source/openola-windows-desktop-source.zip](source/openola-windows-desktop-source.zip); extract it and run `SETUP_AND_LAUNCH.cmd` from `windows-desktop/`. The APK is intended for Android 8.0+ devices using a 64-bit ARM processor. It is debug-signed for preview installation, not a store release. Secure vehicle Wi-Fi diagnostics require a separately authorized identity configured locally. See [the artifact record](source/apk/README.md) for SHA-256, signing details, build provenance, and install steps.

See [VALIDATION_PLAN.md](VALIDATION_PLAN.md) for documentation mismatches, open bugs, and checks required before distributing an APK or desktop package. Review [LICENSE_STATUS.md](LICENSE_STATUS.md) before inviting reuse.

## Contributing

Read CONTRIBUTING.md before opening a pull request. Please use exact model/build profiles, sanitized evidence, and explicit confidence labels. Do not submit personal vehicle identifiers, credentials, local captures, or private signing material.
