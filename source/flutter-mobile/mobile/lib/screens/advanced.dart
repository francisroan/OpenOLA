import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../bluetooth/ble_controller.dart';
import '../data/catalog.dart';
import '../data/vcu_variant.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/preferences.dart';
import '../design/glass.dart';
import '../design/dashboard.dart';
import '../protocol/can.dart';
import '../release_policy.dart';
import 'core.dart';
import 'live_signals.dart';
import 'recorder_page.dart';
import 'identifiers_page.dart';
import 'status_page.dart';
import 'battery_page.dart';
import 'head_unit_page.dart';
import 'mcu_replacement_workspace.dart';

// Charge-path enums, mirrored from the desktop GUI's ChargerInfoParser decode so
// the mobile "Live charge path" card reads identically.
const _chargerConnected = {0: 'None', 1: 'Fast', 2: 'Slow', 3: 'Boost'};
const _vehL1 = {
  0: 'SNA',
  1: 'Idle',
  2: 'Safe',
  3: 'Slow Charge',
  4: 'Fast Charge',
  5: 'Discharge',
  6: 'Boost Charge',
};
const _vehL2 = {
  0: 'SNA',
  1: 'OFF',
  2: 'VACATION',
  3: 'SLEEP',
  4: 'VEHICLE IDLE',
  5: 'SC_CHARGE IDLE',
  6: 'SC_CHARGE FAULT',
  7: 'SC_CHARGE ACTIVE',
  8: 'FC_CHARGE IDLE',
  9: 'FC_CHARGE FAULT',
  10: 'FC_CHARGE ACTIVE',
  11: 'PARK',
  12: 'DRIVE',
  13: 'ALARM',
};
const _chgMode = {
  0: 'Disabled',
  1: 'CC',
  2: 'CV',
  3: 'Complete',
  4: 'CC End',
  5: 'CV End',
  6: 'Balancing',
  7: 'Standby',
};
const _chgRate = {
  0: 'SC_C_RATE_01',
  1: 'SC_C_RATE_02',
  2: 'SC_C_RATE_03',
  3: 'FC_C_RATE_01',
  4: 'FC_C_RATE_02',
  5: 'FC_C_RATE_03',
};

/// Full "Live charge path" rows for the Charging page — the vehicle-CAN charge
/// mirror ported from the desktop GUI. Enum/BMS-limit/C-rate fields come from
/// DBC signals (via profileValue), while charger type, billing (0x213 b6.2) and
/// EVSE id (0x584/0x585) are decoded from raw bytes, matching the firmware map.
List<(String, String, String)> livechargeRows(Diagnostics d) {
  String en(double? v, Map<int, String> t) =>
      v == null ? '—' : (t[v.toInt()] ?? '?${v.toInt()}');
  final r62d = d.raw[0x62d];
  final type = r62d == null ? '—' : (_chargerConnected[r62d[0] & 3] ?? '—');
  final r213 = d.raw[0x213];
  final billing = (r213 == null || r213.length < 7)
      ? '—'
      : ((r213[6] & 0x04) != 0 ? 'YES (paid)' : 'no');
  final lo = d.raw[0x584], hi = d.raw[0x585];
  String hex(List<int> b) =>
      b.map((x) => x.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  final evse = (lo == null && hi == null)
      ? '—'
      : [if (lo != null) hex(lo), if (hi != null) hex(hi)].join(':');
  final volts = d.metrics['Pack voltage (V)'];
  final amps = d.metrics['Pack current (A)'];
  final powerW = (volts != null && amps != null)
      ? volts * amps
      : d.telemetryValues['power_w'];
  return [
    ('SOC', number(d.metrics['State of charge (%)'], 1), '%'),
    ('Pack', number(volts), 'V'),
    ('Current', number(amps), 'A'),
    ('Power', number(powerW, 0), 'W'),
    ('Type', type, ''),
    ('Mode L1', en(d.profileValue(0x143, 'Vehicle_Mode_Level_1'), _vehL1), ''),
    ('Mode L2', en(d.profileValue(0x143, 'Vehicle_Mode_Level_2'), _vehL2), ''),
    ('CC / CV', en(d.profileValue(0x130, 'Charging_Mode_00'), _chgMode), ''),
    (
      'BMS I lim',
      number(d.profileValue(0x121, 'Overall_Charge_current_limit'), 1),
      'A',
    ),
    (
      'BMS V lim',
      number(d.profileValue(0x120, 'Overall_Charge_Voltage_limit'), 2),
      'V',
    ),
    (
      'Chg avail',
      number(d.profileValue(0x213, 'Charging_Current_Available_range'), 1),
      'A',
    ),
    ('C-rate', en(d.profileValue(0x180, 'Charging_Rate'), _chgRate), ''),
    ('Billing', billing, ''),
    ('EVSE id', evse, ''),
  ];
}

class AdvancedPage extends StatefulWidget {
  const AdvancedPage({
    super.key,
    required this.tool,
    required this.d,
    this.ble,
  });
  final Tool tool;
  final Diagnostics d;
  final ScooterBle? ble;
  @override
  State<AdvancedPage> createState() => _AdvancedPageState();
}

class _AdvancedPageState extends State<AdvancedPage> {
  final search = TextEditingController();
  final repairVin = TextEditingController();
  final repairOdometer = TextEditingController();
  final repairBatteryId = TextEditingController();
  final repairGrade = TextEditingController();
  String repairStatus = '';
  int limit = 40;
  String group = 'All';
  int? runningTest;
  String runningLabel = '';
  String? _otaFile;
  List<int>? _otaBytes;
  String _otaTarget = 'ALL';
  @override
  void didUpdateWidget(AdvancedPage old) {
    super.didUpdateWidget(old);
    if (old.tool != widget.tool) {
      search.clear();
      limit = 40;
      group = 'All';
    }
  }

  @override
  void dispose() {
    search.dispose();
    repairVin.dispose();
    repairOdometer.dispose();
    repairBatteryId.dispose();
    repairGrade.dispose();
    super.dispose();
  }

  bool match(String value) =>
      value.toLowerCase().contains(search.text.toLowerCase());
  Widget filter() => GlassField(
    controller: search,
    onChanged: (_) => setState(() => limit = 40),
    label: 'Search',
    suffix: IconButton(
      tooltip: 'Apply search',
      onPressed: () => setState(() => limit = 40),
      icon: const Icon(CupertinoIcons.search),
    ),
  );
  @override
  Widget build(BuildContext context) {
    if (widget.tool == Tool.recorder) return RecorderPage(d: widget.d);
    if (widget.tool == Tool.status) return StatusPage(d: widget.d);
    if (widget.tool == Tool.software) return SoftwarePage(d: widget.d);
    if (widget.tool == Tool.headUnit) return HeadUnitPage(d: widget.d);
    if (widget.tool == Tool.components || widget.tool == Tool.firmware) {
      return IdentifiersPage(
        d: widget.d,
        kind: widget.tool == Tool.components
            ? IdentifierWorkspace.components
            : IdentifierWorkspace.firmware,
      );
    }
    if (!widget.d.connected) return ConnectPage(d: widget.d);
    if (widget.tool == Tool.parameters &&
        Catalog.isS1xModel(widget.d.identity.modelCode)) {
      return _s1xParameterMap();
    }
    if (!widget.d.legacyMethodsAvailable &&
        const [
          Tool.actuators,
          Tool.parameters,
          Tool.features,
          Tool.componentTests,
          Tool.engineering,
        ].contains(widget.tool)) {
      return _unverifiedProfile();
    }
    return switch (widget.tool) {
      Tool.live => _live(),
      Tool.charging => _charging(),
      Tool.actuators => _actuators(),
      Tool.parameters => _parameters(),
      Tool.performance => _performance(),
      Tool.controls => _controls(),
      Tool.features => _features(),
      Tool.componentTests => _componentTests(),
      Tool.engineering => _engineering(),
      _ => FaultsPage(d: widget.d),
    };
  }

  Widget _live() =>
      CustomScrollView(slivers: [LiveSignalsSlivers(d: widget.d)]);

  Widget _unverifiedProfile() {
    final d = widget.d;
    final (title, detail) = switch (widget.tool) {
      Tool.actuators => (
        'Actuator tests',
        'Active test commands need a controller map for this model.',
      ),
      Tool.parameters => (
        'Parameters',
        'Parameter addresses and limits have not been verified for this model.',
      ),
      Tool.features => (
        'Vehicle features',
        'Feature settings and their stored values have not been verified for this model.',
      ),
      Tool.componentTests => (
        'Component tests',
        'Controller routines have not been verified for this model.',
      ),
      _ => (
        'Engineering tools',
        'The controller methods have not been verified for this model.',
      ),
    };
    final hardware = d.identity.hardware;
    return PageStack([
      Heading(title, detail),
      Section(
        'Scooter identity',
        children: [
          Text(d.identity.model),
          Text('Model code: ${d.identity.modelCode ?? 'unavailable'}'),
          Text('Profile: ${d.identity.profileLabel}'),
          Text(
            'Controller hardware: ${hardware.isEmpty ? 'unavailable' : hardware.join(', ')}',
          ),
          Text(
            'MoveOS build: ${d.moveOsBuild.isEmpty ? 'unavailable' : d.moveOsBuild}',
          ),
          Text(
            'Android: ${d.aospVersion.isEmpty ? 'unavailable' : d.aospVersion}',
          ),
          Text(d.identity.reason),
        ],
      ),
      Section(
        'Read-only checks',
        children: [
          const Text(
            'Vehicle status, Components, Software and Reports can collect data without running the older service commands.',
          ),
          GlassButton(
            'Read head-unit identifiers',
            icon: CupertinoIcons.doc_text,
            onPressed: d.busy ? null : () => d.readSoftware('Identifiers'),
          ),
          if (d.softwareResponses['Identifiers'] case final identifiers?)
            Text(identifiers),
        ],
      ),
    ]);
  }

  Widget _charging() {
    final d = widget.d;
    final connected = d.raw[0x62d];
    final type = connected == null
        ? 'Unknown'
        : ['None', 'Fast', 'Slow', 'Boost'][connected[0] & 3];
    return PageStack([
      const Heading(
        'Charging',
        'Received charger state and a local session record.',
      ),
      Section(
        'Charger snapshot',
        icon: CupertinoIcons.bolt,
        children: [
          Text('Charger: ${d.demo ? 'Demo · unknown' : type}'),
          Text('Pack current: ${number(d.metrics['Pack current (A)'])} A'),
          Text('Pack voltage: ${number(d.metrics['Pack voltage (V)'])} V'),
          Text(
            d.freshness,
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
        ],
      ),
      Section(
        'Live charge path',
        icon: CupertinoIcons.bolt,
        children: [
          MetricGrid(livechargeRows(d)),
          Text(
            'Vehicle-CAN charge mirror. Start the monitor to populate. '
            'Billing = 0x213 b6.2 (paid-session flag); a home/slow charger leaves '
            'it clear. Received CAN state, not a confirmation of payment or '
            'permission to charge.',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
          GlassButton(
            d.live ? 'Pause monitor' : 'Start monitor',
            onPressed: d.busy ? null : () => d.liveMode(!d.live),
          ),
        ],
      ),
      Section(
        'Session recording',
        children: [
          Text(
            'Use Recorder in the left menu for the full signal log, plots, JSONL and CSV.',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
          GlassButton(
            d.session.active ? 'Stop & save session' : 'Record charge session',
            onPressed: d.busy || d.session.closing
                ? null
                : () async {
                    if (d.session.active) {
                      await d.stopSession();
                    } else {
                      await d.startSession();
                    }
                  },
          ),
        ],
      ),
      GlassButton(
        'Stop charge',
        destructive: true,
        onPressed: d.busy
            ? null
            : () async {
                if (await confirmGlass(
                  context,
                  'Stop charging?',
                  'Sends the existing HMI stop-charge command. Verify the charging state on the scooter.',
                )) {
                  await d.hmi(13, 'Stop charge');
                }
              },
      ),
    ]);
  }

  Widget _actuators() {
    final d = widget.d;
    final groups = d.catalog.actuators.map((a) => a.group).toSet();
    final rows = d.catalog.actuators
        .where((a) => (group == 'All' || a.group == group) && match(a.label))
        .toList();
    return PageStack([
      const Heading(
        'Actuator tests',
        'Park the scooter and disconnect the charger. Active controls use the existing service protocol.',
      ),
      filter(),
      GlassButton(
        'Category: $group',
        icon: CupertinoIcons.chevron_down,
        onPressed: () async {
          final value = await glassSheet<String>(
            context,
            PageStack([
              for (final g in ['All', ...groups])
                GlassButton(g, onPressed: () => Navigator.pop(context, g)),
            ]),
          );
          if (value != null && mounted) {
            setState(() {
              group = value;
              limit = 40;
            });
          }
        },
      ),
      for (final a in rows.take(limit))
        Section(
          a.label,
          children: [
            Text(
              '${a.group} · DID ${a.did.toRadixString(16).toUpperCase()}${a.danger ? ' · review required' : ''}',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
            GlassButton(
              'Pulse test',
              onPressed: d.busy || !d.legacyMethodsAvailable
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Test ${a.label}?',
                        'Runs this actuator briefly, then sends OFF and returns control to the ECU. Keep the scooter parked.',
                      )) {
                        await d.actuator(a);
                      }
                    },
            ),
            if (a.label.toLowerCase() != 'horn')
              GlassButton(
                d.latched.containsKey(a.did)
                    ? 'Turn OFF and release'
                    : 'Latch ON',
                destructive: a.danger,
                onPressed: d.busy || !d.legacyMethodsAvailable
                    ? null
                    : () async {
                        final on = !d.latched.containsKey(a.did);
                        if (!on ||
                            await confirmGlass(
                              context,
                              'Latch ${a.label} ON?',
                              'This control remains ON until you switch it off. Check the scooter before confirming.',
                            )) {
                          await d.actuator(a, latch: on);
                        }
                      },
              ),
          ],
        ),
      if (rows.length > limit)
        GlassButton(
          'Show more controls',
          onPressed: () => setState(() => limit += 40),
        ),
    ]);
  }

  Widget _parameters() {
    final rows = widget.d.catalog.parameters
        .where(
          (p) => match('${p.name} ${p.ecu.label} ${p.did.toRadixString(16)}'),
        )
        .toList();
    return PageStack([
      const Heading(
        'Parameters',
        'Documented ranges describe encoding limits. They are not verified safe calibration limits.',
      ),
      filter(),
      for (final p in rows.take(limit))
        Section(
          p.name,
          children: [
            Text(
              '${p.ecu.label} · DID ${p.did.toRadixString(16).toUpperCase()} · ${p.length} bytes',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
            GlassButton(
              'Read and inspect',
              onPressed: widget.d.busy || !widget.d.legacyMethodsAvailable
                  ? null
                  : () => glassSheet(context, _ParameterEditor(p, widget.d)),
            ),
          ],
        ),
      if (rows.length > limit)
        GlassButton(
          'Show 40 more (${rows.length} total)',
          onPressed: () => setState(() => limit += 40),
        ),
    ]);
  }

  // Icon-based quick controls for the common actuators (lights, horn, locks).
  // Each maps to an ODX IO-control actuator by label; horn pulses, the rest
  // latch on/off. Service mode is prompted on tap rather than disabling.
  Widget _controls() {
    final d = widget.d;
    Actuator? find(List<String> keys) {
      for (final a in d.catalog.actuators) {
        final n = a.label.toLowerCase();
        if (keys.every(n.contains)) return a;
      }
      return null;
    }

    final items = <(String, IconData, Actuator?, bool)>[
      ('Horn', CupertinoIcons.speaker_3_fill, find(['horn']), true),
      ('Low beam', CupertinoIcons.lightbulb, find(['low', 'beam']), false),
      (
        'High beam',
        CupertinoIcons.lightbulb_fill,
        find(['high', 'beam']),
        false,
      ),
      ('DRL', CupertinoIcons.sun_min, find(['drl']), false),
      (
        'Left indicator',
        CupertinoIcons.arrow_turn_up_left,
        find(['left', 'indicator']),
        false,
      ),
      (
        'Right indicator',
        CupertinoIcons.arrow_turn_up_right,
        find(['right', 'indicator']),
        false,
      ),
      ('Brake light', CupertinoIcons.car_detailed, find(['brake']), false),
      ('Seat / boot', CupertinoIcons.lock_open, find(['seat', 'lock']), false),
    ];
    return PageStack([
      const Heading(
        'Vehicle controls',
        'Tap a control to pulse or latch it. Keep the scooter parked and the '
            'charger unplugged — these drive real lights, horn and locks.',
      ),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final i in items) _controlTile(i.$1, i.$2, i.$3, i.$4)],
      ),
      const SizedBox(height: 10),
      Text(
        'Controls shown dim when the loaded ODX has no matching actuator for '
        'your model. The full list is under Actuator tests.',
        style: TextStyle(color: muted(context), fontSize: 11, height: 1.4),
      ),
    ]);
  }

  Widget _controlTile(String name, IconData icon, Actuator? a, bool pulse) {
    final d = widget.d;
    final on = a != null && d.latched.containsKey(a.did);
    final tint = a == null
        ? muted(context)
        : on
        ? accent
        : purple;
    return GestureDetector(
      onTap: a == null || d.busy ? null : () => _runControl(a, pulse, on),
      child: Opacity(
        opacity: a == null ? 0.4 : 1,
        child: Container(
          width: 104,
          height: 96,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (on ? accent : muted(context)).withValues(
              alpha: on ? .16 : .07,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: on ? accent : separator(context),
              width: on ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: tint, size: 26),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: 11.5, height: 1.1),
              ),
              if (on)
                const Text(
                  'ON',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runControl(Actuator a, bool pulse, bool on) async {
    final d = widget.d;
    if (!await requireServiceMode(context, d)) return;
    if (!mounted) return;
    if (pulse) {
      if (await confirmGlass(
        context,
        'Test ${a.label}?',
        'Pulses this control briefly, then returns control to the ECU. Keep the '
            'scooter parked.',
      )) {
        await d.actuator(a);
      }
    } else {
      final turnOn = !on;
      if (!turnOn ||
          await confirmGlass(
            context,
            'Turn ${a.label} ON?',
            'Stays ON until you turn it off here. Check the scooter before '
                'confirming.',
          )) {
        await d.actuator(a, latch: turnOn);
      }
    }
    if (mounted) setState(() {});
  }

  Widget _componentTests() {
    final d = widget.d;
    final currentRecord = d.vcuVariantRecord;
    final standardRecord =
        currentRecord != null && VcuVariantRecord.isStandard(currentRecord);
    final variantLabel = currentRecord == null
        ? null
        : VcuVariantRecord.describe(currentRecord);
    final restoreDisabledReason = !vcuVariantWritesAvailable
        ? 'Variant writes are unavailable in this build.'
        : currentRecord == null
        ? 'Read the VCU variant record first.'
        : !standardRecord
        ? 'The record is not the exact official S1 Pro non-upgrade template; no write is allowed.'
        : d.busy
        ? 'Another diagnostic operation is running.'
        : !d.demo && !d.prefs.developerMode
        ? 'Enter Developer Mode first.'
        : !d.demo && !d.legacyMethodsAvailable
        ? 'The connected scooter does not have the verified legacy diagnostic profile.'
        : !d.demo && d.mode != 'SERVICE'
        ? 'Enter Service mode first.'
        : !d.demo && !d.parkedFresh
        ? 'Confirm a fresh Park state first.'
        : !d.demo && !d.chargerDisconnectedFresh
        ? 'Disconnect the charger and wait for a fresh charger-state reading before writing the VCU record.'
        : null;
    return PageStack([
      const Heading(
        'Component tests',
        'Switch the trunk, lights, indicators and horn on briefly to check them.',
      ),
      Section(
        'Gen1 VCU variant record',
        icon: CupertinoIcons.square_stack_3d_up,
        children: [
          const Text(
            'For a replacement VCU: read its complete 37-byte record first. '
            'The S1 Pro restoration action is available only when the record '
            'exactly matches the official S1 Pro non-upgrade template. This '
            'local write does not update the cloud variant or owner profile. '
            'Writing also requires Developer Mode.',
          ),
          GlassButton(
            'Read VCU variant record',
            onPressed: d.busy
                ? null
                : () async {
                    await d.readVcuVariantRecord();
                    if (mounted) setState(() {});
                  },
          ),
          if (currentRecord != null) ...[
            Text(variantLabel!),
            SelectableText(hex(currentRecord)),
          ],
          if (vcuVariantWritesAvailable)
            GlassButton(
              'Restore S1 Pro with upgrade',
              destructive: true,
              disabledReason: restoreDisabledReason,
              onPressed:
                  !standardRecord ||
                      d.busy ||
                      (!d.demo &&
                          (!d.prefs.developerMode ||
                              !d.legacyMethodsAvailable ||
                              d.mode != 'SERVICE' ||
                              !d.parkedFresh ||
                              !d.chargerDisconnectedFresh))
                  ? null
                  : () async {
                      final ok = await confirmTyped(
                        context,
                        title: 'Write complete VCU variant record?',
                        message:
                            'This writes the official 37-byte Gen1 S1 Pro '
                            'with upgrade record to this VCU. The app will '
                            're-read the existing record and stop if it changed '
                            'or is not the exact S1 Pro template. Park the '
                            'scooter, unplug the charger, and type CONFIRM.',
                      );
                      if (!ok) return;
                      await d.restoreS1ProUpgrade();
                      if (mounted) setState(() {});
                    },
            ),
          if (d.message.contains('VCU variant') ||
              d.message.contains('S1 Pro upgrade') ||
              d.message.contains('VCU returned'))
            Text(d.message),
        ],
      ),
      Section(
        'Component tests',
        icon: CupertinoIcons.lightbulb,
        children: [
          Text(
            'Trunk, lights and horn — the same VCU actuator tests as the '
            'classic console: each runs briefly, then switches off and returns '
            'control to the scooter. Park it and unplug the charger first. '
            'Needs Service mode.',
            style: TextStyle(
              color: muted(context),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in const [
                ('Trunk', 'Seat Lock', CupertinoIcons.lock_open_fill, purple),
                ('Horn', 'Horn', CupertinoIcons.bell_fill, orange),
                (
                  'Low beam',
                  'Front light low beam',
                  CupertinoIcons.light_min,
                  accent,
                ),
                (
                  'High beam',
                  'Front light high beam',
                  CupertinoIcons.light_max,
                  accent,
                ),
                ('Front DRL', 'Front DRL', CupertinoIcons.sun_max_fill, orange),
                (
                  'Left indicator',
                  'Left Indicators',
                  CupertinoIcons.arrow_left_circle_fill,
                  green,
                ),
                (
                  'Right indicator',
                  'Right Indicators',
                  CupertinoIcons.arrow_right_circle_fill,
                  green,
                ),
                (
                  'Brake light',
                  'Rear Brake light',
                  CupertinoIcons.stop_circle_fill,
                  danger,
                ),
                (
                  'Tail light',
                  'Rear Light POS',
                  CupertinoIcons.circle_fill,
                  danger,
                ),
              ])
                _componentTestTile(t.$1, t.$2, t.$3, t.$4),
            ],
          ),
        ],
      ),
      GlassButton(
        'Return to OLA HMI',
        icon: CupertinoIcons.house,
        onPressed: widget.d.busy ? null : widget.d.launchOlaHmi,
      ),
      Section(
        'Motor calibration',
        icon: CupertinoIcons.gear_alt,
        children: [
          Text(
            'Auto-tune after a motor replacement. The motor spins freely for '
            'up to about 95 seconds: put the scooter on its centre stand with '
            'the rear wheel clear of the ground and everyone away from it. '
            'Park, charger unplugged and Service mode are required. Cancel '
            'stops it at once.',
            style: TextStyle(
              color: muted(context),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          Row(
            children: [
              const Expanded(child: Text('On the centre stand, wheel clear')),
              CupertinoSwitch(
                value: _calStand,
                onChanged: (v) => setState(() => _calStand = v),
              ),
            ],
          ),
          GlassButton(
            'Start motor calibration',
            icon: CupertinoIcons.gear_alt,
            destructive: true,
            onPressed:
                !_calStand || widget.d.busy || !widget.d.legacyMethodsAvailable
                ? null
                : () async {
                    if (await confirmGlass(
                      context,
                      'Calibrate the motor?',
                      'The motor will spin freely. Scooter on the centre stand, '
                          'wheel clear, charger unplugged. Slide to start.',
                    )) {
                      await widget.d.motorCalibration();
                      if (mounted) setState(() {});
                    }
                  },
          ),
          if (widget.d.calibrationStatus.isNotEmpty)
            Text(
              widget.d.calibrationStatus,
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
        ],
      ),
      Section(
        'Lock sequence and module checks',
        icon: CupertinoIcons.lock_shield,
        children: [
          Text(
            'These are diagnostic self-checks. The BF07 routine does not '
            'provide a verified lock or unlock command, so it is not offered '
            'as a steering-lock control. Park, unplug the charger and use '
            'Service mode for the remaining checks.',
            style: TextStyle(
              color: muted(context),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in const [
                ('MCU peripherals', 0xBF01, CupertinoIcons.speedometer, accent),
                (
                  'SOM self-check',
                  0xBF02,
                  CupertinoIcons.device_phone_portrait,
                  accent,
                ),
                (
                  'Smart module UART TX',
                  0xBF03,
                  CupertinoIcons.arrow_up_right_circle,
                  teal,
                ),
                (
                  'Smart module UART RX',
                  0xBF04,
                  CupertinoIcons.arrow_down_left_circle,
                  teal,
                ),
                ('LIN (handlebar)', 0xBF05, CupertinoIcons.link, orange),
                ('Head-unit CAN', 0xBF06, CupertinoIcons.waveform_path, green),
              ])
                _testTile(
                  t.$1,
                  t.$3,
                  t.$4,
                  !widget.d.busy && widget.d.legacyMethodsAvailable,
                  () async {
                    if (await confirmGlass(
                      context,
                      'Run ${t.$1}?',
                      'Starts this VCU routine and reports its status. Keep '
                          'the scooter parked with the charger unplugged. '
                          'Slide to run.',
                    )) {
                      await widget.d.vcuRoutine(t.$2, t.$1);
                      if (mounted) setState(() {});
                    }
                  },
                ),
            ],
          ),
          if (widget.d.lastRoutineStatus != null)
            Text(
              widget.d.lastRoutineStatus!,
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
        ],
      ),
    ]);
  }

  Widget _testTile(
    String label,
    IconData icon,
    Color color,
    bool enabled,
    Future<void> Function() onRun,
  ) {
    return GestureDetector(
      onTap: enabled ? onRun : null,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Container(
          width: 104,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: muted(context).withValues(alpha: .07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: separator(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _componentTestTile(
    String label,
    String actuatorLabel,
    IconData icon,
    Color color,
  ) {
    final d = widget.d;
    final matches = d.catalog.actuators.where((a) => a.label == actuatorLabel);
    final actuator = matches.isEmpty ? null : matches.first;
    final enabled = actuator != null && !d.busy && d.legacyMethodsAvailable;
    return GestureDetector(
      onTap: !enabled
          ? null
          : () async {
              if (await confirmGlass(
                context,
                'Test $label?',
                'Runs the $label briefly, then switches it off and returns '
                    'control to the scooter. Keep the scooter parked with the '
                    'charger unplugged. Slide to run.',
              )) {
                await d.actuator(actuator);
                if (mounted) setState(() {});
              }
            },
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Container(
          width: 104,
          constraints: const BoxConstraints(minHeight: 88),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: muted(context).withValues(alpha: .07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: separator(context)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11.5, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selfTestTile(String label, int cmd, IconData icon) {
    final d = widget.d;
    final active = runningTest == cmd;
    return GestureDetector(
      onTap: d.busy
          ? null
          : () async {
              if (await confirmGlass(
                context,
                'Run $label test?',
                'Runs on the scooter\'s head unit (its diagnostic screen must be '
                    'open). Can interrupt the display, sound or connectivity. '
                    'Keep the scooter parked.',
              )) {
                await d.test(cmd, label, true);
                if (mounted) {
                  setState(() {
                    runningTest = cmd;
                    runningLabel = label;
                  });
                }
              }
            },
      child: Container(
        width: 104,
        height: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (active ? accent : muted(context)).withValues(
            alpha: active ? .16 : .07,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active ? accent : separator(context),
            width: active ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 26, color: active ? accent : purple),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(fontSize: 11.5, height: 1.1),
            ),
            if (active)
              const Text(
                'RUNNING',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Curated performance-limit parameters: MCU torque/speed/throttle/regen plus
  // the BMS discharge-current derate. All are UDS 0x2E config writes —
  // reversible, no firmware reflash — surfaced here with live guard rails and a
  // typed-CONFIRM write instead of being buried in the full Parameters list.
  static const _perfDids = {
    0xb110, 0xb103, 0xb112, 0xb111, 0xb10b, 0xb10d, // MCU
    0xe431, 0xe4bc, 0xe485, 0xe486, 0xe487, // BMS
  };

  static const _perfNames = {
    0xb110: 'Vehicle mode torque limit',
    0xb103: 'Torque setting',
    0xb112: 'Limp-home speed limit',
    0xb111: 'Acceleration time',
    0xb10b: 'Regen current limit',
    0xb10d: 'Throttle sampling limit',
    0xe431: 'BMS discharge-current derate',
    0xe4bc: 'Regen limit enable / disable',
    0xe485: 'Regen start (mV)',
    0xe486: 'Regen capacity (%)',
    0xe487: 'Regen stop (mV)',
  };

  Widget _performance() {
    final d = widget.d;
    final rows = d.catalog.parameters
        .where((p) => _perfDids.contains(p.did))
        .toList();
    final b = d.canBattery;
    return PageStack([
      const Heading(
        'Performance limits',
        'Factory speed, torque, power and regen caps. These are real controller '
            'limits — changing them reduces safety margins.',
      ),
      Glass(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: danger,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Raising these can overheat the battery or motor, reduce braking '
                'margin, void your warranty and be illegal on public roads. The '
                'BMS current derate (0xE431) and the MCU torque/speed caps must '
                'move together — raise one alone and the pack still clamps power '
                'or trips a fault. Only on a parked scooter, and watch the guard '
                'rails below.',
                style: TextStyle(
                  color: muted(context),
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
      Section(
        'Live guard rails',
        icon: CupertinoIcons.gauge,
        children: [
          MetricGrid([
            ('Pack current', number(d.metrics['Pack current (A)'], 1), 'A'),
            ('Pack temp', number(b?.healthValue('effective temp'), 1), '°C'),
            ('Cell spread', number(b?.spreadMv, 0), 'mV'),
          ]),
          Text(
            'Watch these while testing. Rising temperature, high sustained '
            'current, or a widening cell spread under load means back off.',
            style: TextStyle(color: muted(context), fontSize: 11, height: 1.4),
          ),
        ],
      ),
      if (!d.legacyMethodsAvailable)
        Section(
          'Writes unavailable here',
          children: [
            Text(
              'Reading and writing these needs a connected scooter in Service '
              'mode with a verified profile. You can still review the list.',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
          ],
        ),
      if (rows.isEmpty)
        const Section(
          'No parameters',
          children: [
            Text(
              'No performance parameters are present in this vehicle\'s loaded '
              'ODX.',
            ),
          ],
        )
      else
        for (final p in rows)
          Section(
            _perfNames[p.did] ?? p.name,
            children: [
              Text(
                '${p.ecu.label} · DID ${p.did.toRadixString(16).toUpperCase()} · '
                '${p.length} bytes',
                style: TextStyle(color: muted(context), fontSize: 12),
              ),
              GlassButton(
                'Read & edit',
                destructive: true,
                onPressed: d.busy || !d.legacyMethodsAvailable
                    ? null
                    : () => glassSheet(
                        context,
                        _ParameterEditor(p, d, typedConfirm: true),
                      ),
              ),
            ],
          ),
    ]);
  }

  Widget _s1xParameterMap() {
    final d = widget.d;
    final code = d.identity.modelCode;
    final phase = Catalog.s1xPhaseForModel(code);
    final rows = d.catalog
        .s1xParametersForModel(code)
        .where(
          (row) => match(
            '${row.name} ${row.ecu} ${row.source} ${row.dbcName ?? ''} ${row.canId ?? ''}',
          ),
        )
        .toList();
    return SingleChildScrollView(
      child: PageStack([
        Heading(
          'S1X parameter reference',
          phase == null
              ? 'Showing entries common to both imported phase maps. This model code does not establish a phase.'
              : 'Imported Phase $phase map for ${d.identity.model}. Map entries are references; they do not establish live availability.',
        ),
        const Section(
          'Read-only mapping',
          children: [
            Text(
              'CAN values appear only when the active decoder already reports the exact CAN ID and DBC signal. UDS entries are not requested: these map rows do not provide an explicit request identifier.',
            ),
            Text(
              'Documented ranges are encoding metadata, not verified safe repair or calibration limits.',
            ),
          ],
        ),
        filter(),
        for (final row in rows.take(limit))
          Section(
            row.name.isEmpty ? 'Unnamed parameter' : row.name,
            children: [
              Text(
                '${row.ecu} · ${row.source} · ${row.dbcName ?? 'no DBC name'}',
              ),
              if (row.hasCanMapping)
                Builder(
                  builder: (context) {
                    final reading = d.readings['${row.canId}:${row.dbcName}'];
                    return Text(
                      reading == null
                          ? 'Not available in the active decoder or not received yet'
                          : 'Current decoded value: ${number(reading.value)} ${row.unit}'
                                .trim(),
                      style: TextStyle(color: muted(context), fontSize: 12),
                    );
                  },
                )
              else
                Text(
                  'Reference only · no UDS read attempted',
                  style: TextStyle(color: muted(context), fontSize: 12),
                ),
              if (row.canId != null)
                Text('CAN ID 0x${row.canId!.toRadixString(16).toUpperCase()}'),
              if (row.minimum != null || row.maximum != null)
                Text(
                  'Documented range: ${row.minimum ?? '—'} to ${row.maximum ?? '—'} ${row.unit}'
                      .trim(),
                ),
            ],
          ),
        if (rows.length > limit)
          GlassButton(
            'Show 40 more (${rows.length} total)',
            onPressed: () => setState(() => limit += 40),
          ),
      ]),
    );
  }

  // label, enable ordinal, disable ordinal, icon, accent colour, one-line help
  static const _featureList = <(String, int, int, IconData, Color, String)>[
    (
      'Boost mode',
      48,
      49,
      CupertinoIcons.bolt_fill,
      orange,
      'Extra power on demand',
    ),
    (
      'Hill hold',
      66,
      67,
      CupertinoIcons.arrow_up_circle_fill,
      accent,
      'Hold still on inclines',
    ),
    (
      'Vacation mode',
      68,
      69,
      CupertinoIcons.moon_stars_fill,
      purple,
      'Low-drain long storage',
    ),
    (
      'Proximity lock',
      54,
      55,
      CupertinoIcons.lock_shield_fill,
      teal,
      'Auto-lock when you step away',
    ),
    (
      'Motor cutoff delay',
      64,
      65,
      CupertinoIcons.time,
      accent,
      'Delay the motor cutoff',
    ),
    (
      'Park assist',
      103,
      104,
      CupertinoIcons.car_fill,
      green,
      'Low-speed park manoeuvring',
    ),
    (
      'Accident detection',
      50,
      51,
      CupertinoIcons.exclamationmark_triangle_fill,
      danger,
      'Crash alerting',
    ),
    (
      'Tow / tamper alert',
      52,
      53,
      CupertinoIcons.shield_lefthalf_fill,
      orange,
      'Movement alerts when parked',
    ),
    (
      'Smart DRL',
      56,
      57,
      CupertinoIcons.lightbulb_fill,
      green,
      'Daytime running lights',
    ),
    (
      'Hazard lights',
      74,
      75,
      CupertinoIcons.exclamationmark_octagon_fill,
      danger,
      'Turns the hazard blinkers on or off',
    ),
  ];

  Widget _features() {
    final busy = widget.d.busy || !widget.d.legacyMethodsAvailable;
    if (!_featuresRequested) {
      _featuresRequested = true;
      Future<void>.microtask(widget.d.readProfileFeatures);
    }
    return PageStack([
      const Heading(
        'Vehicle features',
        'Stored settings are read from the active HMI profile. A CAN command '
            'does not save that profile, so the HMI may restore its previous '
            'setting. Use the scooter screen to make a lasting change.',
      ),
      Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _featureList.length; i++) ...[
              if (i > 0) Divider(color: separator(context), height: 22),
              _featureRow(_featureList[i], busy),
            ],
          ],
        ),
      ),
      Section(
        'Regeneration',
        icon: CupertinoIcons.arrow_2_circlepath,
        children: [
          Text(
            'The CAN commands below only notify the HMI. They do not change '
            'the MCU regeneration setting, so this app does not offer them '
            'as profile controls.',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
        ],
      ),
    ]);
  }

  // Maps a feature row to its 0x660 state key (featureStatus names). Features
  // with no readable broadcast state are omitted → shown as unknown (neither
  // button highlighted).
  static const _featureStateKeys = {
    'Boost mode': 'Boost mode',
    'Hill hold': 'Hill hold',
    'Vacation mode': 'Vacation mode',
    'Proximity lock': 'Proximity lock',
    'Motor cutoff delay': 'Motor cutoff delay?',
    'Accident detection': 'Fall detection',
    'Tow / tamper alert': 'Tow/tamper detect',
    'Smart DRL': 'Smart DRL',
  };

  bool _featuresRequested = false;
  bool _calStand = false;

  /// Rows the scooter does not report a state for keep the last command sent.
  final _lastCommanded = <String, bool>{};

  Future<void> _toggleFeature(
    (String, int, int, IconData, Color, String) f,
    bool value,
  ) async {
    final sent = await _feature(
      value ? f.$2 : f.$3,
      '${f.$1} ${value ? 'enable' : 'disable'}',
    );
    if (!sent || !mounted) return;
    setState(() {
      if (!_featureStateKeys.containsKey(f.$1)) {
        _lastCommanded[f.$1] = value;
      }
    });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) widget.d.readProfileFeatures();
    });
  }

  Widget _featureRow((String, int, int, IconData, Color, String) f, bool busy) {
    final dbState = widget.d.profileFeatures[f.$1];
    final key = _featureStateKeys.containsKey(f.$1) ? f.$1 : null;
    final int? state = dbState == null ? null : (dbState ? 1 : 0);
    return Row(
      children: [
        IconTile(f.$4, f.$5, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.$1,
                style: TextStyle(
                  color: ink(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${f.$6} · ${key == null
                    ? 'switch shows the last command sent'
                    : state == null
                    ? 'reading HMI setting…'
                    : state == 0
                    ? 'HMI setting: off'
                    : 'HMI setting: on'}',
                style: TextStyle(
                  color: muted(context),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        CupertinoSwitch(
          key: ValueKey('feature-${f.$1}'),
          value: key != null ? (state == 1) : (_lastCommanded[f.$1] ?? false),
          onChanged: busy ? null : (value) => _toggleFeature(f, value),
        ),
      ],
    );
  }

  Future<bool> _feature(int ordinal, String label) async {
    if (await confirmGlass(
      context,
      'Change $label?',
      'Sends the existing feature command. Check availability and outcome on the scooter; no automatic retry. Slide to send.',
    )) {
      await widget.d.hmi(ordinal, label);
      return true;
    }
    return false;
  }

  Future<void> _submitRepair(
    String title,
    Future<void> Function() write,
  ) async {
    if (!await confirmTyped(
      context,
      title: '$title?',
      message:
          'This changes the scooter’s stored identity or battery data. '
          'Use only the value documented for the fitted replacement part and '
          'actual vehicle history. The app rereads the ECU before writing and '
          'checks readback. Type CONFIRM to continue.',
    )) {
      return;
    }
    try {
      await write();
      if (mounted) setState(() => repairStatus = widget.d.message);
    } catch (error) {
      if (mounted) setState(() => repairStatus = '$error');
    }
  }

  Widget _engineering() {
    final d = widget.d;
    final repairReady =
        !d.busy &&
        d.legacyMethodsAvailable &&
        d.mode == 'SERVICE' &&
        d.parkedFresh &&
        d.chargerDisconnectedFresh &&
        d.repairReadAt != null;
    const tests = <(String, int, IconData)>[
      ('LCD', 1, CupertinoIcons.device_phone_portrait),
      ('GPS', 2, CupertinoIcons.location_solid),
      ('Wi-Fi', 5, CupertinoIcons.wifi),
      ('Speaker', 6, CupertinoIcons.speaker_2_fill),
      ('Microphone', 7, CupertinoIcons.mic_fill),
      ('eSIM', 12, CupertinoIcons.antenna_radiowaves_left_right),
    ];
    return PageStack([
      const Heading(
        'Engineering tools',
        'Identifiers, existing self-tests and received fault transitions.',
      ),
      Section(
        'Vehicle identifiers',
        children: [
          GlassButton(
            'Read identifiers',
            onPressed: d.busy ? null : d.loadInfo,
          ),
          Text('Firmware: ${d.firmware}'),
          if (d.manifest.isNotEmpty)
            SelectableText(d.manifest, style: const TextStyle(fontSize: 12)),
        ],
      ),
      McuReplacementWorkspace(d: d),
      if (identityWritesAvailable)
        Section(
          'Replacement identity writes · Gen1',
          icon: CupertinoIcons.wrench,
          children: [
            const Text(
              'Read a fresh snapshot first. VIN comes from the vehicle record, '
              'odometer from documented actual mileage, battery ID from the '
              'fitted pack QR, and grade 01/02 from its service record. The '
              'app cannot establish those source values for you. Each write '
              'requires Service mode, Park, charger unplugged and typed CONFIRM.',
            ),
            GlassButton(
              'Read replacement snapshot',
              onPressed: d.busy
                  ? null
                  : () async {
                      await d.readRepairSnapshot();
                      if (mounted) setState(() => repairStatus = d.message);
                    },
            ),
            for (final entry in d.repairReadBytes.entries)
              SelectableText('${entry.key}: ${hex(entry.value)}'),
            for (final entry in d.repairReadErrors.entries)
              Text('${entry.key}: ${entry.value}'),
            GlassField(
              controller: repairVin,
              label: 'Documented 17-character VIN',
            ),
            GlassButton(
              'Write replacement VIN',
              destructive: true,
              onPressed: repairReady
                  ? () => _submitRepair(
                      'Write VIN',
                      () => d.writeReplacementVin(repairVin.text),
                    )
                  : null,
            ),
            GlassField(
              controller: repairOdometer,
              label: 'Documented actual odometer (km)',
              keyboard: TextInputType.number,
            ),
            GlassButton(
              'Write replacement odometer',
              destructive: true,
              onPressed: repairReady
                  ? () => _submitRepair('Write odometer', () {
                      final km = int.tryParse(repairOdometer.text.trim());
                      if (km == null) {
                        throw const FormatException('Enter whole kilometres');
                      }
                      return d.writeReplacementOdometer(km);
                    })
                  : null,
            ),
            GlassField(
              controller: repairBatteryId,
              label: 'Fitted battery pack ID',
            ),
            GlassButton(
              'Write replacement battery ID',
              destructive: true,
              onPressed: repairReady
                  ? () => _submitRepair(
                      'Write battery ID',
                      () => d.writeReplacementBatteryId(repairBatteryId.text),
                    )
                  : null,
            ),
            GlassField(
              controller: repairGrade,
              label: 'Verified pack grade (01 or 02)',
              keyboard: TextInputType.number,
            ),
            GlassButton(
              'Write verified battery grade',
              destructive: true,
              onPressed: repairReady
                  ? () => _submitRepair('Write battery grade', () {
                      final grade = int.tryParse(repairGrade.text.trim());
                      if (grade == null) {
                        throw const FormatException('Enter grade 01 or 02');
                      }
                      return d.writeReplacementBatteryGrade(
                        grade,
                        repairBatteryId.text,
                      );
                    })
                  : null,
            ),
            if (repairStatus.isNotEmpty) Text(repairStatus),
          ],
        ),
      Section(
        'Diagnostic identity',
        icon: CupertinoIcons.checkmark_shield,
        children: [
          Text(
            'Read-only check of the scooter\'s diagnostic certificate status. '
            'Generating or reinstalling certs can break the scooter\'s trust, so '
            'those are not exposed here.',
            style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
          ),
          GlassButton(
            'Validate identity',
            onPressed: d.busy || !d.connected ? null : d.validateCerts,
          ),
          if (d.certStatus.isNotEmpty)
            Text(
              d.certStatus,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
        ],
      ),
      Section(
        'TechPack / drive-mode entitlement',
        icon: CupertinoIcons.lock_shield,
        children: [
          Text(
            'Reads the daemon ECOS/Dyno state, profile restrictions, shared-preference keys and raw 0x660/0x6D0/0x113 evidence. A successful parental-control update is not paid-entitlement proof.',
            style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
          ),
          GlassButton(
            'Read TechPack evidence',
            onPressed: d.busy || !d.connected ? null : d.readTechPackEvidence,
          ),
          if (d.techPackFlags != null) ...[
            SelectableText('ECOS1: ${d.techPackFlags!.ecos1}'),
            SelectableText('ECOS2: ${d.techPackFlags!.ecos2}'),
            SelectableText('Dyno: ${d.techPackFlags!.dyno}'),
          ],
          if (d.techPackEvidence.isNotEmpty)
            ExpansionTile(
              title: const Text('Evidence details'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    d.techPackEvidence,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          Text(
            'The re-apply request uses the recovered daemon TechPackUpdate("techpack") path. It does not fabricate an entitlement payload.',
            style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
          ),
          GlassButton(
            'Re-apply provisioned TechPack',
            destructive: true,
            onPressed:
                d.busy ||
                    !d.connected ||
                    !d.prefs.developerMode ||
                    !d.parkedFresh ||
                    !d.chargerDisconnectedFresh
                ? null
                : () async {
                    if (await confirmTyped(
                      context,
                      title: 'Send TechPack re-apply request?',
                      message:
                          'Keep the scooter parked and unplugged. This is a live vehicle daemon configuration request. Type CONFIRM to continue.',
                    )) {
                      await d.techPackUpdateProbe('techpack');
                    }
                  },
          ),
          if (d.techPackProbeResult.isNotEmpty)
            ExpansionTile(
              title: const Text('Probe result'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    d.techPackProbeResult,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      Section(
        'Passcode health (read-only)',
        icon: CupertinoIcons.lock_shield,
        children: [
          Text(
            'Checks only aggregate verifier format, remaining-attempt health and the Android recovery cache. PINs and hashes are never returned or displayed.',
            style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
          ),
          GlassButton(
            'Read passcode health',
            onPressed: d.busy ? null : d.readPasscodeHealth,
          ),
          if (d.passcodeHealth != null) ...[
            Text('Profiles: ${d.passcodeHealth!.profileCount}'),
            Text(
              'Verifier format: ${d.passcodeHealth!.allVerifiersExpected ? 'Expected scrypt format' : 'Unexpected'}',
            ),
            Text(
              'Lowest remaining attempts: ${d.passcodeHealth!.minimumRemainingAttempts}',
            ),
            Text(
              'VSM recovery cache: ${d.passcodeHealth!.vsmCachePresent ? 'Present' : 'Not persisted'}',
            ),
          ],
        ],
      ),
      Section(
        'Firmware update (OTA)',
        icon: CupertinoIcons.cloud_download,
        children: [
          Text(
            'EXPERIMENTAL and brick-capable. The checksum format the scooter '
            'expects is UNVERIFIED (assumed SHA-256) — do NOT flash a scooter '
            'you cannot risk until this is validated on a test unit. Needs '
            'Service mode.',
            style: const TextStyle(color: danger, fontSize: 12, height: 1.4),
          ),
          GlassButton(
            'Check update status',
            onPressed: d.busy || !d.connected ? null : d.otaStatus,
          ),
          if (d.otaState.isNotEmpty)
            Text(
              'Status: ${d.otaState}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 6),
          GlassButton(
            _otaFile == null ? 'Choose firmware file' : 'File: $_otaFile',
            icon: CupertinoIcons.doc,
            onPressed: d.busy
                ? null
                : () async {
                    final picked = await FilePicker.pickFiles();
                    if (picked.isNotEmpty &&
                        picked.single.path != null &&
                        mounted) {
                      final bytes = await File(
                        picked.single.path!,
                      ).readAsBytes();
                      if (!mounted) return;
                      setState(() {
                        _otaFile = picked.single.name;
                        _otaBytes = bytes;
                      });
                    }
                  },
          ),
          GlassButton(
            'Target: $_otaTarget',
            icon: CupertinoIcons.chevron_down,
            onPressed: d.busy
                ? null
                : () async {
                    final v = await glassSheet<String>(
                      context,
                      PageStack([
                        for (final t in const [
                          'ALL',
                          'AOSP',
                          'BCM',
                          'BMS',
                          'HU',
                          'MCU',
                        ])
                          GlassButton(
                            t,
                            onPressed: () => Navigator.pop(context, t),
                          ),
                      ]),
                    );
                    if (v != null && mounted) setState(() => _otaTarget = v);
                  },
          ),
          if (d.otaProgress > 0 && d.otaProgress < 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: d.otaProgress,
                  minHeight: 6,
                  backgroundColor: fill(context),
                  color: accent,
                ),
              ),
            ),
          GlassButton(
            'Flash firmware',
            destructive: true,
            onPressed: d.busy || _otaBytes == null
                ? null
                : () async {
                    if (!await requireServiceMode(context, d)) return;
                    if (!mounted) return;
                    if (await confirmTyped(
                      context,
                      title: 'Flash $_otaFile to $_otaTarget?',
                      message:
                          'EXPERIMENTAL and BRICK-CAPABLE. The checksum format is '
                          'unverified; a wrong file or an interrupted write can '
                          'permanently brick the $_otaTarget. Keep the scooter '
                          'parked and on charge, and do not disconnect. Type '
                          'CONFIRM.',
                    )) {
                      await d.otaFlash(_otaBytes!, _otaFile!, _otaTarget);
                      if (mounted) setState(() {});
                    }
                  },
          ),
        ],
      ),
      Section(
        'Motor calibration',
        children: [
          Text(
            'Use Component tests for the guarded MCU AutoTune routine. This read-only angle check helps assess motor compatibility. Hardware validation is pending.',
            style: TextStyle(color: muted(context)),
          ),
          GlassButton(
            'Read motor angle (B113)',
            onPressed: d.busy
                ? null
                : () => d.operation('Read motor angle', () async {
                    if (d.demo) {
                      d.message = 'Demo motor angle: unavailable';
                      return;
                    }
                    final u = d.uds!;
                    final bytes = await u.read(Ecu.mcu, 0xb113);
                    d.message = 'Motor angle raw: ${hex(bytes)}';
                  }),
          ),
        ],
      ),
      Section(
        'Self-tests',
        children: [
          Text(
            'These run on the scooter\'s head unit. The diagnostic app '
            '(com.ola.mfgapp, shown as Diagnostic Mode) is brought to the front '
            'automatically when a test starts, so the result is visible on the '
            'scooter.',
            style: TextStyle(
              color: muted(context),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final t in tests) _selfTestTile(t.$1, t.$2, t.$3)],
          ),
          const SizedBox(height: 10),
          GlassButton(
            'Return to OLA HMI',
            icon: CupertinoIcons.house,
            onPressed: d.busy ? null : d.launchOlaHmi,
          ),
          Text(
            'Self-tests leave the scooter showing the Diagnostic Mode app. '
            'Tap this when you are done to bring the normal dashboard back.',
            style: TextStyle(
              color: muted(context),
              fontSize: 11.5,
              height: 1.4,
            ),
          ),
          if (runningTest != null) ...[
            const SizedBox(height: 10),
            GlassButton(
              'Stop $runningLabel test',
              destructive: true,
              onPressed: d.busy
                  ? null
                  : () async {
                      await d.test(runningTest!, runningLabel, false);
                      if (mounted) setState(() => runningTest = null);
                    },
            ),
          ],
        ],
      ),
      Section(
        'Fault transitions',
        children: [
          Text(
            'SET/CLEAR from received CAN frames; no injected commands.',
            style: TextStyle(color: muted(context)),
          ),
          if (d.watchEvents.isEmpty)
            const Text('No transitions received this session.'),
          for (final event in d.watchEvents.take(30))
            Text(event, style: const TextStyle(fontSize: 12)),
        ],
      ),
      Section(
        'Ride-mode frame',
        children: [
          Text(
            d.raw[0x143] == null
                ? 'No 0x143 frame received.'
                : '0x143 raw: ${hex(d.raw[0x143]!)}',
          ),
          const Text(
            'Mode mapping depends on firmware; raw bytes are not a confirmed mode.',
          ),
        ],
      ),
      Section(
        'Manufacturing configuration',
        icon: CupertinoIcons.wrench_fill,
        children: [
          Text(
            'Factory ECU-write commands from the production app. JTAG toggles '
            'hardware debug ports — reference only; OpenOLA does not send the '
            'BCM writes (BCM is not UDS-addressable here).',
            style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
          ),
          for (final cmd in d.catalog.somCommands)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    cmd.isJtag
                        ? CupertinoIcons.lock_shield
                        : CupertinoIcons.doc_text,
                    size: 16,
                    color: cmd.isJtag ? danger : muted(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cmd.name,
                          style: TextStyle(
                            color: ink(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${cmd.ecu} · DID ${cmd.didHex} · ${cmd.data} · ${cmd.vehType}',
                          style: TextStyle(color: muted(context), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (d.catalog.somResetBms) ...[
            const SizedBox(height: 12),
            GlassButton(
              'BMS reset',
              icon: CupertinoIcons.arrow_clockwise,
              destructive: true,
              onPressed: d.busy
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Reset the BMS?',
                        'Resets the battery management controller. Can clear a '
                            'latched state such as a stuck "charging" flag. Keep '
                            'the scooter parked, charger disconnected. Deep-sleep '
                            'wake is unvalidated.',
                      )) {
                        await d.faultAction(Ecu.bms, true);
                      }
                    },
            ),
          ],
        ],
      ),
    ]);
  }
}

class _ParameterEditor extends StatefulWidget {
  const _ParameterEditor(this.p, this.d, {this.typedConfirm = false});
  final Parameter p;
  final Diagnostics d;

  /// When true the write requires typing CONFIRM (used for the higher-stakes
  /// performance-limit writes) instead of a plain confirm dialog.
  final bool typedConfirm;
  @override
  State<_ParameterEditor> createState() => _ParameterEditorState();
}

class _ParameterEditorState extends State<_ParameterEditor> {
  List<int>? bytes;
  bool reversed = false, loading = false;
  String status = '';
  final edits = <String, TextEditingController>{};
  @override
  void initState() {
    super.initState();
    for (final f in widget.p.fields) {
      edits[f.name] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final c in edits.values) {
      c.dispose();
    }
    super.dispose();
  }

  void decoded() {
    if (bytes != null) {
      for (final entry in widget.p.decode(bytes!, reversed: reversed).entries) {
        edits[entry.key]!.text = entry.value.toString();
      }
    }
  }

  Future<void> read() async {
    setState(() => loading = true);
    final result = await widget.d.readParameter(widget.p);
    if (!mounted) return;
    setState(() {
      bytes = result;
      loading = false;
      status = result == null ? widget.d.message : 'Current values received.';
      decoded();
    });
  }

  @override
  Widget build(BuildContext context) => PageStack([
    Heading(
      widget.p.name,
      '${widget.p.ecu.label} · current values are reread before writing.',
    ),
    GlassToggle(
      'Reverse byte order',
      'Original configuration byte order remains unverified. Validate against known values.',
      reversed,
      loading
          ? null
          : (v) => setState(() {
              reversed = v;
              decoded();
            }),
    ),
    GlassButton('Read current values', onPressed: loading ? null : read),
    if (bytes != null) ...[
      SelectableText(
        'Raw: ${hex(bytes!)}',
        style: const TextStyle(fontSize: 12),
      ),
      for (final f in widget.p.fields)
        GlassField(
          controller: edits[f.name]!,
          label:
              '${f.name} ${f.unit} (${f.minimum ?? '—'}…${f.maximum ?? '—'})',
          keyboard: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
    ],
    if (bytes != null)
      GlassButton(
        'Write with readback verification',
        destructive: true,
        onPressed: loading
            ? null
            : () async {
                final values = <String, double>{};
                try {
                  for (final edit in edits.entries) {
                    values[edit.key] = double.parse(edit.value.text);
                  }
                  widget.p.encode(bytes!, values, reversed: reversed);
                } catch (e) {
                  setState(() => status = 'Check values: $e');
                  return;
                }
                final ok = widget.typedConfirm
                    ? await confirmTyped(
                        context,
                        title: 'Write ${widget.p.name}?',
                        message:
                            'This changes a real controller limit. Bounds shown '
                            'are encoding limits, NOT verified-safe calibration '
                            'limits. Keep the scooter parked and watch pack '
                            'temperature, current and cell spread. Type CONFIRM '
                            'to write.',
                      )
                    : await confirmGlass(
                        context,
                        'Write ${widget.p.name}?',
                        'Changes calibration data. Bounds are encoding limits, not verified safe limits. Fresh bytes are reread, patched and checked after the write.',
                      );
                if (!ok) {
                  return;
                }
                setState(() => loading = true);
                await widget.d.writeParameter(
                  widget.p,
                  values,
                  reversed: reversed,
                );
                if (mounted) {
                  setState(() {
                    loading = false;
                    status = widget.d.message;
                  });
                }
              },
      ),
    if (status.isNotEmpty)
      Text(status, style: TextStyle(color: muted(context))),
  ]);
}
