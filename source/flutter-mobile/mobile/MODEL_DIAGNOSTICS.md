# Model-aware diagnostics — implementation and validation

Date: 1 November 2026. Active app: `mobile/`, version 0.4.2+11. Desktop Python and legacy Kotlin apps are separate projects.

## Implemented

- Model detection from complete CAN 0x211 frames using the 26 named, non-reserved `VehicleTypes` entries recovered from HVDP 7.1.19 (codes 1–26 excluding 11). Names include older S1/Air/S1X, Gen2, Gen3 and M3X. Unknown/reserved codes remain unknown.
- Protocol selection is separate from model naming. Requires firmware plus controller hardware, never a name or an ABS frame alone.
- Legacy profile: model codes 1–4, release 3.0.0 or 5.0.0, BCM/BMS/dipswitch/MCU hardware bytes all zero, consistent with the saved S1 capture. Android 13/MediaTek metadata blocks it.
- 5.6.1 profile: model 6/9 or 20–26, release 5.6.1, BCM=1, BMS=1 and dipswitch 0–3, as specified by the inspected package. Android 10/Qualcomm metadata blocks it. MCU-specific mutations are not enabled because a complete matched procedure is not established.
- All other combinations use common-only signal definitions. Recognition of Gen3 is not a claim of compatibility with every Gen3 battery/controller revision.
- Automatic software/platform metadata reads on connection; unavailable metadata leaves detection conservative. Successful Software-page reads can resolve/re-evaluate the profile.
- Separate CAN assets: 267 non-conflicting newer message definitions; 195 message groups containing only signal encodings shared by both sources. The original database is retained separately.
- Excluded conflicting IDs: 0x223, 0x274, 0x307, 0x314, 0x316, 0x320, 0x333, 0x334, 0x411, 0x657, 0x658, 0x6D1, 0x6D2, 0x7F1. New 0x6DF/0x6E8 definitions are retained with independent VDP code evidence. Exclusion means raw capture can exist but no uncertain decoded value is shown.
- Vehicle status now shows detected model, raw hardware identities, profile/reason, ABS status/wheel-speed/version, BBW gain/selection/energy, hard braking, custom-mode telemetry, battery identity/supply/counter information and the feature-v2 bitmap.
- Features appear as observed telemetry, not inferred fitted hardware. Ten-second freshness timeout distinguishes paused data from zero/no-fault values. Short/non-byte frames are rejected.
- Live faults use one selected DBC; the previous simultaneous MCU/IMCU interpretation of 0x333 is removed. Faults with conflicting new layouts are not decoded.
- Charging latch, plug and charger-status display use the selected decoder. Removed the incorrectly universal interpretation of 0x213 bit 50 as a session flag.
- All legacy security-unlock, calibration/parameter/actuator and HMI procedures are guarded in the controller. Unmatched profiles do not fall back to the old sequence. UI entry points explain unavailable service procedures; cell balancing is disabled when unmatched.
- New-profile stored-fault scanning uses standard read-only UDS requests without guessing the older security unlock; failures stay failures and descriptions remain unmapped instead of borrowing old-model labels.
- Reconnection clears firmware/model/hardware/timestamps/decoded values. A profile change re-decodes received frames, invalidates prior interpreted reads and clears the graph. Late connection metadata cannot repopulate a disconnected session.
- Frozen JSON/text reports include profile identity; JSON also includes new diagnostics, raw bytes, receive times and freshness.

## Where to find it

Home → Detected scooter. Tools → Vehicle status → model-specific diagnostics. Live Signals → Brakes filter. Reports contain the selected profile and observation evidence.

## Deliberately unavailable

ABS bleeding, BBW strength writes, IMCU calibration/DIY writes, firmware flashing and newly discovered mutating RPCs are not exposed. Their presence in firmware is insufficient to infer the entire model/hardware-specific service sequence. Unknown hardware/software combinations retain common passive decoding. The legacy identifier/parameter decoder is not applied to a newer ECU just because its model was recognised.

## Validation

- The current public arm64 preview APK and build provenance are recorded in the repository's `source/apk/README.md`. It is built from the credential-free source archive and has not been validated on a physical scooter.
- Flutter analyzer: no issues.
- Ten new tests: model mapping; unknown/conflicting/incomplete identity; controller hardware mismatch; profile transition/re-decoding; different latch layouts; short/stale frames; blocked legacy methods; disconnect isolation/frozen report; narrow-screen modern diagnostic rendering; unknown-profile rendering.
- Existing read-batch/cancellation test fixtures were updated with explicit known legacy identity, preserving their original behavioral assertions.
- Full updated local suite: 41 passed, 25 failed. In the public clean extraction, the credential-dependent identity test is skipped because the identity is excluded. Remaining failures concern obsolete navigation/UI expectations, hit testing and goldens; the full widget suite is not green.
- No real scooter, Android phone installation, BLE session or live ECU command was tested. Static profile selection and mocked/captured frame behavior are the validation boundary.

## Sources and maintenance

Supporting disassembly and vehicle captures are retained in the private research workspace and are not included in this source archive. The public archive includes no raw personal vehicle captures.

Extend `lib/data/vehicle_profile.dart` only with a documented model/release/hardware match. Add an explicit separate method for any changed security/session/routine procedure; do not broaden the legacy guard to make an unknown scooter work. Preserve the original raw databases and conflicts. Tests must demonstrate that neighbouring/unknown revisions cannot select the new procedure.
