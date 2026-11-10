# Desktop GUI / Flutter coverage — 0.4.2+11

Desktop reference reviewed 8 October 2026. This file describes source/UI coverage, not physical scooter validation. The active Android/iOS app source is this Flutter project; the Kotlin `apk/` is a separate older app.

| Desktop workspace | Flutter location and coverage |
|---|---|
| Home | Home: battery ring, received vitals, Faults/Reports shortcuts, expandable details |
| Battery | Main Battery tab: Overview/Graphs/Settings, per-cell liquid gauges and details, health/cycles/temperature, usable pack Ah, estimated Wh, live trends/CSV, all desktop BMS configuration read definitions and S1 Pro reference differences |
| Health Report | Reports → Read ECU health report: quick/complete ODX reads across all modules, optional identity inclusion, per-DID errors, cancellation; JSON export. Frozen snapshot remains available as TXT/JSON/share |
| Status | Tools → Vehicle status: vitals, broadcast fault flags, vehicle notification history and reconstructed feature fields |
| Recorder | Tools → Recorder: persistent foreground sessions, local library, open desktop JSONL offline, min/max/last/count, up to six plots, JSONL/CSV save and native share |
| Charging | Optional Charging: charger/current/voltage/power, plug/latch/session flag, full-session recorder shortcut and existing slide-verified stop-charge action |
| Live Data | Optional Live signals: full-height lazy page scroll, search by name/unit/CAN ID, arrival-age metadata, Start/Pause. Full numeric session logging is in Recorder |
| Diagnostics | Faults: automatic stored-fault reads on entry when ready, all three ECU groups, received flags and optional slide-verified clearing/restart/recovery |
| ECU Tests | Optional Actuator tests + Engineering tools: grouped pulse/latch/release controls, head-unit self-tests, existing calibration/HMI commands |
| Firmware | Tools → Firmware: decoded read-only identity/version identifiers, raw bytes and per-field results; no compatibility verdict based only on matching strings |
| Components | Tools → Components: BMS/VCU/MCU selection, all readable ODX identifiers, search, individual or bulk reads, expanded fields/raw data and JSON export |
| S1X parameter reference | Tools → Parameters: imported Phase 1/2 map entries; exact phase is selected only for explicitly identified phase model codes. Other S1X model codes show only definitions common to both maps. CAN values appear only when the active decoder reports the exact mapped signal; UDS map entries are references and are never requested from this screen. |
| Calibration | Optional Parameters/Engineering/Vehicle features: current reads, existing readback-checked writes, AutoTune start/stop, motor-angle read, feature commands and fault transitions |
| Software | Tools → Software: software version, Android version, vehicle identifiers and update-status requests. Flashing remains absent |
| Bluetooth | Optional Bluetooth controls: existing discovery/authentication/control port; physical iOS behavior remains untested |

## Deliberate differences and remaining desktop functions

- Recorder is foreground-only. Leaving the app stops/saves it; it does not promise capture with the screen locked or app backgrounded. Durable files replace the earlier 3,600-row in-memory charging UI.
- Charts use separate physical scales rather than mixed-unit overlays. Battery retains the last 600 samples; file previews retain up to 1,500 points per selected signal. CSV/JSONL retains the complete file. Unknown-unit desktop files remain explicitly unitless.
- SoH preserves the ODX's `m-ohms` unit; this is not presented as a measured battery-health percentage. Cell fill is a voltage-based estimate. E107 shared temperatures are mapped by sensor index, not measured separately at every cell. Lowest voltage / relative IR observations are not a diagnosis. Series-cell Ah is never summed as pack capacity.
- BMS Settings is a read-only overview. The desktop S1 Pro preset is labelled as a reference, without claiming that it is appropriate for another scooter or modified pack. Existing opt-in parameter writes remain separate.
- Force balancing, specialized workshop routines/capacity tests, raw-memory probes/dumps, odometer/service-counter mutation, Wi-Fi lock bypass sequences and temporary entitlement-frame injection are not newly added. These need their own backend/hardware validation; some related existing commands remain in Engineering/Parameters.
- Passive signal-learning/replay workflows, raw CAN recording formats, desktop HTML health-report output, screenshot/video capture, OS log-folder controls and desktop BLE recovery details are not ported by this update. JSONL import accepts the desktop full-session recorder format (`recorder`, `t`, `v`), not unrelated charging-CAN/raw-frame logs.
- UART/UART–CAN work remains PC-only as requested. Connection drops, missed commands, stuck updates and deep-sleep BMS wake verification remain the separate backend/device phase.

## Read behavior

New ECU data reads send only existing UDS 0x22 requests, without calling security unlock or session setup. The app requires an explicit parked/unplugged Service-mode confirmation before real reads. Each batch records unsupported DIDs as errors, allows cancellation after the current request, discards late results after disconnect, and restores its prior live monitor. Real scooters may reject these reads; that is displayed as unavailable rather than fabricated data.

## Phone check

Open the Flutter `mobile/` project in Studio and run `lib/main.dart`. Confirm **Settings → OpenOLA → Version 0.4.0**. Try Demo, open Battery, tap **Read battery & cells**, inspect the last cell, try Graphs/Settings, then open Tools → Recorder. Start, stop, reopen, plot and export a demo session. Android/iOS file dialogs and physical scooter values remain device-test items. Shared labels and data maps do not establish equivalent ECU behavior or physical effects across targets; validate each repair action and vehicle variant on its own supported test unit.
