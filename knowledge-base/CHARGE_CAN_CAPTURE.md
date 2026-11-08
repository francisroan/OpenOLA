# Charge-CAN capture (ESP32 / Arduino + MCP2515)

Goal: log the scooter **charge CAN** (`ch_can`) so we can build a **bit-exact**
Hyper/DC protocol for a manufacturer. Firmware gives IDs/names only; **payload
layout + auth + timing require a real log.**

Confirmed on your bike (17 Sep 2026):
- One charge socket → one contactor → battery (SC and FC share HV path)
- Target = **DC Fast / Hyper**
- Tooling = ESP32 or Arduino + MCP2515

Sketch: `tool/charge_can_sniff/charge_can_sniff.ino`

---

## 0. Safety (non-negotiable)

| Do | Do not |
|---|---|
| Probe only **CAN_H / CAN_L / GND** (logic, ~2.5 V dominant differential) | Touch or bridge **HV+ / HV−** (pack voltage) |
| Scooter **OFF**, charger **unplugged**, wait for contactor open before probing | Hot-plug HV while probing |
| Use a **common GND** between MCP2515 module and scooter signal ground | Float the MCP2515 ground |
| Prefer **listen-only** mode (sketch enables it) | Transmit random frames “to test” on the charge bus |

If you are unsure which pins are HV: **stop**. Measure with a DMM first (see §2).

---

## 1. Hardware

- ESP32 (preferred) or Arduino Uno/Nano (5 V SPI — use a 5 V MCP2515 board)
- MCP2515 + TJA1050 (or similar) **breakout with 120 Ω terminator jumper**
- Dupont wires; optional logic-level shifter only if mixing 3.3 V MCU with a 5 V-only board incorrectly wired
- USB cable to PC for Serial log

### ESP32 ↔ MCP2515 (default in sketch)

| MCP2515 | ESP32 |
|---|---|
| VCC | 5 V (or 3.3 V if your module is 3.3 V rated — check silkscreen) |
| GND | GND |
| CS | GPIO 5 |
| SO (MISO) | GPIO 19 |
| SI (MOSI) | GPIO 23 |
| SCK | GPIO 18 |
| INT | GPIO 4 (optional; sketch polls) |

Change pins at top of `.ino` if your wiring differs.

### Terminator

- Charge bus already has termination on the scooter (and on a real charger).
- On the MCP2515 board: **remove / open the 120 Ω jumper** while sniffing mid-bus
  (two terminators is OK; three is bad). If you see nothing and the bus is
  unterminated at the open connector, **try with terminator ON**.

---

## 2. Find charge-CAN pins on the inlet

With scooter OFF, charger out:

1. Open the charge connector / harness. Identify pins with a photo + pin count.
2. DMM continuity / voltage:
   - **HV+ / HV−**: high resistance to chassis when contactor open; when you later
     charge, these carry pack voltage — **never wire these to MCP2515**.
   - **CAN_H / CAN_L**: twisted pair; ~60 Ω between H–L with bus powered and
     terminated (two 120 Ω in parallel). At rest ~2.5 V each to GND when bus is up.
   - **GND / wake / PP / sense**: low-voltage auxiliaries — useful, not for HV.
3. Confirm: with scooter awake (not charging), CAN_H–CAN_L should show activity
   on a scope **or** the sniffer will start printing frames once baud is right.

Wire: **CAN_H → MCP2515 CANH**, **CAN_L → CANL**, **GND → GND**.

---

## 3. Baud (no scope required)

The sketch **auto-tries** `500000`, `250000`, `125000` kbps for 3 s each and picks
the rate with the most good RX frames / fewest errors.

| Result | Meaning |
|---|---|
| Clear winner (e.g. 500k, hundreds of frames) | Use that baud forever |
| All zero | Wrong pins, bus asleep, or wiring — wake scooter / plug slow charger |
| Errors on all rates | Noise, missing GND, or not CAN |

Expected for automotive charge CAN: **500 kbit/s** most likely; 250 k also common.
PERSINO’s 250 k J1939 is unrelated — do not assume it.

---

## 4. Capture procedure (exact)

### A. Dry run — bus alive (no charger)

1. Flash `charge_can_sniff.ino` (Arduino IDE: board = your ESP32, install
   **库** `mcp_can` by coryjfowler — Library Manager search `mcp_can`).
2. Open Serial Monitor **115200**.
3. Power scooter ON (idle). Connect sniffer to charge CAN pins.
4. Note the line `SELECTED_BAUD=...`. You should see IDs scrolling.
5. Save log: in Serial Monitor enable timestamps, or use:

```text
arduino-cli monitor -p COMx -c baudrate=115200 > captures\ch_can_idle.txt
```

(or PuTTY / RealTerm → log to file)

### B. Slow-charge capture (validates method + SC frames)

Even though you want Hyper, **do this first** — proves pinout/baud and logs
`0x00B / 0x080–083 / 0x120 / 0x121 / 0x213`.

1. Start logging.
2. Plug OEM slow charger; charge ≥ 2–3 minutes; unplug cleanly.
3. Save as `captures/ch_can_slow_YYYYMMDD.txt`.

### C. Bolt Blaze / 3 kW DC (do this — highest priority for your goal)

User report: **Bolt Blaze DC charges ~3 kW**, but the scooter UI shows **regular
charging**, not Hyper. That almost certainly means the station is on the
**Slow_Charger / SC protocol path** (`0x00B` / `0x080` / `0x213` / BMS `0x120`–
`0x121`), not the Fast/Hyper path (`0x500` / `0x508`). Power ≠ UI label.

For a **3 kW third-party DC brick**, a Bolt Blaze log is the right manufacturer
target — clone what already works at your power.

**Easiest first capture (no wiring):** desktop GUI **Status → Record charge session**
(or APK Status same button) while Wi‑Fi is up at Bolt Blaze. Saves JSONL under
`captures/charging/`. Then optionally do the MCP2515 charge-port tap for auth IDs.

1. Sniffer on charge CAN, baud locked, logging before plug-in.
2. Plug Bolt Blaze → charge ≥ 2–3 min with current flowing → normal stop.
3. Save `captures/ch_can_boltblaze_YYYYMMDD.txt`.
4. Repeat once at a different SOC if possible.

**Good Blaze/SC-path log must contain:**

| ID | Role |
|---|---|
| `0x00B` | Charger wakeup / identity |
| `0x080` / `0x081` / `0x083` | SC auth (if used) |
| `0x213` | Charger status / available V·I |
| `0x120` / `0x121` | BMS voltage & **current demand** (your 3 kW ceiling) |
| Optionally `0x130` / `0x180` | Mode / C-rate (expect SC_* not FC_*) |

If you also see `0x500`/`0x508`, the station is doing Fast path despite UI — note it.

### D. True Hyper / FC capture (only if you need Hyper UI / higher C-rate)

OEM Hyper (or a station that sets `Charger_Connected=Fast` and
`Vehicle_Mode=FC_CHARGE_*`). Without that, FC bit layouts stay unconfirmed.

1. Same sniff setup.
2. Full Hyper session ≥ 30–60 s current.
3. Save `captures/ch_can_hyper_YYYYMMDD.txt`.

**Good Hyper log IDs:** `0x500`–`0x502`, `0x508`–`0x509`, `0x530`/`0x531`,
`0x534`–`0x563`, `0x580`–`0x587`.

### D. What “good” Hyper / Blaze log contains (after recording)

GUI/APK **Record charge session** writes JSONL to `captures/charging/` (desktop)
or Android `Android/data/.../files/charging/` (APK). Bring those files back into
this repo for decoding.

CSV / JSONL lines look like:

```text
t_ms,id_hex,dlc,b0,b1,b2,b3,b4,b5,b6,b7,flags
12450,500,8,12,34,56,78,9A,BC,DE,F0,RX
```

Drop that folder into this repo — we decode against BCM layouts and write the
manufacturer PDF.

---

## 5. Parallel: vehicle CAN (optional)

`20_cmd.cmd dump 60` while Hyper is connected may catch **mirrored** FC frames
(`0x508/509/510/531/584–587`) on vehicle CAN. Useful backup; **charge-port sniff
is still authoritative** for the charger.

---

## 6. Path to a file you can pay against

| Gate | Criteria |
|---|---|
| Draft | Firmware ID list (already in `CHARGING_PROTOCOL.md`) — **do not pay on this alone** |
| Confirmed | Hyper log with IDs above + decoded scaling + cycle times + auth transcript |
| Manufacturer PDF | PERSINO-style doc with Ola IDs, bit tables, state machine, electrical pinout |

If Hyper access is delayed: we can RE BCM `encode_ch_can_0x500` / `0x508` for
**EV-side bit layouts**, but **charger auth still needs a live Hyper trace**.
