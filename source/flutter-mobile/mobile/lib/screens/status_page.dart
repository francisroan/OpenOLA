import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'model_diagnostics.dart';
import '../diagnostics/controller.dart';
import '../design/glass.dart';
import '../design/dashboard.dart';
import 'core.dart';
import 'battery_page.dart';

class StatusPage extends StatelessWidget {
  const StatusPage({super.key, required this.d});
  final Diagnostics d;
  @override
  Widget build(BuildContext context) => PageStack([
    const Heading(
      'Vehicle status',
      'Battery vitals, received fault flags and notifications.',
    ),
    ModelDiagnostics(d: d),
    Section(
      'Live vehicle',
      icon: CupertinoIcons.gauge,
      children: [
        MetricGrid([
          ('Charge', number(d.metrics['State of charge (%)']), '%'),
          ('Range', number(d.metrics['Reported range (km)'], 0), 'km'),
          ('Voltage', number(d.metrics['Pack voltage (V)']), 'V'),
          ('Current', number(d.metrics['Pack current (A)']), 'A'),
          ('Motor', number(d.metrics['Motor temperature (°C)']), '°C'),
          (
            'Controller',
            number(d.metrics['Controller temperature (°C)']),
            '°C',
          ),
        ]),
        Text(
          d.freshness,
          style: TextStyle(color: muted(context), fontSize: 12),
        ),
        GlassButton(
          d.live ? 'Pause monitor' : 'Start monitor',
          onPressed: !d.connected || d.busy ? null : () => d.liveMode(!d.live),
        ),
      ],
    ),
    Section(
      'Broadcast fault flags',
      icon: CupertinoIcons.waveform_path_ecg,
      children: [
        if (d.broadcast.isEmpty)
          const Text(
            'No asserted flags in the received data. Stored faults are on the Faults tab.',
          ),
        for (final fault in d.broadcast)
          Text(fault, style: const TextStyle(color: orange)),
      ],
    ),
    Section(
      'Vehicle notifications',
      icon: CupertinoIcons.bell,
      children: [
        const Text('0x6D0 feed · newest first'),
        if (d.notifications.isEmpty)
          Text(
            'No vehicle notifications received yet.',
            style: TextStyle(color: muted(context)),
          ),
        for (final notification in d.notifications)
          WorkspaceRow(
            notification.name.replaceAll('_', ' '),
            '${notification.code} · ${notification.time.toLocal().toString().split(' ').last.split('.').first}',
            CupertinoIcons.info_circle,
            notification.alert ? orange : teal,
          ),
        GlassButton(
          'Clear notification view',
          onPressed: d.notifications.isEmpty ? null : d.clearNotifications,
        ),
      ],
    ),
    Section(
      'Received features',
      icon: CupertinoIcons.square_grid_2x2,
      children: [
        Text(
          'Feature availability reported by this scooter. These flags do not '
          'show the active HMI setting. Waiting for identity or fresh data '
          'leaves availability unknown.',
          style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
        ),
        for (final e in d.receivedFeatures.entries)
          WorkspaceRow(
            e.key,
            e.value == null
                ? 'Not received'
                : e.key.contains('(TP)')
                ? 'Reported code ${e.value}'
                : e.value == 0
                ? 'Unavailable'
                : 'Available',
            featureIcon(e.key),
            e.value == null
                ? muted(context)
                : e.value == 0
                ? orange
                : green,
          ),
      ],
    ),
  ]);
}

class SoftwarePage extends StatefulWidget {
  const SoftwarePage({super.key, required this.d});
  final Diagnostics d;
  @override
  State<SoftwarePage> createState() => _SoftwarePageState();
}

class _SoftwarePageState extends State<SoftwarePage> {
  String selected = 'Software version';
  @override
  Widget build(BuildContext context) => PageStack([
    const Heading(
      'Software',
      'Installed software, vehicle identity and update status.',
    ),
    Section(
      'Read information',
      icon: CupertinoIcons.square_arrow_down,
      children: [
        for (final kind in [
          'Software version',
          'Android version',
          'Identifiers',
          'Update status',
        ])
          GlassButton(
            kind,
            primary: kind == selected,
            onPressed: !widget.d.connected || widget.d.busy
                ? null
                : () async {
                    setState(() => selected = kind);
                    await widget.d.readSoftware(kind);
                  },
          ),
      ],
    ),
    Section(
      'Response',
      children: [
        SelectableText(
          widget.d.softwareResponses[selected] ?? 'Choose a request above.',
          style: TextStyle(color: muted(context), fontSize: 13, height: 1.5),
        ),
      ],
    ),
  ]);
}

/// An icon that says what each broadcast feature is (instead of a bare circle).
IconData featureIcon(String name) {
  final n = name.toLowerCase();
  const table = <String, IconData>{
    'boost': CupertinoIcons.bolt_fill,
    'fall': CupertinoIcons.exclamationmark_triangle_fill,
    'tow protection': CupertinoIcons.shield_fill,
    'tow/tamper': CupertinoIcons.shield_lefthalf_fill,
    'proximity l/u': CupertinoIcons.lock_open_fill,
    'proximity lock': CupertinoIcons.lock_fill,
    'hill': CupertinoIcons.arrow_up_circle_fill,
    'smart headlight': CupertinoIcons.lightbulb,
    'smart drl': CupertinoIcons.lightbulb_fill,
    'auto headlight': CupertinoIcons.light_max,
    'hazard': CupertinoIcons.exclamationmark_octagon_fill,
    'auto-indicator': CupertinoIcons.arrow_right_arrow_left,
    'motor cutoff': CupertinoIcons.timer,
    'vacation': CupertinoIcons.moon_zzz_fill,
    'regen': CupertinoIcons.arrow_2_circlepath,
    'fast charger': CupertinoIcons.bolt,
    'hyper charger': CupertinoIcons.bolt_fill,
    'energy insights': CupertinoIcons.chart_bar_fill,
    'geo-fencing': CupertinoIcons.location_fill,
    'time-fencing': CupertinoIcons.clock_fill,
    'mode-fencing': CupertinoIcons.gauge,
    'new upgrades': CupertinoIcons.arrow_up_circle,
    'early-beta': CupertinoIcons.star_fill,
    'smart park': CupertinoIcons.car_detailed,
  };
  for (final entry in table.entries) {
    if (n.contains(entry.key)) return entry.value;
  }
  return CupertinoIcons.circle;
}
