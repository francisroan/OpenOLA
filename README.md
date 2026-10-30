# OpenOLA: GUI, Android source, and repair research

OpenOLA is an independent community project for source-led diagnostics, repair research, and owner-authorized validation on Ola S1 scooters. This repository contains the current Windows GUI, Android app source/build files, research comparison, and a concrete validation plan.

**Bluetooth security note:** Our project has identified a Bluetooth security vulnerability. No technical detail is included here.

This is not affiliated with or supported by Ola Electric. Model, year, head-unit build, ECU firmware, and module firmware matter. A result on one scooter is not proof for every model.

## What this repository contributes

- A comparison of related public Ola reverse-engineering work and the scope of the OpenOLA repair tools.
- The Windows GUI, separate Kotlin Android project, and active Flutter OpenOLA source.
- Reproducible build prerequisites and validation status for each project.
- A contribution format that keeps source evidence, captures, and interpretation separate.

The two recent posts describe different surfaces. The diagnostics post reports root command execution on an S1 Pro Gen 3, while the dashboard SDK is a separate experimental Gen 1 project with host-owned warnings and a constrained action interface. OpenOLA is a separate diagnostics/repair project; do not infer cross-generation compatibility from any one of these projects.

## Project options

| Project | Source archive | Extracted project directory | Build system | Status |
|---|---|---|---|---|
| Windows scooter GUI | [openola-windows-desktop-source.zip](source/openola-windows-desktop-source.zip) | `windows-desktop/` | Python 3.12, Tk/Tcl, pip dependencies | Desktop GUI and mock/demo code exist. Physical validation varies by feature. |
| Kotlin Android app | [openola-android-kotlin-source.zip](source/openola-android-kotlin-source.zip) | `android-kotlin/apk/` | Gradle wrapper, Android SDK, JDK 17 | Separate OpenOLA Kotlin app source. Build this target independently from Flutter. |
| Flutter OpenOLA | [openola-flutter-mobile-source.zip](source/openola-flutter-mobile-source.zip) | `mobile/` | Flutter 3.47.6, Dart 3.13.5, Android Gradle/NDK; Xcode for iOS | Active phone source is 0.4.0+9. Source validation and physical-device validation are separate. |
| Shared repair references | [openola-shared-source.zip](source/openola-shared-source.zip) | `shared/` | Reference data and catalogs | Sanitized shared data for repair research. |
| Legacy Android app | Not included in the curated source | — | Gradle, Android SDK, JDK 17 | Historical project; it is not the current phone build. |

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

The source archives preserve their project folder structure. They contain source and build configuration only; private credentials, local captures, dependency caches, and prebuilt APKs have been excluded. Review the archive contents and verify the exclusions before building or contributing.

See [VALIDATION_PLAN.md](VALIDATION_PLAN.md) for documentation mismatches, open bugs, and checks required before distributing an APK or desktop package. Review [LICENSE_STATUS.md](LICENSE_STATUS.md) before inviting reuse.

## Contributing

Read CONTRIBUTING.md before opening a pull request. Please use exact model/build profiles, sanitized evidence, and explicit confidence labels. Do not submit personal vehicle identifiers, credentials, local captures, or private signing material.
