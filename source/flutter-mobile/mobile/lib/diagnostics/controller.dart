import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../data/catalog.dart';
import '../protocol/can.dart';
import '../protocol/uds.dart';
import '../protocol/wifi_can.dart';
import '../protocol/s1x_tcp_monitor.dart';
import '../protocol/direct_adb.dart';
import '../diagnostics/preferences.dart';
import '../data/identifiers.dart';
import '../data/vehicle_status.dart';
import '../data/vehicle_profile.dart';
import '../data/vcu_variant.dart';
import '../data/repair_values.dart';
import '../data/mcu_replacement_plan.dart';
import '../release_policy.dart';
import 'package:grpc/grpc.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart';
import '../generated/wifican.pbgrpc.dart' as rpc;
import 'battery.dart';
import 'mcu_replacement_trial.dart';
import 'battery_history.dart';
import 'session.dart';
import 'head_unit_tools.dart';
import 'split_package.dart';
import 'sqlite_reader.dart';

enum Connection { disconnected, connecting, connected, error }

class Reading {
  const Reading(this.value, this.unit, this.receivedAt, this.id);
  final double value;
  final String unit;
  final DateTime receivedAt;
  final int id;
}

class Diagnostics extends ChangeNotifier {
  Diagnostics(this.catalog, this.prefs, {SessionRecorder? recorder})
    : session = recorder ?? SessionRecorder() {
    session.addListener(emit);
    history.load();
  }
  final Catalog catalog;
  final Preferences prefs;
  final SessionRecorder session;
  final BatteryHistory history = BatteryHistory();
  SessionSummary? openedSession;
  BatterySnapshot? battery;
  final identifierResults = <String, IdentifierResult>{};
  final graph = <SessionSample>[];
  DateTime? _graphStart;
  bool readCancelled = false;
  bool foreground = true;
  int readDone = 0, readTotal = 0;
  String readLabel = '';
  // Reading ECU/BMS identifiers is non-destructive (UDS 0x22 DID reads, no
  // security access, no writes), so it is gated only on a live connection in
  // SERVICE mode — NOT on the narrow `legacy` profile fingerprint. Destructive
  // actuator/flash/reset paths keep their legacyMethods + typed-CONFIRM gates.
  bool get readReady =>
      connected && !busy && (demo || (bench && mode == 'SERVICE'));
  bool get readingIdentifiers => busy && readTotal > 0;
  Connection connection = Connection.disconnected;
  bool demo = false,
      busy = false,
      bench = false,
      live = false,
      recording = false,
      disposed = false;
  String mode = 'Unknown', firmware = 'Unknown', manifest = '', message = '';
  String certStatus = '';
  RestrictionState? restrictionState;
  rpc.EcosDynoFlags? techPackFlags;
  String techPackEvidence = '';
  String techPackProbeResult = '';
  PasscodeHealth? passcodeHealth;
  double apkInstallProgress = 0;
  String apkInstallStatus = '';
  HeadUnitTransport headUnitTransport = HeadUnitTransport.grpc;
  bool directAdbConnected = false;
  String directAdbStatus = 'Not connected';
  WifiCan? link;
  S1xTcpMonitor? s1xTcpMonitor;
  bool get s1xTcpReadOnly => s1xTcpMonitor != null;
  Uds? uds;
  DateTime? lastFrame;
  final frameTimes = <int, DateTime>{};
  VehicleProfile _decodedProfile = VehicleProfile.common;
  String aospVersion = '';
  String moveOsBuild = '';
  VehicleIdentity get identity =>
      VehicleIdentity.detect(raw, firmware, aosp: aospVersion);
  Iterable<FaultFrame> get activeFaultFrames =>
      catalog.faultsFor(identity.profile);
  bool frameFresh(int id, {DateTime? now}) {
    final time = frameTimes[id];
    return connected &&
        time != null &&
        (now ?? DateTime.now()).difference(time) < const Duration(seconds: 10);
  }

  bool get parkedFresh => frameFresh(0x113) && rideMode == 'Parked';
  bool get chargerDisconnectedFresh {
    final frame = frameFresh(0x62d) ? raw[0x62d] : null;
    return frame != null && frame.isNotEmpty && (frame[0] & 0x03) == 0;
  }

  /// The five IDs the telematics unit keeps alive while the vehicle sleeps —
  /// GPS/LTE/Wi-Fi state, no battery or motor data. (Adopted from ola-s1-rea.)
  static const sleepTrickleIds = {0x6d2, 0x643, 0x6db, 0x66d, 0x65d};

  /// True when frames are arriving but only the telematics sleep trickle — the
  /// scooter is asleep. The UI tells the user to press start or plug in, instead
  /// of showing a blank or stale battery card as if it were live data.
  bool get vehicleAsleep {
    if (!connected || demo) return false;
    final now = DateTime.now();
    var trickleFresh = false, vehicleFresh = false;
    for (final e in frameTimes.entries) {
      if (now.difference(e.value) >= const Duration(seconds: 6)) continue;
      if (sleepTrickleIds.contains(e.key)) {
        trickleFresh = true;
      } else {
        vehicleFresh = true;
      }
    }
    return trickleFresh && !vehicleFresh;
  }

  bool get legacyMethodsAvailable =>
      demo ||
      (identity.legacyMethods && frameFresh(0x211) && frameFresh(0x610));
  void requireLegacyMethod(String method) {
    if (!legacyMethodsAvailable) {
      throw StateError(
        '$method is unavailable for ${identity.model}: no matching legacy method or fresh identity. Passive diagnostics remain available.',
      );
    }
  }

  double? profileValue(int id, String name) {
    if (!frameFresh(id)) return null;
    for (final s in catalog.signalsFor(identity.profile, id)) {
      if (s.name == name) return s.decode(raw[id]!);
    }
    return null;
  }

  Map<String, int?> get receivedFeatures {
    if (identity.profile == VehicleProfile.moveos561) {
      return {
        for (final s in catalog.signalsFor(identity.profile, 0x664))
          s.name.replaceAll('_', ' '): frameFresh(0x664)
              ? s.decode(raw[0x664]!).toInt()
              : null,
      };
    }
    if (identity.profile == VehicleProfile.legacy) {
      return featureStatus(frameFresh(0x660) ? raw[0x660] : null);
    }
    return const {};
  }

  /// Read-only, freshness-aware snapshot; does not infer fitted hardware from a model name.
  Map<String, Object?> get modelDiagnostics => {
    'identity': identity.toJson(),
    'signals': {
      for (final id in modelDiagnosticIds)
        if (raw[id] != null)
          '0x${id.toRadixString(16)}': {
            'fresh': frameFresh(id),
            'received_at': frameTimes[id]?.toUtc().toIso8601String(),
            'raw': hex(raw[id]!),
            'values': {
              for (final s in catalog.signalsFor(identity.profile, id))
                s.name: frameFresh(id) ? s.decode(raw[id]!) : null,
            },
          },
    },
  };
  static const modelDiagnosticIds = [
    0x270,
    0x271,
    0x272,
    0x273,
    0x305,
    0x321,
    0x322,
    0x6df,
    0x6dd,
    0x6e8,
    0x68a,
    0x68b,
    0x664,
    0x417,
    0x419,
  ];
  void refreshVehicleProfile() {
    final selected = identity.profile;
    if (selected == _decodedProfile) return;
    _decodedProfile = selected;
    readings.clear();
    clearGraph();
    broadcast.clear();
    faults.clear();
    identifierResults.clear();
    battery = null;
    unlocked.clear();
    _keepAlive?.cancel();
    log('Diagnostic profile: ${identity.profileLabel} — ${identity.reason}');
    for (final entry in raw.entries) {
      final time = frameTimes[entry.key];
      if (time != null) _decodeFrame(CanPacket(entry.key, entry.value), time);
    }
  }

  final raw = <int, List<int>>{};
  final readings = <String, Reading>{};
  final faults = <Ecu, List<Fault>>{};
  final faultScanErrors = <Ecu, String>{};
  final activity = <String>[];
  final chargeLog = <Map<String, Object?>>[];
  final latched = <int, Actuator>{};
  final unlocked = <Ecu>{}, rejectedKeys = <Ecu>{};
  final watchEvents = <String>[];
  final notifications = <VehicleNotification>[];
  int? _notificationCode;
  final softwareResponses = <String, String>{};
  final broadcast = <String>{};
  Timer? _tick, _keepAlive;
  bool _keepingAlive = false;
  Future<void>? _keepAliveInFlight;
  int _generation = 0;
  // Lockup detection: the head unit's diagnostics_server/VCU can wedge under
  // sustained command load until the gRPC session is torn down. Count link
  // trouble (command no-echo, read timeouts) and flag it so the UI can reconnect.
  int _stuckStrikes = 0;
  bool connectionStuck = false;
  void _noteLinkTrouble() {
    if (++_stuckStrikes >= 3 && !connectionStuck) connectionStuck = true;
  }

  void _noteLinkOk() {
    _stuckStrikes = 0;
    connectionStuck = false;
  }

  /// Tears down and re-establishes the link using the saved connection details.
  /// This is the known recovery for a wedged head-unit session — surfaced to the
  /// user (and auto-triggered) instead of them having to disconnect by hand.
  Future<void> reconnect() async {
    final host = prefs.store.getString('host') ?? '';
    final port = prefs.store.getInt('port') ?? 50005;
    final secure = prefs.store.getBool('secure') ?? false;
    final phoneHotspot = prefs.store.getBool('phoneHotspot') ?? false;
    final s1xTcp = prefs.store.getBool('s1xTcp') ?? false;
    _noteLinkOk();
    await disconnect(keepWanted: true);
    if (host.isNotEmpty) {
      await connect(
        host,
        port,
        secure: secure,
        phoneHotspot: phoneHotspot,
        s1xTcp: s1xTcp,
      );
    }
  }

  bool get connected => connection == Connection.connected;
  String get freshness => demo
      ? 'Simulated telemetry'
      : !connected
      ? 'Disconnected'
      : lastFrame == null
      ? 'Waiting for CAN data'
      : DateTime.now().difference(lastFrame!).inSeconds > 10
      ? 'CAN updates paused · last frame ${DateTime.now().difference(lastFrame!).inSeconds}s ago'
      : 'Receiving CAN data · last frame ${DateTime.now().difference(lastFrame!).inSeconds}s ago';
  void emit() {
    if (!disposed) notifyListeners();
  }

  void log(String text) {
    activity.add('${DateTime.now().toUtc().toIso8601String()} $text');
    if (activity.length > 2000) activity.removeAt(0);
  }

  static const ids = [
    ...modelDiagnosticIds,
    0x78e,
    0x7b1,
    0x786,
    0x7b0,
    0x7a6,
    0x7b4,
    0x410,
    0x411,
    0x122,
    0x430,
    0x431,
    0x333,
    0x213,
    0x210,
    0x642,
    0x11c,
    0x353,
    0x640,
    0x120,
    0x121,
    0x62d,
    0x313,
    0x130,
    0x143,
    0x180,
    0x190,
    0x6bf,
    0x660,
    0x6d0,
    0x508,
    0x584,
    0x585,
    0x6c0,
    0x334, // MCU fault data 2
    0x66e, // VCU faults
    0x352, // Display_Info_4: Display_SoC + SOH_Disp (SoC moved here from 0x353)
    0x356, // Display_Info_5: Odometer_Value_in_mtrs (so the odometer decodes)
    0x6d8, // BMS balancing temperature (broadcast)
    0x211, // Vehicle_Config_Data_1: Vehicle_Variant
    0x610, // Vehicle_Hardware_Variant (BCM/BMS/MCU/Charger/Motor gen)
    0x678, // SOM_Hardware variant
    0x1ab, 0x1ac, 0x1ad, 0x1ae, // per-cell DCIR (14 cells, uohm)
    0x1a5, 0x1a6, 0x1a9, 0x1aa, // per-cell voltages (14S) — broadcast on CAN
    0x1a4,
    0x1a7,
    0x1a8, // extra battery frames (cell balancing temp, per olamate)
    0x150, // BMS00_Parameter_3: Pack_SoH, Bus_Voltage_00, Available_Capacity_00
    0x160, // BMS00_Parameter_4: Effective_Battery_Temperature_00
    0x170, // BMS0_Cell_Status: min/max cell voltage + per-cell balancing
    0x643, 0x6db, 0x66d, 0x65d, // telematics sleep-trickle (asleep detection)
    0x113, // Vehicle_Discharge_Mode (drive mode) + Throttle_Value1
    0x224, // DC_Current_MCU + Motor_Frequency
    0x225, // Regen_torque_perc
    0x683, // Safety state: fall / tow-theft / regen availability / hill-hold
  ];

  int? _byte(int id, int index) {
    final d = raw[id];
    return d != null && index < d.length ? d[index] : null;
  }

  /// Vehicle variant code (0x211 byte 0). Raw; see FIRMWARE_RULES for names.
  int? get vehicleVariant => _byte(0x211, 0);

  /// Per-ECU hardware-variant codes (0x610 / 0x678). Used to match firmware.
  Map<String, int?> get hardwareVariants => {
    'BCM': _byte(0x610, 0),
    'BMS': _byte(0x610, 1),
    'BMS DipSwitch': _byte(0x610, 2),
    'MCU': _byte(0x610, 3),
    'Charger': _byte(0x610, 4),
    'Motor': _byte(0x610, 5),
    'SOM': _byte(0x678, 0),
    'Display': _byte(0x678, 1),
  };

  /// Per-cell DC internal resistance in mΩ (CAN 0x1AB–0x1AE, 14 cells, uohm).
  List<double?> get cellDcir {
    final out = <double?>[];
    for (final (id, count) in const [
      (0x1ab, 4),
      (0x1ac, 4),
      (0x1ad, 4),
      (0x1ae, 2),
    ]) {
      final d = frameFresh(id) ? raw[id] : null;
      for (var i = 0; i < count; i++) {
        final lo = d == null || i * 2 + 1 >= d.length ? null : d[i * 2];
        final hi = d == null || i * 2 + 1 >= d.length ? null : d[i * 2 + 1];
        out.add(lo == null ? null : (lo | hi! << 8) / 1000.0); // uohm -> mOhm
      }
    }
    return out;
  }

  /// Per-cell voltages (V) from CAN 0x1A5/0x1A6/0x1A9/0x1AA (14S pack, 16-bit
  /// little-endian, 0.001 V). Confirmed identical across two independent
  /// working community tools (ola-s1-rea, olamate) and our own DBC. These are
  /// broadcast passively — no UDS read, security access or Service mode needed.
  List<double?> get cellVoltages {
    final out = <double?>[];
    for (final (id, count) in const [
      (0x1a5, 4), // cells 1-4
      (0x1a6, 4), // cells 5-8
      (0x1a9, 4), // cells 9-12
      (0x1aa, 2), // cells 13-14
    ]) {
      final d = frameFresh(id) ? raw[id] : null;
      for (var i = 0; i < count; i++) {
        final lo = d == null || i * 2 + 1 >= d.length ? null : d[i * 2];
        final hi = d == null || i * 2 + 1 >= d.length ? null : d[i * 2 + 1];
        out.add(lo == null ? null : (lo | hi! << 8) / 1000.0); // mV -> V
      }
    }
    return out;
  }

  /// Passive battery snapshot assembled from the live CAN stream — the approach
  /// the known-working community tools use. SoH, per-cell voltages, cycle count
  /// and pack temperature are all broadcast on CAN, so this populates without
  /// the UDS deep read (which stays as an optional enhancement). Returns null
  /// until at least one battery frame has been seen.
  BatterySnapshot? get canBattery {
    final volts = cellVoltages, dcir = cellDcir;
    final cells = <BatteryCell>[];
    for (var i = 0; i < volts.length; i++) {
      final v = volts[i];
      if (v == null || v <= 0) continue;
      cells.add(
        BatteryCell(
          i + 1,
          v,
          ir: i < dcir.length ? dcir[i] : null,
          temperature: profileValue(0x160, 'Effective_Battery_Temperature_00'),
        ),
      );
    }
    final health = <DecodedValue>[];
    void add(String name, double? value, String unit) {
      if (value != null) health.add(DecodedValue(name, value, unit));
    }

    // SOH_Disp (0x352) reads 0 on firmware 5.0.0 (verified on a real S1, VIN
    // P53…), which a plain `??` would treat as a valid 0 % and show instead of
    // the true value. Pack_SoH (0x150) carries the real figure (100 on that
    // unit), so only trust SOH_Disp when it is a positive reading.
    final sohDisp = profileValue(0x352, 'SOH_Disp');
    add(
      'SOH',
      (sohDisp != null && sohDisp > 0)
          ? sohDisp
          : profileValue(0x150, 'Pack_SoH'),
      '%',
    );
    add('Cycle count', profileValue(0x6d8, 'Cycle_Number'), '');
    add(
      'Effective temperature',
      profileValue(0x160, 'Effective_Battery_Temperature_00'),
      '°C',
    );
    // Available_Capacity_00 is a percentage on CAN, not amp-hours — true usable
    // Ah / pack-Wh come only from the UDS deep read, so they stay blank here.
    add(
      'Available capacity',
      profileValue(0x150, 'Available_Capacity_00'),
      '%',
    );
    if (cells.isEmpty && health.isEmpty) return null;
    return BatterySnapshot(cells, health, const [], DateTime.now(), false);
  }

  /// Friendly vehicle-state readout decoded from CAN: drive mode, safety states
  /// (0x683), motor and charge-time signals. Values are '—' when not reported.
  /// Enum decoding mirrors the known-working community tools.
  /// Current ride mode from 0x113 Vehicle_Discharge_Mode — verified against a
  /// live capture (Park→Normal→Sport→Hyper→Eco→Custom all decoded correctly).
  /// Returns null until the mode frame is fresh.
  String? get rideMode {
    final v = profileValue(0x113, 'Vehicle_Discharge_Mode');
    if (v == null) return null;
    return const {
          0: 'Parked',
          2: 'Normal',
          3: 'Sport',
          4: 'Custom',
          5: 'Reverse',
          6: 'Eco',
          7: 'Hyper',
          10: 'Reverse',
          13: 'Reverse',
        }[v.toInt()] ??
        'Mode ${v.toInt()}';
  }

  Map<String, String> get vehicleState {
    String driveMode() {
      final v = profileValue(0x113, 'Vehicle_Discharge_Mode');
      if (v == null) return '—';
      return switch (v.toInt()) {
        0 => 'Parked',
        2 => 'Normal',
        3 => 'Sport',
        4 => 'Custom',
        5 || 10 || 13 => 'Reverse',
        6 => 'Eco',
        7 => 'Hyper',
        _ => 'Mode ${v.toInt()}',
      };
    }

    String enumOf(int id, String name, Map<int, String> m) {
      final v = profileValue(id, name);
      if (v == null) return '—';
      return m[v.toInt()] ?? 'state ${v.toInt()}';
    }

    String num1(int id, String name, String unit) {
      final v = profileValue(id, name);
      return v == null
          ? '—'
          : '${v.toStringAsFixed(1)}${unit.isEmpty ? '' : ' $unit'}';
    }

    return {
      'Drive mode': driveMode(),
      'Fall detection': enumOf(0x683, 'Fall_Detection_State', {
        0: 'off',
        1: 'active',
        2: 'inactive',
        3: 'recovered',
      }),
      'Tow / theft': enumOf(0x683, 'Tow_Theft_Detection', {
        0: 'off',
        1: 'active',
        2: 'inactive',
      }),
      'Regen': enumOf(0x683, 'Regen_Availability', {
        0: 'not available',
        1: 'available',
        2: 'throttle limited',
      }),
      'Hill hold': enumOf(0x683, 'Hill_Hold_Availability', {
        1: 'unavailable',
        2: 'active',
        3: 'not active',
        6: 'activated',
      }),
      'Motor current': num1(0x224, 'DC_Current_MCU', 'A'),
      'Motor frequency': num1(0x224, 'Motor_Frequency', 'Hz'),
      'Regen torque': num1(0x225, 'Regen_torque_perc', '%'),
      'Charge time (full)': num1(0x190, 'Time_to_Full_chargeSC_00', 'min'),
    };
  }

  /// Live fault flags decoded from the per-ECU *_fault_dbc maps, grouped by
  /// source (BMS/MCU/VCU/IMCU). Empty when nothing is asserted.
  Map<String, List<String>> liveFaults() {
    final out = <String, List<String>>{};
    for (final frame in activeFaultFrames) {
      final active = frame.active(frameFresh(frame.id) ? raw[frame.id] : null);
      if (active.isNotEmpty) (out[frame.ecu] ??= []).addAll(active);
    }
    return out;
  }

  Future<void> connect(
    String host,
    int port, {
    bool secure = false,
    bool simulated = false,
    bool phoneHotspot = false,
    bool s1xTcp = false,
  }) async {
    if (busy || connection == Connection.connecting) return;
    // Demo/simulated runs need no scooter address.
    if (!simulated && (host.trim().isEmpty || port < 1 || port > 65535)) {
      throw ArgumentError('Enter a valid host and port');
    }
    if (connected) return;
    await disconnect();
    final token = ++_generation;
    firmware = 'Unknown';
    manifest = '';
    aospVersion = '';
    moveOsBuild = '';
    demo = simulated;
    connection = Connection.connecting;
    message = '';
    emit();
    await prefs.store.setString('host', host.trim());
    await prefs.store.setInt('port', port);
    await prefs.store.setBool('secure', secure);
    await prefs.store.setBool('phoneHotspot', phoneHotspot);
    await prefs.store.setBool('s1xTcp', s1xTcp);
    WifiCan? candidate;
    S1xTcpMonitor? tcpCandidate;
    var recoveringSecureStream = false;
    try {
      if (simulated) {
        mode = 'SERVICE';
        firmware = 'DEMO-MOCK-5.0.0';
        bench = true;
        _demoReadings();
      } else if (s1xTcp) {
        if (secure) {
          throw ArgumentError('S1X raw TCP does not support the TLS option');
        }
        tcpCandidate = S1xTcpMonitor();
        s1xTcpMonitor = tcpCandidate;
        tcpCandidate.onFrame = (frame) {
          if (token == _generation) _receive(frame);
        };
        tcpCandidate.onError = (error) {
          if (token != _generation) return;
          message = 'S1X TCP stream stopped: $error';
          log(message);
          emit();
        };
        await tcpCandidate.connect(
          host.trim(),
          port,
          phoneHotspot: phoneHotspot,
        );
        mode = 'READ ONLY';
        firmware = 'Unknown';
        bench = false;
        message = 'S1X TCP monitor connected. Commands are disabled.';
      } else {
        candidate = WifiCan();
        link = candidate;
        candidate.onFrame = (frame) {
          if (token == _generation) _receive(frame);
        };
        candidate.onStreamError = (error) {
          if (token == _generation) {
            if (secure &&
                !recoveringSecureStream &&
                WifiCan.isTlsHandshakeError(error)) {
              recoveringSecureStream = true;
              unawaited(() async {
                try {
                  await candidate!.reconnectInsecure(
                    phoneHotspot: phoneHotspot,
                  );
                  await candidate!.reader(dump: true);
                  if (token == _generation) {
                    await prefs.store.setBool('secure', false);
                    message =
                        'Connected without TLS for this legacy S1 scooter';
                    log(message);
                    emit();
                  }
                } catch (recoveryError) {
                  if (token == _generation) {
                    message = 'CAN stream stopped: $recoveryError';
                    log(message);
                    emit();
                  }
                }
              }());
              return;
            }
            message = 'CAN stream stopped: $error';
            log(message);
            emit();
          }
        };
        await candidate.connect(
          host.trim(),
          port,
          secure,
          phoneHotspot: phoneHotspot,
        );
        // Passive, read-only monitoring via CanDumpStream, with NO Init. The
        // Init/Register call reconfigures the vehicle CAN acquisition filter and
        // interrupts the live charger handshake — opening the app would click the
        // charger contactor open. A plain dump stream is a non-invasive tap (it
        // never disturbed charging in testing). UDS operations switch to the
        // filtered diag session only on demand (see _unlock), so deep reads,
        // fault scans, parameter/actuator writes and commands should still be
        // avoided while actively charging.
        await candidate.reader(dump: true);
        // Vehicle mode / firmware are metadata RPCs that some generations answer
        // differently (seen on Gen2/Gen3). A difference here must NOT drop the
        // whole connection — live CAN + UDS still work. Keep them best-effort.
        try {
          final receivedMode = await candidate.mode();
          if (token != _generation) {
            await candidate.close();
            return;
          }
          mode = receivedMode;
          // A scooter can already be in SERVICE when we connect (entered on the
          // vehicle, or left in service from a prior session). `bench` gates the
          // read flow but was previously only set by the in-app Enter Service
          // toggle, so an already-service scooter showed "Leave Service mode"
          // yet kept the battery/cell read disabled. Mirror the detected mode.
          bench = mode == 'SERVICE';
        } catch (error) {
          if (token != _generation) return;
          mode = 'UNKNOWN';
          bench = false;
          log('Vehicle mode RPC unavailable: $error');
        }
        try {
          final receivedFirmware = await candidate.firmware();
          if (token != _generation) {
            await candidate.close();
            return;
          }
          firmware = receivedFirmware;
        } catch (error) {
          if (token != _generation) return;
          firmware = 'Unknown';
          log('Firmware RPC unavailable: $error');
        }
        try {
          final response = await candidate.client.getAospVersion(
            Empty(),
            options: CallOptions(timeout: const Duration(seconds: 4)),
          );
          if (token != _generation) {
            await candidate.close();
            return;
          }
          if (response.status == rpc.RespStatus.RESP_SUCCESS) {
            moveOsBuild = response.statusMsg;
          }
        } catch (error) {
          log('Platform identification unavailable: $error');
        }
        try {
          aospVersion = 'Android ${await _androidRelease(candidate)}';
        } catch (error) {
          log('Android release unavailable: $error');
        }
        if (token != _generation) {
          await candidate.close();
          return;
        }
        refreshVehicleProfile();
        uds = Uds(candidate);
      }
      if (token != _generation) {
        await candidate?.close();
        await tcpCandidate?.close();
        return;
      }
      connection = Connection.connected;
      _wantConnected = !simulated;
      if (!simulated) unawaited(_setForegroundService(true));
      log('Connected ${simulated ? 'DEMO' : '$host:$port'}');
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (demo) _demoReadings();
        unawaited(_maybeReadOdometerFallback());
        unawaited(_watchStream());
        if (s1xTcpReadOnly && !(s1xTcpMonitor?.active ?? false)) {
          unawaited(_autoReconnect());
        }
        _sampleIrEstimate();
        sampleTelemetry();
        if (recording) {
          chargeLog.add({
            'captured_at': DateTime.now().toUtc().toIso8601String(),
            'demo': demo,
            'metrics': metrics,
          });
        }
        if (chargeLog.length >= 3600) {
          recording = false;
          message =
              'Recording reached 3,600 samples. Export before starting another.';
        }
        emit();
      });
    } catch (error) {
      await candidate?.close();
      await tcpCandidate?.close();
      if (token != _generation) return;
      link = null;
      s1xTcpMonitor = null;
      uds = null;
      connection = Connection.error;
      message = 'Connection failed: $error';
      log(message);
    }
    emit();
  }

  void _receive(CanPacket frame) => acceptFrame(frame);

  /// Shared receive path for live traffic and deterministic capture tests.
  void acceptFrame(CanPacket frame, {DateTime? receivedAt}) {
    if (frame.data.length != 8 || frame.data.any((b) => b < 0 || b > 255)) {
      return;
    }
    final now = receivedAt ?? DateTime.now();
    lastFrame = now;
    _firstFrameAt ??= now;
    raw[frame.id] = List<int>.unmodifiable(frame.data);
    frameTimes[frame.id] = now;
    refreshVehicleProfile();
    if (frame.id == 0x6d0 && identity.profile == VehicleProfile.legacy) {
      observeNotification(frame.data);
    }
    _decodeFrame(frame, now);
  }

  void _decodeFrame(CanPacket frame, DateTime now) {
    for (final signal in catalog.signalsFor(identity.profile, frame.id)) {
      final value = signal.decode(frame.data);
      readings['${frame.id}:${signal.name}'] = Reading(
        value,
        signal.unit,
        now,
        frame.id,
      );
      if (frame.id == 0x356 && signal.name == 'Odometer_Value_in_mtrs') {
        final km = (value / 1000).floor();
        if (km >= 0) odometerKm = km;
      }
      final isFault =
          signal.bits == 1 &&
          RegExp(
            '(?<!de)fault|error|fail|warn|protect|abnormal|overcurrent|overvolt|undervolt|overtemp|short|disconnect|timeout|corrupt|stall|deviation',
            caseSensitive: false,
          ).hasMatch(signal.name) &&
          // Exclude command/control/acknowledge signals that merely contain a
          // fault-ish word (e.g. "Drivers_Fault_Reset" is a reset pulse, not an
          // active fault) — otherwise they sit in the broadcast list forever.
          !RegExp(
            'default|demand|status_signal|counter|calibration|balancing|indicator_ttl|'
            'reset|request|command|enable|disable|feedback|setpoint|_ack|config',
            caseSensitive: false,
          ).hasMatch(signal.name);
      if (isFault) {
        final name = '0x${frame.id.toRadixString(16)} / ${signal.name}';
        final active = value.toInt() == 1;
        if (active != broadcast.contains(name)) {
          active ? broadcast.add(name) : broadcast.remove(name);
          watchEvents.insert(
            0,
            '${now.toIso8601String()} ${active ? 'SET' : 'CLEAR'} $name',
          );
          if (watchEvents.length > 300) watchEvents.removeLast();
        }
      }
    }
  }

  void _demoReadings() {
    final now = DateTime.now();
    final values = {
      'Display_SoC': 82.5,
      'Bus_Voltage_00_10ms': 52.4,
      'Overall_Battery_Current': 4.4,
      'Vehicle_speed_in_kmph': 0.0,
    };
    odometerKm = 12345;
    for (final entry in values.entries) {
      readings['demo:${entry.key}'] = Reading(entry.value, '', now, 0);
    }
    for (final id in raw.keys) {
      frameTimes[id] = now;
    }
    // Sample live fault flags so the Faults page is reviewable in demo.
    raw[0x66e] = [0x05, 0, 0, 0, 0, 0, 0, 0]; // VCU: two sample flags
    raw[0x410] = [0, 0, 0, 0, 0, 0, 0, 0x02]; // BMS: one sample flag
    // Sample variant + DCIR so Vehicle/hardware + cell DCIR render in demo.
    raw[0x211] = [0x03, 1, 1, 1, 1, 0, 1, 0]; // Vehicle_Variant = 3
    raw[0x610] = [0, 0, 0, 0, 0, 0, 0, 0];
    raw[0x678] = [0x11, 0x07, 0, 0, 0, 0, 0, 0];
    for (final (i, id) in const [0x1ab, 0x1ac, 0x1ad, 0x1ae].indexed) {
      final b = <int>[];
      for (var c = 0; c < 4; c++) {
        final v = 850 + (i * 4 + c) * 12; // ~0.85–1.0 mΩ
        b
          ..add(v & 0xff)
          ..add(v >> 8);
      }
      raw[id] = b;
    }
  }

  void observeNotification(List<int> data) {
    if (data.isEmpty) return;
    final code = data[0];
    if (code == _notificationCode) return;
    _notificationCode = code;
    if (code == 0) return;
    notifications.insert(
      0,
      VehicleNotification(
        code,
        catalog.notifications[code] ?? 'Unknown notification $code',
        DateTime.now(),
      ),
    );
    if (notifications.length > 200) notifications.removeLast();
  }

  void clearNotifications() {
    notifications.clear();
    emit();
  }

  Future<String> _androidRelease(WifiCan target) async {
    final output = await target.adb(
      'getprop ro.build.version.release; getprop ro.build.version.sdk',
      timeout: const Duration(seconds: 5),
    );
    final values = RegExp(
      r'^\s*(\d+(?:\.\d+){0,2})\s*$',
      multiLine: true,
    ).allMatches(output).map((match) => match.group(1)!).toList();
    if (values.isEmpty) {
      throw StateError('No Android release in head-unit reply');
    }
    final api = values.length > 1 ? int.tryParse(values[1]) : null;
    return '${values.first}${api != null && api >= 20 && api <= 50 ? ' (API $api)' : ''}';
  }

  Future<void> readSoftware(String kind) => operation('Read $kind', () async {
    final token = _generation;
    String result;
    if (demo) {
      result = 'Demo · simulated $kind response. Firmware DEMO-MOCK-5.0.0';
    } else if (kind == 'Identifiers') {
      result = await link!.identifiers();
    } else if (kind == 'Update status') {
      result = const JsonEncoder.withIndent('  ').convert(
        (await link!.client.swUpdateCheckStatus(
          Empty(),
          options: CallOptions(timeout: const Duration(seconds: 10)),
        )).toProto3Json(),
      );
    } else if (kind == 'Android version') {
      try {
        final android = await _androidRelease(link!);
        result =
            'Android $android'
            '${moveOsBuild.isEmpty ? '' : '\nMoveOS build: $moveOsBuild'}';
      } catch (_) {
        result =
            'Android release unavailable from the head unit'
            '${moveOsBuild.isEmpty ? '' : '\nMoveOS build: $moveOsBuild'}';
      }
    } else {
      final reply = await link!.client.getSwVersion(
        Empty(),
        options: CallOptions(timeout: const Duration(seconds: 10)),
      );
      if (reply.status != rpc.RespStatus.RESP_SUCCESS) {
        throw StateError(reply.statusMsg);
      }
      result = reply.statusMsg;
    }
    if (token == _generation && connected) {
      softwareResponses[kind] = result;
      if (kind == 'Software version') firmware = result;
      if (kind == 'Android version' && result.startsWith('Android ')) {
        aospVersion = result.split('\n').first;
      }
      refreshVehicleProfile();
      message = '$kind received';
    }
  });
  double? signal(List<String> names, {List<int>? ids}) {
    for (final name in names) {
      for (final entry in readings.entries) {
        if ((ids == null || demo || ids.contains(entry.value.id)) &&
            entry.key.split(':').last.toLowerCase() == name.toLowerCase()) {
          return entry.value.value;
        }
      }
    }
    return null;
  }

  double? _bounded(double? value, double min, double max) =>
      value != null && value.isFinite && value >= min && value <= max
      ? value
      : null;
  double? _temp(int index) {
    if (demo) return index == 2 ? 36 : 32;
    final data = raw[0x313];
    return data == null
        ? null
        : _bounded((data[index] | data[index + 1] << 8) * .01, -40, 200);
  }

  Map<String, double?> get metrics => {
    'State of charge (%)': _bounded(
      signal(
        ['Display_SoC', 'Pack_SOC_00', 'Overall_SOC'],
        ids: [0x352, 0x11c, 0x120],
      ),
      0,
      100,
    ),
    'Reported range (km)': _bounded(
      signal(['Vehicle_Range'], ids: [0x353]),
      0,
      400,
    ),
    'Pack voltage (V)': _bounded(
      signal(
        ['Bus_Voltage_00_10ms', 'Battery_voltage_OCV_00'],
        ids: [0x640, 0x11c],
      ),
      0,
      200,
    ),
    'Pack current (A)': signal(['Overall_Battery_Current'], ids: [0x120]),
    'Battery temperature (°C)': battery?.healthValue('effective temp'),
    'Motor temperature (°C)': _temp(4),
    'Controller temperature (°C)': _temp(2),
    'Vehicle speed (km/h)': _bounded(
      signal(
        ['Vehicle_speed_in_kmph', 'Vehicle_Speed', 'Motor_Speed'],
        ids: [0x313],
      ),
      0,
      200,
    ),
  };
  Map<String, double> get telemetryValues {
    final now = DateTime.now();
    final values = <String, double>{};
    for (final entry in readings.entries) {
      if (!demo && now.difference(entry.value.receivedAt).inSeconds >= 3) {
        continue;
      }
      values.putIfAbsent(entry.key.split(':').last, () => entry.value.value);
    }
    if (!connected) return {};
    double? freshSignal(List<String> names, List<int> ids) {
      for (final name in names) {
        for (final e in readings.entries) {
          if ((demo || ids.contains(e.value.id)) &&
              e.key.split(':').last == name &&
              (demo || now.difference(e.value.receivedAt).inSeconds < 3)) {
            return e.value.value;
          }
        }
      }
      return null;
    }

    final fresh = <String, double?>{
      'batt_soc': freshSignal(
        ['Display_SoC', 'Pack_SOC_00', 'Overall_SOC'],
        [0x352, 0x11c, 0x120],
      ),
      'batt_range_km': freshSignal(['Vehicle_Range'], [0x353]),
      'batt_volts': freshSignal(
        ['Bus_Voltage_00_10ms', 'Battery_voltage_OCV_00'],
        [0x640, 0x11c],
      ),
      'batt_amps': freshSignal(['Overall_Battery_Current'], [0x120]),
      'batt_speed': freshSignal(
        ['Vehicle_speed_in_kmph', 'Vehicle_Speed', 'Motor_Speed'],
        [0x313],
      ),
    };
    if (demo ||
        readings.values.any(
          (r) => r.id == 0x313 && now.difference(r.receivedAt).inSeconds < 3,
        )) {
      fresh['batt_motor_t'] = _temp(4);
      fresh['batt_mcu_t'] = _temp(2);
    }
    for (final e in fresh.entries) {
      if (e.value != null && e.value!.isFinite) values[e.key] = e.value!;
    }
    if (fresh['batt_volts'] != null && fresh['batt_amps'] != null) {
      values['power_w'] = fresh['batt_volts']! * fresh['batt_amps']!;
    }
    return values;
  }

  void sampleTelemetry({DateTime? now}) {
    if (!foreground) return;
    final values = telemetryValues;
    if (values.isEmpty) return;
    now ??= DateTime.now();
    _graphStart ??= now;
    graph.add(
      SessionSample(
        now.difference(_graphStart!).inMilliseconds / 1000,
        Map.unmodifiable(values),
      ),
    );
    if (graph.length > 600) graph.removeAt(0);
    session.sample(values, now: now);
    // Persist a battery-health trend point (throttled inside record()).
    final cb = canBattery;
    if (cb != null) {
      final spread = cb.spreadMv;
      history.record(
        cb.healthValue('soh'),
        spread > 0 ? spread : null,
        cb.usableAh ?? battery?.usableAh,
      );
    }
  }

  void clearGraph() {
    graph.clear();
    _graphStart = null;
    emit();
  }

  Future<void> startSession() async {
    if (busy || !connected || session.active || session.closing) return;
    if (!live) await liveMode(true);
    if (!live || !connected) return;
    await operation('Start session recording', () async {
      final token = _generation;
      await session.start({
        'demo': demo,
        'firmware': firmware,
        'platform': 'OpenOLA mobile',
        'foreground_only': true,
        'units': {
          'batt_soc': '%',
          'batt_range_km': 'km',
          'batt_volts': 'V',
          'batt_amps': 'A',
          'batt_speed': 'km/h',
          'batt_motor_t': '°C',
          'batt_mcu_t': '°C',
          'power_w': 'W',
          for (final e in readings.entries) e.key.split(':').last: e.value.unit,
        },
      });
      message = 'Recording all fresh signals. Keep OpenOLA in the foreground.';
      if (token != _generation || !connected || !foreground) {
        await session.stop();
        return;
      }
    }, allowTcpReadOnly: true);
  }

  Future<void> stopSession({String? reason}) async {
    await session.stop();
    message =
        session.error ??
        reason ??
        'Recording saved · ${session.samples} samples';
    emit();
  }

  void cancelRead() {
    readCancelled = true;
    emit();
  }

  /// A test seam for read-only UDS, deliberately without security unlock/session change.
  Future<List<int>> readIdentifierBytes(ReadIdentifier definition) async => demo
      ? _demoIdentifier(definition)
      : await uds!.read(definition.ecu, definition.did);
  Future<void> identifierStream(bool monitor) async {
    if (demo) return;
    if (link!.streamMode != 'dump') await link!.reader(dump: true);
  }

  Future<List<IdentifierResult>> readIdentifiers(
    List<ReadIdentifier> definitions,
  ) async {
    final result = <IdentifierResult>[];
    final token = _generation;
    await operation(
      'Read ECU data',
      () async {
        // DID reads are non-destructive and the ODX identifier layout is shared
        // across generations, so no legacy-profile gate here. Reads that an ECU
        // refuses simply surface as per-row NRC errors.
        final resume = live;
        readDone = 0;
        readTotal = definitions.length;
        readCancelled = false;
        try {
          if (!demo) {
            live = false;
            await identifierStream(false);
          }
          for (final definition in definitions) {
            if (readCancelled || !connected || token != _generation) break;
            readLabel = '${definition.ecu.label} · ${definition.title}';
            emit();
            IdentifierResult row;
            try {
              final bytes = await readIdentifierBytes(definition);
              row = IdentifierResult(definition, bytes: bytes);
            } catch (e) {
              row = IdentifierResult(definition, error: e.toString());
            }
            if (!connected || token != _generation) break;
            result.add(row);
            identifierResults[definition.key] = row;
            readDone++;
            emit();
          }
          message =
              '${readCancelled ? 'Read cancelled' : 'Read complete'} · ${result.length}/${definitions.length} identifiers${demo ? ' · simulated' : ''}';
        } finally {
          readTotal = 0;
          readLabel = '';
          if (resume && connected && token == _generation) {
            if (demo) {
              live = true;
            } else {
              try {
                await identifierStream(true);
                live = true;
              } catch (e) {
                live = false;
                message = '$message · Live monitor could not resume: $e';
              }
            }
          }
        }
      },
      service: identity.legacyMethods,
      restoreCustomer: true,
    );
    return result;
  }

  List<int> _demoIdentifier(ReadIdentifier d) {
    final length = d.fields.fold(0, (int end, f) {
      final n =
          (int.tryParse('${f['StartBit']}') ?? 0) +
          (int.tryParse('${f['Size (Bits)']}') ?? 0);
      return n > end ? n : end;
    });
    final data = List<int>.filled((length + 7) ~/ 8, 0);
    for (var i = 0; i < d.fields.length; i++) {
      final f = d.fields[i];
      final bits = int.tryParse('${f['Size (Bits)']}') ?? 0,
          start = int.tryParse('${f['StartBit']}') ?? 0;
      if (bits <= 0) continue;
      if ('${f['Encoding']}'.toLowerCase() == 'ascii') {
        final text = 'DEMO ${d.ecu.label}';
        for (var j = 0; j < bits ~/ 8; j++) {
          data[start ~/ 8 + j] = j < text.length ? text.codeUnitAt(j) : 0;
        }
        continue;
      }
      final name = '${f['Parameter']}'.toLowerCase();
      final physical = switch (d.did) {
        0xe100 =>
          name == 'pack voltage' || name == 'bus voltage'
              ? 54724.0
              : name.contains('temperature')
              ? 33.0
              : name.contains('minimum')
              ? 3858.0
              : name.contains('maximum')
              ? 3916.0
              : name.contains('current')
              ? 4.4
              : 0.0,
        0xe103 => name.contains('soc') ? 82.5 : 96.0,
        0xe106 => i == 8 ? 3.858 : 3.90 + (i % 5) * .004,
        0xe109 => i == 8 ? 3.1 : 1.8 + (i % 3) * .1,
        0xe108 => 3.2,
        0xe107 => 31.0 + i,
        0xe102 => 1.2,
        0xe434 => 57.6,
        _ =>
          name.contains('soh')
              ? 96.0
              : name.contains('cycle')
              ? 148.0
              : name.contains('temp')
              ? 33.0
              : 0.0,
      };
      final resolution = double.tryParse('${f['Resolution']}') ?? 1,
          offset = double.tryParse('${f['Offset']}') ?? 0;
      if (resolution == 0) continue;
      final value = BigInt.from(((physical - offset) / resolution).round());
      for (var bit = 0; bit < bits; bit++) {
        if ((value & (BigInt.one << bit)) != BigInt.zero) {
          data[(start + bit) ~/ 8] |= 1 << ((start + bit) % 8);
        }
      }
    }
    return data;
  }

  Future<void> readBattery() async {
    if (!readReady) return;
    final token = _generation;
    final rows = await readIdentifiers(
      catalog.identifiers
          .where(
            (r) =>
                r.ecu == Ecu.bms &&
                [
                  0xe100,
                  0xe101,
                  0xe102,
                  0xe103,
                  0xe434,
                  0xe106,
                  0xe107,
                  0xe108,
                  0xe109,
                ].contains(r.did),
          )
          .toList(),
    );
    if (rows.isNotEmpty && connected && token == _generation) {
      battery = BatterySnapshot.fromResults(rows, demo: demo);
      emit();
    }
  }

  Future<void> operation(
    String name,
    Future<void> Function() work, {
    bool service = false,
    bool headUnit = false,
    bool cancellable = true,
    bool cooperativeCancel = false,
    bool restoreCustomer = false,
    bool allowTcpReadOnly = false,
  }) async {
    if (busy) return;
    if (s1xTcpReadOnly && !allowTcpReadOnly) {
      message =
          'S1X TCP monitoring is read-only; commands and ECU reads are disabled.';
      emit();
      return;
    }
    if (!connected && !(headUnit && headUnitReady)) {
      message = 'Connect to a scooter first.';
      emit();
      return;
    }
    if (service && !demo && (!bench || mode != 'SERVICE')) {
      message =
          'Confirm parked, charger disconnected and enter Service mode first.';
      emit();
      return;
    }
    busy = true;
    _criticalWrite = !cancellable;
    cancelRequested = false;
    _cancelSignal = Completer<void>();
    message = '';
    emit();
    log(name);
    try {
      final opId = ++_opId;
      if (cooperativeCancel) {
        await runZoned(work, zoneValues: {#openolaOp: opId});
      } else if (cancellable) {
        await Future.any<void>([
          runZoned(work, zoneValues: {#openolaOp: opId}),
          _cancelSignal!.future.then<void>(
            (_) => throw StateError('Cancelled'),
          ),
        ]);
      } else {
        await runZoned(work, zoneValues: {#openolaOp: opId});
      }
    } catch (error) {
      message = error.toString().contains('Cancelled')
          ? '$name cancelled'
          : '$name: $error';
      log(message);
      final e = error.toString().toLowerCase();
      if (e.contains('timeout') ||
          e.contains('deadline') ||
          e.contains('unavailable') ||
          e.contains('response timeout')) {
        _noteLinkTrouble();
      }
    } finally {
      _cancelSignal = null;
      if (_diagActive) {
        try {
          await _releaseDiagnostics();
        } catch (error) {
          log('Release diagnostics: $error');
        }
      }
      if (restoreCustomer && enteredServiceMode && !demo && link != null) {
        try {
          await link!.setMode(false).timeout(const Duration(seconds: 3));
          mode = 'CUST';
          bench = false;
          enteredServiceMode = false;
          log('Returned to Customer mode after $name');
        } catch (error) {
          log('Return to Customer mode after $name: $error');
          message = '$message · Return to Customer mode was not confirmed';
        }
      }
      busy = false;
      _criticalWrite = false;
      cancelRequested = false;
      emit();
    }
  }

  /// True while the app itself has put the scooter in Service mode (which can
  /// limit the scooter's own handlebar controls).
  bool enteredServiceMode = false;

  Future<void> serviceMode(bool value) =>
      operation(value ? 'Enter Service mode' : 'Return to Customer', () async {
        if (!demo) await link!.setMode(value);
        mode = value ? 'SERVICE' : 'CUST';
        enteredServiceMode = value;
        bench = value;
        unlocked.clear();
        _keepAlive?.cancel();
        message = value
            ? 'Service mode acknowledged'
            : 'Customer mode acknowledged';
      });
  Future<void> _unlock(Ecu ecu) async {
    if (demo) return;
    requireLegacyMethod('ECU security/session sequence');
    if (link!.streamMode != 'dump') {
      await link!.reader(dump: true);
      live = true;
    }
    if (rejectedKeys.contains(ecu)) {
      throw StateError(
        'Key rejected on this connection. Reconnect after checking ECU lockout.',
      );
    }
    if (!unlocked.contains(ecu)) {
      // Session 10 03 is sent inside unlock(). Even a rejected key must be
      // followed by 10 01, otherwise the handlebar buttons may stay disabled.
      unlocked.add(ecu);
      _diagActive = true;
      try {
        await uds!.unlock(
          ecu,
          gen3McuKey:
              ecu == Ecu.mcu &&
              identity.modelCode != null &&
              identity.modelCode! >= 20 &&
              identity.modelCode! <= 26,
        );
      } catch (error) {
        if (RegExp('0x35|0x36|0x37').hasMatch(error.toString())) {
          rejectedKeys.add(ecu);
        }
        rethrow;
      }
    }
    _diagActive = true;
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (_keepingAlive || disposed || !connected || uds!.requestInFlight) {
        return;
      }
      _keepingAlive = true;
      try {
        final send = uds!.testerPresent(ecu);
        _keepAliveInFlight = send;
        await send;
      } catch (error) {
        log('Tester present: $error');
      } finally {
        _keepAliveInFlight = null;
        _keepingAlive = false;
      }
    });
  }

  Future<void> scan({Ecu? ecu}) => operation(
    'Read stored faults',
    () async {
      if (ecu == null) faultScanErrors.clear();
      for (final target in ecu == null ? Ecu.values : [ecu]) {
        try {
          if (demo) {
            faults[target] = target == Ecu.bms
                ? [const Fault('P0A80', 'Demo: battery pack fault example', 9)]
                : [];
          } else {
            // New profile: standard read only. Never reuse the older security key
            // or session sequence when a controller rejects the request.
            if (identity.legacyMethods) await _unlock(target);
            final response = await uds!.dtcs(target);
            faults[target] = catalog
                .parseFaults(target, response)
                .map(
                  (f) => identity.legacyMethods
                      ? f
                      : Fault(
                          f.code,
                          f.description,
                          f.status,
                          meaningVerified: false,
                        ),
                )
                .toList();
          }
          faultScanErrors.remove(target);
        } catch (error) {
          if (identity.legacyMethods || ecu != null) rethrow;
          faults.remove(target);
          faultScanErrors[target] = error.toString();
          log('${target.label} best-effort fault read unavailable: $error');
        }
      }
      final unavailable = faultScanErrors.length;
      final unavailableNames = faultScanErrors.keys
          .map((target) => target.label)
          .join(', ');
      message =
          'Fault scan complete${demo ? ' · simulated' : ''}${unavailable == 0 ? '' : ' · $unavailableNames unavailable; see Diagnose for details'}';
    },
    service: identity.legacyMethods,
    restoreCustomer: true,
  );
  Future<void> faultAction(Ecu ecu, bool reset) => operation(
    reset ? 'Restart ${ecu.label}' : 'Clear ${ecu.label} history',
    () async {
      if (!demo) {
        await _unlock(ecu);
        reset ? await uds!.reset(ecu) : await uds!.clear(ecu);
      }
      if (reset) {
        unlocked.remove(ecu);
      } else {
        faults.remove(ecu);
      }
      message =
          '${demo ? 'Demo: ' : ''}${reset ? 'Restart' : 'Clear'} acknowledged. Deep-sleep wake is unvalidated.';
    },
    service: true,
  );

  /// Requests BMS cell balancing (RoutineControl 0x05F8). Balancing is
  /// BMS-governed — these packs normally balance only while charging with the
  /// cells imbalanced — so this asks for it; the pack decides. This app does
  /// not expose a live status signal; use the cell-voltage spread as a proxy.
  Future<void> forceBalance() => operation('Cell balancing', () async {
    if (!demo) {
      await _unlock(Ecu.bms);
      final resp = await uds!.routine(Ecu.bms, 0x05f8);
      // Require the BMS to echo the routine (0x71 01 05 F8) before claiming
      // success — the service byte alone is not enough.
      if (resp.length < 4 ||
          resp[1] != 0x01 ||
          resp[2] != 0x05 ||
          resp[3] != 0xf8) {
        throw StateError('BMS did not acknowledge the balancing routine.');
      }
    }
    message =
        '${demo ? 'Demo: ' : ''}Balancing requested. The BMS balances during '
        'charging when the cells are imbalanced — it decides whether to act.';
  }, service: true);

  Future<void> recover() => operation('Existing fault recovery', () async {
    // Finish every read before issuing a destructive command. A failed read is
    // not evidence of an empty fault list.
    for (final ecu in Ecu.values) {
      if (demo) {
        faults[ecu] = ecu == Ecu.bms
            ? [const Fault('P0A80', 'Demo fault', 9)]
            : [];
      } else {
        await _unlock(ecu);
        faults[ecu] = catalog.parseFaults(ecu, await uds!.dtcs(ecu));
      }
    }
    var targets = Ecu.values.where((e) => faults[e]!.isNotEmpty).toList();
    if (targets.isEmpty) targets = [Ecu.vcu];
    for (final ecu in targets) {
      if (!demo) {
        await _unlock(ecu);
        await uds!.clear(ecu);
        faults.remove(ecu);
        await uds!.reset(ecu);
      } else {
        faults.remove(ecu);
      }
      unlocked.remove(ecu);
    }
    _keepAlive?.cancel();
    unlocked.clear();
    if (!demo) await link!.setMode(false);
    mode = 'CUST';
    bench = false;
    message =
        '${demo ? 'Demo: ' : ''}Recovery commands acknowledged. Rescan after reconnecting; deep-sleep wake is unvalidated.';
  }, service: true);

  Future<void> restartHeadUnit() => operation('Restart head unit', () async {
    String result;
    try {
      if (!demo) await link!.restartHeadUnit();
      result =
          '${demo ? 'Demo: ' : ''}Restart acknowledged. Wait for the head unit, then reconnect manually.';
    } catch (error) {
      result =
          'Restart outcome unknown: $error. Check the head unit before reconnecting; no retry.';
    }
    await disconnect();
    message = result;
    log(result);
  }, service: true);

  Future<void> liveMode(bool value) {
    if (s1xTcpReadOnly) {
      live = value;
      message = value
          ? 'S1X TCP live monitoring is active (read-only)'
          : 'Live view paused; passive TCP monitoring stays active';
      emit();
      return Future<void>.value();
    }
    return operation(
      value ? 'Start live signals' : 'Stop live signals',
      () async {
        if (!demo && link!.streamMode != 'dump') {
          await link!.reader(dump: true);
        }
        live = value;
        message = value
            ? 'Passive CAN monitoring is active'
            : 'Live view paused; passive CAN monitoring stays active';
      },
    );
  }

  Future<void> actuator(Actuator a, {bool? latch}) =>
      operation(a.label, () async {
        if (!demo) {
          await _unlock(Ecu.vcu);
          if (latch != null) {
            await uds!.io(a.did, latch);
            if (!latch) await uds!.io(a.did, false, release: true);
          } else {
            try {
              await uds!.io(a.did, true);
              await Future<void>.delayed(
                Duration(
                  milliseconds: a.label.toLowerCase() == 'horn' ? 750 : 2000,
                ),
              );
            } finally {
              await uds!.io(a.did, false);
              await uds!.io(a.did, false, release: true);
            }
          }
        }
        if (latch != null) {
          latch ? latched[a.did] = a : latched.remove(a.did);
        }
        message =
            '${demo ? 'Demo: ' : ''}${a.label}: ${latch == null
                ? 'pulse'
                : latch
                ? 'ON'
                : 'OFF'} acknowledged';
      }, service: true);

  /// VCU routine control (`31 01 <id>`): the factory lock/unlock sequence
  /// (0xBF07) and the module self-checks (0xBF01-0xBF06). The VCU runs the
  /// routine itself (for the lock sequence it sends the CAN traffic), and the
  /// reply carries one routine-status byte. Needs Park, charger disconnected
  /// and Service mode, like the actuator tests.
  String? lastRoutineStatus;
  Future<void> vcuRoutine(int id, String label) => operation(label, () async {
    if (!demo && !parkedFresh) {
      throw StateError('A fresh 0x113 frame must confirm Park');
    }
    if (!demo && !chargerDisconnectedFresh) {
      throw StateError('A fresh 0x62D frame must confirm charger disconnected');
    }
    int? status;
    if (!demo) {
      await _unlock(Ecu.vcu);
      final reply = await uds!.routine(Ecu.vcu, id);
      // Positive reply: 71 01 <id hi> <id lo> <status>.
      status = reply.length > 4 ? reply[4] : null;
    }
    lastRoutineStatus = status == null ? null : '$label: status $status';
    message = demo
        ? 'Demo: $label'
        : status == null
        ? '$label: routine accepted (no status byte returned)'
        : '$label: routine accepted, status byte $status '
              '(ODX range 0-1). Check the scooter itself.';
  }, service: true);

  /// Motor auto-tune (after a motor replacement), the way the official app does
  /// it: UDS routine to the MCU (`31 01 06 F1`), then watch the
  /// Successful_Calibration_Counter (CAN 0x333 byte 4) rise above its baseline.
  /// Stops with `31 02 06 F1` and releases the session in every case (abort,
  /// timeout, failure bit, link loss). Needs Park, charger off and the owner's
  /// centre-stand and wheel-clear confirmation (checked in the UI).
  String calibrationStatus = '';
  McuReplacementTrial? mcuReplacementTrial;
  String mcuReplacementTrialStatus = '';
  final mcuReplacementPreflight = <String, String>{};
  DateTime? mcuReplacementPreflightAt;
  String? mcuReplacementVin;
  String? mcuReplacementSoftware;
  final mcuReplacementSurvey = <String, String>{};
  DateTime? mcuReplacementSurveyAt;
  String? mcuReplacementSurveyVin;
  String? mcuReplacementSurveySoftware;

  /// Common, read-only replacement intake for every connected model. It does
  /// not enter an ECU session or infer a firmware from an unknown profile.
  Future<void> readMcuReplacementSurvey() => operation(
    'Identify MCU replacement route',
    () async {
      mcuReplacementSurvey.clear();
      mcuReplacementSurveyAt = null;
      mcuReplacementSurveyVin = null;
      mcuReplacementSurveySoftware = null;
      mcuReplacementSurvey['Scooter'] = identity.model;
      mcuReplacementSurvey['Model code'] =
          '${identity.modelCode ?? 'unavailable'}';
      mcuReplacementSurvey['Connection'] = s1xTcpReadOnly
          ? 'S1X TCP (passive)'
          : 'Wi-Fi gRPC';
      mcuReplacementSurvey['MoveOS'] = firmware;
      mcuReplacementSurvey['Controller hardware'] = frameFresh(0x610)
          ? hex(raw[0x610]!)
          : 'Unavailable: no fresh CAN 0x610';
      if (uds == null) {
        final reason = s1xTcpReadOnly
            ? 'Unavailable on passive TCP'
            : 'Unavailable: ECU bridge is not ready';
        mcuReplacementSurvey['VCU VIN · F190'] = reason;
        mcuReplacementSurvey['MCU software · F181'] = reason;
      } else {
        for (final (label, ecu, did) in const [
          ('VCU VIN · F190', Ecu.vcu, 0xF190),
          ('MCU software · F181', Ecu.mcu, 0xF181),
          ('Motor angle · B113', Ecu.mcu, 0xB113),
        ]) {
          try {
            final bytes = await uds!.read(ecu, did);
            final printable = String.fromCharCodes(
              bytes.where((v) => v >= 32 && v <= 126),
            ).trim();
            if (did == 0xF190 &&
                RegExp(r'^[A-Z0-9]{17}$').hasMatch(printable)) {
              mcuReplacementSurveyVin = printable;
            }
            if (did == 0xF181 && printable.isNotEmpty) {
              mcuReplacementSurveySoftware = printable;
            }
            mcuReplacementSurvey[label] =
                '${hex(bytes)}${printable.isEmpty ? '' : ' · $printable'}';
          } catch (error) {
            mcuReplacementSurvey[label] = 'Unavailable: $error';
          }
        }
      }
      mcuReplacementSurveyAt = DateTime.now();
      message =
          'MCU replacement route identified from live scooter data. No write sent.';
    },
    allowTcpReadOnly: true,
  );

  /// Read-only inputs for planning a Gen1 MCU replacement. The preparation
  /// screen can show the official APK's candidate file, but neither this read
  /// nor the APK's selector verifies the physical replacement MCU hardware.
  Future<void> readMcuReplacementPreflight() => operation(
    'Read MCU replacement preflight',
    () async {
      if (!demo) requireLegacyMethod('MCU replacement preflight');
      mcuReplacementPreflight.clear();
      mcuReplacementPreflightAt = null;
      mcuReplacementVin = null;
      mcuReplacementSoftware = null;
      for (final (label, ecu, did) in const [
        ('Vehicle VIN · F190', Ecu.vcu, 0xF190),
        ('MCU software · F181', Ecu.mcu, 0xF181),
        ('Motor angle · B113', Ecu.mcu, 0xB113),
      ]) {
        try {
          final bytes = demo
              ? (did == 0xF190
                    ? 'TESTVAN1234567890'.codeUnits
                    : did == 0xF181
                    ? 'DEMO-MCU'.codeUnits
                    : <int>[0, 0])
              : await uds!.read(ecu, did);
          final printable = String.fromCharCodes(
            bytes.where((v) => v >= 32 && v <= 126),
          ).trim();
          if (did == 0xF190 && printable.length == 17) {
            mcuReplacementVin = printable;
          }
          if (did == 0xF181 && printable.isNotEmpty) {
            mcuReplacementSoftware = printable;
          }
          mcuReplacementPreflight[label] =
              '${hex(bytes)}${printable.isEmpty ? '' : ' · $printable'}';
        } catch (error) {
          mcuReplacementPreflight[label] = 'Unavailable: $error';
        }
      }
      mcuReplacementPreflight['MCU hardware broadcast'] = frameFresh(0x610)
          ? '${hardwareVariants['MCU'] ?? 'unavailable'} (CAN 0x610)'
          : 'Unavailable: no fresh CAN 0x610 frame';
      mcuReplacementPreflight['Calibration status'] = frameFresh(0x333)
          ? 'CAN 0x333: ${hex(raw[0x333]!)}'
          : 'Unavailable: no fresh CAN 0x333 frame';
      mcuReplacementPreflightAt = DateTime.now();
      message =
          'MCU preflight read complete. Review the candidate and replacement hardware before any flash.';
    },
    service: true,
    restoreCustomer: true,
  );

  void prepareMcuReplacementTrial(McuReplacementTrial trial) {
    if (mcuReplacementTrial != null &&
        mcuReplacementTrial!.stage != McuTrialStage.postchecked) {
      throw StateError(
        'Finish or explicitly discard the current MCU trial first.',
      );
    }
    _checkMcuTrialInputs(trial);
    if (trial.partNumber.trim().length < 4) {
      throw StateError(
        'Record the replacement MCU part number from its label.',
      );
    }
    if (mcuReplacementSoftware == null) {
      throw StateError(
        'The replacement MCU software identifier is unavailable.',
      );
    }
    mcuReplacementTrial = trial;
    mcuReplacementTrialStatus = 'Prepared; no write sent.';
    trial.events.add(
      '${DateTime.now().toUtc().toIso8601String()} prepared: VIN and firmware candidate checked; physical part match is technician-confirmed',
    );
    log('MCU replacement trial prepared for ${trial.candidate.file}');
    emit();
  }

  void discardMcuReplacementTrial() {
    final trial = mcuReplacementTrial;
    if (trial != null) {
      log(
        'MCU trial ended at ${trial.stage.name}: ${trial.lastError ?? 'operator stopped'}',
      );
    }
    mcuReplacementTrial = null;
    mcuReplacementTrialStatus = 'Trial ended; no further action queued.';
    emit();
  }

  void _checkMcuTrialInputs(McuReplacementTrial trial) {
    requireLegacyMethod('Gen1 MCU replacement trial');
    if (identity.modelCode != 2 && identity.modelCode != 3) {
      throw StateError('Only verified Gen1 S1 Pro is supported.');
    }
    final readAt = mcuReplacementPreflightAt;
    if (readAt == null ||
        DateTime.now().difference(readAt) > const Duration(minutes: 10)) {
      throw StateError('Read fresh MCU replacement inputs first.');
    }
    if (mcuReplacementVin != trial.vin) {
      throw StateError('The VCU VIN differs from this trial. Stop.');
    }
    final expected = McuFirmwareCandidate.forGen1(
      vin: trial.vin,
      headUnitSoftware: firmware,
      motor: trial.motor,
    );
    if (expected == null ||
        expected.file != trial.candidate.file ||
        expected.version != trial.candidate.version ||
        expected.sha256 != trial.candidate.sha256) {
      throw StateError(
        'Firmware selection changed; stop and restart the trial.',
      );
    }
    if (!parkedFresh || !chargerDisconnectedFresh) {
      throw StateError(
        'Fresh CAN frames must confirm Park and unplugged charger.',
      );
    }
  }

  Future<void> flashMcuReplacementTrial() => operation(
    'Flash replacement MCU',
    () async {
      final trial =
          mcuReplacementTrial ?? (throw StateError('No MCU trial prepared.'));
      if (trial.stage != McuTrialStage.prepared || trial.lastError != null) {
        throw StateError('Trial is not ready for a first flash attempt.');
      }
      try {
        _checkMcuTrialInputs(trial);
        final bridge =
            link ?? (throw StateError('Scooter gRPC link is unavailable.'));
        final file = File(trial.filePath);
        if (!await file.exists()) {
          throw StateError('The selected MCU firmware file is unavailable.');
        }
        final bytes = await file.readAsBytes();
        if (bytes.length != 98304 ||
            sha256.convert(bytes).toString().toUpperCase() !=
                trial.candidate.sha256) {
          throw StateError(
            'Firmware file changed or failed SHA-256 validation.',
          );
        }
        final remote = '/data/ola/${trial.candidate.file}';
        try {
          mcuReplacementTrialStatus =
              'Sending verified firmware over the scooter connection';
          emit();
          await bridge.adb(HeadUnitCommands.removePartDir);
          await bridge.adb(HeadUnitCommands.clearApkUploads(1));
          await bridge.adb(HeadUnitCommands.preparePartDir);
          var sent = 0;
          await _uploadChunks(0, bytes, (n) {
            sent += n;
            mcuReplacementTrialStatus =
                'Sending firmware: ${(sent / bytes.length * 100).clamp(0, 100).toStringAsFixed(0)}%';
            emit();
          });
          final decoded = await bridge.adb(HeadUnitCommands.decodeParts(0));
          final decodedBytes = int.tryParse(
            decoded.trim().split(RegExp(r'\s+')).last,
          );
          if (decodedBytes != bytes.length) {
            throw StateError(
              'Scooter decoded ${decodedBytes ?? 'unknown'} of ${bytes.length} firmware bytes.',
            );
          }
          final stagedHash = (await bridge.adb(
            HeadUnitCommands.hashApkAt(0),
          )).trim().split(RegExp(r'\s+')).first.toUpperCase();
          if (stagedHash != trial.candidate.sha256) {
            throw StateError(
              'Staged firmware SHA-256 did not match. Flash was not started.',
            );
          }
          await bridge.adb(
            'mkdir -p /data/ola && cp ${HeadUnitCommands.apkPath} $remote',
          );
          final remoteHash = (await bridge.adb(
            'sha256sum $remote',
          )).trim().split(RegExp(r'\s+')).first.toUpperCase();
          if (remoteHash != trial.candidate.sha256) {
            throw StateError(
              'On-scooter firmware SHA-256 did not match. Flash was not started.',
            );
          }
        } finally {
          try {
            await bridge.adb(HeadUnitCommands.removePartDir);
            await bridge.adb(HeadUnitCommands.clearApkUploads(1));
          } catch (error) {
            log('MCU upload temporary-file cleanup: $error');
          }
        }
        mcuReplacementTrialStatus =
            'Flashing MCU; keep the phone and scooter powered';
        emit();
        final output = await bridge.adb(
          'uds_client_test_app -c no -e no -t MCU -f $remote',
          timeout: const Duration(minutes: 5),
        );
        trial.events.add(
          'Flash tool output: ${output.length > 4000 ? output.substring(output.length - 4000) : output}',
        );
        if (!McuReplacementTrial.flashReportedComplete(output)) {
          throw StateError(
            'Flash tool did not report an unambiguous transfer complete.',
          );
        }
        trial.advance(
          McuTrialStage.prepared,
          McuTrialStage.flashReportedComplete,
          'gRPC bridge remote SHA-256 matched; flash tool reported transfer complete',
        );
        mcuReplacementTrialStatus =
            'Flash tool reported complete. BMS reset is next; physical flash is not yet verified.';
      } catch (error) {
        trial.fail(error);
        mcuReplacementTrialStatus = 'STOP: $error';
        rethrow;
      }
    },
    service: true,
    cancellable: false,
  );

  Future<void> resetForMcuReplacementTrial({
    required bool finalReset,
  }) => operation(
    finalReset ? 'Final MCU replacement reset' : 'First MCU replacement reset',
    () async {
      final trial =
          mcuReplacementTrial ?? (throw StateError('No MCU trial prepared.'));
      final expected = finalReset
          ? McuTrialStage.calibrated
          : McuTrialStage.flashReportedComplete;
      final next = finalReset
          ? McuTrialStage.finalResetRequested
          : McuTrialStage.firstResetRequested;
      if (trial.stage != expected || trial.lastError != null) {
        throw StateError(
          'Trial stage is ${trial.stage.name}; reset is unavailable.',
        );
      }
      try {
        _checkMcuTrialInputs(trial);
        await _unlock(Ecu.bms);
        final response = await uds!.reset(Ecu.bms);
        if (response.isEmpty || response[0] != 0x51) {
          throw StateError('BMS did not acknowledge the reset request.');
        }
        trial.advance(
          expected,
          next,
          'BMS acknowledged UDS reset; wait for physical reboot and reconnect',
        );
        mcuReplacementTrialStatus =
            'Reset requested. Confirm scooter power cycle, reconnect, and read the inputs again.';
      } catch (error) {
        trial.fail(error);
        mcuReplacementTrialStatus = 'STOP: $error';
        rethrow;
      }
    },
    service: true,
    cancellable: false,
  );

  void verifyMcuReplacementFlash() {
    final trial =
        mcuReplacementTrial ?? (throw StateError('No MCU trial prepared.'));
    if (trial.stage != McuTrialStage.firstResetRequested ||
        trial.lastError != null) {
      throw StateError('First reset is not pending verification.');
    }
    _checkMcuTrialInputs(trial);
    if (!trial.candidate.matchesCurrentSoftware(mcuReplacementSoftware)) {
      throw StateError(
        'MCU software readback does not match ${trial.candidate.version}.',
      );
    }
    trial.advance(
      McuTrialStage.firstResetRequested,
      McuTrialStage.flashVerified,
      'MCU F181 readback matches ${trial.candidate.version}',
    );
    mcuReplacementTrialStatus = 'Firmware readback matched. AutoTune is next.';
    emit();
  }

  Future<void> calibrateMcuReplacementTrial() async {
    final trial =
        mcuReplacementTrial ?? (throw StateError('No MCU trial prepared.'));
    if (trial.stage != McuTrialStage.flashVerified || trial.lastError != null) {
      throw StateError('Firmware readback must pass before AutoTune.');
    }
    _checkMcuTrialInputs(trial);
    calibrationStatus = '';
    await motorCalibration();
    if (!calibrationStatus.startsWith('Motor calibration succeeded')) {
      final error = StateError(
        'AutoTune did not report a counter increase: $message',
      );
      trial.fail(error);
      mcuReplacementTrialStatus = 'STOP: $error';
      emit();
      return;
    }
    trial.advance(
      McuTrialStage.flashVerified,
      McuTrialStage.calibrated,
      calibrationStatus,
    );
    mcuReplacementTrialStatus =
        'AutoTune counter increased. Final BMS reset is next.';
    emit();
  }

  void verifyMcuReplacementPostcheck() {
    final trial =
        mcuReplacementTrial ?? (throw StateError('No MCU trial prepared.'));
    if (trial.stage != McuTrialStage.finalResetRequested ||
        trial.lastError != null) {
      throw StateError('Final reset is not pending verification.');
    }
    _checkMcuTrialInputs(trial);
    if (!trial.candidate.matchesCurrentSoftware(mcuReplacementSoftware)) {
      throw StateError('Final MCU software readback differs from the target.');
    }
    if (mcuReplacementPreflight['Motor angle · B113']?.startsWith(
          'Unavailable',
        ) ??
        true) {
      throw StateError('Motor angle B113 could not be read.');
    }
    if (!frameFresh(0x333) ||
        raw[0x333]!.isEmpty ||
        (raw[0x333]![0] & 8) != 0) {
      throw StateError(
        'Fresh MCU status is missing or reports a tuning failure.',
      );
    }
    trial.advance(
      McuTrialStage.finalResetRequested,
      McuTrialStage.postchecked,
      'Final VIN/F181/B113 readback and MCU status passed; physical motor and fault checks still required',
    );
    mcuReplacementTrialStatus =
        'Software post-check passed. Technician must still verify motor operation and faults.';
    emit();
  }

  Future<void> motorCalibration() => operation(
    'Motor calibration',
    () async {
      if (!demo) requireLegacyMethod('MCU motor calibration');
      if (!demo && !parkedFresh) {
        throw StateError('A fresh 0x113 frame must confirm Park');
      }
      if (!demo && !chargerDisconnectedFresh) {
        throw StateError(
          'A fresh 0x62D frame must confirm charger disconnected',
        );
      }
      int counter() =>
          (raw[0x333] != null && raw[0x333]!.length > 4) ? raw[0x333]![4] : -1;
      bool failureBit() =>
          raw[0x333] != null &&
          raw[0x333]!.isNotEmpty &&
          (raw[0x333]![0] & 8) != 0;
      void state(String text) {
        calibrationStatus = text;
        emit();
      }

      if (demo) {
        state('Demo: calibration simulated');
        message = calibrationStatus;
        return;
      }
      final baseline = counter();
      if (baseline < 0 || !frameFresh(0x333)) {
        throw StateError('No MCU status frame (0x333) yet; wait for live data');
      }
      state('Starting (baseline counter $baseline)');
      await Future<void>.delayed(const Duration(seconds: 5));
      _checkCancelled();
      if (!foreground) {
        throw StateError('App left the foreground before calibration started');
      }
      var started = false;
      try {
        await _unlock(Ecu.mcu);
        await uds!.routine(Ecu.mcu, 0x06F1);
        started = true;
        final begin = DateTime.now();
        while (true) {
          _checkCancelled();
          if (!foreground) {
            throw StateError('App left the foreground; stopping calibration');
          }
          final elapsed = DateTime.now().difference(begin).inSeconds;
          state(
            'Calibrating, ${elapsed}s (counter ${counter()}, baseline $baseline)',
          );
          if (counter() > baseline) {
            message = 'Motor calibration succeeded (counter ${counter()}).';
            state(message);
            return;
          }
          if (elapsed > 8 && failureBit()) {
            throw StateError(
              'The MCU reported a tuning failure. Check that the MCU software '
              'matches this motor, then retry.',
            );
          }
          if (elapsed >= 95) {
            throw StateError('No calibration result after 95 s; try again.');
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
      } finally {
        if (started) {
          try {
            await uds!.positive(Ecu.mcu, [0x31, 2, 0x06, 0xF1]);
          } catch (_) {}
        }
      }
    },
    service: true,
    cooperativeCancel: true,
  );

  Future<List<int>?> readParameter(Parameter p) async {
    List<int>? result;
    await operation(
      'Read ${p.name}',
      () async {
        if (!demo) await _unlock(p.ecu);
        result = demo
            ? List.filled(p.length, 0)
            : await uds!.read(p.ecu, p.did);
        message = 'Read ${p.name}';
      },
      service: true,
      restoreCustomer: true,
    );
    return result;
  }

  Future<void> writeParameter(
    Parameter p,
    Map<String, double> edits, {
    bool reversed = false,
  }) => operation(
    'Write ${p.name}',
    () async {
      if (!demo) await _unlock(p.ecu);
      final current = demo
          ? List.filled(p.length, 0)
          : await uds!.read(p.ecu, p.did);
      final proposed = p.encode(current, edits, reversed: reversed);
      if (!demo) {
        await uds!.writeDid(p.ecu, p.did, proposed);
        final after = await uds!.read(p.ecu, p.did);
        if (!listEquals(after, proposed)) {
          throw StateError('Readback differs; no automatic retry');
        }
      }
      message =
          '${demo ? 'Demo: ' : ''}Write acknowledged and readback matches. Reboot persistence unverified.';
    },
    service: true,
    cancellable: false,
    restoreCustomer: true,
  );
  Future<void> hmi(int ordinal, String label) => operation(label, () async {
    if (!demo) {
      requireLegacyMethod('HMI command');
      await link!.write(0x6bc, [ordinal, 0, 0, 0, 0, 0, 0, 0]);
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (demo) {
      message = 'Demo: $label';
    } else if (raw[0x6c0]?[0] == ordinal) {
      _noteLinkOk();
      message = '$label: echo seen; physical completion unverified';
    } else {
      _noteLinkTrouble();
      message =
          '$label: sent, no echo within 400 ms. Outcome unknown; no retry.';
    }
  }, service: true);

  /// VCU odometer in km. Read via UDS `22 0103` (4-byte little-endian) — the same
  /// request the factory diag app, the classic S1 Diag app and the desktop GUI
  /// use. No security access or Service mode is required for the read. The
  /// replacement-only write is separately gated and requires a documented
  /// actual mileage value supplied by the operator.
  int? odometerKm;
  List<int>? vcuVariantRecord;
  final repairReadBytes = <String, List<int>>{};
  final repairReadErrors = <String, String>{};
  DateTime? repairReadAt;

  static String repairKey(Ecu ecu, int did) =>
      '${ecu.label}:${did.toRadixString(16).toUpperCase().padLeft(4, '0')}';

  /// A snapshot for local replacement writes. Each failed DID remains visible.
  Future<void> readRepairSnapshot() =>
      operation('Read repair snapshot', () async {
        repairReadBytes.clear();
        repairReadErrors.clear();
        repairReadAt = null;
        for (final (ecu, did) in const [
          (Ecu.vcu, 0xF190),
          (Ecu.vcu, 0x0103),
          (Ecu.vcu, 0x0100),
          (Ecu.bms, 0xF120),
          (Ecu.bms, 0xE421),
        ]) {
          final key = repairKey(ecu, did);
          try {
            final bytes = demo
                ? switch (did) {
                    0xF190 => RepairValues.vin('TESTVAN1234567890'),
                    0x0103 => RepairValues.odometerKm(12345),
                    0x0100 => VcuVariantRecord.standard,
                    0xF120 => RepairValues.batteryId(
                      'TESTPACK1234',
                      expectedLength: 12,
                    ),
                    _ => [1],
                  }
                : await uds!.read(ecu, did);
            if (ecu == Ecu.vcu && did == 0x0100 && bytes.length != 37) {
              throw StateError(
                'VCU variant record has ${bytes.length} bytes; expected 37',
              );
            }
            if (ecu == Ecu.vcu && did == 0x0103 && bytes.length != 4) {
              throw StateError(
                'VCU odometer has ${bytes.length} bytes; expected 4',
              );
            }
            repairReadBytes[key] = List<int>.unmodifiable(bytes);
          } catch (error) {
            repairReadErrors[key] = error.toString();
          }
        }
        repairReadAt = DateTime.now();
        final record = repairReadBytes[repairKey(Ecu.vcu, 0x0100)];
        if (record != null) vcuVariantRecord = record;
        message =
            'Repair snapshot: ${repairReadBytes.length} reads, '
            '${repairReadErrors.length} unavailable. No write sent.';
      });

  Future<void> _writeRepairDid(
    Ecu ecu,
    int did,
    List<int> proposed,
  ) => operation(
    'Write ${repairKey(ecu, did)}',
    () async {
      if (!identityWritesAvailable) {
        throw StateError('Identity writes are unavailable in this build');
      }
      if (!demo) {
        if (!prefs.developerMode ||
            !legacyMethodsAvailable ||
            !parkedFresh ||
            !chargerDisconnectedFresh) {
          throw StateError(
            'Need Developer Mode, verified Gen1 identity, Park and unplugged charger',
          );
        }
        final readAt = repairReadAt;
        final key = repairKey(ecu, did);
        final expected = repairReadBytes[key];
        if (readAt == null ||
            DateTime.now().difference(readAt) > const Duration(minutes: 5) ||
            expected == null) {
          throw StateError('Read a fresh $key repair snapshot first');
        }
        await _unlock(ecu);
        final before = await uds!.read(ecu, did);
        if (!listEquals(before, expected)) {
          throw StateError('$key changed since snapshot; no write sent');
        }
        if (listEquals(before, proposed)) {
          message = '$key already matches; no write sent';
          return;
        }
        final ack = await uds!.writeDid(ecu, did, proposed);
        if (ack.length < 3 || ack[1] != did >> 8 || ack[2] != (did & 255)) {
          throw StateError('$key write acknowledgement did not echo the DID');
        }
        final after = await uds!.read(ecu, did);
        repairReadBytes[key] = List<int>.unmodifiable(after);
        if (!listEquals(after, proposed)) {
          throw StateError('$key readback differs; no automatic retry');
        }
      } else {
        repairReadBytes[repairKey(ecu, did)] = List<int>.unmodifiable(proposed);
      }
      message =
          '${repairKey(ecu, did)} readback matches. Reboot persistence and cloud state remain unverified.';
    },
    service: true,
    cancellable: false,
  );

  Future<void> writeReplacementVin(String vin) =>
      _writeRepairDid(Ecu.vcu, 0xF190, RepairValues.vin(vin));
  Future<void> writeReplacementOdometer(int km) =>
      _writeRepairDid(Ecu.vcu, 0x0103, RepairValues.odometerKm(km));
  Future<void> writeReplacementBatteryId(String id) {
    final current = repairReadBytes[repairKey(Ecu.bms, 0xF120)];
    if (current == null) {
      throw StateError('Read the current BMS battery ID first');
    }
    return _writeRepairDid(
      Ecu.bms,
      0xF120,
      RepairValues.batteryId(id, expectedLength: current.length),
    );
  }

  Future<void> writeReplacementBatteryGrade(int grade, String packId) {
    final current = repairReadBytes[repairKey(Ecu.bms, 0xF120)];
    if (current == null ||
        !listEquals(
          current,
          RepairValues.batteryId(packId, expectedLength: current.length),
        )) {
      throw StateError('BMS battery ID must match the confirmed pack ID');
    }
    return _writeRepairDid(Ecu.bms, 0xE421, RepairValues.grade(grade));
  }

  /// Read the complete VCU record before planning a board/variant repair.
  Future<void> readVcuVariantRecord() =>
      operation('Read VCU variant', () async {
        final bytes = demo
            ? VcuVariantRecord.standard
            : await uds!.read(Ecu.vcu, 0x0100);
        if (bytes.length != 37) {
          throw StateError('VCU returned ${bytes.length} bytes; expected 37');
        }
        vcuVariantRecord = List<int>.unmodifiable(bytes);
        message =
            'VCU variant: ${VcuVariantRecord.describe(bytes)} · ${hex(bytes)}';
      });

  /// Only the exact official Gen1 non-upgrade template may be changed here.
  /// An unknown/customized record requires a separate recovery plan.
  Future<void> restoreS1ProUpgrade() => operation(
    'Restore S1 Pro upgrade',
    () async {
      if (!vcuVariantWritesAvailable) {
        throw StateError('Variant writes are unavailable in this build');
      }
      if (!demo) {
        if (!prefs.developerMode) {
          throw StateError('Enter Developer Mode before a VCU identity write');
        }
        requireLegacyMethod('VCU variant restoration');
        if (identity.modelCode != 2 ||
            !parkedFresh ||
            !chargerDisconnectedFresh) {
          throw StateError(
            'Need a fresh Gen1 S1 Pro identity, Park and unplugged charger',
          );
        }
        await _unlock(Ecu.vcu);
      }
      final before = demo
          ? VcuVariantRecord.standard
          : await uds!.read(Ecu.vcu, 0x0100);
      vcuVariantRecord = List<int>.unmodifiable(before);
      if (!listEquals(before, VcuVariantRecord.standard)) {
        throw StateError(
          'VCU record is ${VcuVariantRecord.describe(before)}; no write sent',
        );
      }
      if (!demo) {
        await uds!.writeDid(Ecu.vcu, 0x0100, VcuVariantRecord.upgrade);
        final after = await uds!.read(Ecu.vcu, 0x0100);
        vcuVariantRecord = List<int>.unmodifiable(after);
        if (!listEquals(after, VcuVariantRecord.upgrade)) {
          throw StateError('VCU variant readback differs; no automatic retry');
        }
      } else {
        vcuVariantRecord = VcuVariantRecord.upgrade;
      }
      message =
          'VCU returned the complete upgrade record. Reboot persistence, features and cloud state remain unverified.';
    },
    service: true,
    cancellable: false,
  );
  DateTime? _firstFrameAt;

  // ---- diagnostic-session release -----------------------------------------
  bool _diagActive = false;

  /// Ends the extended diagnostic session after an operation: stops the
  /// TesterPresent heartbeat, sends UDS 10 01 to each ECU that was unlocked, and
  /// returns to the passive dump stream. Without this the heartbeat keeps the
  /// controllers in diagnostic mode until disconnect, which disables the
  /// scooter's handlebar buttons.
  Future<void> _releaseDiagnostics() async {
    _keepAlive?.cancel();
    try {
      await _keepAliveInFlight;
    } catch (_) {}
    final held = unlocked.toList();
    unlocked.clear();
    _diagActive = false;
    if (demo || link == null || uds == null) return;
    for (final ecu in held) {
      try {
        await uds!.defaultSession(ecu).timeout(const Duration(seconds: 2));
      } catch (error) {
        log('Default session ${ecu.name}: $error');
      }
    }
    try {
      if (link!.streamMode == 'diag') {
        await link!.reader(dump: true);
        live = true;
      }
    } catch (error) {
      log('Passive stream restore: $error');
    }
  }

  // ---- CAN stream watchdog -------------------------------------------------
  bool _restartingStream = false;
  DateTime? _lastStreamRestart;

  /// The scooter ends the CAN stream when it locks or its head unit sleeps. As
  /// long as the gRPC link is up, quietly re-open the passive dump stream.
  Future<void> _watchStream() async {
    if (demo || busy || !connected || link == null || _restartingStream) return;
    final now = DateTime.now();
    final dead = link!.streamMode == null;
    final stale =
        lastFrame != null &&
        now.difference(lastFrame!) > const Duration(seconds: 30);
    if (!dead && !stale) return;
    final last = _lastStreamRestart;
    if (last != null &&
        now.difference(last) < Duration(seconds: dead ? 4 : 30)) {
      return;
    }
    _restartingStream = true;
    _lastStreamRestart = now;
    try {
      await link!.reader(dump: true);
      live = true;
      _streamFailures = 0;
      log('CAN stream re-opened');
    } catch (error) {
      _streamFailures++;
      log('CAN stream re-open failed ($_streamFailures): $error');
    } finally {
      _restartingStream = false;
    }
    // Re-opening on a dead channel never recovers (e.g. after the hotspot or
    // Wi-Fi dropped), so rebuild the whole connection, with growing pauses.
    final silent =
        lastFrame == null ||
        DateTime.now().difference(lastFrame!) > const Duration(seconds: 45);
    final longSilence =
        lastFrame != null &&
        DateTime.now().difference(lastFrame!) > const Duration(seconds: 60);
    if (_wantConnected && silent && (_streamFailures >= 2 || longSilence)) {
      unawaited(_autoReconnect());
    }
  }

  // ---- persistent connection ------------------------------------------------
  static const _service = MethodChannel('in.crossfire.openola/network');
  bool _wantConnected = false, _autoReconnecting = false;
  int _streamFailures = 0, _reconnectAttempts = 0;
  DateTime? _lastAutoReconnect;

  /// Foreground service + wake/Wi-Fi locks so the stream keeps flowing with the
  /// screen off or the app in the background.
  Future<void> _setForegroundService(bool on) async {
    try {
      await _service.invokeMethod(on ? 'startKeepAlive' : 'stopKeepAlive');
    } catch (_) {
      // Not available (tests, older Android): the in-app watchdog still works.
    }
  }

  Future<void> _autoReconnect() async {
    if (_autoReconnecting || !_wantConnected || demo || transferActive) return;
    final wait = Duration(seconds: (5 << _reconnectAttempts.clamp(0, 4)));
    final last = _lastAutoReconnect;
    if (last != null && DateTime.now().difference(last) < wait) return;
    _autoReconnecting = true;
    _lastAutoReconnect = DateTime.now();
    _reconnectAttempts++;
    try {
      log('Auto-reconnect attempt $_reconnectAttempts');
      message = 'Connection lost, reconnecting (attempt $_reconnectAttempts)…';
      emit();
      await reconnect();
      if (connected) {
        _reconnectAttempts = 0;
        _streamFailures = 0;
        message = 'Reconnected';
        emit();
      }
    } catch (error) {
      log('Auto-reconnect failed: $error');
    } finally {
      _autoReconnecting = false;
    }
  }

  // ---- cancel --------------------------------------------------------------
  Completer<void>? _cancelSignal;
  bool cancelRequested = false;
  bool _criticalWrite = false;
  int _opId = 0;
  final _cancelledOps = <int>{};

  /// True while a head-unit install or pull is running.
  bool get transferActive =>
      (apkInstallStartedAt != null && apkInstallFinishedAt == null) ||
      (pullStartedAt != null && pullFinishedAt == null);

  /// One line for the global progress strip, e.g. "Installing: Uploading · 42%".
  String get transferSummary {
    final pulling = pullStartedAt != null && pullFinishedAt == null;
    final status = pulling ? pullStatus : apkInstallStatus;
    final fraction = pulling ? pullProgress : apkInstallProgress;
    return '${pulling ? 'Pulling' : 'Installing'}: $status · '
        '${(fraction * 100).round()}% — tap to open';
  }

  /// Asks the running operation to stop. Transfers stop between chunks; any
  /// other request is abandoned (its answer, if it arrives, is ignored).
  void cancelOperation() {
    if (!busy || _criticalWrite) return;
    cancelRequested = true;
    _cancelledOps.add(_opId);
    final now = DateTime.now();
    // A cancelled transfer must stop looking "in progress" straight away, even
    // though the abandoned request may take a moment to unwind.
    if (apkInstallStartedAt != null && apkInstallFinishedAt == null) {
      apkInstallFinishedAt = now;
      apkInstallIndeterminate = false;
    }
    if (pullStartedAt != null && pullFinishedAt == null) {
      pullFinishedAt = now;
      pullIndeterminate = false;
    }
    final signal = _cancelSignal;
    if (signal != null && !signal.isCompleted) signal.complete();
    if (headUnitTransport == HeadUnitTransport.adb && !demo) {
      unawaited(DirectAdb.disconnect().catchError((Object _) => ''));
    }
    message = 'Cancelling…';
    if (signal == null) {
      // Something set `busy` outside operation() (no cancel hook): release it so
      // the UI is never stuck on "Operation in progress".
      busy = false;
      message = 'Cancelled';
    }
    emit();
  }

  /// Throws if the operation this code belongs to was cancelled. The operation
  /// id travels in the zone, so work that outlives its operation (a request that
  /// was abandoned on Cancel) still stops at its next step instead of carrying on.
  void _checkCancelled() {
    final id = Zone.current[#openolaOp] as int?;
    if (cancelRequested || (id != null && _cancelledOps.contains(id))) {
      throw StateError('Cancelled');
    }
  }

  // ---- live internal-resistance estimate -----------------------------------
  List<double> _restCellV = const [];
  DateTime? _restCellAt;
  final List<double?> _irEstimate = List<double?>.filled(14, null);

  /// Per-cell IR estimate in mΩ from the voltage sag against the rest voltage
  /// under load (|I| ≥ 5 A). The BMS only reports real IR under load on some
  /// firmware, so this fills the gap while riding or charging. It is an
  /// estimate: sag also includes a little SoC drift.
  List<double?> get cellIrEstimate => List.unmodifiable(_irEstimate);

  void _sampleIrEstimate() {
    if (demo || !connected || !frameFresh(0x120)) return;
    final amps = profileValue(0x120, 'Overall_Battery_Current');
    if (amps == null) return;
    final volts = cellVoltages;
    if (volts.any((v) => v == null || v <= 0)) return;
    final now = DateTime.now();
    final magnitude = amps.abs();
    if (magnitude < 1.0) {
      _restCellV = [for (final v in volts) v!];
      _restCellAt = now;
      return;
    }
    final at = _restCellAt;
    if (magnitude < 5.0 ||
        _restCellV.length != volts.length ||
        at == null ||
        now.difference(at) > const Duration(minutes: 20)) {
      return;
    }
    for (var i = 0; i < volts.length && i < _irEstimate.length; i++) {
      final estimate = (_restCellV[i] - volts[i]!).abs() / magnitude * 1000;
      if (estimate <= 0 || estimate > 60) continue;
      final old = _irEstimate[i];
      _irEstimate[i] = old == null ? estimate : old * 0.8 + estimate * 0.2;
    }
  }

  /// Pack temperature: the BMS effective temperature when broadcast, else the
  /// UDS snapshot's, else null.
  double? get batteryTemperature =>
      canBattery?.healthValue('effective temp') ??
      battery?.healthValue('effective temp');

  bool _odometerFallbackTried = false;

  /// True when the passive route cannot supply the odometer and a single
  /// vehicle-controller read is possible (or has been tried).
  bool get odometerFallbackSafe => parkedFresh && chargerDisconnectedFresh;

  /// When the scooter never broadcasts 0x356, read the odometer once from the
  /// VCU (UDS 22 0103) — but only when it is provably safe: parked, charger
  /// unplugged, nothing else running. That route opens a diagnostic session,
  /// which can interrupt charging, so it never runs on a plugged-in scooter and
  /// is tried at most once per connection.
  Future<void> _maybeReadOdometerFallback() async {
    if (s1xTcpReadOnly) return;
    if (_odometerFallbackTried || busy || !odometerNotBroadcast) return;
    if (!odometerFallbackSafe) return;
    _odometerFallbackTried = true;
    await readOdometer();
  }

  /// True when the scooter is awake and streaming but has not broadcast the
  /// 0x356 odometer frame for 20 s (some firmware does not send it). Lets Home
  /// say so instead of showing "Reading automatically…" forever.
  bool get odometerNotBroadcast {
    final since = _firstFrameAt;
    return connected &&
        !demo &&
        odometerKm == null &&
        !vehicleAsleep &&
        since != null &&
        DateTime.now().difference(since) > const Duration(seconds: 20);
  }

  Future<void> readOdometer() => operation('Read odometer', () async {
    if (demo) {
      odometerKm = 12345;
      message = 'Demo odometer: 12345 km';
      return;
    }
    final data = await uds!.read(Ecu.vcu, 0x0103);
    if (data.length < 4) {
      throw StateError('Short odometer response (${data.length} bytes)');
    }
    odometerKm = data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
    message = 'Odometer: $odometerKm km';
  }, service: false);

  /// Read-only diagnostic-identity (certificate) status check. Does not
  /// generate or install certs — those server-side operations are brick-risky
  /// and deliberately not exposed.
  Future<void> validateCerts() => operation('Validate identity', () async {
    certStatus = demo
        ? 'Demo: diagnostic identity valid'
        : 'Valid — the head unit accepted the diagnostic identity '
              '(reply: ${(await link!.validateCerts()).trim()}). This checks the '
              'certificate only; it does not test commands.';
    message = certStatus;
  });

  // --- Firmware OTA (gRPC SwUpdate). otaStatus is read-only/safe; otaFlash is
  // brick-capable and EXPERIMENTAL (the checksum format is unverified). ---
  String otaState = '';
  double otaProgress = 0; // 0..1 during upload

  Future<void> otaStatus() => operation('Update status', () async {
    otaState = demo ? 'IDLE (demo)' : await link!.swStatus();
    message = otaState;
  });

  // --- Root shell on the head unit (ExecuteADBCommand). Dev-mode gated in the
  // UI. Runs as uid 0, so powerful; used for self-test foregrounding and to
  // read the on-device diagnostic identity. ---
  String adbOutput = '';
  List<HeadUnitApp> headUnitApps = const [];

  bool get headUnitReady =>
      demo ||
      (headUnitTransport == HeadUnitTransport.grpc
          ? connected
          : directAdbConnected);

  Future<String> _headUnitShell(
    String command, {
    Duration timeout = const Duration(seconds: 30),
  }) {
    if (headUnitTransport == HeadUnitTransport.adb) {
      if (!directAdbConnected) {
        throw StateError('Direct ADB is not connected');
      }
      return DirectAdb.shell(command);
    }
    if (!connected || link == null) {
      throw StateError('The gRPC root bridge is not connected');
    }
    return link!.adb(command, timeout: timeout);
  }

  Future<void> connectDirectAdb(String host, int port) async {
    if (busy) return;
    busy = true;
    message = '';
    directAdbStatus = 'Connecting to $host:$port';
    emit();
    try {
      directAdbStatus = demo
          ? 'Demo: Authorized & connected'
          : await DirectAdb.connect(
              host,
              port,
              phoneHotspot: prefs.store.getBool('phoneHotspot') ?? false,
            ).timeout(const Duration(seconds: 25));
      directAdbConnected = true;
      headUnitTransport = HeadUnitTransport.adb;
      await prefs.store.setString('adbHost', host);
      await prefs.store.setInt('adbPort', port);
      message = directAdbStatus;
      log('Direct ADB connected to $host:$port');
    } catch (error) {
      directAdbConnected = false;
      if (error is TimeoutException) {
        try {
          await DirectAdb.disconnect();
        } catch (_) {}
      }
      directAdbStatus = error is TimeoutException
          ? 'ADB did not answer on $host:$port. Use the scooter\'s IPv4 address '
                '(Find ADB host), and authorize this key via gRPC first.'
          : 'Connection failed: $error';
      message = directAdbStatus;
      log(directAdbStatus);
    } finally {
      busy = false;
      emit();
    }
  }

  Future<void> authorizeDirectAdbViaGrpc() => operation(
    'Authorize OpenOLA ADB key',
    () async {
      if (demo) {
        directAdbStatus = 'Demo: OpenOLA ADB key authorized';
        message = directAdbStatus;
        return;
      }
      final bridge = link;
      if (bridge == null) {
        throw StateError('The gRPC root bridge is not connected');
      }
      final token = await DirectAdb.publicKey();
      final output = await bridge.adb(HeadUnitCommands.provisionAdbKey(token));
      if (!RegExp(r'(^|\n)installed(\r?$|\n)').hasMatch(output)) {
        throw StateError('Scooter did not confirm the authorized ADB key');
      }
      await bridge.adb(HeadUnitCommands.restartAdbd);
      directAdbStatus = 'OpenOLA app key authorized · connect to port 5555';
      message = directAdbStatus;
      log('Authorized this OpenOLA installation for direct ADB');
    },
  );

  Future<void> removeDirectAdbAuthorizationViaGrpc() =>
      operation('Remove OpenOLA ADB key', () async {
        if (demo) {
          directAdbStatus = 'Demo: OpenOLA ADB key removed';
          message = directAdbStatus;
          return;
        }
        final bridge = link;
        if (bridge == null) {
          throw StateError('The gRPC root bridge is not connected');
        }
        final token = await DirectAdb.publicKey();
        final output = await bridge.adb(HeadUnitCommands.removeAdbKey(token));
        if (!RegExp(r'(^|\n)removed(\r?$|\n)').hasMatch(output)) {
          throw StateError('Scooter did not confirm removal of the ADB key');
        }
        await bridge.adb(HeadUnitCommands.restartAdbd);
        await DirectAdb.disconnect();
        directAdbConnected = false;
        headUnitTransport = HeadUnitTransport.grpc;
        directAdbStatus = 'OpenOLA app key removed';
        message = directAdbStatus;
        log('Removed this OpenOLA installation from direct ADB');
      });

  Future<void> disconnectDirectAdb() async {
    if (!demo) await DirectAdb.disconnect();
    directAdbConnected = false;
    directAdbStatus = 'Not connected';
    if (headUnitTransport == HeadUnitTransport.adb) {
      headUnitTransport = HeadUnitTransport.grpc;
    }
    emit();
  }

  void selectHeadUnitTransport(HeadUnitTransport value) {
    headUnitTransport = value;
    if (value == HeadUnitTransport.adb && !directAdbConnected && !demo) {
      message = 'Connect ADB below to use this transport';
    }
    emit();
  }

  Future<void> adbCommand(String cmd) => operation('ADB', () async {
    adbOutput = demo
        ? 'Demo: `$cmd` was not executed.'
        : await _headUnitShell(cmd);
    message = 'ADB command ran';
  }, headUnit: true);

  Future<void> refreshHeadUnitApps() =>
      operation('Discover head-unit apps', () async {
        if (demo) {
          headUnitApps = const [
            HeadUnitApp(
              label: 'OLA HMI',
              packageName: 'com.olaelectric.hmiclient',
              component: HeadUnitCommands.olaHmiComponent,
            ),
            HeadUnitApp(
              label: 'Diagnostic Mode',
              packageName: 'com.ola.mfgapp',
              component: 'com.ola.mfgapp/.MainActivity',
            ),
            HeadUnitApp(
              label: 'UDS test tool',
              packageName: 'com.olaelectric.udstestapp',
              component: 'com.olaelectric.udstestapp/.MainActivity',
            ),
          ];
        } else {
          headUnitApps = HeadUnitCommands.parseLaunchableApps(
            await _headUnitShell(HeadUnitCommands.listLaunchableApps),
          );
        }
        message = headUnitApps.isEmpty
            ? 'No launchable activities were returned'
            : '${headUnitApps.length} launchable apps found';
      }, headUnit: true);

  Future<void> launchHeadUnitApp(HeadUnitApp app) =>
      operation('Launch ${app.label}', () async {
        final command = HeadUnitCommands.launchComponent(app.component);
        adbOutput = demo
            ? 'Demo: ${app.component} was not launched.'
            : await _headUnitShell(command);
        if (RegExp(r'(^|\n)(Error:|Exception)').hasMatch(adbOutput)) {
          throw StateError(adbOutput.trim());
        }
        message = '${app.label} brought to front';
      }, headUnit: true);

  Future<void> launchOlaHmi() => launchHeadUnitApp(
    const HeadUnitApp(
      label: 'OLA HMI',
      packageName: 'com.olaelectric.hmiclient',
      component: HeadUnitCommands.olaHmiComponent,
    ),
  );

  Future<String> _currentProfileUuid() async => HeadUnitCommands.parseUuid(
    await link!.adb(HeadUnitCommands.currentProfileUuid),
  );

  /// Feature settings as the OLA HMI itself stores them: columns of the current
  /// profile's `user_profile` row. 0x660 only says what is *available*, so this
  /// is the nearest thing to the setting the HMI screen displays.
  Map<String, bool> profileFeatures = const {};
  DateTime? profileFeaturesAt;
  bool _featureReadBusy = false;

  static const _featureColumns = {
    'Boost mode': 'adaptive_power_boost',
    'Hill hold': 'hill_hold',
    'Vacation mode': 'vacation_mode',
    'Motor cutoff delay': 'motor_cut_off',
    'Accident detection': 'fall_detection',
    'Tow / tamper alert': 'tow_theft',
    'Smart DRL': 'smart_drl',
  };

  /// Quiet, read-only refresh (no busy lock, no message): copies the profile
  /// database and reads this profile's feature columns.
  Future<void> readProfileFeatures() async {
    if (_featureReadBusy || !connected || demo || busy) return;
    _featureReadBusy = true;
    try {
      final uuid = await _currentProfileUuid();
      final snapshot = await _databaseSnapshot(
        HeadUnitCommands.profileDatabase,
      );
      final rows = snapshot.rows('user_profile');
      if (rows == null) return;
      final row = rows.where((r) => r['uda_uuid'] == uuid).firstOrNull;
      if (row == null) return;
      profileFeatures = {
        for (final e in _featureColumns.entries)
          if (row[e.value] is num) e.key: (row[e.value] as num) != 0,
      };
      profileFeaturesAt = DateTime.now();
      emit();
    } catch (error) {
      log('Feature state read: $error');
    } finally {
      _featureReadBusy = false;
    }
  }

  String? _restrictionDb;
  bool restrictionUnsupported = false;

  /// Copies a file off the head unit through the root shell (base64 in chunks).
  /// Used to read the profile databases, because the head unit has no `sqlite3`
  /// binary; nothing on the scooter is changed.
  Future<Uint8List> _readRemoteFile(
    String path, {
    int maxBytes = 4 << 20,
  }) async {
    final size = int.tryParse(
      (await link!.adb(HeadUnitCommands.fileSize(path))).trim(),
    );
    if (size == null || size < 0) {
      throw StateError('Could not read the size of ${path.split('/').last}');
    }
    if (size > maxBytes) {
      throw StateError('${path.split('/').last} is too large to read');
    }
    final out = BytesBuilder(copy: false);
    const chunk = 48 * 1024;
    for (var offset = 0; offset < size; offset += chunk) {
      _checkCancelled();
      final n = (size - offset).clamp(1, chunk);
      final text = await link!.adb(HeadUnitCommands.readChunk(path, offset, n));
      final bytes = base64Decode(text.replaceAll(RegExp(r'\s+'), ''));
      if (bytes.length != n) {
        throw StateError(
          'Short read at byte $offset of ${path.split('/').last}',
        );
      }
      out.add(bytes);
    }
    return out.takeBytes();
  }

  /// A database plus its write-ahead log, read locally. The WAL matters: recent
  /// changes (for example after a Sport/Hyper update) live there until a
  /// checkpoint.
  Future<SqliteSnapshot> _databaseSnapshot(String path) async {
    final database = await _readRemoteFile(path);
    var wal = Uint8List(0);
    try {
      wal = await _readRemoteFile('$path-wal');
    } catch (_) {
      // No WAL file: the database file is complete on its own.
    }
    return SqliteSnapshot(database, wal);
  }

  /// Reads the Sport/Hyper flags for [uuid] from a copy of the profile database
  /// (`drive_mode_restriction`). The error says what was found so a release
  /// that really lacks the table is diagnosable.
  Future<RestrictionState> _readRestrictionState(String uuid) async {
    final listing = await link!.adb(HeadUnitCommands.listProfileDatabases);
    final found = HeadUnitCommands.parseProfileDatabases(listing);
    final candidates = <String>{
      ?_restrictionDb,
      ...found,
      HeadUnitCommands.restrictionDatabase,
    };
    final notes = <String>[];
    for (final database in candidates) {
      final name = database.split('/').last;
      try {
        final snapshot = await _databaseSnapshot(database);
        final rows = snapshot.rows('drive_mode_restriction');
        if (rows == null) {
          notes.add('$name has no restriction table');
          continue;
        }
        final mine = rows.where((r) => r['udaUuid'] == uuid);
        if (mine.isEmpty) {
          notes.add('$name has no row for the current profile');
          continue;
        }
        bool on(Object? v) => v is num && v != 0;
        _restrictionDb = database;
        restrictionUnsupported = false;
        return RestrictionState(
          sportEnabled: on(mine.first['sports_mode_enabled']),
          hyperEnabled: on(mine.first['hyper_mode_enabled']),
        );
      } on SqliteFormatException catch (error) {
        notes.add('$name: ${error.message}');
      }
    }
    restrictionUnsupported = true;
    throw StateError(
      'This software release does not expose the Sport/Hyper restriction '
      'flags (${notes.isEmpty ? 'no profile database found' : notes.join('; ')}).',
    );
  }

  Future<void>
  readRestrictions() => operation('Read ride restrictions', () async {
    if (demo) {
      restrictionState = const RestrictionState(
        sportEnabled: true,
        hyperEnabled: true,
      );
    } else {
      final uuid = await _currentProfileUuid();
      restrictionState = await _readRestrictionState(uuid);
    }
    message =
        'Sport ${restrictionState!.sportEnabled ? 'enabled' : 'disabled'} · Hyper ${restrictionState!.hyperEnabled ? 'enabled' : 'disabled'}';
  });

  Future<void> setRestrictions(
    RestrictionMode target,
  ) => operation('Update ride restrictions', () async {
    if (!demo && !parkedFresh) {
      throw StateError('A fresh 0x113 frame must confirm Park');
    }
    if (!demo && !chargerDisconnectedFresh) {
      throw StateError('A fresh 0x62D frame must confirm charger disconnected');
    }
    if (demo) {
      restrictionState = RestrictionState(
        sportEnabled: target.sportEnabled,
        hyperEnabled: target.hyperEnabled,
      );
      message = 'Demo restriction state updated';
      return;
    }
    final uuid = await _currentProfileUuid();
    final started = DateTime.now();
    await link!.adb(HeadUnitCommands.restrictionBroadcast(uuid, target));
    var canAcknowledged = false;
    for (var attempt = 0; attempt < 25; attempt++) {
      canAcknowledged = notifications.any(
        (notification) =>
            notification.code == target.responseCode &&
            !notification.time.isBefore(started),
      );
      if (canAcknowledged) break;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final stored = await _readRestrictionState(uuid);
    if (stored.sportEnabled != target.sportEnabled ||
        stored.hyperEnabled != target.hyperEnabled) {
      throw StateError('Profile Manager readback did not match the request');
    }
    if (!canAcknowledged) {
      throw StateError(
        'Profile updated, but vehicle CAN acknowledgement ${target.responseCode} was not observed',
      );
    }
    restrictionState = stored;
    message =
        'Restriction verified: Sport ${stored.sportEnabled ? 'enabled' : 'disabled'} · Hyper ${stored.hyperEnabled ? 'enabled' : 'disabled'}; paid entitlement not verified';
  });

  /// Collects the two independent entitlement views without changing the
  /// scooter: daemon ECOS/Dyno strings, profile-manager restriction state,
  /// relevant shared-preference keys, and passive CAN evidence.
  Future<void>
  readTechPackEvidence() => operation('Read TechPack evidence', () async {
    if (demo) {
      techPackFlags = rpc.EcosDynoFlags(
        status: rpc.RespStatus.RESP_SUCCESS,
        ecos1: 'demo',
        ecos2: 'demo',
        dyno: 'demo',
      );
      techPackEvidence = 'DEMO — no scooter data read';
      return;
    }
    techPackFlags = await link!.ecosDynoFlags();
    final uuid = await _currentProfileUuid();
    final snapshot = await _databaseSnapshot(HeadUnitCommands.profileDatabase);
    final rows = snapshot.rows('drive_mode_restriction') ?? const [];
    final restriction = rows.where((r) => r['udaUuid'] == uuid);
    final prefKeys = <String>[];
    for (final path in [
      HeadUnitCommands.profilePreferences,
      HeadUnitCommands.vehicleStatePreferences,
    ]) {
      final xml = await link!.adb('cat $path');
      for (final match in RegExp(
        r'name="([^"]*(?:techpack|ecos|dyno|hyper|sport)[^"]*)"',
        caseSensitive: false,
      ).allMatches(xml)) {
        prefKeys.add('${path.split('/').last}: ${match.group(1)}');
      }
    }
    String frame(int id) {
      final bytes = raw[id];
      return bytes == null
          ? 'unavailable'
          : bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    }

    techPackEvidence = [
      'profile_uuid=$uuid',
      'drive_mode_restriction=${restriction.isEmpty ? 'missing' : restriction.first}',
      'profile_pref_keys=${prefKeys.isEmpty ? 'none' : prefKeys.join(' | ')}',
      'CAN_0x660=${frame(0x660)}',
      'CAN_0x6D0=${frame(0x6d0)}',
      'CAN_0x113=${frame(0x113)}',
    ].join('\n');
    message = 'TechPack evidence read; no vehicle configuration changed';
  }, service: true);

  /// Calls the recovered official daemon re-apply endpoint. It does not
  /// fabricate a flag payload; the daemon decides whether the provisioned
  /// cloud configuration can be applied.
  Future<void> techPackUpdateProbe(String type) => operation(
    'TechPack update probe',
    () async {
      if (type != 'techpack') {
        throw ArgumentError(
          'Only the evidence-backed techpack request is enabled',
        );
      }
      if (demo) {
        techPackProbeResult =
            'DEMO — no TechPackUpdate RPC sent; no scooter was contacted';
        message = 'Demo: TechPack update probe simulated';
        return;
      }
      if (!parkedFresh || !chargerDisconnectedFresh) {
        throw StateError(
          'Fresh Park and disconnected-charger evidence is required',
        );
      }
      final before = await link!.ecosDynoFlags();
      final result = await link!.techPackUpdateProbe(type: type);
      final after = await link!.ecosDynoFlags();
      techPackFlags = after;
      techPackProbeResult = [
        'request_type=$type',
        'status=${result.status.name}',
        'message=${result.statusMsg}',
        'before_dyno=${before.dyno}',
        'after_dyno=${after.dyno}',
        'before_ecos1=${before.ecos1}',
        'after_ecos1=${after.ecos1}',
        'before_ecos2=${before.ecos2}',
        'after_ecos2=${after.ecos2}',
        'result_is_not_entitlement_proof=true',
      ].join('\n');
      message =
          'TechPack daemon probe completed; entitlement still requires readback';
    },
    service: true,
    cancellable: false,
  );

  Future<void> readPasscodeHealth() =>
      operation('Read passcode health', () async {
        if (demo) {
          passcodeHealth = const PasscodeHealth(
            profileCount: 2,
            scryptVerifierCount: 2,
            minimumRemainingAttempts: 5,
            vsmCachePresent: false,
          );
        } else {
          final cache = await link!.adb(HeadUnitCommands.vsmProfileCache);
          final snapshot = await _databaseSnapshot(
            HeadUnitCommands.profileDatabase,
          );
          final rows = snapshot.rows('user_profile');
          if (rows == null) {
            throw StateError(
              'This software release keeps no passcode profile table the app '
              'can read. Nothing was changed.',
            );
          }
          passcodeHealth = PasscodeHealth.fromRows(
            rows,
            cache.trim() == 'present',
          );
        }
        final health = passcodeHealth!;
        message = health.allVerifiersExpected
            ? 'Passcode verifier format is healthy'
            : 'Unexpected passcode verifier format detected';
      });

  // ---- Head-unit package install (single APK or split bundle) -------------
  DateTime? apkInstallStartedAt, apkInstallFinishedAt;
  String apkInstallDetail = '';
  bool apkInstallIndeterminate = false;

  void _apkProgress(
    double fraction,
    String status, {
    String detail = '',
    bool indeterminate = false,
  }) {
    apkInstallProgress = fraction;
    apkInstallStatus = status;
    apkInstallDetail = detail;
    apkInstallIndeterminate = indeterminate;
    emit();
  }

  void _apkBegin() {
    apkInstallStartedAt = DateTime.now();
    apkInstallFinishedAt = null;
    _apkProgress(0, 'Preparing');
  }

  void _apkEnd() {
    apkInstallFinishedAt = DateTime.now();
    apkInstallIndeterminate = false;
  }

  Future<void> installHeadUnitApk(List<int> bytes, String fileName) =>
      installHeadUnitPackage(ApkPackage(fileName, [ApkPart(fileName, bytes)]));

  /// Installs a single APK or an `.apks`/`.xapk`/`.apkm` split bundle through
  /// the gRPC root bridge. Every part is uploaded, size- and SHA-256-verified
  /// on the head unit, then installed in one package-manager session.
  /// Uploads [bytes] as numbered part files with three calls in flight (each
  /// call is a separate shell round trip, so sequential sending is slow). The
  /// decode step later joins the parts in order. Falls back to 24 KiB chunks,
  /// one at a time, if the head unit rejects the large ones.
  Future<void> _uploadChunks(
    int index,
    List<int> bytes,
    void Function(int) onSent,
  ) async {
    var uploaded = 0;
    Future<void> run(int chunkSize, int parallel) async {
      final count = (bytes.length / chunkSize).ceil();
      var next = 0;
      Object? failure;
      Future<void> worker() async {
        while (failure == null) {
          final k = next++;
          if (k >= count) return;
          _checkCancelled();
          final start = k * chunkSize;
          final end = (start + chunkSize).clamp(0, bytes.length);
          try {
            await link!.adb(
              HeadUnitCommands.writeApkPart(
                index,
                k,
                bytes.sublist(start, end),
              ),
            );
            uploaded += end - start;
            onSent(end - start);
          } catch (error) {
            failure ??= error;
            return;
          }
        }
      }

      await Future.wait([for (var w = 0; w < parallel; w++) worker()]);
      if (failure != null) throw failure!;
    }

    try {
      // 90 KiB raw -> ~120 KB base64 per call, under the 128 KiB argv limit.
      await run(90 * 1024, 3);
    } catch (error) {
      if (cancelRequested || error.toString().contains('Cancelled')) rethrow;
      log('Large upload chunks failed ($error); retrying with 24 KiB');
      onSent(-uploaded);
      uploaded = 0;
      await link!.adb(HeadUnitCommands.clearParts(index));
      await run(24 * 1024, 1);
    }
  }

  Future<void> installHeadUnitPackage(
    ApkPackage pkg,
  ) => operation('Install head-unit APK', () async {
    final parts = pkg.parts;
    if (parts.isEmpty || parts.any((p) => p.bytes.isEmpty)) {
      throw ArgumentError('APK is empty');
    }
    if (pkg.totalBytes > ApkPackage.maxTotalBytes) {
      throw ArgumentError('APK exceeds the 300 MB safety limit');
    }
    _apkBegin();
    if (demo) {
      _apkProgress(1, 'Demo: ${pkg.name} was not uploaded');
      _apkEnd();
      message = apkInstallStatus;
      return;
    }
    try {
      await link!.adb(HeadUnitCommands.removePartDir);
      await link!.adb(HeadUnitCommands.clearApkUploads(parts.length));
      await link!.adb(HeadUnitCommands.preparePartDir);
      final total = pkg.totalBytes;
      var sent = 0;
      for (var i = 0; i < parts.length; i++) {
        final bytes = parts[i].bytes;
        final detail = parts.length > 1
            ? 'File ${i + 1} of ${parts.length} · ${parts[i].name}'
            : parts[i].name;
        await _uploadChunks(i, bytes, (n) {
          sent += n;
          _apkProgress(sent / total * 0.85, 'Uploading', detail: detail);
        });
        _apkProgress(
          sent / total * 0.85,
          'Verifying',
          detail: detail,
          indeterminate: true,
        );
        final decoded = await link!.adb(HeadUnitCommands.decodeParts(i));
        final decodedBytes = int.tryParse(
          decoded.trim().split(RegExp(r'\s+')).last,
        );
        if (decodedBytes != bytes.length) {
          throw StateError(
            'Decoded size mismatch in ${parts[i].name} '
            '(${decodedBytes ?? 'unknown'} / ${bytes.length})',
          );
        }
        final expected = sha256.convert(bytes).toString();
        final actual = (await link!.adb(
          HeadUnitCommands.hashApkAt(i),
        )).trim().split(RegExp(r'\s+')).first;
        if (actual.toLowerCase() != expected) {
          throw StateError('SHA-256 verification failed for ${parts[i].name}');
        }
      }
      // The package manager reports no progress, so show elapsed time only.
      _apkProgress(
        0.9,
        parts.length > 1 ? 'Installing ${parts.length} parts' : 'Installing',
        indeterminate: true,
      );
      String result;
      if (parts.length == 1) {
        result = await link!.adb(
          HeadUnitCommands.installApk,
          timeout: const Duration(minutes: 5),
        );
      } else {
        // `pm` has no install-multiple: stage every file in one session, commit.
        final session = HeadUnitCommands.parseSessionId(
          await link!.adb(HeadUnitCommands.installCreate),
        );
        try {
          for (var i = 0; i < parts.length; i++) {
            final written = await link!.adb(
              HeadUnitCommands.installWrite(session, i, parts[i].bytes.length),
              timeout: const Duration(minutes: 3),
            );
            if (!written.contains('Success')) {
              throw StateError(
                'Could not stage ${parts[i].name}: ${written.trim()}',
              );
            }
          }
          result = await link!.adb(
            HeadUnitCommands.installCommit(session),
            timeout: const Duration(minutes: 5),
          );
        } catch (_) {
          try {
            await link!.adb(HeadUnitCommands.installAbandon(session));
          } catch (_) {}
          rethrow;
        }
      }
      if (!RegExp(r'(^|\s)Success(\s|$)').hasMatch(result)) {
        throw StateError('Package manager rejected the APK: ${result.trim()}');
      }
      _apkProgress(1, 'Installed ${pkg.name}');
      message = apkInstallStatus;
    } finally {
      _apkEnd();
      await link!.adb(HeadUnitCommands.removePartDir);
      await link!.adb(HeadUnitCommands.clearApkUploads(parts.length));
    }
  });

  Future<void> installHeadUnitApkDirect(String path, String fileName) =>
      installHeadUnitPackageDirect([path], fileName, 0);

  /// Direct-ADB install of one or several APK files already on the phone.
  /// Native code pushes each file with byte counting, so the bar shows real
  /// bytes sent of the total size; the final `pm install` step has no progress
  /// and shows elapsed time only.
  Future<void> installHeadUnitPackageDirect(
    List<String> paths,
    String fileName,
    int totalBytes,
  ) => operation('Install head-unit APK over ADB', () async {
    if (headUnitTransport != HeadUnitTransport.adb) {
      throw StateError('Select the ADB execution mode first');
    }
    _apkBegin();
    if (demo) {
      _apkProgress(1, 'Demo: $fileName was not installed');
      _apkEnd();
      message = apkInstallStatus;
      return;
    }
    final sub = DirectAdb.progress.stream
        .where((e) => e.op == 'install')
        .listen((e) {
          final detail = e.count > 1
              ? 'File ${e.index + 1} of ${e.count}'
              : fileName;
          _apkProgress(
            e.total == 0 ? 0 : e.sent / e.total * 0.9,
            e.sent >= e.total ? 'Installing' : 'Uploading',
            detail: detail,
            indeterminate: e.sent >= e.total,
          );
        });
    try {
      final result = await DirectAdb.installFiles(paths);
      if (!RegExp(r'(^|\s)Success(\s|$)').hasMatch(result)) {
        throw StateError('ADB package install failed: ${result.trim()}');
      }
      _apkProgress(1, 'Installed $fileName over direct ADB');
      message = apkInstallStatus;
    } finally {
      await sub.cancel();
      _apkEnd();
    }
  }, headUnit: true);

  // ---- APK pull: copy an installed app's APK(s) off the head unit ----------
  DateTime? pullStartedAt, pullFinishedAt;
  double pullProgress = 0;
  String pullStatus = '', pullDetail = '';
  bool pullIndeterminate = false;
  List<String> pulledFiles = const [];

  void _pullState(
    double fraction,
    String status, {
    String detail = '',
    bool indeterminate = false,
  }) {
    pullProgress = fraction;
    pullStatus = status;
    pullDetail = detail;
    pullIndeterminate = indeterminate;
    emit();
  }

  /// Copies every APK of [package] (base plus splits) from the head unit into
  /// [destination] on the phone. Read-only on the scooter: it only runs
  /// `pm path`, `stat`, `sha256sum` and reads file ranges. Each file is
  /// SHA-256-verified against the head unit's own hash before it is saved.
  /// One APK is saved as `<package>.apk`; an app with splits is saved into a
  /// `<package>/` folder so the files can be reinstalled together.
  static const _protectedPrefixes = [
    'com.olaelectric.',
    'com.android.',
    'com.google.android.',
    'com.qualcomm',
    'org.codeaurora',
    'vendor.',
  ];

  /// Uninstalls a user-installed app from the head unit. Ola, Android and
  /// vendor packages are refused by name, and anything with an APK outside
  /// /data/app (a system app) is refused by location.
  Future<void> uninstallHeadUnitApp(
    String package,
    String label,
  ) => operation('Uninstall $label', () async {
    if (!HeadUnitCommands.isPackageName(package) ||
        package == 'android' ||
        _protectedPrefixes.any(package.startsWith)) {
      throw StateError('$label is a protected system app and was not touched');
    }
    if (demo) {
      message = 'Demo: $label was not uninstalled';
      return;
    }
    final paths = HeadUnitCommands.parsePackagePaths(
      await _headUnitShell(HeadUnitCommands.packagePaths(package)),
    );
    if (!HeadUnitCommands.isUserInstalled(paths)) {
      throw StateError('$label is a system app and cannot be uninstalled here');
    }
    final result = await _headUnitShell(
      HeadUnitCommands.uninstallPackage(package),
    );
    if (!RegExp(r'(^|\s)Success(\s|$)').hasMatch(result)) {
      throw StateError('Package manager refused: ${result.trim()}');
    }
    headUnitApps = [
      for (final app in headUnitApps)
        if (app.packageName != package) app,
    ];
    message = 'Uninstalled $label';
  }, headUnit: true);

  /// Copies one file off the head unit with three ranged reads in flight (each
  /// is its own shell round trip) and writes every range at its own offset.
  Future<void> _pullFile(
    String remote,
    File local,
    int size,
    void Function(int received) onProgress,
  ) async {
    const chunk = 90 * 1024;
    final file = await local.open(mode: FileMode.write);
    var received = 0, next = 0;
    Object? failure;
    Future<void> worker() async {
      while (failure == null) {
        final offset = next;
        next += chunk;
        if (offset >= size) return;
        _checkCancelled();
        final n = (size - offset).clamp(1, chunk);
        try {
          final text = await link!.adb(
            HeadUnitCommands.readChunk(remote, offset, n),
          );
          final bytes = base64Decode(text.replaceAll(RegExp(r'\s+'), ''));
          if (bytes.length != n) {
            throw StateError(
              'Short read at byte $offset (${bytes.length} of $n)',
            );
          }
          file.setPositionSync(offset);
          file.writeFromSync(bytes);
          received += n;
          onProgress(received);
        } catch (error) {
          failure ??= error;
          return;
        }
      }
    }

    try {
      await Future.wait([for (var w = 0; w < 3; w++) worker()]);
      if (failure != null) throw failure!;
    } finally {
      await file.close();
    }
  }

  Future<void> pullHeadUnitApp(
    String package,
    String destination,
    String label,
  ) => operation('Pull APK', () async {
    try {
      await _pullHeadUnitAppInner(package, destination, label);
    } catch (error) {
      // Show the failure on the transfer bar itself, with the step it died in,
      // instead of leaving a bar that just sits at 0%.
      final cancelled = error.toString().contains('Cancelled');
      _pullState(
        pullProgress,
        cancelled ? 'Cancelled' : 'Failed at "$pullStatus"',
        detail: cancelled
            ? ''
            : error.toString().replaceFirst('Bad state: ', ''),
      );
      log('Pull ${cancelled ? 'cancelled' : 'failed'} ($pullStatus): $error');
      rethrow;
    }
  });

  Future<void> _pullHeadUnitAppInner(
    String package,
    String destination,
    String label,
  ) async {
    pullStartedAt = DateTime.now();
    pullFinishedAt = null;
    pulledFiles = const [];
    _pullState(0, 'Locating $label');
    log('Pull $package -> $destination');
    emit();
    final dest = Directory(destination);
    final temp = await Directory.systemTemp.createTemp('openola_pull');
    try {
      if (demo) {
        _pullState(1, 'Demo: nothing was pulled');
        message = pullStatus;
        return;
      }
      final remotes = HeadUnitCommands.parsePackagePaths(
        await link!.adb(HeadUnitCommands.packagePaths(package)),
      );
      if (remotes.isEmpty) {
        throw StateError('No APK path was reported for $package');
      }
      log('Pull paths: ${remotes.length}');
      final sizes = <int>[];
      for (final remote in remotes) {
        final size = int.tryParse(
          (await link!.adb(HeadUnitCommands.fileSize(remote))).trim(),
        );
        if (size == null || size <= 0) {
          throw StateError('Could not read the size of $remote');
        }
        sizes.add(size);
      }
      final total = sizes.fold<int>(0, (a, b) => a + b);
      log('Pull size: $total bytes');
      if (total > ApkPackage.maxTotalBytes) {
        throw StateError('The app exceeds the 300 MB pull limit');
      }
      final locals = <File>[];
      var done = 0;
      for (var i = 0; i < remotes.length; i++) {
        final remote = remotes[i];
        final local = File('${temp.path}/part_$i.apk');
        final detail = remotes.length > 1
            ? 'File ${i + 1} of ${remotes.length} · ${remote.split('/').last}'
            : remote.split('/').last;
        String megabytes(int bytes) => (bytes / 1048576).toStringAsFixed(1);
        await _pullFile(remote, local, sizes[i], (received) {
          _pullState(
            (done + received) / total * 0.95,
            'Copying',
            detail:
                '$detail · ${megabytes(done + received)} of ${megabytes(total)} MB',
          );
        });
        _pullState(done / total * 0.95, 'Verifying', detail: detail);
        if (await local.length() != sizes[i]) {
          throw StateError('Size mismatch for ${remote.split('/').last}');
        }
        final expected = (await link!.adb(
          HeadUnitCommands.fileHash(remote),
        )).trim().split(RegExp(r'\s+')).first.toLowerCase();
        final actual = (await sha256.bind(local.openRead()).first).toString();
        if (expected != actual) {
          throw StateError(
            'SHA-256 mismatch for ${remote.split('/').last}; nothing was saved',
          );
        }
        locals.add(local);
        done += sizes[i];
      }
      _pullState(0.97, 'Saving', indeterminate: true);
      final saved = <String>[];
      var usedFallback = false;
      // Writes into the chosen folder when the app is allowed to; Android 11+
      // usually refuses a plain file write there, so fall back to
      // Download/OpenOLA through MediaStore, which needs no permission.
      Future<String> saveOne(File from, String name, String subfolder) async {
        if (!usedFallback) {
          try {
            final dir = Directory(
              subfolder.isEmpty ? dest.path : '${dest.path}/$subfolder',
            );
            await dir.create(recursive: true);
            var target = File('${dir.path}/$name');
            var n = 1;
            final dot = name.lastIndexOf('.');
            final stem = dot < 0 ? name : name.substring(0, dot);
            final ext = dot < 0 ? '' : name.substring(dot);
            while (await target.exists()) {
              target = File('${dir.path}/${stem}_$n$ext');
              n++;
            }
            await from.copy(target.path);
            return target.path;
          } catch (error) {
            log('Chosen folder not writable ($error); using Download/OpenOLA');
            usedFallback = true;
          }
        }
        const channel = MethodChannel('in.crossfire.openola/network');
        final shown = await channel.invokeMethod<String>('saveToDownloads', {
          'source': from.path,
          'name': name,
          'folder': subfolder.isEmpty ? 'OpenOLA' : 'OpenOLA/$subfolder',
        });
        return shown ?? 'Download/OpenOLA/$name';
      }

      if (locals.length == 1) {
        saved.add(await saveOne(locals.single, '$package.apk', ''));
      } else {
        for (var i = 0; i < locals.length; i++) {
          saved.add(
            await saveOne(locals[i], remotes[i].split('/').last, package),
          );
        }
      }
      pulledFiles = List.unmodifiable(saved);
      _pullState(
        1,
        saved.length == 1
            ? 'Saved ${saved.single.split(RegExp(r'[\\/]')).last}'
            : 'Saved ${saved.length} files',
      );
      message = pullStatus;
    } finally {
      pullFinishedAt = DateTime.now();
      pullIndeterminate = false;
      try {
        await temp.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Brings the scooter's "Diagnostic Mode" app (com.ola.mfgapp, the
  /// manufacturing app that hosts the self-tests) to the
  /// foreground so head-unit self-tests actually display. Best-effort.
  // `monkey -p … -c LAUNCHER` returns no events under the head unit's gRPC exec
  // context (no controlling terminal), so the diag app never actually comes
  // forward. An explicit `am start` on its launcher activity works reliably —
  // confirmed against the apps installed on a live S1: com.ola.mfgapp (label
  // "Diagnostic Mode") owns the LCD/GPS/BT/speaker/mic activities; the older
  // code launched com.olaelectric.udstestapp, a UDS config/flash tool.
  Future<String> foregroundDiagApp() async =>
      demo ? 'Demo' : link!.adb('am start -n com.ola.mfgapp/.MainActivity');

  /// EXPERIMENTAL firmware OTA. Brick-capable. The scooter's expected checksum
  /// format is UNVERIFIED (assumed SHA-256 hex). Gated by `service: true`; the
  /// UI additionally requires Developer Mode + typed-CONFIRM. [target] is a
  /// component name (ALL/AOSP/BCM/BLE/BMS/HU/MCU).
  Future<void> otaFlash(
    List<int> bytes,
    String name,
    String target,
  ) => operation('Firmware OTA', () async {
    if (demo) {
      for (var p = 0.0; p <= 1.0; p += 0.2) {
        otaProgress = p;
        emit();
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
      otaState = 'SUCCESS (demo — nothing was written)';
      message = otaState;
      otaProgress = 0;
      return;
    }
    // Guards from the official app's flow: a known single target, and enough
    // battery that the pack cannot drop out mid-flash.
    const targets = {'AOSP', 'BCM', 'BLE', 'BMS', 'HU', 'MCU'};
    if (!targets.contains(target)) {
      throw StateError(
        'Choose one component (${targets.join(', ')}); "$target" is not allowed',
      );
    }
    final charge = (metrics['State of charge (%)'] as num?)?.toDouble();
    if (charge == null || charge <= 30) {
      throw StateError(
        'Battery must read above 30 % before flashing (now '
        '${charge == null ? 'unknown' : charge.toStringAsFixed(0)} %)',
      );
    }
    final csum = sha256.convert(bytes).toString();
    otaProgress = 0;
    otaState = 'Clearing cache';
    emit();
    await link!.swClearCache();
    otaState = 'Sending metadata';
    emit();
    await link!.swSendMeta(name, bytes.length, csum);
    otaState = 'Uploading';
    emit();
    await link!.swTransfer(
      bytes,
      onProgress: (sent) {
        otaProgress = sent / bytes.length;
        emit();
      },
    );
    otaProgress = 1;
    otaState = 'Triggering install';
    emit();
    await link!.swTrigger(target);
    otaState = await link!.swStatus();
    message =
        'OTA triggered · $otaState. Poll status; the scooter reboots during install.';
    otaProgress = 0;
  }, service: true);
  Future<void> loadInfo() => operation('Read identifiers', () async {
    manifest = demo
        ? jsonEncode({'demo': true, 'firmware': firmware})
        : await link!.identifiers();
    message = 'Identifiers received';
  });
  Future<void> test(int command, String label, bool start) =>
      operation(label, () async {
        if (!demo) requireLegacyMethod('Head-unit self-test');
        if (!demo && start) {
          // Best-effort: bring the diagnostic app to the front so the test is
          // visible on the head unit (self-tests are no-ops without it).
          try {
            await foregroundDiagApp();
          } catch (_) {
            /* foregrounding is optional — continue with the test */
          }
        }
        message = demo
            ? 'Demo: $label ${start ? 'start' : 'stop'}'
            : await link!.remoteTest(command, start);
      }, service: true);
  bool toolActive(Tool tool) =>
      tool == Tool.live && live ||
      tool == Tool.charging && recording ||
      tool == Tool.actuators && latched.isNotEmpty;
  Future<void> disconnect({bool keepWanted = false}) async {
    ++_generation;
    if (!keepWanted) {
      _wantConnected = false;
      unawaited(_setForegroundService(false));
    }
    _tick?.cancel();
    _keepAlive?.cancel();
    if (directAdbConnected) {
      try {
        if (!demo) await DirectAdb.disconnect();
      } catch (_) {
        // The socket may already have been lost with Wi-Fi; continue teardown.
      }
      directAdbConnected = false;
      directAdbStatus = 'Not connected';
      headUnitTransport = HeadUnitTransport.grpc;
    }
    if (enteredServiceMode && !demo && link != null) {
      // Leave the scooter the way an owner expects it: not in Service mode.
      try {
        await link!.setMode(false).timeout(const Duration(seconds: 3));
      } catch (error) {
        log('Return to Customer mode on disconnect: $error');
      }
    }
    enteredServiceMode = false;
    readCancelled = true;
    await session.stop();
    final old = link;
    link = null;
    final oldTcp = s1xTcpMonitor;
    s1xTcpMonitor = null;
    if (!demo && old != null && latched.isNotEmpty) {
      try {
        final u = Uds(old);
        for (final a in latched.values) {
          await u.io(a.did, false);
          await u.io(a.did, false, release: true);
        }
      } catch (error) {
        log('Release failed: $error');
        message =
            'Some latched controls could not be released. Check the scooter.';
      }
    }
    await old?.close();
    await oldTcp?.close();
    uds = null;
    unlocked.clear();
    rejectedKeys.clear();
    latched.clear();
    connection = Connection.disconnected;
    busy = false;
    demo = false;
    bench = false;
    mode = 'Unknown';
    live = false;
    recording = false;
    raw.clear();
    frameTimes.clear();
    vcuVariantRecord = null;
    repairReadBytes.clear();
    repairReadErrors.clear();
    repairReadAt = null;
    mcuReplacementPreflight.clear();
    mcuReplacementPreflightAt = null;
    mcuReplacementVin = null;
    mcuReplacementSoftware = null;
    mcuReplacementSurvey.clear();
    mcuReplacementSurveyAt = null;
    mcuReplacementSurveyVin = null;
    mcuReplacementSurveySoftware = null;
    _decodedProfile = VehicleProfile.common;
    firmware = 'Unknown';
    aospVersion = '';
    moveOsBuild = '';
    manifest = '';
    readings.clear();
    faults.clear();
    faultScanErrors.clear();
    notifications.clear();
    _notificationCode = null;
    softwareResponses.clear();
    identifierResults.clear();
    battery = null;
    restrictionState = null;
    passcodeHealth = null;
    odometerKm = null;
    _firstFrameAt = null;
    _odometerFallbackTried = false;
    apkInstallProgress = 0;
    apkInstallStatus = '';
    clearGraph();
    broadcast.clear();
    lastFrame = null;
    emit();
  }

  @override
  void dispose() {
    disposed = true;
    _tick?.cancel();
    _keepAlive?.cancel();
    session.removeListener(emit);
    unawaited(session.stop());
    session.dispose();
    unawaited(link?.close() ?? Future<void>.value());
    super.dispose();
  }
}
