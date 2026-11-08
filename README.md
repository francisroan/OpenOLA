# OpenOLA

**Local scooter diagnostics and service research**

OpenOLA is an independent Android app and Windows diagnostic GUI for Ola scooter owners and technicians. It reads vehicle data locally and organises diagnostics, reports, and selected service workflows. OpenOLA is not affiliated with Ola Electric.

## Safety and use

OpenOLA is an independent diagnostic and service-research tool. It is not made, approved, or supported by Ola Electric, and it does not replace the vehicle manufacturer’s instructions or a qualified technician’s judgment.

Vehicle models, hardware, and software differ. A function that works on one scooter may not be suitable for another. Some service operations can disable or damage a vehicle or create an unsafe condition. Before using them, confirm the detected model and software, understand the procedure, and make sure you have the training and recovery equipment it requires. Stop if the identity, readings, or result is unclear.

You are responsible for deciding whether you are authorized and qualified to use a function, checking the vehicle before and after an operation, and complying with applicable law. Do not use the app while riding or to defeat safety or security features.

The app and its documentation are provided without guarantees of accuracy, compatibility, availability, or fitness for a particular purpose, to the extent permitted by law. To the extent permitted by law, the project maintainers are not responsible for losses arising from use or inability to use the app. Nothing in this notice excludes rights or responsibilities that applicable law does not allow to be excluded.

> **Current release:** Android **0.5.19 Public** · version code **2059**  
> **Previous Git release:** Android **0.4.2 preview**  
> **Windows GUI:** older release; it has not been updated to match Android 0.5.19.

[Download Android 0.5.19](source/apk/OpenOLA-0.5.19-public-arm64-v8a.apk) · [Flutter source archive](source/openola-flutter-mobile-source.zip) · [Full changelog](CHANGELOG.md) · [Knowledge base](knowledge-base/README.md) · [Build and source manifest](SOURCE_BUILD_MANIFEST.md)

## Android app features
### Connect and identify
- Connect to the scooter diagnostic service over local Wi-Fi and display connection state.
- Detect model code, controller hardware identifiers, and available software versions.
- Read shared vehicle signals across recognized models. Model-specific commands remain restricted to profiles with supporting evidence.
- Use passive 18-byte TCP telemetry for S1X Plus Phase 2 when that transport is available.

### Monitor and diagnose
- View vehicle status, battery charge, voltage, current, temperatures, range, and supported live CAN signals.
- Inspect battery and cell measurements, ECU components, firmware, head-unit software, and update status.
- Read stored BMS, VCU, MCU and IMCU fault codes. Where a fault description has not been verified for the detected model/software, the app shows the catalog description with an **(i) unverified** marker and retains the raw code and status.
- Decode the verified Gen1 BMS, MCU and VCU fault-bit tables. Unknown or unsupported data is shown as unavailable.
- Record live sessions, review saved readings, and export reports for service discussions.
- Search across app functions and diagnostic information.

### Service and engineering
- Use owner, technician, and service workspaces with model-aware feature availability.
- Review charging and service information, actuator tests, engineering readouts, parameters, and reports.
- Open the Engineering **MCU replacement setup** to read VIN, MCU software and hardware identity, inspect the detected route, preview a firmware candidate where selection inputs are known, and share the read-only setup report.
- Inspect 27 MCU/motor-related firmware files bundled from the analyzed diagnostic app. The app verifies bundled file hashes before use.
- Use the guarded Gen1 S1 Pro technician trial to transfer a selected firmware file through the head-unit gRPC bridge, check the flash result, perform required reset/readback steps, and stage calibration.

The replacement trial is **not validated on a replacement controller**. Air, Gen2, S1X, Gen3, and S1X Plus Phase 2 replacement flows are not enabled as active flash procedures. Gen3 uses a distinct IMCU/IDIQ sequence; S1X Plus Phase 2 uses a separate OTA-trigger route.

## Public edition
The Public edition excludes VIN and odometer modifications and replacement identity/variant writes. Bluetooth pairing and commands are disabled because of a security flaw in Ola’s Bluetooth architecture.

The 0.5.19 Android package includes diagnostic client identity files used by secure gRPC. They are reusable by anyone who obtains the public APK or source archive. See the [artifact record](source/apk/README.md) for details.

Some service functions can damage or disable a scooter when used with the wrong model, firmware, or procedure. Confirm the detected model and software, follow the service steps, and have an appropriate recovery plan before performing a service operation.

## What has been tested
| Area | Evidence |
| --- | --- |
| Static checks | Flutter analysis passed for the release source. |
| Focused tests | MCU route and candidate selection, bundled firmware hashes/import, replacement flow stages, UI, protocol, and fault-catalog tests passed. See the [changelog](CHANGELOG.md). |
| APK build | Android Public release built as version 0.5.19, code 2059. The package contains 27 MCU/motor firmware files. |
| Phone install | Installed on a OnePlus 12. Android reported version 0.5.19 / code 2059 and accepted the launch command. |
| Earlier scooter observations | Gen1 and Gen3 diagnostic connections/shared telemetry were observed. An S1 Air (model 5, MoveOS 5.0.0) returned stored MCU faults. These do not prove the 0.5.19 build’s model-specific write behavior. |

### Still to verify
- Live scooter connection and vehicle operation on the exact 0.5.19 build.
- Replacement MCU flash, reset, firmware readback, and calibration on a controlled Gen1 S1 Pro service test.
- Hardware and firmware compatibility for S1 Air, Gen2, S1X and other variants.
- Gen3 IMCU/IDIQ replacement and variant-write procedure.
- S1X Plus Phase 2 OTA replacement route.
- Cell-balancing request response on Gen3 model 31.
- Windows GUI parity with the current Android features.
- iOS build and physical-device connection.
- Redistribution permission for bundled manufacturer firmware.

## Changelog: Git release to current Android build
### 0.5.19 Public — current Android build
Compared with the 0.4.2 preview already in Git:
- Added Owner, Technician and Service workspaces, expanded app navigation, and universal search.
- Added model and controller identity detection with read-only common-signal coverage for newer scooter families.
- Added passive S1X Plus Phase 2 TCP telemetry.
- Expanded battery, cell, component, firmware, software, live-signal, recorder, report, and service screens.
- Added catalog descriptions to stored fault cards and an **(i) unverified** marker for model/software meanings that have not been confirmed.
- Added per-bit Gen1 BMS, MCU and VCU fault decoding.
- Added the model-aware MCU replacement setup, read-only candidate preview, shareable report, and 27 bundled firmware resources.
- Added the guarded Gen1 S1 Pro replacement trial using the gRPC head-unit transfer path.
- Kept VIN/odometer modification and replacement identity writes out of Public; disabled Bluetooth pairing and commands.
- Installed the resulting APK on a OnePlus phone and confirmed Android reports version 0.5.19.

### 0.4.2 preview — previous Git release
- Debug-signed arm64 Android preview with its own APK artifact record.
- Curated Flutter source archive for the earlier Android feature set.
- The Windows GUI and Android app are separate releases; their feature sets do not match.

The detailed [changelog](CHANGELOG.md) includes artifact hashes, test groups, known limits, and evidence boundaries.

## Build the Flutter app
1. Download and extract the [Flutter source archive](source/openola-flutter-mobile-source.zip).
2. Open the extracted mobile folder with Flutter 3.47.6 / Dart 3.13.5.
3. Run:
   ~~~powershell
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --release --flavor public
   ~~~
4. The Android APK appears in build/app/outputs/flutter-apk/.

See [SOURCE_BUILD_MANIFEST.md](SOURCE_BUILD_MANIFEST.md) for Android SDK/NDK requirements and other project archives. The Windows GUI is built separately and remains at an older release.

## Knowledge base and support
The [knowledge base](knowledge-base/README.md) gathers diagnostic, component-replacement, firmware-selection, charging, and system research. Notes distinguish APK/source observations from tested ECU responses and physical scooter validation.

Join the [OpenOLA Discord group](https://discord.gg/sqNwH3WqK) for support. When sharing diagnostic results, include model code, software version, raw fault code and status, and whether the code returns on a fresh scan. Remove personal vehicle and account identifiers from shared reports.

