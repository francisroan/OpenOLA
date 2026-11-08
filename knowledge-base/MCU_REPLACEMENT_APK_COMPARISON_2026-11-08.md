# MCU replacement: comparing the two diagnostic APKs

**8 November 2026 — static analysis, no MCU replacement performed.**

## Which APK supplies the flow?

| APK | Version | MCU replacement evidence |
| --- | --- | --- |
| [`notes/base.apk`](../notes/base.apk) | Ola Diagnostics 0.26.0 | Contains `res/raw/odx.json` with AutoTune Start/Stop/Result definitions. No `MotorReplacementFragment`, `MotorMcuReplacementFragment`, or bundled `mcu_*.bin` files found in its DEX/resources. It does not establish a complete replacement workflow. |
| [`notes/OlaDiagnostics-0.32.215-improved.apk`](../notes/OlaDiagnostics-0.32.215-improved.apk) | Ola Diagnostics Prod 0.32.215 | Contains the motor replacement screens, 26 MCU/IMCU-related `.bin` resources (including `mcu_52_*`, `mcu_72_*`, `mcu_82_*`, `mcu_92_*`, Ola/SEG motor variants), and the wizard logic examined in [`scratch/diag215_motor_calibration.md`](../scratch/diag215_motor_calibration.md). This is the relevant APK for reconstructing the procedure. |

Both ODX files have the same unusual discrepancy: `ROx06F1_AutotuneStart` names routine **06F1**, but its `RequestFormat` says `31 01 05 F1`; Stop and Result both say **06F1**. The newer app builds routine requests from the **command name**, so `31 01 06 F1` is the high-confidence inferred start frame. This still needs a wire capture or a safe bench confirmation. The app sends that UDS frame to MCU CAN request `0x7A6`, not the gRPC `RMT_CMD_MCU_CAL` command.

## Newer app's Gen1 motor replacement sequence

1. Read VIN and MCU software version; check their compatibility. Blank VIN exits. VIN prefix and MCU software suffix distinguish vehicle/motor families and decide whether to flash the MCU.
2. Push the selected bundled MCU firmware to the scooter's head unit over ADB, then invoke the head-unit flashing tool and parse flash status. A mismatched or unavailable firmware can lead to a skip-to-tuning path; this should not be treated as proof of compatibility.
3. Reset the scooter through a security-access BMS reset and reconnect.
4. Capture `Successful_Calibration_Counter` from MCU CAN `0x333` byte 4. Send the MCU AutoTune start routine. The wizard checks for a counter increment at roughly 65–90 seconds, and reports failure if none arrives.
5. Check `Failure_for_motor_parameter_tuning` on `0x333`. Depending on the MCU software suffix, also read motor angle DID `B113` and compare it with the expected motor range.
6. Reset/reconnect once more, then report completion. The official app's success dialog is a software result; physical motor operation and fault-free behavior still require a scooter-side check.

The newer APK also contains `McuConfigParams` and `McuDodValues` types and a **separate** MCU configuration page. The examined motor replacement fragment does not reference those types. Therefore the earlier claim that this wizard automatically writes all `2E B13x` MCU values is **unproven**. We must determine whether a replacement MCU retains values, receives them during flash, or needs a separate configuration step before OpenOLA offers a guided repair.

## OpenOLA correction made in this pass

The Engineering page had a duplicate **Start AutoTune** button routed to gRPC `RemoteRunTestCmd(RMT_CMD_MCU_CAL)`. The official replacement wizard does not use that route, so the duplicate buttons were removed. The guarded **Component tests → Start motor calibration** path uses UDS `31 01 06 F1` to MCU and watches the CAN calibration counter. It now explicitly requires a verified legacy scooter and a fresh MCU status frame before starting. It still has **no live replacement validation**.

OpenOLA has a Gen1 S1 Pro service-centre trial flow: read-only preflight (`F190`, `F181`, `B113`, hardware and calibration CAN), firmware candidate from [MCU_FIRMWARE_SELECTION_2026-11-08.md](MCU_FIRMWARE_SELECTION_2026-11-08.md), bundled resource SHA-256 check, gRPC head-unit bridge upload and remote hash check, the official head-unit flash command, two acknowledged BMS reset requests, MCU software readback, AutoTune counter check and final software post-check. All 27 MCU and motor-related binaries from the diagnostic APK are bundled; only four verified Gen1 S1 Pro candidates are selectable by this active flow. A diagnostic APK can be selected as an optional fallback. The official app uses direct ADB for transfer, while OpenOLA uses its already-connected gRPC root-command bridge, avoiding separate ADB authorization. The Engineering replacement setup automatically identifies other model families and offers read-only VIN, MCU software and hardware intake where possible, without enabling their unverified flash procedures. This Gen1 flow is **implemented but has not been run on a replacement MCU**; see [MCU_SERVICE_CENTRE_TRIAL_2026-11-08.md](MCU_SERVICE_CENTRE_TRIAL_2026-11-08.md). The replacement MCU part number and pinout cannot be established by the APK selector; the technician must independently verify them and a recovery route. A software result is not a physical motor-safety result.

## Offline conclusion

No cloud MCU-to-VCU bind call was found in this newer motor replacement wizard. The visible flash, UDS and CAN calibration steps are local, so offline completion is plausible on compatible hardware. It is not proven: ECU firmware may impose checks not visible in the Android app, and no replacement run has been captured. A positive UDS reply or a counter increment alone cannot establish a safe replacement.
