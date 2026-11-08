# OLA S1 CHARGING CAN BUS COMMUNICATION SPECIFICATION — Ver 1.0

---

## 1. Communication Specification

| Item | Value |
|---|---|
| Bus | Charge CAN (`ch_can`); slow-charger control frames also mirrored on vehicle CAN |
| Frame format | Standard CAN 2.0A, 11-bit identifier |
| Bit rate | 500 kbit/s |
| Byte order | Intel (little-endian); multi-byte values low byte first |
| DLC | 8 |

Each node accesses the bus with a fixed set of message identifiers. Messages are addressed
by identifier, not by a J1939 source/destination address.

---

## 2. CAN Network Node Distribution

| Node Name | Function |
|---|---|
| BMS | Battery Management System — publishes battery limits, receives charger status |
| VCU | Vehicle Control Unit — authentication, contactor control, charge supervision |
| SC | Slow Charger (AC/DC ≤ ~3 kW) |
| FC | Fast / Boost Charger (DC) |
| SOM / HU | Head unit — display, logging (listen-only) |

---

## 3. Message Format

Value = Raw × Scale + Offset. Reserved bytes = 0x00.

### Message 1: `0x00B` Slow_Charger_to_battery_wakeup  (SC → BMS)

| OUT | IN | ID | Cycle |
|---|---|---|---|
| SC | BMS | 0x00B | on plug-in |

| Byte | Bits | Name | Scale / Notes |
|---|---|---|---|
| BYTE0 | 0–1 | Battery_Wakeup_Request | 1 |
| BYTE1–4 | 0–31 | Serial_Number | 32-bit |
| BYTE5 | 0–3 | Firmware_version | 4-bit |
| BYTE5 | 4–7 | Hardware_version | 4-bit |
| BYTE6 | 0–3 | Manufacturer_Code | 4-bit |
| BYTE6 | 4–7 | Bootloader_version | 4-bit |
| BYTE7 | — | Reserved | 0 |

### Message 2: `0x120` Overall_Battery_Status_Info  (BMS → Charger)

| OUT | IN | ID | Cycle |
|---|---|---|---|
| BMS | Charger | 0x120 | periodic |

| Byte | Name | Scale | Offset | Unit |
|---|---|---|---|---|
| BYTE0–1 | Overall_Battery_Current | 0.01 | −300 | A |
| BYTE2–3 | Overall_SOC | 0.01 | 0 | % |
| BYTE4–5 | Overall_Charge_Voltage_limit | 0.001 | 0 | V |
| BYTE6 (bits 0–2) | Charger_Mode_Request | 1 | 0 | enum |

### Message 3: `0x121` Overall_Battery_Current_Limit  (BMS → Charger)

| OUT | IN | ID | Cycle |
|---|---|---|---|
| BMS | Charger | 0x121 | periodic |

| Byte | Name | Scale | Offset | Unit |
|---|---|---|---|---|
| BYTE0–1 | Overall_Charge_current_limit | 0.01 | 0 | A |
| BYTE2–3 | Overall_Discharge_current_limit | 0.01 | −400 | A |
| BYTE4–5 | Overall_Regen_Power_Limit | 1 | 0 | W |
| BYTE6–7 | Overall_Discharge_Power_Limit | 1 | −50000 | W |

The charger output must not exceed `min(0x213 available, 0x121 Overall_Charge_current_limit)`
nor the `0x120 Overall_Charge_Voltage_limit`.

### Message 4: `0x213` Charger_Status  (Charger → BMS)

| OUT | IN | ID | Cycle |
|---|---|---|---|
| Charger | BMS | 0x213 | periodic |

| Start bit | Len | Name | Scale | Unit |
|---|---|---|---|---|
| 0 | 1 | Charger_Status_Signal | 1 | — |
| 1 | 3 | Charger_Mode | 1 | enum |
| 4 | 16 | Charging_Voltage_Available_range | 0.1 | V |
| 20 | 16 | Charging_Current_Available_range | 0.1 | A |
| 36 | 2 | Slow_Charger_Fault_Information | 1 | — |
| 50 | 1 | Charger_Billing_Status | 1 | 1 = paid/billed session |

**BYTE5 status flags (bits 40–48):**

| Bit | Name | Meaning |
|---|---|---|
| 40 | Charger_output_Short_circuit_error | 1 = short circuit |
| 41 | Charger_under_temperature_error | 1 = under-temp |
| 42 | Charger_over_temperature_error | 1 = over-temp |
| 43 | Low_AC_voltage_error | 1 = input voltage low |
| 44 | Rectifier_hardware_error | 1 = rectifier fault |
| 45 | Authentication_Error | 1 = auth failed |
| 46 | Battery_Parameter_Time_out_error | 1 = no BMS message |
| 47 | Data_Corruption_error | 1 = bad data |
| 48 | Charge_control_message_timeout_error | 1 = control timeout |

### Message 5: `0x62D` Charger_Connection_Status  (VCU → bus)

| OUT | IN | ID | Cycle |
|---|---|---|---|
| VCU | bus | 0x62D | periodic |

| Byte | Bits | Name | Values |
|---|---|---|---|
| BYTE0 | 0–1 | Charger_Connected | 0 None · 1 Fast · 2 Slow · 3 Boost |
| BYTE0 | 2 | Charger_Plugged_In | 0/1 |

### Message 6: `0x130` BMS Charge Phase  (BMS → bus)

| Byte | Name | Scale | Unit |
|---|---|---|---|
| BYTE0–1 | Charge_current_limit_00 | 0.01 | A |
| BYTE2–3 | Discharge_current_limit_00 (offset −400) | 0.01 | A |
| BYTE4–5 | Charge_Voltage_limit_00 | 0.001 | V |
| BYTE6 (bits 0–2) | Charging_Mode_00 | 1 | enum (below) |

`Charging_Mode_00`: 0 Disabled · 1 CC · 2 CV · 3 Complete · 4 CC End · 5 CV End ·
6 Balancing · 7 Standby.

### Authentication messages (VCU ↔ Charger)

| ID | Direction | Name |
|---|---|---|
| 0x080 | VCU → SC | VCU_to_Slow_Charger_Authentication_Request (seed) |
| 0x083 | SC → VCU | Slow_Charger_to_VCU_Authentication_Response |
| 0x081 | VCU → SC | VCU_to_Slow_Charger_Authentication_Status |

Auth failure sets `0x213` bit 45 (Authentication_Error) and the charger stops output.

### Fast / Boost charger messages (DC)

| ID | Direction | Name | Field |
|---|---|---|---|
| 0x508 | FC → EV | Fast_Charger_Parameter_1 | BYTE1 bit 2 = Vehicle_Connector_Latched |
| 0x500 | EV → FC | EV_Parameter_1 | requested current / target voltage / charging enable |
| 0x501 | EV → FC | EV_Parameter_2 | max charging time / control protocol |
| 0x530 / 0x531 | EV ↔ FC | Keep-alive | Vehicle_Alive / Fast_Charger_Alive |
| 0x584 | FC → EV | EVSE_Identification_Low | BYTE0–7 (station id, low half) |
| 0x585 | FC → EV | EVSE_Identification_High | BYTE0–7 (station id, high half) |

---

## 4. Workflow

### Slow / Boost charge

1. On plug-in the charger sends `0x00B` (serial, firmware, hardware, manufacturer code).
2. Authentication: VCU `0x080` (seed) → charger `0x083` (response) → VCU `0x081` (status).
   On failure the charger sets `0x213` bit 45 and does not output.
3. The BMS sends `0x120` (SOC, charge-voltage limit, mode request) and `0x121`
   (charge-current limit) periodically.
4. The charger publishes `0x213` (available voltage/current, status, faults) and regulates its
   output to `min(available, 0x121 charge-current limit)` within `0x120` voltage limit.
5. Charge phase is reported by `0x130` Charging_Mode_00 (CC / CV / Complete …).
6. If the charger stops receiving BMS messages within the timeout, it sets `0x213` bit 46 /
   bit 48 and stops output.

### Fast charge (DC)

1. Plug-in and contactor status via `0x62D` (Charger_Connected = Fast/Boost) and `0x508`
   (connector latched).
2. Station identity via `0x584` / `0x585`.
3. Keep-alive `0x530` / `0x531` maintained both directions.
4. EV demand on `0x500` / `0x501`; charger regulates within BMS limits (`0x120` / `0x121`).
5. Stop on EV request, EVSE stop, keep-alive loss, or any `0x213` fault bit.
