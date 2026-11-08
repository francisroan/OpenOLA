# Component replacement and offline operation

**Status: 8 November 2026.** This is based on read-only analysis of Ola Diagnostics Prod 0.32.215 and current OpenOLA source. It is **not** a completed scooter-side replacement test. The official app's visible steps do not prove all ECU firmware requirements or that a replacement will survive reboot and cloud reconnection.

## Direct answer

It is **not 100% true** that a replaced MCU, BMS or VCU cannot work offline. There is no single universal “pair new component to VCU” command in the analyzed app. “Pairing” covers several different operations: making a module communicate on CAN, loading compatible firmware and configuration, granting a diagnostic security session, writing vehicle identity and variant, provisioning certificates, and updating Ola's cloud/owner record. Different replacement parts need different subsets.

The analyzed **motor/MCU replacement** wizard is mostly local. It checks the scooter VIN and MCU software compatibility, flashes matching MCU software, and calibrates the motor. The newer app also has separate MCU configuration/DoD screens, but the examined motor replacement wizard has **not** been shown to call those writes automatically. No separate cloud MCU-to-VCU pairing API was found in that wizard. That is encouraging for an offline repair, **not a guarantee** that every new MCU will work: the replacement hardware, firmware, security access, configuration and calibration still need to match.

A **VCU replacement** can receive VIN, odometer and variant locally, but the official process also rebinds head-unit/crypto-chip IDs in Ola's cloud and restores the owner profile through the cloud. The analyzed certificate calls are addressed to the scooter head unit; whether they can complete from a disconnected, fresh replacement board has not been verified. A locally running scooter and a fully restored Ola account/cloud identity are distinct outcomes.

## Flow by component

| Part | Steps visible in the official app | Local/offline prospects | Unresolved dependency |
| --- | --- | --- | --- |
| Motor / MCU | Confirm VIN and software compatibility; flash MCU; motor autotune (`31 01 06 F1` inferred from command name); check calibration counter/fault and reboot. MCU parameter/DoD writes exist in separate tooling, but their place in this wizard remains unproven | Mostly local. No cloud MCU-to-VCU bind call identified in this replacement path | Exact firmware compatibility, security session, whether parameter writes are required, calibration result and reboot/ride validation |
| Battery / BMS | Check BMS hardware/software; scan fitted pack ID; write battery ID `2E F120`; fetch grade from cloud; write grade `2E E421`; flash compatible BMS firmware; SOC/OCV reset and checks | Identity and configuration writes are local if the correct pack data and firmware are independently known | Official grade selection uses a cloud lookup by battery ID; pack/firmware compatibility and physical effect need validation |
| VCU | Read old VIN `22 F190`, odometer `22 0103`, variant; save variant to cloud; replace board; certificate provisioning and `ProvisionVin`; bind SOM/TA100 IDs in cloud; write odometer `2E 0103`, VIN `2E F190`, 37-byte variant record `2E 0100`, customer mode; push owner profile and OTA through cloud | Several identity writes are local. The Gen1 S1 Pro “with upgrade” record has first byte `03`; regular S1 Pro is `02` | Fresh-board certificate behavior offline, cloud hardware binding, owner profile, OTA and persistence after cloud reconnection |
| BLE/HMI/SOM | C-App setup reads SOM/TA100 IDs, checks cloud connectivity, whitelists phone, compares nearby BLE ID to a cloud record | Local BLE radio connection is a separate subject from ECU replacement | Cloud phone whitelist, cloud hardware identity and owner profile are explicit official-app steps |

**The Gen1 S1 Pro variant is a 37-byte VCU record, not just a one-byte toggle.** OpenOLA's current restore function accepts only the exact known regular S1 Pro record and writes the complete known upgrade record. It does not use a guessed record and does not update Ola's cloud variant. The user's working regular S1 Pro can supply read-only evidence about the standard record, but it cannot prove what a replacement upgraded VCU should contain or whether the upgrade persists on that scooter.

## What an offline repair tool would do

1. **Before removal, capture a backup:** VIN, actual odometer, the complete 37-byte VCU variant record, ECU identifiers, hardware/software versions, MCU parameters and DoD values, BMS pack ID/grade, fault codes, and SOM/TA100 IDs. Record read failures. The user's earlier VCU has no backup, so the missing values must come from trustworthy vehicle/part records; they should not be guessed.
2. **Identify the fitted replacement:** part number, hardware revision and firmware family. Refuse writes when those do not match a verified compatibility map.
3. **Run only the component-specific local sequence:** use the verified security session, compatible firmware, exact configuration values and required calibration. VIN and actual mileage must come from the vehicle's documented history. A positive UDS acknowledgement proves only that a request was accepted, not that the scooter is repaired.
4. **Read back and recover:** compare every written DID/parameter, return ECUs to default/customer mode, reboot, read again, confirm live CAN and handlebar controls, and scan faults. Preserve the original values and a recovery plan before any flash.
5. **Treat cloud restoration separately:** certificate state, hardware binding, owner profile, phone whitelist and OTA may remain incomplete while offline. Reconcile those with Ola's services when available and verify that the cloud does not replace the local variant/configuration.

## What OpenOLA has today

The **Super build** has guarded local read/write primitives for VIN, odometer, battery ID/grade and the exact Gen1 S1 Pro variant restore, plus parameter/security and motor-calibration pieces. They require a connected, verified legacy scooter, Service mode, Park, unplugged charger, fresh reads and explicit confirmation. These are **pieces of a workflow, not a validated MCU/BMS/VCU replacement wizard**. OpenOLA does not yet flash the official MCU/BMS replacement package or perform the full VCU certificate/cloud steps. Readback has not been verified on the user's replacement hardware. No certificate-generation or cloud hardware-binding flow should be called complete.

The **Public build** excludes replacement identity/variant writes and Bluetooth pairing/commands. It can still perform read-only checks. The two Android flavors use separate app IDs, so their data and settings are separate. Build flags control app packaging; they are not scooter-side authorization or protection against a modified APK.

## Confidence and next proof

| Question | Current answer | Evidence needed to settle it |
| --- | --- | --- |
| Is MCU-to-VCU pairing necessarily online? | No cloud bind step was found for MCU replacement; local completion looks plausible | Capture a replacement on compatible Gen1 hardware, including firmware/config/calibration, reboot and physical operation |
| Can a fresh VCU be fully provisioned offline? | Unknown. The official client calls local certificate APIs but separately requires cloud hardware binding and profile push | Observe certificate results and head-unit state with network disconnected, then after reconnection; compare IDs, VIN, profile and variant |
| Can BMS replacement complete offline? | Possibly, if the correct grade and compatible firmware are known from reliable pack records | Verify the pack ID/grade and flash compatibility, then BMS readback, SOC/OCV behavior and fault state |
| Does OpenOLA already provide a complete replacement workflow? | No | Finish component-specific guided steps and validate on the user's hardware |

## Evidence and interpretation

- [`scratch/diag215_pairing_features.md`](../scratch/diag215_pairing_features.md): extracted official-app VCU, battery, motor/MCU and C-App replacement steps. Its “OpenOLA status” is from the original analysis and predates later source changes.
- [`DIAG_APP_BREAKDOWN.md`](../DIAG_APP_BREAKDOWN.md): section 3.7 summarizes local and cloud VCU steps; section 3.6 identifies the motor-calibration routine.
- [`docs/MCU_REPLACEMENT_APK_COMPARISON_2026-11-08.md`](MCU_REPLACEMENT_APK_COMPARISON_2026-11-08.md): compares both diagnostic APKs and records the MCU wizard's actual observed steps.
- [`notes/base.apk`](../notes/base.apk) is official Diagnostics 0.26.0. It contains the AutoTune definition but no `MotorReplacementFragment`, `MotorMcuReplacementFragment` or bundled MCU firmware. [`notes/OlaDiagnostics-0.32.215-improved.apk`](../notes/OlaDiagnostics-0.32.215-improved.apk) is 0.32.215 and contains those replacement screens and MCU firmware files. The newer APK is the relevant source for the wizard. These are package/bytecode observations, not an executed repair.
- [`mobile/lib/diagnostics/controller.dart`](../mobile/lib/diagnostics/controller.dart): current local repair reads/writes and variant restoration. Source capabilities are not evidence of successful scooter-side replacement.
- [`mobile/lib/release_policy.dart`](../mobile/lib/release_policy.dart): Public/Super packaging switches.

No “100% offline impossible” conclusion follows from static client analysis. Equally, the absence of a visible cloud call in one screen does not prove that ECU firmware, certificate provisioning or later account synchronization has no external dependency.
