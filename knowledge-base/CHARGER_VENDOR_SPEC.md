# Ola SC-path charger node — vendor spec draft (v0.1)

**Purpose:** frame-by-frame spec for the charger-side (EVSE) CAN node, so a 3 kW DC module can
speak Ola's *slow-charger (SC) protocol* natively. Intended as the one-time CAN change.
**Basis:** re-analysis of `captures/charging/ch_can_*.txt` (Slow charger 185325/184220, Bolt Blaze
DC 232616) plus `CHARGER_DEV_HANDOFF.md`. **Written 30 Sep 2026.**

Tags: **[C]** measured in the captures (this doc re-derived it) · **[H]** from HANDOFF/DBC, not
re-verified here · **[P]** PROPOSED — my recommendation, *not* observed on any real charger ·
**[?]** unknown, must be tested before the firmware is frozen.

> This is a draft for engineering review. Do not send it to a vendor until the **§9 pre-freeze
> tests** have been run on the bench — several fields cannot be corrected after a one-time change.

---

## 1. Physical / link  [C][H]
- Dedicated `ch_can` bus at the charge socket, **500 kbit/s**, classic CAN 2.0, **11-bit IDs**, DLC 8 on
  every charge frame, **Intel/little-endian** signals.
- Termination 120 Ω at the ends. Charger transmits **only its own IDs** (§3).
- Isolate the charger CAN from the module's mains-side logic (this bus reaches the vehicle).
- The vehicle mirrors `0x00B/0x120/0x121/0x213` onto its internal bus; auth (`0x080/81/83`) and the
  `0x5xx` family are `ch_can`-only [H].

## 2. What is on the bus (Blaze session 1, 366 s) [C]

| ID | Sender | Period (median) | Notes |
|---|---|---|---|
| `0x00B` | Charger | ~93–100 ms | wake + identity, static payload |
| `0x083` | Charger | ~103 ms | auth response, static payload |
| `0x213` | Charger | ~103 ms (min 84, max 418) | status + V/I available |
| `0x040` | BMS | ~52 ms | wake reason, `03 00 …` steady |
| `0x080` / `0x081` | Vehicle | 100 ms | auth request/status, **keep running after the charger leaves** |
| `0x120` | BMS | irregular: median 0.6–0.8 s, **max 4 s** | do **not** use as a watchdog |
| `0x121` | BMS | 100 ms (max gap ≈ 0.5 s) | current limit — the control input |
| `0x500/501/502`, `0x580–583` | Vehicle | 100–2500 ms | fast-charge family, **idle zeros** on SC path; ignore |

## 3. Frames the charger MUST transmit

### 3.1 `0x213` Charger_Status — every 100 ms [C][H]
Signal layout (LE): `bit0` status(1=active) · `bits1–3` mode (1 = CC) · `bits4–19` V-available
×0.1 V · `bits20–35` I-available ×0.1 A · fault bits `36–48` (see HANDOFF §4.4) · byte6 bit2 =
billing flag (keep 0).

Observed payloads, decoded:

| Payload | Meaning |
|---|---|
| `00 00 00 00 00 00 00 00` | idle / not ready (Blaze, first ~8–10 s) |
| `80 25 00 00 …` | status 0, V=60.0, I=0 (slow charger, first ~0.3 s) |
| `82 25 80 07 …` | status 0, CC, 60.0 V, **12.0 A** (slow charger, pre-active) |
| `83 25 80 07 …` | **ACTIVE**, CC, 60.0 V, 12.0 A (slow charger) |
| `82 25 40 1F …` | status 0, CC, 60.0 V, **50.0 A** (Blaze, pre-active, ~1.0 s) |
| `83 25 B0 1E …` | **ACTIVE**, CC, 60.0 V, **49.1 A** (Blaze) |

**Correction to HANDOFF §4.4:** "byte0 = 0x83 means active" is a coincidence. The high nibble of
byte 0 is the low nibble of the voltage field (60.0 V = 0x258 → `8`). Decode `status = bit0`,
`mode = bits1–3`; at any other voltage byte 0 will differ (e.g. 54.0 V → `0xC3`).

### 3.2 `0x083` Authentication_Response — every ~100 ms, from power-up [C]
Static 8-byte ASCII string per charger. Blaze `35 37 41 45 37 37 38 45` ("57AE778E"); stock
`45 41 37 35 45 38 37 37` ("EA75E877"). Blaze starts it at the same instant as `0x213`. **[?] whether
an unlisted value is accepted — §9 test 1.**

### 3.3 `0x00B` Wake + identity — every ~100 ms [C][H]
Blaze: `01 86 D1 12 00 81 9A 89` (constant). Stock: `01 0B C0 32 83 23 11 00`. Fields per
HANDOFF §4.1 (serial 32 b, FW/HW ver, Manufacturer_Code, bootloader). When the charger is powered
but **not** yet connected it sends `0x00B` alone at ~300 Hz to wake the BMS [H, bench]. **[?] whether
the vehicle validates Manufacturer_Code / serial — §9 test 2.**

## 4. Frames the charger consumes

- `0x121` bytes 0–1 = **charge current limit**, ×0.01 A (LE). Blaze: `2E 13` = 49.10 A. This is the
  control input; it equals the charger's advertised `Iavail` once active [C].
- `0x120` bytes 0–1 = pack current (×0.01 − 300 A), bytes 2–3 = SOC ×0.01 %, bytes 4–5 = a voltage
  ×0.001 V. Measured: this voltage **tracks live pack voltage** (51.4→51.9 V slow-charger session;
  52.6→53.7 V Blaze) and reads **31.0 V** when idle — the DBC name "charge voltage limit" appears
  misleading. Usable as a pack-voltage input [C]; treat as [?] until confirmed against a meter.
  Byte 6 bits0–2 = charger-mode request (1 = CC observed).
- `0x040`, `0x080`, `0x081`: no charger action observed. `0x080` is constant `37 42 31 31 …` ("7B11").

## 5. Startup sequence and timing [C]

| Step | Slow charger | Blaze DC |
|---|---|---|
| Charger `0x213` starts | t≈0–10 ms | t≈1.2 s (first plug) |
| `0x213` = idle/zero | ~30–100 ms | **~8–10 s** |
| `0x213` = status 0, mode 1, Iavail set | t≈0.3–1.2 s | ~1.0 s |
| `0x213` = **active (bit0=1)** | **~5 s** after the previous step | after ~1.0 s |
| `0x121` limit reaches Iavail | ~5–6 s | ~10.5 s (first 50.0 A, then 49.1 A) |

Observations the charger firmware must respect:
- The pre-active step ("status 0, Iavail set") is real and lasted **1 s (Blaze) to 5 s (stock)**. The
  BMS closed its charge switch only after `0x213` went active. Do not assume a fixed delay: **[P]** go
  active only when the output stage is ready and hold the pre-active state for ≥1 s.
- `0x121` also ramps up in ~1 A steps (0→11 A within 2 s, and 0→51 A over 5 s after unplug) with **no
  charger present**. Don't treat a non-zero `0x121` as proof the vehicle is in a charge session.

## 6. Control loop [C][H]
`I_out = min(Iavail, 0x121 limit)`, CC mode. Blaze: Iavail 49.1 A → `0x121` 49.1 A → pack current
46.7–49.5 A, SOC 30→41.6 % over two sessions, no faults. The pack's ceiling was measured at 96 A
(HANDOFF §7) — advertising up to that is **not yet tested with a charger [?]**.
**Not captured: CV taper and end-of-charge.** Both sessions stopped at 36–42 % SOC. What the BMS
does near 100 % (limit → 0, mode change, `0x120` request) is unknown.

## 7. Stop behaviour — what the captures actually show [C]

In **every** real-charger session (5 stock, 2 Blaze) the last `0x213` is the **active** payload and
the charger's frames (`0x213`, `0x083`, `0x00B`) simply **stop within the same ~10 ms**, ~1.2–1.3 s
before the vehicle-side frames stop. There is **no observed graceful end frame**. The connector/pilot
drop is what the vehicle sees.

So "a real charger ends with a `0x213` transition" (in our older notes) is **not supported by the
captures**; the transition-out-of-active idea is an inference. What is known: abruptly silencing CAN
*while the pilot is still connected* left the S1 latched in "charging" (see memory note on the
stuck state).

**[P] Requirements for the vendor:**
1. On any stop reason, drop output current to 0 **first**.
2. Keep transmitting `0x213` for ≥1 s with status = 0 and Iavail = 0, then stop TX.
3. On **loss of `0x121` for >1 s** (see §2: normal gaps ≤0.5 s), or any fault: output → 0, same
   sequence.
4. Set the relevant `0x213` fault bit for the cause (over-temp, short, …).
5. Never leave the module regulating with the CAN link down; watchdog must be in hardware/independent
   of the CAN stack.

## 8. Limits the module must enforce itself [P]
Max output voltage, max output current, and over-temperature cut-out configured **inside the
module**, independent of anything received over CAN. For a 3 kW build the Blaze values (60.0 V,
49.1 A) are a proven starting point; do not advertise more than the power stage can sustain.

## 9. Pre-freeze tests (bench, no pack) — must pass BEFORE the one-time change

Use the Arduino emulator (`tool/charge_can_emulator/`) against the S1 with a battery-safe setup.

1. **Arbitrary `0x083`:** does the vehicle accept a value that no real charger uses? If not, the
   charger can only be shipped with a value from a known list — and we don't know the list.
2. **Arbitrary `0x00B` identity** (serial / Manufacturer_Code / FW/HW): same question.
3. **Iavail steps:** 12 A, 49.1 A, 60 A, up to ~96 A. Confirm `0x121` follows and there's no fault.
4. **Pre-active dwell:** shortest `0x213` "status 0" period the BMS accepts before active.
5. **Stop variants:** (a) silent stop with connector removed, (b) status 0/Iavail 0 for 1 s then stop,
   (c) silent stop with connector still latched. Record which one leaves the S1 clean (the latch we hit
   on 19 Sep).
6. **Timeout:** stop `0x213` for 0.2 / 0.5 / 1 / 2 s while charging; record BMS reaction and
   `Charge_control_message_timeout_error`.
7. **Full charge:** at least one run to termination to capture the CV taper.
8. **Pack voltage field:** confirm `0x120` bytes 4–5 against a meter.

## 10. Known gaps
- Paid classes (Boost/Hyper) are out of scope. On the Ola stack, the FC family `0x5xx` and a billing
  flag exist; emulating Boost triggered `CHARGING_PAYMENT_DUE` on our S1 (memory note) — the SC path
  as specified here stays on the standard class and did not.
- Only one vehicle (S1) tested. Other Ola models/firmware are unknown; firmware updates may change
  acceptance rules.
- No captures below 30 % or above 42 % SOC, none of a fault, none of an end-of-charge.
