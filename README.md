# OpenOLA

OpenOLA is an independent, offline-first scooter diagnostics and repair research project. The active Android app is built with Flutter; this repository also contains a Windows diagnostic GUI, an older Kotlin app, and a [knowledge base](knowledge-base/README.md). It is not affiliated with Ola Electric.

**Release review status, 8 November 2026:** Git currently contains the older **0.4.2 preview**. A **0.5.19+2059 Public** APK has been built locally and is being reviewed. The new APK and matching source archive have **not** been uploaded. The 0.4.2 download below does not contain the features described for 0.5.19.

## Current Public app capabilities

- Connect over the scooter's local diagnostic Wi-Fi link, detect its reported model and controller hardware, and show shared vehicle status. S1X Plus Phase 2 has a passive TCP telemetry path; other supported connections use the Wi-Fi diagnostic bridge. Connection alone does not validate model-specific commands.
- Read live CAN signals, battery and cell data, stored ECU faults, component identifiers, firmware information, and head-unit software. Export recordings and reports. Fault cards show catalog descriptions and mark meanings **(i) unverified** where the model/software profile has not been validated.
- Offer owner, technician, and service workspaces with search, fault guidance, charging information, engineering readouts, and guarded service tools. Availability depends on the detected vehicle profile.
- Show an Engineering **MCU replacement setup** that reads VIN, MCU software, and hardware identity and previews the manufacturer app's firmware candidate when its selection inputs are known. The local app contains 27 MCU/motor-related files from the analyzed diagnostic APK. A candidate match does not prove physical compatibility.
- Offer a guarded **Gen1 S1 Pro** technician trial for MCU firmware transfer, flash-result checking, reset, readback, and calibration. Transfer uses the diagnostic gRPC bridge. It has **not** been tested with a replacement MCU. Other variants remain read-only setup pending validation; Gen3 IMCU/IDIQ and S1X Plus Phase 2 OTA use different official workflows.
- The Windows GUI is a separate, older release. It has not been updated to match the current Android app or its 0.5.19 features.

## Public edition boundaries

**VIN and odometer modifications are not included in the Public build for legal reasons.** Replacement identity and variant writes are excluded. Bluetooth pairing and commands are disabled because of a security flaw in Ola's Bluetooth architecture. The Public/Super distinction is an app packaging boundary, not scooter-side authorization.

Some service functions may brick a scooter if used without correct hardware, firmware, recovery equipment, and training. Read the detected model and software before using a service function. A successful command reply does not prove repair.

## Validation and open tests

| Level | Evidence |
| --- | --- |
| Source and build | Flutter analysis passed. Focused MCU route, firmware import/hash, replacement state, UI, protocol, and fault-catalog tests passed. The local 0.5.19 Public APK built successfully. |
| Package inspection | The APK contains all 27 intended MCU/motor firmware assets. |
| Earlier connected observations | Gen1 and Gen3 diagnostic connections and shared telemetry have been observed. A connected S1 Air model code 5, MoveOS 5.0.0 returned stored MCU codes. These observations do **not** validate the new 0.5.19 package or model-specific writes. |
| Still untested | This exact APK on a phone/scooter; physical replacement-MCU flashing and calibration; Air/Gen2/S1X firmware compatibility; Gen3 integrated MCU replacement; S1X Plus Phase 2 OTA; balancing request on model 31; iOS build and hardware connection. |

The 0.5.19 APK includes the diagnostic client identity required by its secure gRPC connection. This is a shared credential and its publication means others may be able to use it. Manufacturer firmware redistribution rights also need review. See [the changelog](CHANGELOG.md).

## Downloads and building

The [0.5.19 Public APK](source/apk/OpenOLA-0.5.19-public-arm64-v8a.apk) and [Flutter source archive](source/openola-flutter-mobile-source.zip) are included with this release. The [0.4.2 preview APK](source/apk/OpenOLA-0.4.2-preview-arm64-v8a.apk) is retained as the previous build. See [SOURCE_BUILD_MANIFEST.md](SOURCE_BUILD_MANIFEST.md) for archive contents and prerequisites.

For the current Flutter source, extract `source/openola-flutter-mobile-source.zip`, open `mobile/`, install locked dependencies, then run `flutter analyze`, focused tests, and `flutter build apk --release --flavor public`. The Windows GUI package remains at its older release.

## Support and contributing

Join the [OpenOLA Discord](https://discord.gg/sqNwH3WqK) for support. For a fault report, share model code, MoveOS build, raw DTCs and status bytes, and whether codes return after another read. Remove VIN, device identifiers, account details, and location data before posting.

See [CONTRIBUTING.md](CONTRIBUTING.md), [the knowledge base](knowledge-base/README.md), and [LICENSE_STATUS.md](LICENSE_STATUS.md). Static app analysis, a successful build, an ECU reply, and a physical repair are different evidence levels; label results accordingly.
