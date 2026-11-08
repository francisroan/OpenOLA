# MCU and IMCU replacement routes in Ola Diagnostics 0.32.215

Static APK audit, 8 November 2026. Source: `notes/OlaDiagnostics-0.32.215-improved.apk`, especially the DEX extracts in `scratch/mr/classes16.txt`, `scratch/mr/classes4.txt`, `scratch/mr/mrf_main.c`, `scratch/mr/imrf.c`, and `scratch/mr/s1xplus.c`. **No hardware flash, tuning, reset, or replacement test was performed.** A route in the official app is evidence of its intended procedure, not proof that a controller or binary is compatible with a particular scooter.

## Entry route

`ConnectionViewModel.goToMotorReplacementTest` (`classes16.txt`, DEX `0x0B264C`) chooses by transport first and then a Gen3 flag:

| Condition | Destination | Implication |
| --- | --- | --- |
| `TYPE_OF_SERVICE == TCP` | `MotorReplacementS1XPlusFragment` | Socket-connected S1X Plus Phase 2 takes the OTA-trigger procedure even if a Gen3 flag is also present. |
| Otherwise `isVehicleGen3()` | `MotorReplacementFragmentGen3`, implemented by `IMotorReplacementFragment` | Integrated IMCU/IDIQ and auto-tune procedure. |
| Otherwise | `MotorReplacementFragment` | Legacy MCU binary flash and tuning procedure. |

The router does **not** check a replacement controller part number, motor hardware identity, or VIN before opening a procedure. VIN and software checks occur later inside the fragments. The route alone cannot classify an S1 Air, S1X Phase 1, or Gen2 as safe for a particular file.

## Legacy non-TCP, non-Gen3 procedure

This route is structurally shared by any scooter that passes the connection screen without TCP or the Gen3 flag, including potentially S1 Air, S1X Phase 1, and Gen2. Its *actual file choices* are limited to the VIN, chosen motor type, and head-unit software branches detailed in [the full selection table](MCU_FIRMWARE_SELECTION_2026-11-08.md). In brief:

| VIN prefix | Operator-selected motor | Candidate file family |
| --- | --- | --- |
| `P53AU`, `P53BA`, `P53BD` | SEG or HUB | `mcu_72_*`; exact file and hashes are in the selection table. |
| `P53AF`, `P53AB`, `P53AC` | SEG or HUB | `mcu_92_*`, chosen by head-unit major 3, 4, or 5. |
| `P53AW` | HUB | `mcu_92_*`, chosen by head-unit major 3, 4, or 5. |
| `P53CC`, `P53BW/BV/BU/BT/BS/BR/BP` | HUB | `mcu_52_*`, with a documented current-version inconsistency for the B group. |
| Others | Either | No local file; some paths offer a skip to tuning. |

The fragment checks the current MCU software against the chosen target string. If different, it transfers the APK resource via ADB port 5555 to `/data/ola`, runs `uds_client_test_app -c no -e no -t MCU -f /data/ola/<file>`, and watches console text for `FLASH_STATE_TRANSFER_COMPLETE` or failure. Its tune path requests MCU routine `06F1`, watches a calibration counter and fault/angle signals, and invokes BMS hard reset at the reboot steps. These are APK control-flow observations, not physical result verification. The fragment does not demonstrate a replacement-MCU part-number or board-revision read before firmware choice. An operator-selected HUB/SEG value is not a hardware read.

**S1 Air, S1X Phase 1 and Gen2 remain unresolved as named models.** The table shows VIN branches, but the available evidence does not establish a reliable name-to-VIN-to-controller-hardware map for every production variant, nor a verified flash on each. Therefore, OpenOLA must not infer that the Gen1 active flash/tune sequence can be reused for those models simply because the official router reaches the same fragment. Read-only collection of VIN, hardware ID, MCU software and motor type is justified; active procedures need variant-specific validation.

## TCP / S1X Plus Phase 2 procedure

`MotorReplacementS1XPlusFragment` is reached for TCP service (router at `0x0B267A`; TCP connection also dispatches the `motor_replacement` flow through `goToMotorReplacementTest`). It reads VIN and MCU software, asks for motor type, checks suffix `.02` for HUB versus `.03` for SEG, and has a VIN/software-family mismatch check: prefixes `P53BE` and `P53BF` reject an MCU software family beginning `72` (`s1xplus.c`, `0x053A88`–`0x053C1C`). This is a software-family check, not a physical part-number read.

The fragment calls `SoftwareTriggerViewModel.sendOtaTriggerMoveOs3(...)` (`s1xplus.c`, `0x0540B4`) and displays “OTA was successfully triggered. Please exit the flow.” It has no local bundled-binary push or `uds_client_test_app` flash step in this fragment. The static call does not prove that the OTA service, firmware selection or delivery works offline. **Do not use the legacy local-flash procedure for this TCP route.** The subsequent OTA/backend behavior and exact target firmware policy need separate analysis and live validation.

## Gen3 / integrated IMCU procedure

`MotorReplacementFragmentGen3` routes to `IMotorReplacementFragment` (`imrf.c` layout `FragmentMotorReplacementGen3Binding`). Its declared steps (`classes4.txt`, around DEX `0x04A01A`–`0x04A17E`) are: Check IDIQ Status; IDIQ Flashing; Check Autotuning Status; Auto-Tune Motor; Write variant VIN based; Check IMCU Grade3 Fault; MCU SW File Flashing; Rebooting the scooter. This is a different sequence from legacy MCU replacement.

The fragment contains bundled `idiq_file.bin` and `imcu_file.bin` paths. It pushes IDIQ as `ECU_CONST_IMCU` and selected MCU/IMCU files as `ECU_IMCU` under `/data/vendor/ola` (`imrf.c`, `idIqInstalling` and `mcuInstalling`). Its MCU-file selection also contains the following VIN/head-unit-major branches in `flashMcuBin` (`0x045A74`); the two packed-switch payloads at `0x045F90` and `0x045FA0` were decoded from the APK bytes (keys 3 and 4):

| VIN prefix | Major 3 | Major 4 | Other major |
| --- | --- | --- | --- |
| `P53CC` | `mcu_52_02_126.bin` | same | same |
| `P53BW/BV/BU/BT/BS/BR/BP` | `mcu_52_02_122_01.bin` | same | same |
| `P53AW` | `mcu_92_01_35_11.bin` | `mcu_92_01_49_11.bin` | no branch |
| `P53AF/AC/AB` | `mcu_92_01_28_01.bin` | `mcu_92_01_35_01.bin` | no branch |

All named files are nonempty APK resources. The IMCU procedure checks IDIQ and auto-tune status and uses `IMotorReplacementViewModel.sendMcuDod(variantNumberBattery)` in `writeDidOnMcu` (`imrf.c`, `0x048F48`), so it includes a controller write beyond firmware flashing. The available static evidence does not yet resolve the write DID/payload, prove the hardware part identity, or confirm flash result by a fresh version read. The legacy Gen1 tune command must not be assumed equivalent to this integrated flow. On a connected model 31 scooter, even the model variant and controller command map remain unverified in OpenOLA.

## What can be implemented now

1. Present a **read-only** route report using transport, Gen3 flag, VIN prefix, observed MCU software, head-unit major, and available hardware ID. Show the APK's candidate file only when all decision inputs are present; label it a candidate, not an approved flash.
2. Keep active legacy flash and tuning limited to a separately validated Gen1 hardware combination. Reuse on S1 Air, S1X Phase 1, or Gen2 only after part-number mapping, binary compatibility, recovery procedure, and controlled service-centre test.
3. Treat S1X Plus Phase 2 as an OTA-trigger flow pending backend analysis, not as an offline flash. Treat Gen3 as its own IMCU/IDIQ/variant-write flow.
4. For any active replacement test, record before/after hardware identity, VIN, MCU/IMCU software, variant value, faults, calibration counter, and motor response. A successful file transfer, flash text marker, or UDS acknowledgement is not enough to establish a safe repair.
