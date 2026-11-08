# GUI diagnostic dashboard — 12 September 2026

Implemented in `tool/health_dashboard.py`, mounted in the Diagnostics page.
Uses the existing Wi-Fi backend and DBC; no ADB dependency or new actuator writes.

## Operation

Connect, open Diagnostics, and select Start monitoring. This uses the existing
broadcast stream and does not request Service mode or security access. Switching
from actuator diagnostics to monitoring uses the existing stream/session cleanup.

Six searchable views:

- Fault signals: DBC names matching fault/error/inhibit/derate and related terms.
  Fresh single-bit fields show asserted/not asserted. Multi-bit values remain raw
  status. Search classification is not an authoritative fault severity map.
- Stored DTCs: individual explicit BMS/VCU/MCU reads; descriptions, code and status
  flags with receipt time. Reads pause live display and retain existing bench
  confirmation. Failures replace prior results visibly. Empty results mean no
  codes returned for the existing requested status mask, not a complete clean bill
  of health. No automatic session/access, retry, clearing or reset is added.
- Battery: source-decoded battery/BMS/cell/SOC/contactor values. No guessed health
  thresholds or recalibration of source units.
- Drive inputs: specific existing DBC brake, stand, throttle, drive-request,
  contactor and mode signals. Raw numeric encodings retained; no safe-to-drive
  verdict, simulated brake or remote Drive activation.
- Communication: per-message freshness for the known DBC. Missing optional frames
  do not establish an ECU failure; three seconds is a display threshold only.
- Events: last 1,000 observed fault-signal value/freshness changes during GUI use.
  This is a sampled display event history, not lossless capture of every CAN edge.

Missing values are Not received; replay is Offline; stopped display is Paused;
disconnected values are Disconnected; old live values are Stale. These are never
shown as current asserted/not-asserted observations. Historical raw values remain
visible alongside their state and age. Offline replay does not generate live events.

Export report saves JSON with current observations, mode label, DTC snapshots,
errors, timestamps, and bounded event history. Export does not transmit data.
Source DBC is untouched. The MoveOS 3 additional CAN names remain research leads
and are not decoded or used for writes without confirmed layouts.

## Validation

- Three pure model tests cover missing, stale, disconnected, paused and replay
  values plus single-bit clear/asserted/unexpected states.
- Offline dashboard UI test covers six tabs, fault transitions, DTC success then
  failure, and report JSON export with mocked ECU calls.
- Existing Windows GUI smoke passes at 1180×820 and 1000×720, offline capture,
  filtering, settings, learning window and clean shutdown.
- Tcl/Tk tests ran outside the sandbox; no physical scooter connection was made.

Next physical verification: Start monitoring, inspect each tab, then make one
explicit ECU DTC read with the existing parked/charger-unplugged confirmation.
Restart monitoring afterward. Firmware may refuse a plain read; that error is
preserved rather than triggering an automatic unlock.
