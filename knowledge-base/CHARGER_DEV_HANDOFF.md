# Ola S1 — Charge-CAN protocol handoff (Slow Charger path)

**For:** third-party charger developer / manufacturer
**Status:** SC path implementation-ready, incl. DC up to ~5 kW via `0x213` Iavail (Blaze DC
confirmed at 2.5 kW). Dedicated Fast/Boost class still unspecified (see §9).
**Date:** 18 Sep 2026
**Basis:** live `ch_can` captures + independent vehicle-CAN GUI decode + vehicle DBC + BCM firmware.

Every row is tagged:
**[C]** confirmed on live capture · **[G]** confirmed by GUI/vehicle-CAN decode ·
**[D]** from vehicle DBC (`da_can_dbc.json`) · **[⚠]** inferred, verify before relying.

---

## 1. Physical / link layer  **[C]**

| Item | Value |
|---|---|
| Bus | Dedicated **`ch_can`** exposed at the charge socket (11-bit standard IDs) |
| Bit rate | **500 kbit/s** — triple-confirmed (in-session, probe, charger-alone bench) |
| Frame format | Classic CAN, 8-byte DLC on all charge frames |
| Byte order | **Intel / little-endian** for multi-byte signals |
| Termination | 120 Ω expected at bus ends |

**Topology (confirmed).** `ch_can` is a **dedicated bus at the socket**. The VCU/BCM
**mirrors a subset** of charge frames (`0x00B, 0x120, 0x121, 0x213`) onto the separate
**vehicle CAN** for the dashboard. **Auth (`0x080/081/083`) and the fast-charger family
(`0x500/501/502/58x`) exist ONLY on `ch_can`** — they never appear on vehicle CAN.
(Proven: a Wi-Fi vehicle-CAN sniff received the mirror set but none of the auth/FC frames.)

**Node behaviour requirement.** The charger must be a well-behaved bus node:
transmit **only its own IDs**, never emit vehicle IDs, and tolerate all other traffic.

---

## 2. Message directory (SC path)

Dir = direction. Cycle = observed period. All DLC 8.

| ID | Dir | Name | Cycle | Src |
|---|---|---|---|---|
| `0x00B` | Charger → EV | Slow_Charger_to_battery_wakeup + identity | ~3 ms when waking, **100 ms** in-session | [C] |
| `0x040` | BMS → bus | MBMS_WakeUp_Reason | 100 ms | [C] |
| `0x080` | VCU → Charger | Authentication_Request | 100 ms | [C] |
| `0x081` | VCU → Charger | Authentication_Status | 100 ms | [C] |
| `0x083` | Charger → VCU | Authentication_Response | ~100 ms, only at connect | [C] |
| `0x120` | BMS → Charger | Overall_Battery_Status (I, SOC, V-limit) | ~850 ms | [C][G] |
| `0x121` | BMS → Charger | Charge/Discharge current limits | 100 ms | [C][G] |
| `0x213` | Charger → EV | Charger_Status (mode, V/I avail, faults) | 100 ms | [C][G] |

Direction is **bench-confirmed for `0x00B`** (see §3) and firmware-named for the rest.

---

## 3. Wake + handshake sequence  **[C]**

Observed, charger powered but **not** yet connected, then connected:

1. **Wake flood.** Charger alone transmits **`0x00B` at ~300 Hz** (every ~3 ms) — nothing
   else — to wake the sleeping BMS. This is the only frame a charger emits unsolicited.
2. **Pack wakes.** BMS starts `0x040` (wake reason), `0x120/0x121` (limits). `0x00B` rate
   drops to **100 ms**.
3. **Auth.** `0x080` (req) → `0x083` (charger response) → `0x081` (status). See §5.
4. **Capability exchange.** Charger publishes available V/I in `0x213`; BMS publishes limits
   in `0x120/0x121`.
5. **Energy transfer.** BMS closes charge switch (`Charge_Switch_demand`, contactor state 6),
   charger regulates current to `min(own available, BMS 0x121 limit)`. Mode = **CC**.
6. **Stop.** On unplug the bus goes idle within <1 s; `0x213` state leaves the active value.

---

## 4. Signal layouts (bit-exact)

### 4.1 `0x00B` Wake + identity  **[C][D]**
Live payload (static): `01 0B C0 32 83 23 11 00`

| Signal | Start bit | Len | Notes |
|---|---|---|---|
| WakeReq | 0 | 2 | |
| Serial | 8 | 32 | bytes 1–4 → `0x8332C00B` (LE) |
| FW ver | 40 | 4 | |
| HW ver | 44 | 4 | |
| Manufacturer_Code | 48 | 4 | byte 6 low nibble = `0x1` |
| Bootloader | 52 | 4 | |

### 4.2 `0x120` Overall_Battery_Status (BMS → Charger)  **[C][G][D]**

| Signal | Start | Len | Scale / offset | Units | Live |
|---|---|---|---|---|---|
| Overall_Battery_Current | 0 | 16 | 0.01, −300 | A | ramped to ~11.5, held |
| Overall_SOC | 16 | 16 | 0.01 | % | 35.2 → 36.5 |
| Overall_Charge_Voltage_limit | 32 | 16 | 0.001 | V | 31.0 → 52.0 |
| Charger_Mode_Request | 48 | 3 | 1 | enum | 1 (CC) |

> Note: `Current` reads ~0 at the plug/unplug instants; sample mid-session for the real value.

### 4.3 `0x121` Charge current limit (BMS → Charger)  **[C][G][D]**

| Signal | Start | Len | Scale/offset | Units | Live |
|---|---|---|---|---|---|
| Overall_Charge_current_limit | 0 | 16 | 0.01 | A | **steady 12.0** |
| Overall_Discharge_current_limit | 16 | 16 | 0.01, −400 | A | 0 |
| Regen / Discharge power limits | 32 / 48 | 16 | 1 | W | — |

> **The charger MUST track `0x121` continuously** and never exceed it. Live values:
> **12 A** with the stock slow charger, **49.1 A** with the Bolt Blaze DC — in both cases
> equal to the charger's own advertised available current (see §7).

### 4.4 `0x213` Charger_Status (Charger → EV)  **[C][G][D]** — Intel/LE

| Signal | Start | Len | Scale | Notes |
|---|---|---|---|---|
| Charger_Status_Signal | 0 | 1 | 1 | byte0=0x83 = active in session |
| Charger_Mode | 1 | 3 | 1 | enum |
| Charging_Voltage_Available_range | 4 | 16 | 0.1 V | live 60.0 V (both chargers) |
| Charging_Current_Available_range | 20 | 16 | 0.1 A | 12.0 A slow / **49.1 A Blaze DC** |
| Slow_Charger_Fault_Information | 36 | 2 | 1 | |
| Charger_output_Short_circuit_error | 40 | 1 | | |
| Charger_under/over_temperature_error | 41–42 | 1 | | |
| Low_AC_voltage_error | 43 | 1 | | AC-OBC heritage; idle on DC |
| Rectifier_hardware_error | 44 | 1 | | idem |
| Authentication_Error | 45 | 1 | | |
| Battery_Parameter_Time_out_error | 46 | 1 | | |
| Data_Corruption_error | 47 | 1 | | |
| Charge_control_message_timeout_error | 48 | 1 | | |
| chargerBillingStatus | byte6 bit2 | 1 | | billing/paid-session flag [G] |

---

## 5. Authentication — **STATIC / replayable**  **[C]**

`0x080` (request) and `0x081` (status) are **vehicle-side and identical for every charger**.
`0x083` (charger response) is a **fixed per-charger identity** — constant across all connects
of a given charger, different between chargers:

| Frame | Dir | Bytes | ASCII | Seen on |
|---|---|---|---|---|
| `0x080` | VCU → Charger | `37 42 31 31 00 00 00 00` | "7B11" | all |
| `0x081` | VCU → Charger | `01 00 00 00 00 00 00 00` | status=01 OK | all |
| `0x083` | Charger → VCU | `45 41 37 35 45 38 37 37` | "EA75E877" | stock slow charger |
| `0x083` | Charger → VCU | `35 37 41 45 37 37 38 45` | "57AE778E" | Bolt Blaze DC |

**No rolling challenge/response, no per-session nonce.** The vehicle accepted **two different
`0x083` values with `auth_err=0`**, so it is **not a single-key lockout** — a charger presents
its own fixed identity string and the vehicle admits it. A third-party charger can therefore
reproduce a valid `0x083` deterministically. Cadence differs: the slow charger sends `0x083`
only a few times at connect; the Blaze DC streams it continuously (~10 Hz).
`Authentication_Error` (`0x213` bit45) / `ChargerReAuthError` (`0x411`) can also fire
mid-session — handle both.

> ⚠ Open: whether an *arbitrary* `0x083` is accepted or only values on an internal list.
> Two distinct real charger IDs both passed; we have not tried a fabricated one.

---

## 6. Faults / timeouts the charger must honour  **[D]**
`0x213` carries: short-circuit, over/under-temp, auth error, **battery-parameter timeout**,
data-corruption, **charge-control-message timeout**. Watchdogs on both sides — keep the
100 ms cadence or the BMS/charger will fault out.

---

## 7. Control loop & current-limit — **RESOLVED**  **[C][G]**

Regulation: **charger output current = `min(charger available, BMS 0x121 limit)`**, CC mode.
Proven across two chargers, GUI cross-checked:

| | Stock slow charger | **Bolt Blaze DC** |
|---|---|---|
| `0x213` Iavail (charger advertises) | 12.0 A | **49.1 A** |
| `0x121` (BMS grants) | 12.0 A | **49.1 A** |
| `0x120` actual current | ~11.5 A | **~48 A** |
| Pack voltage | 51 V | 52–53 V |
| Power | ~0.6 kW | **~2.5 kW** |
| `chg_mode` / `veh_l2` | CC / SC_CHARGE ACTIVE | CC / SC_CHARGE ACTIVE |

**The clamp hypothesis is confirmed: `0x121 = min(pack_capability, charger_available)`.**
The BMS returned *exactly* each charger's advertised current. The pack's true ceiling is
visible in the GUI during idle gaps between charges: **`charge_i_lim = 96.0 A`** (CRC-validated).

> **Feasibility answer: the battery is not the bottleneck — the charger is.** Pack allows
> **~96 A (~5 kW @ 53 V)**; the Blaze advertises only 49.1 A so delivers ~2.5 kW. A charger
> advertising a higher `0x213` Iavail (up to ~96 A) should draw the full pack capacity — on
> the **slow-charger protocol path** (see §9).

> Internal note: the "96 A" here is the GUI-validated idle pack limit — real. A *different*
> single-frame "96 A" in a slow-charger raw capture was corrupt and was retracted; don't
> conflate them.

---

## 8. Getting decoded telemetry without a `ch_can` tap  **[G]**
The vehicle-CAN GUI (`captures/charging/*.jsonl`) decodes the mirrored subset with signals:
`0x11C` (Contactor_state, Pack_SOC, BMS_Mode), `0x640` (Charge_Switch_demand, bus voltage),
`0x130` (CC/CV phase), `0x62D` (charger connected/plugged), plus a `vitals` roll-up
(SOC, A, V, W, i-lim, mode, faults). Useful for validation and for live monitoring during a
session — but it will **not** show auth or FC frames (those are `ch_can`-only).

---

## 9. DC charging & charger class — **CAPTURED (Bolt Blaze DC)**  **[C][G]**

**Key finding: a DC charger delivering ~2.5 kW runs entirely on the SC protocol path and is
classified "Slow Charger."** The Blaze DC used `0x00B` wake + `0x213` status + SC auth; the
vehicle reported `charger_type = Slow Charger`, `veh_l2 = SC_CHARGE ACTIVE`, `rate =
SC_C_RATE_01`, `mode = CC` — for the whole session. Higher power came purely from a higher
`0x213` Iavail (49.1 A), **not** a different protocol.

**Charger class is set by which message set the charger speaks, not by a self-declared type
byte.** `0x62D Charger_Connected` (byte0 bits0–1: 1=Fast, 2=Slow, 3=Boost) is the *vehicle's*
verdict, published on vehicle CAN. To be classified Fast/Boost a charger must actually drive
the **FC message set** — which nothing has yet done:

**The FC frames stayed idle even on DC.** `0x500 = 00 20/22 00…` (status flag only),
`0x501`/`0x502` = zeros throughout. So the FC control loop was never exercised, and these
remain **unspecified**:

- FC layouts: `0x500/501/502` (EV params), `0x508/509/510` (charger params), `0x530/531`
  keepalives, `0x53x/54x/55x/56x` auth, `0x580–0x587` identification / EVSE ID.
- FC contactor / connector-latch (`0x014`, `0x508` byte1 bit2).
- What input flips `0x62D` to Fast/Boost.

**To specify the fast path you must drive the FC frames**, which no available charger does.
The practical route is the **Arduino charger-emulator** (`ch_can` TX): replay auth, inject
live FC demand frames, and observe `0x62D` / BMS response. Until then, treat **§1–§8 + this
section as a complete SC-path spec** (covering DC up to ~5 kW via `0x213` Iavail), and the
dedicated **Fast/Boost class as unspecified**.

---

## 10. Data provenance
- `captures/charging/ch_can_20260918_185325.txt` — 5-min sustained SC session (control loop)
- `captures/charging/ch_can_20260918_184220.txt` — multi-session (auth static proof)
- `captures/charging/ch_can_20260918_191338.txt` — charger-only bench (wake + direction)
- `captures/charging/ch_can_20260918_232616.txt` — **Bolt Blaze DC, 2×~6-min (§7/§9)**
- `captures/charging/charge_session_20260918_185433.jsonl` — vehicle-CAN GUI decode (slow)
- `captures/charging/charge_session_20260918_232727.jsonl` — **vehicle-CAN GUI decode (Blaze DC)**
- `reverse_engineering/da_can_dbc.json`, `CHARGING_PROTOCOL.md` — DBC + prior RE

Tooling: `tool/charge_can_sniff/` (`charge_can_sniff.ino`, `log_serial.py`, `split_sessions.py`).
