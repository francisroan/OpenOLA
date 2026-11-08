# Changelog and validation status

## 0.5.19+2059 Public — 8 November 2026

This compares the current Public build with the **0.4.2+11 preview at Git HEAD `16888229de146894e8a28cf745d6c38eece37440`**. APK SHA-256: `AD9A5619E110ADABBD1AA2D919DA5896906A4DF9DE57ED2AFB8A525C8E455C2B`. The Android release is updated; the Windows GUI remains at its older release and does not match the Android features.

### Added or substantially expanded since the Git preview

- Owner, technician, and service navigation; vehicle status, live signals, recorder, charging, components, firmware, software, engineering, actuator, parameters, reports, and universal search surfaces.
- Model-aware connection and read-only common-signal coverage for reported variants including Gen3 model 31 and S1 Air model 5; passive 18-byte TCP telemetry path for S1X Plus Phase 2.
- Stored DTC display with the available catalog description. For an unverified model/software profile, the card and detail sheet carry an **(i) meaning unverified** marker. Raw DTC and status remain visible.
- Gen1 per-ECU fault-bit decoding, battery and cell telemetry, report export, and guarded controls; unknown values remain unavailable rather than invented.
- Engineering MCU replacement setup: live model route, VIN/MCU software/hardware survey, shareable report, and read-only firmware-candidate preview for the legacy route. Twenty-seven original diagnostic APK MCU/motor resources are packaged with a hash manifest.
- Gen1 S1 Pro-only technician replacement trial that transfers a selected bundled binary through the existing head-unit gRPC bridge, checks flash output, requires reset and firmware readback, and stages calibration. No replacement MCU or physical flash has been tested.
- Separate Public and Super packaging controls. Public excludes VIN/odometer and other replacement identity writes and disables Bluetooth pairing/commands.

### Validation performed for this candidate

- `flutter analyze --no-pub`: passed after the final fault-display change.
- Focused MCU route, candidate selection, 27-resource hash/import, replacement-stage, and guide tests: 13 passed.
- Protocol and fault-catalog tests including the three S1 Air MCU codes: 16 passed.
- `flutter build apk --release --flavor public --no-pub`: passed. Package inspection found 27 firmware binaries and the credential assets named below.
- Installed on the owner's Android phone (OnePlus CPH2573IN), which reported version 0.5.19, code 2059. Android accepted a launch command. No connected scooter validation was performed for this exact package.

### Known limits and release gates

1. **Credential exposure:** the APK and source include the shared `ecos.key` client identity and iOS PKCS12 equivalent to support secure gRPC. The project owner explicitly chose to include them for this release. Anyone who obtains the public artifacts can extract and reuse the identity.
2. **Firmware rights:** permission to redistribute the 27 manufacturer firmware files in a public APK or source archive remains unverified. Hashes establish file integrity, not licensing or hardware compatibility.
3. **Hardware validation:** Gen1 S1 Pro replacement flash/calibration, Air/Gen2/S1X candidate compatibility, Gen3 IMCU/IDIQ procedure and variant write, S1X Plus Phase 2 OTA, and Gen3 balancing response remain untested. S1 Air fault descriptions come from a bundled manufacturer table but are not validated against its MoveOS 5.0.0 profile.
4. **Windows GUI:** it remains the older release and has not been updated to match Android 0.5.19.

## 0.4.2+11 preview — published Git baseline

The Git repository contains an older debug-signed arm64 preview, source archives, and research notes. Its README and build manifest describe that preview; they do not establish the capabilities or physical validation of 0.5.19.
