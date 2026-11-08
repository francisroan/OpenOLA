# S1 Air motor-controller fault readout — 8 November 2026

An owner-supplied OpenOLA screenshot shows a connected **S1 Air, model code 5, MoveOS 5.0.0**, with three MCU stored codes. This is a read-only interpretation of the screenshot and bundled diagnostic-app DTC table. No repair, controller test, or fresh post-clear scan was performed. Personal vehicle identifiers from the screenshot are intentionally omitted.

| Raw MCU DTC | Bundled catalog wording | Meaning on this Air |
| --- | --- | --- |
| `1301F0` | Software overcurrent protection (Grade 3) | **(i) Unverified** for this model/software profile. |
| `130EF0` | Encoder disconnection (Grade 3) | **(i) Unverified** for this model/software profile. |
| `1318F0` | DC Bus undervoltage fault (Grade 3) | **(i) Unverified** for this model/software profile. |

Each displayed status is `0x08`, whose bit 3 is the confirmed-DTC flag in the diagnostic status convention. This indicates a stored/confirmed code; it does not establish that all three conditions are active now or which happened first. The three codes could share a cause, but the screenshot cannot identify one.

The useful next evidence is a fresh scan with timestamp, scooter power state and battery voltage, plus live battery/MCU voltage and motor/encoder signals if available. Preserve the first read before clearing any DTC. A trained technician can then compare current measurements and connector condition with service specifications. Do not perform calibration or firmware flashing based only on these three descriptions.
