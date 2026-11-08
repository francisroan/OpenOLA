# MCU replacement firmware selection in Ola Diagnostics 0.32.215

**Static APK analysis, 8 November 2026. No firmware was flashed and no replacement MCU was tested.** The source of this reconstruction is `scratch/mr/mrf_main.c`, the dexdump of `MotorReplacementFragment` from `classes4.dex` in `notes/OlaDiagnostics-0.32.215-improved.apk`. The switch payloads at DEX offsets `0x04DFE0`–`0x04E100` were decoded from the APK bytes; the shortened dexdump alone does not show their targets.

## Inputs and decision

The wizard takes the **first five VIN characters**, the current MCU software version, an **operator-selected motor type** (`SEG_MOTOR` or `HUB_MOTOR`), and the **first digit of the head unit software version** (`GetSwVersion`, first line). It does not read a replacement MCU hardware part number in `flashMcuBin`. The firmware selection below is therefore a description of the app's rules, not a verified hardware compatibility guarantee.

For the Gen1-era VIN prefixes traced through both motor branches, the bundled file chosen for head unit software major **3, 4, or 5** is:

| VIN prefix | Selected SEG motor | Selected HUB motor |
| --- | --- | --- |
| `P53AU` | `mcu_72_01_58_03.bin` (72.01.58.03) | `mcu_72_01_58_02.bin` (72.01.58.02) |
| `P53BA`, `P53BD` | `mcu_72_01_53_03.bin` (72.01.53.03) | `mcu_72_01_53_02.bin` (72.01.53.02) |

The **complete reachable file-choice branches** of this method are below. “Major” means the first digit of the head unit software version, not the MCU version. A dash means that major does not have a file-choice branch here.

| Selected motor | VIN prefix | Major 3 | Major 4 | Major 5 |
| --- | --- | --- | --- | --- |
| SEG | `P53AU` | `mcu_72_01_58_03.bin` | same | same |
| SEG | `P53BA`, `P53BD` | `mcu_72_01_53_03.bin` | same | same |
| SEG | `P53AF`, `P53AB`, `P53AC` | `mcu_92_01_24.bin` | `mcu_92_01_35_00.bin` | `mcu_92_01_35_00.bin` |
| HUB | `P53AU` | `mcu_72_01_58_02.bin` | same | same |
| HUB | `P53BA`, `P53BD` | `mcu_72_01_53_02.bin` | same | same |
| HUB | `P53CC` | `mcu_52_02_126.bin` | same | same |
| HUB | `P53BW`, `P53BV`, `P53BU`, `P53BT`, `P53BS`, `P53BR`, `P53BP` | `mcu_52_02_54_02.bin` | same | same |
| HUB | `P53AW` | `mcu_92_01_35_11.bin` | `mcu_92_01_49_11.bin` | `mcu_92_01_59_11.bin` |
| HUB | `P53AF`, `P53AB`, `P53AC` | `mcu_92_01_28_01.bin` | `mcu_92_01_35_01.bin` | `mcu_92_01_35_01.bin` |

The HUB `P53CC` and `P53B*` rows do **not** switch on the head unit software major, so they choose those files even if that first digit is outside 3–5. All other rows require major 3, 4 or 5; an unrecognized major reaches the no-file outcome. Other VIN prefixes with SEG selected exit with “No compatible MCU SW found.” Other VIN prefixes with HUB selected enter the “No compatible MCU SW found. Please skip to Auto Tuning” dialog. That skip is an APK control-flow outcome, **not** evidence that tuning is safe for the unrecognized combination.

There is a notable inconsistency in the HUB `P53B*` group: although every branch selects `mcu_52_02_54_02.bin`, its “already current” comparison uses `52.02.54.03` for BW/BV/BU, `52.02.54.04` for BT, `52.02.54.01` for BS, and `52.02.54.02` for BR/BP. This may be deliberate compatibility reuse or an app bug; the APK alone does not resolve it. Do not derive a firmware version from the filename in those branches.

The app compares the current MCU software version with the exact target version string. If equal, it exits saying the scooter is already on the latest MCU; otherwise it assigns the raw resource and filename and starts the ADB flash path. A version mismatch triggers the flash path; it does **not** validate that a physically swapped MCU has the right board, motor, pinout, or flash layout. For several other VIN branches the app offers “skip to Auto Tuning” instead of a file.

The preceding compatibility method retries when the MCU version is `null`, then takes its first and last two characters. The decompiled path has no demonstrated handling for a blank or malformed version from an unprogrammed replacement MCU. That case needs a separate read-only/service-centre check; the table must not be applied blindly to a controller that cannot identify its current software.

## Resource check

All files in the complete table are present as nonempty `res/raw/*.bin` entries in the newer APK. The four `mcu_72_*` files in the Gen1 table are each 98,304 bytes. Their SHA-256 hashes, computed on the uncompressed APK entries, are:

| APK resource | SHA-256 |
| --- | --- |
| `mcu_72_01_53_02.bin` | `053F4766D4B03DB37A44A84F605ACA346C93596A68A918A50B68A9543B33801B` |
| `mcu_72_01_53_03.bin` | `93A32064BC0470A88C0669DA23BFA3EDDB5946AA37D712D186CF2AD7B849FA83` |
| `mcu_72_01_58_02.bin` | `B6B4BB7C928CE65E1D03E1DCD6FC6BF764B65C226FF6A5C0B337E6F2430AA1A5` |
| `mcu_72_01_58_03.bin` | `FE5D34B522916B072189D8D0B823E85E8BEAFBE02CC6BACC66559C12CA89FAA0` |

The older `notes/base.apk` does not contain this replacement wizard or these files. The bundled bytes have not been compared with a service-centre firmware manifest or successfully flashed on replacement hardware.

## Flash pipeline traced from the APK

The following is bytecode-confirmed control flow for the legacy `MotorReplacementFragment`; it has **not** been run on a scooter.

1. `setUpAdbConnection` constructs `AdbConnector` with the scooter IP already held by `GrpcManager` and TCP port **5555** (`mrf_main.c`, `0x051038`). When that link reports connected, the wizard starts `sendMcuFile`.
2. After a five-second timer, `MotorReplacementFragment$sendMcuFile$1.onFinish` opens the chosen bundled `R.raw` resource and calls `AdbConnector.sendFileToVehicle(stream, filename, "/data/ola")` for a non-Gen3 scooter (`classes4.txt`, `0x04C460`). Gen3 instead uses `/data/vendor/ola`. The callback accepts a file-transfer status containing `OKAY` and marks the file-push step passed; otherwise it shows retry (`classes4.txt`, `0x04BEC4`). `OKAY` confirms the transfer callback's success condition, not file integrity on the target.
3. At the install step, `mcuInstalling$lambda$37` calls `AdbConnector.triggerPush("MCU", filename, "/data/ola")` on the legacy path (`mrf_main.c`, `0x04F4B0`). Despite that method name, its `AdbShellExecutor$triggerPush$1` builds and runs the head-unit shell command **`uds_client_test_app -c no -e no -t MCU -f /data/ola/<selected-file>`** after a three-second delay (`classes8.txt`, `0x0414C4`). The Gen3 branch uses `ECU_IMCU` and `/data/vendor/ola`; it is a separate case and does not validate the Gen1 command.
4. The fragment scans its displayed ADB console text for `FLASH_STATE_START`, `FLASH_STATE_TRANSFER_INPROGRESS`, `FLASH_STATE_TRANSFER_FAILURE`, and `FLASH_STATE_TRANSFER_COMPLETE`, case insensitively (`mrf_main.c`, `0x04E9D0`). `TRANSFER_FAILURE` produces a retry dialog. `TRANSFER_COMPLETE` marks `isMcuFlashed=true` and completes the install step. This is a text-marker criterion; the traced fragment does not independently hash the file on the scooter, verify the flasher process exit code, read back the new MCU software before proceeding, or prove that the motor can run safely.
5. At reboot steps 3 and 6, the Reset dialog calls `VehicleSecurityViewModel.initBmsHardReset()`, which starts the BMS extended-session/security/reset sequence (`mrf_main.c`, `0x050B4C`; `classes13.txt`, `0x055AA4`). The dialog callback then immediately navigates to reconnect at step 3, or marks the step passed and navigates to parts replacement at step 6. It does not wait in that callback for a confirmed power cycle. The separate BMS reset listener handles the subsequent UDS result; a user-facing success screen should not be interpreted as physical reset verification.

No replacement-MCU part number, board revision or motor pinout read appears in this selection/flash fragment. The motor type comes from a selection dialog (`observeDialog$lambda$36`, `mrf_main.c`, `0x0505D8`); a mismatch warning checks the current MCU version suffix, but is not a hardware-identity check. OpenOLA should require an independently verified part/motor identity and a known recovery route before exposing any flash action.

## Required checks before a guided flash

1. Collect read-only VIN (`VCU F190`), MCU software (`F181`), head unit software version, MCU hardware identity or part number, and physical motor type from the actual scooter and replacement part. Confirm the VIN prefix belongs to the intended Gen1 variant. `OpenOLA` currently reads VIN and MCU software, but does not establish all these inputs or pick a file.
2. Independently confirm the physical replacement MCU and motor type. The APK's motor-type dialog is an operator choice, not a hardware authentication step. The `flashMcuBin` method has no hardware part-number guard.
3. Verify the selected binary against a known compatible part and service procedure, including flash recovery and rollback. Preserve the APK's exact file bytes and checksums in a private, controlled inventory before use.
4. Only then implement a guarded selection/flash flow and test it with a service-centre technician. Do not treat a successful ADB transfer, positive UDS reply, or calibration-counter increment as proof of safe motor operation.

The broader procedure and its calibration limits are in `MCU_REPLACEMENT_APK_COMPARISON_2026-11-08.md` and `scratch/diag215_motor_calibration.md`.
