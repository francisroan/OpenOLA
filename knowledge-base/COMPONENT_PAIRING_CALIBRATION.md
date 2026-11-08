# Component pairing / calibration on the Ola S1 (diagnostic path)

What the factory diagnostic app does when a **new BMS / MCU / pack** is fitted,
and which of it we can reproduce over the Wi-Fi/gRPC diagnostic bridge. Own-vehicle
service use. Everything here rides the same `:50005` gRPC → UDS path we already use.

Status tags: **[verified]** seen working or in the toolkit · **[in ODX]** present
in the extracted diagnostic database, not yet run on the vehicle · **[inferred]**
reconstructed from the params/routines, exact factory sequence not yet confirmed.

**Recheck 17 Sep 2026:** ODX `odx.json` + `wifican.proto` + `olacmd.py mcu-cal`
confirm MCU AutoTune / `RMT_CMD_MCU_CAL` / `B113` as below (B113 Intel LE, 0.1°,
0–360; Start=`31 01 05 F1`, Stop=`31 02 06 F1`, Result=`31 03 06 F1`). Exposed in
desktop GUI **Calibration** tab and APK **Tools → MCU calibration**. Not yet run
on-vehicle (still **RED**). ODX quirk: AutoTune **Start** uses routine id `05 F1`,
while **Stop/Result** use `06 F1` — keep those bytes exact; do not “normalize” them.

---

## 1. The three mechanisms

"Pairing/calibration" is not one magic button — it is a combination of:

1. **gRPC `RemoteRunTest`** — high-level test/calibration commands the scooter's
   diagnostic server translates to CAN internally. Example already in the toolkit:
   `mcu-cal start|stop` → `RmtCmdReq(RMT_CMD_MCU_CAL, …_START/_STOP)`. **[verified in toolkit]**
2. **UDS RoutineControl `31`** — start `31 01 <routine>`, stop `31 02`, get result
   `31 03`. The **exact routine catalog** (from the diag app's `odx.json`, base.apk): **[ODX-exact]**

   | ECU | Routine | Start / Stop / Result | Purpose |
   |---|---|---|---|
   | **MCU** | `06F1` AutoTune | `31 01 05 F1` / `31 02 06 F1` / `31 03 06 F1` | **Motor autotune** — learns motor params + angle (the MCU pairing step) |
   | **BMS** | `05F8` CellBalancing | `31 01 05 F8` / — / `71 01 05 F8` | Cell balancing routine |
   | VCU | `BF01` | `31 01 BF 01` | Check MCU peripherals (EOL) |
   | VCU | `BF02` | `31 01 BF 02` | Self-check on SOM |
   | VCU | `BF03/04` | `31 01 BF 03/04` | SOM UART Tx / Rx check |
   | VCU | `BF05` | `31 01 BF 05` | HBC LIN comms check |
   | VCU | `BF06` | `31 01 BF 06` | HU CAN comms check |
   | VCU | `BF07` | `31 01 BF 07` | Lock/unlock sequence over CAN |

   Result of a routine is read with `31 03 <id>` → `71 03 <id> <status …>` (AutoTune
   returns *attempted counter* + *successful count*).
3. **UDS write `2E <DID>`** — write a calibration value or a component identity
   (serial numbers, capacities, sensor offsets, motor angle). Gated by security
   access (`27`) in SERVICE mode — the same seed/key we solved. **[in ODX]**

All of it needs: `SetVehicleOperationMode(SERVICE)` → extended session `10 03` →
security access `27 01/02` → the write/routine. (Exactly the actuator flow.)

---

## 1c. Factory sequence at a glance (ordered UDS)

Preamble for every step: `SetVehicleOperationMode(SERVICE)` → `10 03` (extended
session) → `27 01`/`27 02` (security unlock, our solved seed/key) → keep `3E 80`
tester-present alive. Parked, centre stand, charger disconnected. Read back every
write with `22 <DID>`.

**New MCU / motor (MCU ECU `07A6`→`07B4`):**
1. `31 01 05 F1` — AutoTune **Start**
2. poll `31 03 06 F1` — AutoTune **Result** until success count increments
3. `31 02 06 F1` — AutoTune **Stop**
4. `22 B1 13` → confirm learned angle; `2E B1 13` only if writing a donor value
5. `11 01` MCU reset, then re-read faults — the encoder/overspeed DTCs should clear

**New BMS / pack (BMS ECU `078E`→`07B1`):**
1. `2E F1 91` BMS serial · `2E F1 20` pack serial · `2E F1 81` app-SW id
2. capacity: `2E` usable capacity (`E434`) + rated cell caps (`E4C0/E4C1/E4C2`)
3. SoH: `2E E4 3B` / `2E E4 3C` / `2E E4 3D`
4. sensor zero/scale: `2E E3 02/E3 03` (temp) · `2E E3 05` (cell V) · `2E E3 0B/0C/0D`
   (cell comp-resistance) · `2E E3 0E` (samples)
5. `31 01 05 F8` — Cell Balancing routine; poll `71 01 05 F8`
6. `11 01` BMS reset; verify SOC/limits sane and zero DTCs

> Values come from the replacement part's label/data sheet — never guess HV numbers.

## 2. Replacing / pairing a new MCU (motor controller)

The critical fact for a synchronous PMSM: the controller must know the **rotor
electrical angle offset**, or commutation is wrong (that is what the stored
`Encoder disconnection` / `over speed` / `hardware overcurrent` DTCs are about).

Steps the factory flow performs (all `31`/`2E` values are **ODX-exact**):

1. **Motor AutoTune** — the pairing action. `31 01 05 F1` (AutoTuneStart), let it
   spin/learn, poll `31 03 06 F1` (AutoTuneResult → *attempted counter* + *success
   count*), then `31 02 06 F1` (AutoTuneStop / forceful disable). This learns the
   motor's electrical parameters and the resolver/encoder **angle offset**. The
   toolkit's `mcu-cal start|stop` (gRPC `RMT_CMD_MCU_CAL`) is the same procedure
   wrapped by the diagnostic server. **[ODX-exact; run on centre stand only — RED]**
2. **Initial angle DID** — `2E B1 13` *WxB113_AngleofSynchronousMotor* (°, 0–360,
   0.1). AutoTune sets this; it can also be written directly if you have the value
   from an identical donor. **[ODX-exact]**
3. **Torque calibration slots** — `B110` seven torque limits (Eco/Normal/Sport/
   Boost/Reverse/Limphome/Turbo): per-vehicle calibration restored on a swap. **[in ODX]**
4. **Boot/SW identity** — `2E F1 80` boot SW id; read `F181` app-SW id. A new
   controller must run compatible firmware (else sw-update).

> AutoTune is the single most important MCU/motor pairing action. Skipping it →
> bad commutation → the exact `encoder disconnection / over speed / hardware
> overcurrent` MCU DTCs we already read stored on this vehicle.

---

## 3. Replacing / pairing a new BMS or battery pack

A new BMS must be told **what pack it is driving** and have its **sensors zeroed**.

**A. Component identity [ODX-exact `2E` writes]**
- `2E F1 91` BMS_SerialNumber, `2E F1 20` BatteryPackSerialNumber,
  `2E F1 81` ApplicationSoftwareIdentificationDID — write when the physical serials
  change (this is the "pairing" the app records).

**B. Capacity / State-of-Health [in ODX]** — so SOC% and range are correct:
- `E434` Usable capacity (Ah), `E4C0` usable capacity per cell, `E4C1` rated cell
  capacity, `E4C2` rated CV-phase capacity.
- `E43B`/`E43C` SoH lower/upper threshold, `E43D` SoH correction factor.
- **Capacity test** (learns real Ah): params `E49E–E4A1` (CC current, stop voltage,
  temp window) plus a capacity-test routine/RemoteRunTest. **[inferred]**

**C. Sensor calibration (zero/scale) [ODX-exact `2E` writes]** — a new AFE/pack needs offsets:
- `2E E3 02` pack-temp scaling, `2E E3 03` pack-temp offsets (×6),
- `2E E3 05` per-cell voltage offsets (×14),
- `2E E3 0B/0C/0D` cell 4/8/11 compensation-resistance, `2E E3 0E` number of samples,
- (also `E300` shunt current, `E301` bus voltage, `E306-E30A` PDU/AFE temp scale+offset).

**D. SoH + balancing [ODX-exact]** — `2E E4 3B` SoH lower, `2E E4 3C` SoH upper,
`2E E4 3D` SoH correction factor; run **`31 01 05 F8` Cell Balancing** routine.
`2E E4 9C` gates a secure pack-data read.

**E. Contactor / precharge health** — precharge params `E43E–E443`; a self-test
routine confirms the contactors before HV enable. **[inferred]**

---

## 4. What is a "routine" vs a "write" here

- **Routine (`31`)**: an *action* the ECU performs (spin the motor and learn angle;
  run a capacity test; self-test contactors; the BF07 lock sequence). You start it,
  poll `31 03` for the result.
- **Write (`2E`)**: sets a *stored value* (serial, capacity, offset, angle). Takes
  effect immediately, read back with `22` to confirm.

The factory "pair new component" wizard is a scripted sequence of these two, framed
by SERVICE mode + security access. We have all the primitives.

---

## 5. What we can do now vs. what needs confirming

| Capability | State |
|---|---|
| Enter SERVICE + security unlock | **verified** (same as actuators) |
| `mcu-cal` motor recalibration | toolkit + GUI Calibration + APK Tools, **RED**, not yet run on vehicle |
| Read any identity/param (`22`) | **verified** path |
| Write params/identity (`2E`) | path exists; **not yet exercised** for these DIDs |
| Exact factory pairing *sequence* per component | **inferred** — the guided flow/order is in `base.apk` UI, not yet extracted |

**Next to make this concrete:** extract the diagnostic app's guided
"component replacement" screens from `base.apk` to get the exact ordered steps
(and any routine IDs beyond BF07). That pins §2–§3 from **[inferred]** to a
factory-exact procedure.

## 7. Guided flow in the factory app (base.apk) — what's a *wizard* vs a screen

Extracted the diagnostic app's replacement UI (`presentation.views.fragments.
replacementtype.*`, `otatrigger.*`, `replacement.ReplacementViewModel`). Finding:

**There is a guided step-wizard for exactly ONE component: the VCU board.** BMS and
MCU have **no replacement wizard** — a new BMS/MCU is paired via the normal ECU-test
/ calibration screens (the routines + `2E` writes in §1c). That matches the hardware:
only the VCU carries migratable identity (VIN, odometer, mTLS certs).

### VCU-board replacement wizard — ordered steps (`ReplacementAutoTest`)
1. **Fetch VIN, Odometer & Certificates** from the vehicle (read current identity).
2. **Show Information / Replace VCU Board** (physical swap).
3. **Fetch SomId & TA100ID** of the new board.
4. **Certificate Provision** — provision the new board's mTLS cert. **☁ cloud**
   (scan passcode → backend; `otatrigger` + `ScanPasscodeFragment`).
5. **Set up Odometer** — `2E` write odometer to the new board. **Exact payload
   (from `VcuConfigParamsViewModel.setUpOdometerReading`):** service `2E`, DID
   `0103`, then the odometer value as a **4-byte little-endian** integer in **km**
   (the app byte-reverses the int and hex-encodes it; ISO-TP single-frame PCI `07`
   = 3 + 4 bytes). Read-back is `22 0103` → 4-byte LE km. e.g. 12345 km →
   `2E 0103 39 30 00 00`.
6. **VIN Writing** — `2E` write VIN to the new board. **Exact payload
   (`VinControl`):** read `22 F190`, write `2E F190` + the 17-character VIN as
   ASCII (standard ISO-14229 DID F190).
7. **Update SOM by gRPC / SOM update → backend.** **☁ cloud**
8. Auto-test block: **DTC Test → Charging Test → Drive Test → HBC Button Test →
   Cloud Connectivity Check → Auto Test Completed**, then **send VCU report to backend**. **☁**

### Offline feasibility of each pairing
| Component | Guided flow | Offline-doable with our tools? |
|---|---|---|
| **MCU / motor** | none (calibration screen) | **Yes** — AutoTune `31 01 05F1`→`06F1` + `B113`. Fully offline. |
| **BMS / pack** | none (calibration screen) | **Yes** — identity/capacity/SoH/offset `2E` + CellBalancing `05F8`. Offline. |
| **VCU board** | **wizard (above)** | **Partly.** VIN/odometer `2E` writes: yes. **Certificate provision + SOM-update + backend report: NO** — cloud/passcode-gated (same server wall as the diagnostic passcode). |

So: a new **MCU or BMS** can be paired fully offline with the §1c sequences. A new
**VCU board** can have its VIN/odometer written, but the **certificate provisioning
and backend registration cannot be reproduced offline** — that needs Ola's backend.

### How the certificate is provisioned (it is *pushed* from the backend)
The new VCU/SOM mTLS certificate is **not generated on the tablet**. It is issued by
Ola's backend and pushed to the board's secure element. The gate chain (all online):

1. **Operator login** — OAuth to `authz.olaelectric.com` / `authz.olaplant.com`
   (`?app_name=diagnostic_tool`). This is what mints the diagnostic app's own mTLS
   client cert (`CertificateUtils.getPrivateKey`, `SelfSignedCertificate`); all backend
   calls are **TLS certificate-pinned** (`okhttp3.CertificatePinner`).
2. **QR passcode** — `ScanPasscodeFragment` scans a job QR (`qrData`), and
   `PasscodeRepository.getPasscode()` POSTs it to the backend, which validates it and
   returns an authorization (`PasscodeResultData.passcode`). One-time, server-issued.
3. **Board identity** — `fetchSom` reads the new board's **SomId + TA100ID** (secure
   element hardware IDs).
4. **Provision + register** — `updateSomByGrpc()` sends those IDs (with the passcode
   authorization) to the backend over gRPC; the endpoint `/v1/vcu/upgrade/process`
   drives provisioning and the backend **pushes the signed cert** to the SOM, then the
   VCU report is posted to `/v1/reports/data`.

**Why there is no offline path:** the trust anchor lives on Ola's servers. Without a
valid operator session + a server-validated passcode bound to that board's hardware IDs,
no cert the vehicle's cloud will trust can be minted. VIN and odometer are just local
UDS `2E` writes and *do* work offline; the cert is the only truly gated piece.

### Odometer / VIN test hooks now in our tools
`readOdometer` / `writeOdometer` (APK **Tools** tab, GUI **Calibration** tab) issue the
exact factory bytes — `22 0103` read, `2E 0103` + 4-byte LE km write — behind a typed
confirmation, so you can test on your own scooter whether the VCU **accepts** the write
or returns a **UDS negative response** (0x33 security, 0x31 out-of-range, 0x22 conditions).
This is for legitimate mileage restoration / Ola disclosure only.

## 6. Safety (this is HV / drivetrain)
- Wrong `B113` / skipped `mcu-cal` → bad commutation, overcurrent, runaway torque.
  Bench / centre-stand only.
- Wrong capacity/SoH → mis-estimated SOC, over-charge/over-discharge risk.
- Writing sensor offsets wrong → false cell readings → the BMS can mis-protect.
- Do calibration writes only with the real replacement part's data, parked,
  charger disconnected, and re-read (`22`) every value after writing.
