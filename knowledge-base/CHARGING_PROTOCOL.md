# Ola S1 charging protocol (BMS / VCU ↔ charger)

**Rechecked 17 Sep 2026** against `da_can_dbc.json`, BCM firmware strings
(`pack_ch_can_*` / `pack_veh_can_*` in `moveos3/ecu_firmware_string_evidence.csv`),
diagnostic params, and the PERSINO OBC PDF in `notes/`.

Signal *names* and message *IDs* below are solid. Exact bit packing, scaling, cycle
times, and auth crypto still need a live `ch_can` capture (and/or BCM pack/unpack RE).
Marked ⚠ where inferred.

---

## 0. Verdict — what was wrong in the first TL;DR

| Claim in first draft | Status |
|---|---|
| SC on vehicle CAN, FC on a *separate* “FC CAN” with PERSINO-like protocol | **Overstated / wrong framing** |
| Two fully separate HV charge paths (main pack contactors vs dedicated FC contactors) | **Partially supported in software; not proven as “two packs of contactors”** |
| PERSINO PDF is the Ola external-charger protocol | **False** — PERSINO is a different OEM’s AC-OBC J1939 spec |

### What is actually true

1. **There is a dedicated charge CAN** (`ch_can` in BCM firmware), with its own
   transceiver gated by `FC_CAN_TRX_Standby_command` (`0x6BF` on vehicle CAN).
   Naming: “FC_CAN” ≈ this charge transceiver, **not** “fast-only bus.”

2. **Both Slow and Fast protocols live on `ch_can`.** Same physical charge bus,
   different message sets / auth. Some FC frames are also packed on **vehicle CAN**
   (`pack_veh_can_0x508/509/510/531/584–587`) — likely bridge/mirror for HU/logging,
   not the charger’s primary talk path.

3. **Contactors:** VCU exposes `FC_contactor_Positive/Negative_supply_command` and
   faults `HV_FC_POS_contactor_*`. BMS has its own Charge/Precharge/Discharge switch
   demands (`0x640`) and a single `Contactor_state` enum (incl. secondary CHG/DSG
   connect states). That is **coil/driver evidence for an FC path**, not proof that
   SC and FC each have independent contactors. A single electromechanical FC
   contactor (or POS-only + solid NEG), shared HV bus, and BMS charge FETs for SC
   is fully compatible with the signals — and with “I only see one contactor.”

4. **PERSINO PDF** (`notes/1_4_标准协议中英文PROTOCOL(1).pdf`): 250 kbps, 29-bit
   J1939, BMS=`0xF4`, OBC=`0xE5`, messages `0x1806E5F4` / `0x18FF50E5`. Useful as a
   *template* for how to write a manufacturer spec; **it is not what the S1 speaks.**

---

## 1. Buses (corrected)

```
┌─────────────┐     vehicle CAN (11-bit)      ┌─────┐
│ BMS / VCU / │◄────────────────────────────►│ SOM │  (dashboard, DBC, UDS)
│ MCU / …     │                               └─────┘
└──────┬──────┘
       │  bridge / select via FC_CAN_TRX
       ▼
┌─────────────┐     charge CAN = ch_can       ┌──────────────────┐
│ VCU/BCM     │◄────────────────────────────►│ Slow charger OR  │
│             │   (own transceiver)           │ Fast/Hyper DC    │
└─────────────┘                               └──────────────────┘
```

⚠ Baud, pinout, and whether SC and FC share the same charge-port pins are
hardware questions (see §6). Firmware treats one `ch_can` message namespace for both.

Also present: UART pack/unpack for some SC frames (`pack_uart_0x00b`, `0x213`, …) —
likely an internal bridge or alternate SC link; treat as secondary until proven.

---

## 2. Contactors / HV path (software evidence only)

| Signal / param | Where | Meaning |
|---|---|---|
| `Precharge_Switch_demand`, `Charge_Switch_demand`, `Discharge_Switch_demand` | `0x640` BMS | Pack-side FET/switch demands |
| `Contactor_state_00` | `0x11C` / UDS | Enum incl. Precharge → Connected; also `BV_Secondary_Connect_CHG` / `BC_Secondary_Connect_DSG` |
| `FC_contactor_Positive_supply_command` / `_Negative_` | `0x6BF` VCU DO | Coil supply enables for FC contactor(s) |
| `Current_sense_of_FC_Contactors_supply` | `0x6C2` | Coil-supply current sense |
| `HV_FC_POS_contactor_*` faults | `0x431` | Only **POS** FC contactor faults named (no NEG fault bits in DBC) |
| `EV_contactor_status` | `ch_can` `0x500` | Contactor status published **to** the FC charger |
| `Fast_Charger_Contactor_Status` | `veh_can` `0x014` | FC plug/contactor status on vehicle CAN |

**Interpretation for a third-party charger:** the charger does **not** close vehicle
contactors itself. It waits for EV-side contactor status / enable bits, then sources
current within the BMS/VCU demand. Whether SC and FC share one mechanical contactor
is a harness/BMS-board question — see questions in §6.

---

## 3. Message sets (what to give manufacturers)

### 3a. Slow charger on `ch_can` (and mirrored on vehicle CAN)

| ID | Direction | Message | Role |
|---|---|---|---|
| `0x00B` | Charger → EV | `Slow_Charger_to_battery_wakeup` | Wake + serial / FW / HW / mfr / bootloader |
| `0x040` | EV | `MBMS_WakeUp_Reason` | Wake reason |
| `0x080` | VCU → SC | `VCU_to_Slow_Charger_Authentication_Request` | Auth seed (`VCU_To_SC_Seed`) |
| `0x081` | VCU → SC | `VCU_to_Slow_Charger_Authentication_Status` | Auth result |
| `0x083` | SC → VCU | `Slow_Charger_to_VCU_Authentication_Response` | Auth response |
| `0x120` | BMS → Charger | `Overall_Battery_Status_Info` | SOC, charge voltage limit, `Charger_Mode_Request` |
| `0x121` | BMS → Charger | `Overall_Battery_Current_Limit` | **Charge current limit** (charger must follow) |
| `0x213` | Charger → EV | `Charger_Status` | Mode, V/I available range, SC faults, auth error, timeouts |
| `0x7BE` / `0x7B7` | SC diag | `SC_Diagnostic_Request/Response` | Diag on charge CAN |

Vehicle DBC already has bit layout for `0x00B`, `0x120`, `0x121`, `0x213` (usable
starting point for an SC brick). Auth frames `0x080/081/083` are **firmware-named
only** — layout ⚠.

### 3b. Fast / Hyper charger on `ch_can` (primary manufacturer target)

**Not in `da_can_dbc.json`.** Recovered from BCM `pack_ch_can_*` / `encode_ch_can_*`
strings. This is the protocol a DC Hyper-style station must speak.

| ID | Dir (from name) | Message | Key signals (names only) |
|---|---|---|---|
| `0x500` | EV → FC | `EV_Parameter_1` | `requested_DC_output_current`, `DC_output_voltage_target/limit`, `EV_charging_enabled`, `EV_charging_stop_control`, `EV_contactor_status`, `Digital_communication_toggle`, OV/UV/temp/deviation errors |
| `0x501` | EV → FC | `EV_Parameter_2` | `Maximum/Estimated_charging_time`, `Control_protocol_number`, `Charging_rate` |
| `0x502` | EV → FC | `EV_Voltage_Control` | voltage control |
| `0x508` | FC → EV | `Fast_Charger_Parameter_1` | `rated_DC_output_voltage`, `Available_DC_output_current`, EVSE ready/status/stop/estop/malfunction, connector latched |
| `0x509` | FC → EV | `Fast_Charger_Parameter_2` | (fields unnamed beyond message) |
| `0x510` | ? | `FC_Voltage_Control` | |
| `0x530` | EV → FC | `EV_Keep_Alive_Message` | `Vehicle_Alive` |
| `0x531` | FC → EV | `Fast_Charger_Keep_Alive_Message` | `Fast_Charger_Alive` |
| `0x532` | EV | `EV_Unlatch_Request` | |
| `0x533` | EV | `EV_VIN_Publish` | |
| `0x534` / `0x543` | FC ↔ EV | Fast charger authentication req/resp | |
| `0x535` / `0x553` | VCU ↔ | VCU authentication req/resp | |
| `0x536` / `0x563` | EV | Signature req/resp | |
| `0x580`–`0x587` | EV | Identification + protocol ID bytes | |
| `0x666` / `0x667` | | Future_Requirement_* | reserved |

Looks **CHAdeMO-family in spirit** (EV demand current/voltage, EVSE status, toggle,
contactor status, keepalives) but IDs and auth are **Ola-proprietary**, not stock
CHAdeMO/CCS/GB/T — and **not** PERSINO.

Also on vehicle CAN (mirror): `0x014` Fast_Charger_Connection_Status
(`Fast_Charger_Plug_Status`, `Fast_Charger_Contactor_Status`).

### 3c. Vehicle-CAN housekeeping (not the charger control loop)

| ID | Notes |
|---|---|
| `0x62D` | `Charger_Connected` = None / Fast / Slow; `Charger_Plugged_In` |
| `0x143` | Vehicle mode L1 SC/FC, L2 `SC_CHARGE_*` / `FC_CHARGE_*` |
| `0x130` / `0x180` / `0x190` | Charging_Mode, Charging_Rate (SC/FC C-rate enums), time-to-charge SC/FC |
| `0x640` | Pack switch demands / bus voltage |
| UDS `RxCF0D` | Fast/Slow charger status + authentication flags |

---

## 4. Handshake (inferred — confirm on capture)

### Slow
1. Plug sense → SC sends `0x00B` wakeup with identity.
2. Seed/response auth `0x080` → `0x083` → `0x081` (⚠; `Authentication_Error` on `0x213` if fail).
3. Capability: SC `0x213` available V/I; BMS `0x120`/`0x121` limits.
4. BMS precharge + charge switch; SC regulates to `min(available, BMS limit)`.
5. Watchdogs: `Charge_control_message_timeout_error` / `Battery_Parameter_Time_out_error`.

### Fast
1. Plug / `0x014` connection + FC contactor supply enable on vehicle side.
2. Protocol/ID exchange `0x580–0x587`; auth/signature `0x534–0x563` (⚠ crypto unknown).
3. Keepalives `0x530`/`0x531`.
4. EV publishes demand on `0x500`/`0x501`/`0x502`; FC publishes capability/status on `0x508`/`0x509`.
5. Energy transfer only when `EV_charging_enabled` + contactor status + EVSE ready agree.
6. Stop via `EV_charging_stop_control` / EVSE stop / fault bits.

---

## 5. Ceiling / “can we charge faster?”

Unchanged: charger cannot exceed BMS `Charge_current_limit` + thermal derate.
Diag hints ~120 A internal CC ceiling (`E49E`). `Charging_Rate` selects SC vs FC
C-rate buckets; it is not a hidden unlock byte for a third-party brick.

---

## 6. Locked answers (17 Sep 2026)

| # | Answer |
|---|---|
| Target | **~3 kW DC** (Bolt Blaze already does this); Hyper UI optional |
| HV path | Inlet → **one contactor** → battery; SC and FC share this path |
| Socket | **One** charge socket for both charger types |
| Field evidence | Bolt Blaze DC @ ~3 kW → scooter shows **regular** charge (not Hyper) ⇒ almost certainly **SC protocol path**, not `0x500` FC |
| Capture kit | ESP32/Arduino + MCP2515 — see `CHARGE_CAN_CAPTURE.md` + `tool/charge_can_sniff/` |
| Manufacturer file | Pay after a **Bolt Blaze charge-CAN log** confirms SC-path DC (or Hyper log if you need FC) |
| Baud | Sniffer auto-probes 500/250/125 kbit/s (no scope required) |

Hardware implication: software “FC contactor +/- supply” is that **one** inlet
contactor’s coil drive, not a second HV path. BMS charge FETs may still sit
in-series or as pack protection — protocol still reports `EV_contactor_status`.

---

## 7. Path to a manufacturer deliverable

| Step | Output |
|---|---|
| A. Wire + baud on charge CAN | `SELECTED_BAUD` + idle frames |
| B. **Bolt Blaze session log** (primary for 3 kW) | Bit-exact SC-path DC (`0x00B/213/120/121` + auth) |
| C. Hyper session log (only if Hyper UI / FC C-rate needed) | `0x500–0x587` |
| D. Manufacturer PDF (PERSINO *style*, Ola IDs) | Hand-off you can pay against |

**Do not pay a charger vendor on firmware names alone.** For your 3 kW goal,
confirmed = Bolt Blaze CSV showing the live demand/status loop.

How-to: `reverse_engineering/CHARGE_CAN_CAPTURE.md`

**Bottom line:** One socket, one contactor, shared HV. Hyper talks Ola `ch_can`
(`0x500`/`0x508` family), not PERSINO. For ~3 kW, Bolt Blaze on the **SC message
set** is the practical target; see §8 for bit-exact SC layouts already in the DBC.

---

## 8. Missed / underused evidence (pulled from existing docs)

### 8.1 SC control loop is already bit-exact in `da_can_dbc.json`

For a Bolt Blaze–class brick you do **not** need firmware RE for the main
demand/status frames — only cycle time + auth (`0x080/081/083`) from a live log.

**Charger → EV `0x213` Charger_Status** (Intel / little-endian):

| Signal | Start bit | Len | Scale | Max | Notes |
|---|---|---|---|---|---|
| Charger_Status_Signal | 0 | 1 | 1 | 1 | |
| Charger_Mode | 1 | 3 | 1 | 7 | enum TBD from capture |
| Charging_Voltage_Available_range | 4 | 16 | 0.1 V | 120 V | |
| Charging_Current_Available_range | 20 | 16 | 0.1 A | 500 A | 3 kW ≈ 50–60 A @ pack V |
| Slow_Charger_Fault_Information | 36 | 2 | 1 | 3 | |
| Charger_output_Short_circuit_error | 40 | 1 | | | |
| Charger_under/over_temperature_error | 41–42 | 1 | | | |
| **Low_AC_voltage_error** | 43 | 1 | | | AC-OBC heritage |
| **Rectifier_hardware_error** | 44 | 1 | | | AC-OBC heritage |
| Authentication_Error | 45 | 1 | | | |
| Battery_Parameter_Time_out_error | 46 | 1 | | | BMS timed out |
| Data_Corruption_error | 47 | 1 | | | |
| Charge_control_message_timeout_error | 48 | 1 | | | |

`Low_AC` / `Rectifier` bits show `0x213` was designed for an **AC-input slow
charger**, yet a **DC** Bolt Blaze can still use this frame (those bits idle/OK).
That fits “3 kW DC + regular charge UI.”

**BMS → Charger `0x120`:**

| Signal | Start | Len | Scale / offset | Units |
|---|---|---|---|---|
| Overall_Battery_Current | 0 | 16 | 0.01, offset −300 | A |
| Overall_SOC | 16 | 16 | 0.01 | % |
| Overall_Charge_Voltage_limit | 32 | 16 | 0.001 | V (≤65) |
| Charger_Mode_Request | 48 | 3 | 1 | |

**BMS → Charger `0x121`:**

| Signal | Start | Len | Scale | Max |
|---|---|---|---|---|
| **Overall_Charge_current_limit** | 0 | 16 | 0.01 A | **600 A** |
| Overall_Discharge_current_limit | 16 | 16 | 0.01, off −400 | A |
| Regen / Discharge power limits | 32 / 48 | 16 | 1 W | |

Charger must track `min(own available, 0x121 charge limit)`.

**Wake `0x00B`:** WakeReq(2) @0; Serial(32) @8; FW(4) @40; HW(4) @44; **Manufacturer_Code(4) @48**; BL(4) @52.

**`0x130` Charging_Mode_00** is **CC/CV phase**, not SC vs FC:

`0=Disabled, 1=CC, 2=CV, 3=Complete, 4=CC End, 5=CV End, 6=Balancing, 7=Standby`

SC vs FC is `Charger_Connected` (`0x62D`: 1=Fast, 2=Slow), `Vehicle_Mode` L1/L2
(`0x143`), and `Charging_Rate` buckets (`0x180` — live_params enum SC_C_RATE_* vs
FC_C_RATE_*; DBC “%” unit on that signal looks wrong).

### 8.2 UDS you can read *during* Blaze (no pinout needed)

| DID | Meaning |
|---|---|
| `22 E1 04` ChargeDemand | Live demand **current** (0.01 A) + **voltage** (0.001 V) |
| `22 CF 0D` Charger Information | Connected Fast/Slow, plugged, Fast/Slow auth + status, rate |
| `22 E4 B1` | Max DC output voltage by EV (**0–80 V**) — LV pack class |
| `22 E4 B0` | Max charging time permitted by EV (min) |
| `22 E4 BD` | **CAN charging enable** flag (0/1) |
| `22 E4 9E` | Capacity-test CC limit 0–120 A (ceiling hint) |
| `22 E4 C4/C5` | Cell mV CC-end / charge-complete thresholds |
| `22 E4 CA` | Charge-complete current (0–5 A, 0.1 A) |

If Wi‑Fi diag works at the station: log these while Blaze runs — cross-check vs CAN.

### 8.3 Other names we underplayed

| Item | Why it matters |
|---|---|
| `0x014` Fast_Charger_Connection_Status | Plug + **contactor** status on vehicle CAN; Hyper fingerprint |
| `0x411` ChargerReAuthError | Auth can fail **mid-session**, not only at start |
| `0x6F4` Vehicle_Range_Hyper | “Hyper” also used for **range estimate**, not only charge UI |
| `Sounds_Mode_Hyper` on `0x214` | Same — Hyper branding ≠ charge protocol |
| `E70B` ChargeFET / `E70C` PreChargeFET | Pack FETs exist beside the inlet contactor |
| SC diag on ch_can `0x7BE`/`0x7B7` | Slow charger has UDS-like diag on charge CAN |
| UART pack of `0x00B`/`0x213`/`0x508` | Internal bridge; external sniff still = charge CAN pins |

### 8.4 Still missing after docs-only

- Bit layout of SC auth `0x080/081/083` and all FC `0x500–0x587`
- Cycle times / handshake order
- Auth crypto (seed → key)
- Confirmed baud and inlet pinout
- Whether Bolt Blaze skips auth or uses a known Manufacturer_Code

**Practical takeaway:** you can draft ~70% of a **3 kW SC-path manufacturer PDF**
from the DBC today; a Blaze capture fills auth + timing and proves which IDs
actually appear.

---

## 9. MoveOS 5 / S2 app-layer decode (18 Sep 2026) ⭐ bit-exact, from firmware

Decompiled the MoveOS-5 head-unit apps in `notes/System_apps/`
(see `SYSTEM_APPS_MOVEOS5_FINDINGS.md`). The S2 CAN parser
(`com.olaelectric.vehicleparser`, `ChargerInfoParser` + `MasterParser`) gives the
**exact byte/bit extraction** the SOM uses for the charge frames on **vehicle CAN**.
This is real product code, not inference — but note the SOM reads the *vehicle-CAN
mirror*, so the charge-CAN-only auth frames (`0x080/081/083`, `0x53x–0x56x`) are still
**not** here (physical `ch_can` tap still required for those).

### 9.1 Charger type now has **four** states (was two)

`vehicleinterface/ChargerTypes` enum — value of `Charger_Connected` on `0x62D`:

| val | type |
|---|---|
| 0 | NONE |
| 1 | **FAST_CHARGER** |
| 2 | **SLOW_CHARGER** |
| 3 | **BOOST_CHARGER** ← new class between slow and fast |

And `ChargingModes` (mode field, cf. `0x130`/`0x143`):
`0 SNA · 1 Idle · 2 Safe · 3 Slow_Charge · 4 Fast_Charge · 5 Discharge · 6 Boost_Charge`.
→ **Boost charge is a first-class mode**, not just a power level. Any capture at a Bolt
Blaze / Hyper should be checked for `Charger_Connected==3` or `mode==6`.

### 9.2 Exact bit offsets the SOM decodes (vehicle CAN)

**`0x62D` Charger_Connection_Status** (`parseChargerConnectionStatus`):
- `Charger_Connected` (type enum above) = **byte[0] bits 0–1** (`data[0] & 0x03`)
- `Charger_Plugged_In` = **byte[0] bit 2** (`(data[0] >> 2) & 1`)

**`0x213` Charger_Status** (`parseChargerStatus`):
- `chargerBillingStatus` = **byte[6] bit 2** (`(data[6] & 0x04) == 0x04`)
  → the charger signals a **billing / paid-session** flag to the vehicle. Relevant to
  whether a 3rd-party brick is accepted or shows "billing" state. (Bit layout for the
  V/I-available fields is unchanged from §8.1.)

**`0x508` Fast_Charger_Parameter_1** (`parseFastChargerParameter1`, mirrored on veh CAN):
- `Vehicle_Connector_Latched` = **byte[1] bit 2** (`(data[1] >> 2) & 1`)
  → confirms `0x508` is on vehicle CAN and the SOM reads connector-latch from it.

**`0x584` / `0x585` EVSE Identification** (`parseEvseIdentificationLowByte/HighByte`):
- Each frame = **all 8 bytes** → hex string. `0x584` = low half, `0x585` = high half,
  concatenated → a **16-byte station/EVSE identifier**, persisted in `ChargerInfoSharedPref`.
  This is the station-ID handshake earlier docs only listed as "identification bytes."

**`0x00B` Slow_Charger_to_battery_wakeup** → `parseSlowChargerToBatteryWakeup` (identity,
as §8.1). **`0x040`** carries `MBMSWakeUpReason` incl. `Charger_CAN_Wakeup` — i.e. plugging
a charger is one of the enumerated **BMS deep-sleep wake sources**.

### 9.3 Full charge-related CAN ID list the S2 dispatches

| ID | dec | Handler |
|---|---|---|
| `0x00B` | 11 | Slow charger wakeup / identity |
| `0x040` | 64 | MBMS wake reason (incl. Charger_CAN_Wakeup) |
| `0x120` | 288 | Overall battery status (V-limit, SOC, mode req) |
| `0x121` | — | Charge/discharge current limits (BMS ceiling) |
| `0x213` | 531 | Charger status + **billing flag** |
| `0x508` | 1288 | Fast charger param 1 + **connector latched** |
| `0x584` | 1412 | EVSE ID low 8 bytes |
| `0x585` | 1413 | EVSE ID high 8 bytes |
| `0x62D` | 1581 | Charger connected(type)/plugged (byte0) |

### 9.4 Updated "still missing"

Everything in §8.4 **except** the following, which are now resolved from firmware:
- ✅ Charger-type/plugged bit positions on `0x62D`
- ✅ Billing-status bit on `0x213`
- ✅ Connector-latched bit on `0x508`; EVSE-ID byte layout on `0x584/0x585`
- ✅ Boost as a distinct charger type + charge mode

Still open (needs a live `ch_can` tap, unchanged): SC auth `0x080/081/083` + FC auth
`0x53x/0x56x` crypto, FC V/I scaling bytes, cycle times, confirmed baud + inlet pinout.

### 9.5 Feed this into the tools

Add `0x508`, `0x584`, `0x585`, and the 4-state `ChargerTypes` to the DBC / charge-session
recorder (they are **absent** from `da_can_dbc.json` today). Decoding `chargerBillingStatus`
and the EVSE-ID during a Bolt Blaze session tells you whether the station authenticates /
bills and which station id it presents — useful signal even before a charge-CAN tap.
