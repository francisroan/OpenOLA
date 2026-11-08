# Gen1 S1 Pro MCU replacement: supervised OpenOLA trial

**8 November 2026. Software flow implemented; no replacement MCU has been connected, flashed, reset or road-tested with OpenOLA.** Use a compatible replacement and a technician who can recover a failed MCU flash. This flow is for Gen1 S1 Pro model code 2 or 3 with a verified legacy profile. It does not apply to S1 Air, S1X or Gen3.

## Bring to the trial

- The replacement MCU's readable part number, board revision and pinout, plus a service record confirming compatibility with the scooter and its SEG motor. OpenOLA cannot verify that match electronically.
- OpenOLA includes all 27 MCU and motor-related `.bin` resources found in Ola Diagnostics Prod 0.32.215. The active Gen1 S1 Pro trial chooses among four `mcu_72_*.bin` files by VIN prefix, head-unit software major and technician-confirmed motor type, then checks the included 98,304-byte resource against its recorded SHA-256 before use. The diagnostic APK picker remains an optional fallback. Other bundled files have no active flash route. No cloud firmware download is used.
- Stable scooter/phone power, the scooter on its centre stand with the rear wheel clear, and a service-centre recovery route if the MCU stops responding.

## In the app

1. Connect through the scooter's ordinary Wi-Fi/gRPC route. Check the displayed model is a verified older S1 Pro. Enter Service mode while parked and unplugged.
2. Open **Engineering tools → MCU replacement · Gen1 service trial**. Read replacement inputs. The screen reads VCU VIN `F190`, MCU software `F181`, motor angle `B113`, hardware broadcast and calibration status. Any missing VIN or MCU software identifier stops preparation.
3. Confirm **SEG motor** for an S1 Pro only after checking the actual motor. Tap **Verify included MCU firmware**. Enter the replacement MCU part number and confirm the physical part, recovery and wheel-clear checks. Prepare the trial.
4. Keep the scooter's ordinary Wi-Fi/gRPC connection open; separate ADB authorization or port 5555 is not required. Re-enter Service mode if the preflight returned the scooter to Customer mode. Press **Flash replacement MCU** and complete the slide confirmation. OpenOLA sends the file through the existing gRPC head-unit bridge, copies it to `/data/ola`, checks its on-scooter SHA-256, then runs `uds_client_test_app -c no -e no -t MCU -f /data/ola/<selected-file>` through that bridge. It stops unless the tool reports `FLASH_STATE_TRANSFER_COMPLETE` without `FLASH_STATE_TRANSFER_FAILURE`.
5. Request the first BMS reset. A UDS acknowledgement records **reset requested**, not a confirmed physical reboot. Watch the scooter power-cycle, reconnect, enter Service mode, and use **Read and verify flashed MCU**. OpenOLA requires fresh VIN and MCU `F181` readback matching the target.
6. With the wheel clear, re-enter Service mode and run **Motor AutoTune**. OpenOLA requires the MCU CAN `0x333` calibration counter to increase and stops on a reported failure or timeout.
7. Request the final BMS reset. Observe the power cycle, reconnect and read the final VIN, MCU software, motor angle `B113` and fresh MCU status. The app calls this a **software post-check**, not proof that the repair is safe to ride.
8. Read stored faults, inspect the motor and wiring, verify physical motor operation under the service centre's procedure, then share the in-app trial report. Do not ride based solely on the app's completion message.

The app retains step state through an in-app scooter reconnect. Keep the app open during this first trial and share the report before ending it. If the phone app is killed, the trial state is not automatically restored; inspect the scooter and restart with a fresh read rather than repeating a flash blindly. Any `STOP` message means do not continue to the next button until a technician has diagnosed the cause.

## What the diagnostic APK established

The firmware table, hashes and head-unit flash command were reconstructed from the newer diagnostic APK in [MCU_FIRMWARE_SELECTION_2026-11-08.md](MCU_FIRMWARE_SELECTION_2026-11-08.md). **Engineering tools → MCU replacement setup** now identifies the connected model and captures VIN, MCU software and hardware data where the transport supports those reads. The official app transfers over direct ADB; OpenOLA uses its existing gRPC root-command bridge for the same head-unit file and flash command. The official wizard does not read the replacement MCU's part number or make a separate cloud bind call. Offline completion and physical compatibility remain unproven until this supervised trial succeeds.
