# OpenOLA Flutter source validation — 8 October 2026

Version **0.4.0+9**, project `D:\Ola_claude\mobile`.

## Verified here

- Official stable Flutter 3.47.6 / Dart 3.13.5; resolved dependencies in `pubspec.lock`.
- `flutter analyze --no-pub`: **no issues**.
- `flutter test --no-pub`: **50 tests pass**, including saved PNG comparisons.
- CAN encoding/legacy reply decoding, known VCU seed/key vector, ISO-TP flow control, UDS pending/negative responses, multiframe security request, BLE CRC/corruption/chunk reassembly/AES roundtrip, local catalogs and wide parameter bit preservation.
- Frozen reports distinguish unscanned from zero faults; identifiers/activity are excluded by default. Demo recovery invalidates changed scans and returns to Customer mode.
- Widget checks: light/dark phone 390×844, tablet 1024×900 with side rail, 360×800 at 1.6 text scale, persisted theme, demo connection → fault scan → frozen report retained across tabs, categorized left tools menu with swipe/Back/outside dismissal, expandable battery details, all advanced pages at narrow width, slide verification/cancel.
- Rendered previews inspected in `test/goldens/`. Font and Cupertino icon assets load. Enlarged text keeps brand/navigation labels intact and body content scrollable.
- The GUI-aligned 0.3.1 revision adds core-page/menu previews in both themes. Partial slide, tap, Cancel and completed verification are checked; the app's Service-mode flow is exercised in demo state. No three-second arming remains in the Flutter UI. That revision is recorded in `qa/2026-10-08-gui-style/`. The 0.3.2 evidence is in `qa/2026-10-08-sidebar/`. The latter simplifies Home/header hierarchy, moves tools/appearance into the left menu and Service mode into connection details; tablet tool navigation and narrow menus at 1.6 text scale are checked.
- The 0.3.3 Faults page automatically reads all controllers on entry when permitted and idle, and presents all returned codes together. Checks cover deferred connection/Service/idle transitions, no repeated reads on notifications, loading/error states, explicit refresh, 1.6 text scale and leaving/re-entering during a read. That revision is recorded in `qa/2026-10-08-auto-faults/`. Protocol/diagnostics backend source is unchanged.
- The 0.3.4 Live Signals page has a single full-height vertical viewport, lazy signal rows and controls that scroll away. Four phone/theme/tablet/large-text cases verify the viewport occupies over 68 percent of the screen, row 100 of 120 is reachable without paging, off-screen rows are built lazily, search/live updates work and empty states stay clear. The Tools entry is labeled in the phone header. Final evidence is in `qa/2026-10-08-live-scroll/`.
- The previous read-only ADB package check found **0.2.1-openola**, version code 3 on the connected phone. No Flutter build/install was performed; old installed APK behaviour does not validate this source.
- Dart loads the PEM credential context on Windows. Generated iOS PKCS12 has the same certificate and private-key public key as the source identity. This does **not** test iOS TLS or a scooter TLS connection.
- Android/iOS scaffolding, permissions, scooter launcher assets and branded native launch source are present. Native XML/plist source parses; iOS permission descriptions are at the Info.plist root.

## Not verified here

No APK/AAB/IPA was built. No emulator, physical phone, iPhone, camera, native save/share chooser, Bluetooth module or scooter was used for this Flutter version. The previous Kotlin APK's build, native TLS and 16 KB evidence do **not** establish those properties for this Flutter source. Check the APK you compile on the affected Android phone before treating the earlier page-size popup as fixed.

There is no measured phone frame-time, memory, startup or response benchmark. Telemetry updates are coalesced at one second, actuator/parameter catalog rendering is bounded to 40 entries per page while live rows are built lazily for the viewport, queues/logs are bounded, the background is isolated from repainting, and BLE initializes on demand. These are implementation choices, not measured speed gains.

Deep-sleep BMS wake, recovery, latched outputs, parameter reboot persistence, HMI feature changes, charging control and BLE pairing require controlled hardware tests. Missing echoes and connection drops report unknown outcomes. No command is silently replayed after reconnect/resume. Connection drops, missed commands and stalled updates remain the later backend investigation.

## Migration differences

- Dart gRPC/HTTP2 and reactive BLE replace Kotlin transports. No HTTP2 keepalive pings were enabled. Existing CAN IDs, UDS bytes, seed/key constants, catalogs and HMI ordinals are port references.
- Multiframe requests require valid flow control; the old implementation could continue when it was missing. Extended-session setup is a single attempt rather than the old delay/retry path. Pending responses extend the receive deadline.
- BLE uses platform discovery IDs (iOS UUID is not Android MAC). Android bonding/cache quirks were not copied into the plugin. Authentication includes the existing encrypted `D_ALIVE` exchange and now requires its reply. Periodic BLE idle keepalive/recovery and bonding edge cases remain unported.
- Fault recovery reads every ECU successfully before clear/reset; a failed read stays an error. Controllers with codes are reset, with the existing VCU fallback when none have codes. Cleared data becomes unscanned until reread. Failures stop the sequence; Customer mode is reported only after acknowledgement.
- A head-unit connection drop does not prove successful restart. The local link closes and reconnect is manual.
- iOS TLS uses DER trusted root plus PKCS12 client identity to match Dart iOS SecurityContext formats. No certificate verification bypass was added.
- Native document save/share sheets belong to Android/iOS; application controls use the glass system.
- Specialized odometer/service-counter mutations, Wi-Fi lock bypass sequences and platform-specific BLE recovery are not in this port. UART/UART–CAN work remains PC-only as requested.

## Next phone checks

1. Run from Studio, open Demo, switch themes, inspect glass forms/tools/confirmation, rotate and increase text size. Check cold startup and the page-size message.
2. Save/share demo TXT/JSON; scan an IP QR after camera permission.
3. On diagnostic Wi-Fi, verify address, firmware/mode, CAN arrival/pause state and battery values against the scooter. Use secure mode where required.
4. Park, unplug the charger, explicitly enter Service mode, read each ECU and compare reports. Capture before considering clear/reset. Investigate connection drops separately.
5. On a Mac, run on iPhone; verify local-network/Bluetooth/camera prompts, reachability, TLS, BLE and native export/share. Test iPad share positioning.

Current source/dependency hashes, desktop references and command logs are under `qa/2026-10-08-desktop-parity/`; earlier evidence remains in the dated QA directories above. Source/dependency changes require renewed checks.

## Desktop-parity update (0.4.0)

- 50 tests cover the previous suite plus read-only ODX scaling/ASCII/signed/missing fields, partial read failures, guarded reads, monitor restoration, cancellation/disconnect, snapshot identity exclusion and battery-cell freezing.
- Battery Overview/Graphs/Settings and cell detail sheets are checked on light/dark phone, tablet and 1.6 text-scale viewports. Cell 14 is reachable using the normal page scroll; the viewport remains over 65 percent of screen height.
- Recorder writes desktop-format JSONL to real temporary disk storage; 3,200 samples round-trip through summaries, reduced plots and complete CSV exports. The actual desktop Python parser opened the Flutter fixture and exported its CSV (`DESKTOP_COMPATIBILITY.json`). The UI test reopens a saved file through the offline library, loads charts and filters its signals.
- New notification mapping preserves unknown codes and unavailable feature fields. Starting a recording during storage setup can be cancelled; recording is explicitly foreground-only.
- SoH uses the ODX unit (`m-ohms`) rather than assuming percent. E434 supplies usable pack Ah. Estimated pack Wh uses E100 snapshot pack voltage; missing/non-positive voltage leaves it unavailable. E108/E109/E106 decode derived per-cell Ah/IR/voltage; their physical meanings still require scooter comparison.
- No native APK/IPA build, installation, real scooter command or new backend reliability investigation was performed. The read-only feature batch deliberately restores the previous live monitor after its own request; CAN/UDS transport files remain byte-identical to 0.3.4.

