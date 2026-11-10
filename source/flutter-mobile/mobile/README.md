# OpenOLA — Flutter mobile source

Android and iPhone source for local scooter diagnostics, version **0.4.0+9**. The Apple-inspired glass design uses backdrop blur, translucent layers, reflective rims, subtle motion, Cupertino icons and a scooter render mark. These are Flutter materials, not Apple's native Liquid Glass API.

The everyday workspace is **Home → Battery → Faults → Reports → Settings**. Recorder, Vehicle status, Components, Firmware and Software are always available in the categorized left glass menu. Enable additional advanced tools in Settings. On phones, tap the labeled Tools button at the upper left or swipe from the left edge. The five main tabs stay in the bottom dock. Tablets have a persistent sidebar. System, Light and Dark appearance and Reduce Motion are saved. The core path covers connection, battery readings, controller faults and frozen TXT/JSON reports. Opening Faults automatically reads all controllers once the connection is idle and the existing parked Service-mode requirement is satisfied. All returned codes appear together; Refresh faults remains available. Failed reads show an error and require an explicit retry.

The calmer Home screen puts battery charge first, groups fault/report actions and reveals secondary readings under Battery details. Appearance and tool management live in the side menu. Tap Connected/Demo or menu → Connection to inspect the link and change Service mode. The design follows the desktop GUI's palette and proportions: green/teal battery ring, compact metric values, colored workspace icons, neutral glass panels and solid blue actions. All app confirmations use **Slide to verify**, replacing the three-second delay. Partial slides and cancellation leave the action untouched. Current previews and comparison evidence are in `qa/2026-10-08-desktop-parity/REVIEW.md` and `test/goldens/`; earlier Live Signals evidence remains in `qa/2026-10-08-live-scroll/`.

The existing Kotlin `../apk/`, desktop `../tool/` and legacy `../android/` are retained as references. Use this `mobile/` project for the new Flutter app. **No APK was built for this delivery.** Start with Try Demo to inspect the UI without a scooter.

The previous read-only phone check found **0.2.1-openola**, the earlier Kotlin build. To see this redesign, open **`D:\Ola_claude\mobile`** as the Flutter project, run **`lib/main.dart`**, and check **Settings → OpenOLA → Version 0.4.0** after your installation. Earlier `apk/releases/` files do not contain these Flutter changes.

Live Signals uses one full-height page scroll: its controls scroll away with the signal rows. All filtered signals are available through lazy scrolling, without the forty-row Show more step. Signal values update in place, and search matches names, units or CAN IDs. The bottom tabs remain available while scrolling.

## Updated desktop workspaces

The main dock is **Home · Battery · Faults · Reports · Settings**. The left Tools menu always includes **Vehicle status, Recorder, Components, Firmware and Software**. Active service tools, charging, Live Signals and Bluetooth are enabled in Settings as before. Tablet layouts keep a permanent left sidebar.

Battery has **Overview / Graphs / Settings**: liquid-filled cell gauges, individual voltage/IR/derived Ah, estimated cell Wh, shared temperature details, pack usable Ah and estimated pack Wh, cycle count, the catalog’s SoH reading and configuration readout. Real ECU reads require parked/unplugged Service mode; they do not send a UDS unlock or change ECU session, and live monitoring resumes afterwards. Missing or unsupported values remain unavailable. Wh estimates use Ah × the snapshot voltage, not a measured discharge-energy test. The ODX labels SoH in `m-ohms`; the UI preserves that unit rather than presenting an unverified percentage.

Recorder saves all fresh numeric signals each second to the app’s documents/recordings directory. It can reopen its saved sessions or import desktop JSONL, plot up to six signals on separate physical scales, show min/max/last values, export wide CSV or JSONL and share a session. Recording stops and saves when the app leaves the foreground; background-service recording is not implemented. Each chart preview is bounded to 1,500 points, while exported recordings retain every sample. Native Save exports up to 64 MB per file; use Share session for larger files.

Reports now includes an expandable **Read ECU health report** with quick/complete reads and per-identifier errors/cancellation. Frozen snapshots include battery cells and decoded ECU data while excluding identity/VIN by default. Components reads all cataloged 0x22 identifiers per ECU; Firmware reads the identity/version group; Software requests head-unit software, Android, identity and update status. Vehicle status includes received fault flags, the deduplicated 0x6D0 notification feed and reconstructed 0x660 feature fields with uncertain labels retained.

See [DESKTOP_PARITY.md](DESKTOP_PARITY.md) for exact coverage and remaining desktop-specific functions. QA evidence is in `qa/2026-10-08-desktop-parity/`. No APK was built or installed.

## Open in Android Studio

1. Install Android Studio's **Flutter** plugin (and its Dart dependency). Open the entire `D:\Ola_claude\mobile` directory as a Flutter project.
2. Set the Flutter SDK path to your stable SDK. The SDK used here is `D:\Ola_claude\scratch\flutter-sdk` (**Flutter 3.47.6 / Dart 3.13.5**). It is retained locally and is not part of the app source.
3. Use **JDK 17** for Gradle. Run `flutter doctor -v` and install the Android SDK/NDK components it requests. The generated wrapper uses AGP 9.1.0 / Gradle 9.3.1. Use the tested Flutter version with the checked-in lockfile rather than independently upgrading dependencies.
4. In the project's terminal run:

```powershell
flutter pub get
flutter analyze
flutter test
```

5. Enable USB debugging, select your Android phone in Studio, open `lib/main.dart`, then **Run**. This compiles/installs from your machine. The Android app ID remains `in.crossfire.s1diag` and minimum Android API is 26.

If an existing installation has a different signing certificate, Android will refuse to update it. Use the same development signing key or uninstall the old app after preserving anything you need. Release signing currently uses the development debug configuration; configure your own release signing before distribution.

### Build fixes applied (2026-10-25) — read before upgrading dependencies

The first real `flutter build apk` surfaced several blockers that are now fixed in
source. Keep these in mind:

- **NDK is mandatory.** Flutter 3.47 always provisions Android NDK `28.2.13676358`
  (it strips debug symbols from the prebuilt `.so` files shipped by
  `flutter_reactive_ble` and `mobile_scanner`), even though this app has no C/C++.
  Android Studio's **SDK Manager** installs it automatically on first build — accept
  the prompt. A standalone `cmdline-tools` "android" preview shim cannot install NDKs;
  use Android Studio or a real `sdkmanager`.
- **`compileSdk = 37`** (`android/app/build.gradle.kts`) — `reactive_ble_mobile`
  compiles against SDK 37, so the app must too.
- **`path_provider_android` pinned to `>=2.2.5 <2.3.0`** (`pubspec.yaml`
  `dependency_overrides`) — 2.3.x adds a JNI/CMake C++ build; the 2.2.x line is
  API-identical and keeps the native build light.
- **`kotlin.incremental=false`** (`android/gradle.properties`) — Android Studio's
  bundled JBR is JDK 25, which breaks Kotlin's incremental-compile cache
  ("Could not close incremental caches … *.tab"). Disabling it compiles cleanly.
- **`-Djava.net.preferIPv4Stack=true`** (`android/gradle.properties`
  `org.gradle.jvmargs`) — only needed if Gradle dependency downloads fail with
  "No such host is known" on an IPv6-only-resolving network; harmless otherwise.

Verified: with these in place the debug build compiles, dexes and packages all
modules; the only remaining step that needs the installed NDK is the final native
symbol strip, which Android Studio handles once the NDK is present.

### Production diag app (v205) integration — status

Feature work folding the production Ola diagnostic app's data/capabilities into
this apk and the desktop GUI (expanded DBC, per-ECU fault views, battery-% fix,
cell balancing, and the pending firmware-flashing / variant-detection / Wi-Fi
binding work) is tracked in the repo-root
[`HANDOFF_PROD_INTEGRATION.md`](../HANDOFF_PROD_INTEGRATION.md).

## Build/run on iPhone

The same Dart UI and diagnostic source is provided with `ios/`. **iOS compilation and device signing require macOS with Xcode**; Windows Android Studio cannot produce an iPhone build. On a Mac, install the tested stable Flutter SDK/Xcode, run `flutter doctor -v` and `flutter pub get`, open `ios/Runner.xcworkspace` in Xcode, choose your team and a unique bundle ID if needed, select the device, then run with Xcode or `flutter run`.

The generated project uses Flutter's Swift Package Manager integration and iOS 15 minimum. Local network, Bluetooth and camera permission descriptions are included. BLE discovers a platform device ID instead of asking for a MAC address. The PKCS12 asset is the existing client identity converted for iOS; its conversion tool is `tools/prepare_ios_identity.py` (Python `cryptography`). Physical iPhone connectivity has not been tested here.

[Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup) explains Mac/Xcode setup; [Flutter installation](https://docs.flutter.dev/install) covers SDK installation.

## Source map

| Directory | Responsibility |
|---|---|
| `lib/design/` | Shared glass surfaces, typography, controls, sheets and confirmations |
| `lib/screens/` | Connection, Home, Faults, Reports, Settings and advanced tools |
| `lib/diagnostics/` | State, saved preferences, operations, frozen report generation |
| `lib/protocol/` | gRPC, CAN codec, ISO-TP, UDS and seed/key |
| `lib/bluetooth/` | BLE discovery, framing, crypto and session |
| `lib/data/` | Local DBC, DTC and ODX interpretation |
| `lib/generated/`, `proto/` | Existing wire contract and generated Dart bindings |
| `assets/` | Existing catalogs, scooter render, local credentials, Inter font |
| `test/` | Protocol/report tests, widget workflows and visual baselines |
| `android/`, `ios/` | Native platform projects and permissions |

Advanced categories contain live signals, charging recording, actuator pulse/latch/release, parameter read/write with fresh readback, existing HMI feature commands, engineering tests/identifiers, Bluetooth controls and fault actions. See [VALIDATION.md](VALIDATION.md) for port differences and missing specialized legacy actions.

Generated protobuf files are checked in: normal builds need no protoc. To regenerate with protoc 3.25.3 and protoc_plugin 25.1.0 on your PATH:

```text
dart pub global activate protoc_plugin 25.1.0
protoc --dart_out=grpc:lib/generated -Iproto proto/wifican.proto google/protobuf/empty.proto
```

Refresh launcher source assets with `dart run flutter_launcher_icons`. Keep bundled asset paths synchronized with `pubspec.yaml` when replacing them.

## Validation and publication boundary

Static analysis has no issues and **50 tests pass**. See [VALIDATION.md](VALIDATION.md) and `test/goldens/` for evidence. No Flutter Android/iOS binary or physical scooter test was performed; the page-size popup, BLE/native plugins, connection reliability and BMS deep-sleep wake still need device verification. The backend investigation remains separate.

This is a **local development source tree**, containing the existing `assets/certs/ecos.key` and its iOS PKCS12 equivalent. Before publishing the fully open project, remove/replace private credentials, select a project license, and verify redistribution rights for reverse-engineered catalogs/protocol assets and the scooter render. Free dependencies do not establish rights to those existing assets. No paid packages or service subscriptions were introduced here. Dependency and asset provenance is recorded in [THIRD_PARTY.md](THIRD_PARTY.md).
