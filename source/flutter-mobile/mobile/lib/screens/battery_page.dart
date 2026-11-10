import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/battery.dart';
import '../diagnostics/gen3_balance_probe.dart';
import '../design/glass.dart';
import '../design/dashboard.dart';
import '../design/signal_chart.dart';
import 'core.dart';
import 'identifiers_page.dart';

class BatteryPage extends StatefulWidget {
  const BatteryPage({super.key, required this.d});
  final Diagnostics d;
  @override
  State<BatteryPage> createState() => _BatteryPageState();
}

class _BatteryPageState extends State<BatteryPage> {
  int tab = 0;
  String signal = 'batt_soc', status = '';
  String? gen3BalanceReport;
  static const graphSignals = {
    'batt_soc': ('Charge', '%'),
    'batt_volts': ('Voltage', 'V'),
    'batt_amps': ('Current', 'A'),
    'power_w': ('Power', 'W'),
    'batt_motor_t': ('Motor', '°C'),
    'batt_mcu_t': ('Controller', '°C'),
  };
  @override
  Widget build(BuildContext context) {
    // Per-cell voltages, SoH, cycles and pack temperature are all broadcast on
    // CAN; the UDS deep read only adds per-cell Ah/resistance and on current
    // firmware (5.0.0) returns no cells at all. So an empty-cell UDS snapshot
    // must never shadow the live CAN cells — prefer whichever snapshot actually
    // carries cells, and fall back to the CAN snapshot otherwise. This keeps the
    // cell grid and CAN temperature visible even after a UDS "Read battery".
    final d = widget.d;
    final balanceDisabledReason = d.busy
        ? 'Another diagnostic operation is running.'
        : !d.legacyMethodsAvailable
        ? 'This build has not verified the balancing routine for this scooter profile.'
        : d.mode != 'SERVICE'
        ? 'Enter Service mode first.'
        : !d.bench
        ? 'Confirm the scooter is parked first.'
        : null;
    final uds = d.battery, canB = d.canBattery;
    final b = (uds != null && uds.cells.isNotEmpty)
        ? uds
        : (canB != null && canB.cells.isNotEmpty)
        ? canB
        : (uds ?? canB);
    final overallBalancing = d.frameFresh(0x160) && d.raw[0x160]!.isNotEmpty
        ? (d.raw[0x160]![0] & 1) != 0
        : null;
    final cellBalanceFrame = d.frameFresh(0x170) ? d.raw[0x170] : null;
    final balancingGroups =
        cellBalanceFrame != null && cellBalanceFrame.length >= 2
        ? [
            for (var index = 0; index < 14; index++)
              if ((cellBalanceFrame[index ~/ 8] & (1 << (index % 8))) != 0)
                index + 1,
          ]
        : null;
    return PageStack([
      Heading(
        'Battery',
        d.demo
            ? 'Simulated battery · explore every cell.'
            : 'Health, individual cells and live pack trends.',
      ),
      GlassSegment<int>(
        values: const [0, 1, 2],
        selected: tab,
        label: (v) => ['Overview', 'Graphs', 'Settings'][v],
        onChanged: (v) => setState(() => tab = v),
      ),
      if (tab == 0) ...[
        Section(
          'Battery health',
          icon: CupertinoIcons.heart,
          children: [
            MetricGrid([
              ('SoH reading', number(b?.healthValue('soh'), 1), '%'),
              ('Cycles', number(b?.healthValue('cycle'), 0), ''),
              ('Temperature', number(d.batteryTemperature, 1), '°C'),
              ('Charge', number(d.metrics['State of charge (%)'], 1), '%'),
              // The BMS reports these as per-cycle accumulators that reset to 0
              // at rest, so 0 means "not computed", not an empty pack — show it
              // as unavailable rather than a misleading 0.0.
              (
                'Usable capacity',
                number((b?.usableAh ?? 0) > 0 ? b!.usableAh : null, 1),
                'Ah',
              ),
              (
                'Estimated pack energy',
                number(
                  (b?.estimatedPackWh ?? 0) > 0 ? b!.estimatedPackWh : null,
                  0,
                ),
                'Wh',
              ),
            ]),
            if (d.vehicleAsleep)
              Text(
                'Scooter asleep — press the start button or plug in the charger '
                'to wake the battery, then values appear here.',
                style: const TextStyle(
                  color: orange,
                  fontSize: 12,
                  height: 1.4,
                ),
              )
            else if (b == null)
              Text(
                'Waiting for battery frames from the pack…',
                style: TextStyle(color: muted(context), fontSize: 12),
              )
            else if ((b.usableAh ?? 0) <= 0)
              Text(
                'Usable capacity and pack energy are per-cycle accumulators — '
                'the BMS resets them at rest, so they stay blank until you ride '
                'and then fill in.',
                style: TextStyle(
                  color: muted(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            // Live SoH, cell voltages, cycles and temperature come from CAN with
            // no action needed. The deeper read adds per-cell resistance and Ah
            // capacity; it needs Service mode, and tapping prompts the user to
            // enter it rather than silently disabling the button.
            GlassButton(
              d.battery == null
                  ? 'Read battery & cells'
                  : 'Refresh battery & cells',
              primary: true,
              icon: CupertinoIcons.arrow_clockwise,
              onPressed: d.busy
                  ? null
                  : () async {
                      final dd = widget.d;
                      if (!dd.readReady) {
                        final ok = await requireServiceMode(context, dd);
                        if (!ok || !dd.readReady) return;
                      }
                      await dd.readBattery();
                    },
            ),
            ReadContext(d: d),
            Text(
              'The deep read adds per-cell resistance and Ah capacity. SoH, cell '
              'voltages, cycles and temperature already come from CAN above.',
              style: TextStyle(
                color: muted(context),
                fontSize: 11,
                height: 1.4,
              ),
            ),
            if (b != null)
              Text(
                b.demo
                    ? 'Demo snapshot · simulated values'
                    : d.battery != null
                    ? 'UDS snapshot from ${b.time.toLocal().toString().split('.').first}'
                    : 'Live from CAN',
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
          ],
        ),
        if (b != null && b.cells.isNotEmpty)
          Builder(
            builder: (context) {
              final (verdict, detail) = b.healthAssessment;
              final c = verdict.startsWith('Attention')
                  ? danger
                  : verdict.startsWith('Monitor')
                  ? orange
                  : green;
              return Section(
                'Health assessment',
                icon: CupertinoIcons.heart_circle,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.circle_fill, size: 10, color: c),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          verdict,
                          style: TextStyle(
                            color: c,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    detail,
                    style: TextStyle(
                      color: muted(context),
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Informational only — a comparison of live readings, not a '
                    'certified battery-health test.',
                    style: TextStyle(
                      color: muted(context),
                      fontSize: 10.5,
                      height: 1.3,
                    ),
                  ),
                ],
              );
            },
          ),
        if (d.readingIdentifiers) ReadProgress(d: d),
        if (b != null && b.errors.isNotEmpty)
          Section(
            'Some data unavailable',
            children: [
              for (final error in b.errors)
                Text(
                  error,
                  style: TextStyle(color: muted(context), fontSize: 12),
                ),
            ],
          ),
        Section(
          'Individual cells',
          icon: CupertinoIcons.battery_100,
          children: [
            if (b == null || b.cells.isEmpty)
              const Text(
                'Read the battery to see voltage, resistance and capacity for each cell group.',
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusChip('${b.cells.length} groups', color: teal),
                  StatusChip(
                    '${b.spreadMv.toStringAsFixed(1)} mV spread',
                    color: b.spreadMv > 30 ? orange : green,
                  ),
                  StatusChip('Lowest #${b.lowestCell}', color: muted(context)),
                ],
              ),
              if (b.spreadMv >= 50)
                Text(
                  'Group #${b.lowestCell} sits ${b.spreadMv.toStringAsFixed(0)} mV '
                  'below the highest. The SoH figure is the BMS own estimate '
                  'and does not look at cell balance, so it can read 100% while '
                  'one group is weak. A group that stays low and falls fastest '
                  'under load or at low charge is the one to have checked.',
                  style: const TextStyle(
                    color: orange,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 4),
              LayoutBuilder(
                builder: (context, box) {
                  final large = MediaQuery.textScalerOf(context).scale(12) > 16;
                  final count = (box.maxWidth / (large ? 120 : 74))
                      .floor()
                      .clamp(3, 8);
                  final width = (box.maxWidth - (count - 1) * 8) / count;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    children: [
                      for (final c in b.cells)
                        SizedBox(
                          width: width,
                          child: CellGauge(
                            cell: c,
                            snapshot: b,
                            resistance: cellResistance(
                              c,
                              d.cellDcir,
                              d.cellIrEstimate,
                            ),
                            resistanceEstimated: cellResistanceInfo(
                              c,
                              d.cellDcir,
                              d.cellIrEstimate,
                            ).$2,
                            availableWh: cellAvailableWh(
                              c,
                              b.cells.length,
                              d.identity.model,
                            ),
                            onTap: () => _details(c, b),
                          ),
                        ),
                    ],
                  );
                },
              ),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final (label, color) in [
                    ('Typical', green),
                    ('Watch', orange),
                    ('Check', danger),
                  ])
                    StatusChip(label, color: color),
                ],
              ),
            ],
            if (b != null &&
                b.cells.isNotEmpty &&
                b.cells.every(
                  (c) =>
                      cellResistance(c, d.cellDcir, d.cellIrEstimate) == null,
                ))
              const Text(
                'IR is empty because this scooter reports it only under load. Ride the scooter (or charge it) and IR fills in.',
                style: TextStyle(color: orange, fontSize: 12, height: 1.4),
              ),
            Text(
              'Pack SOC comes from the BMS. Each cell group % is only a voltage-based estimate from a fixed curve, not a measured cell SOC; it can show about 95% when the pack reports 100%. Compare group voltages and their spread for balance. Wh is also an estimate. IR is measured when reported, otherwise ~ estimated under load. Tap a group for details.',
              style: TextStyle(
                color: muted(context),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ],
        ),
        Section(
          'Live pack',
          icon: CupertinoIcons.waveform,
          children: [
            MetricGrid([
              ('Voltage', number(d.metrics['Pack voltage (V)']), 'V'),
              ('Current', number(d.metrics['Pack current (A)']), 'A'),
              ('Power', number(d.telemetryValues['power_w'], 0), 'W'),
              ('Charger', chargerLabel(d), ''),
            ]),
            Text(
              d.freshness,
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
            GlassButton(
              d.live ? 'Pause monitor' : 'Start monitor',
              onPressed: !d.connected || d.busy
                  ? null
                  : () => d.liveMode(!d.live),
            ),
          ],
        ),
      ],
      if (tab == 1) ...[
        Section(
          'Live trends',
          icon: CupertinoIcons.chart_bar,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in graphSignals.entries)
                  GlassButton(
                    e.value.$1,
                    compact: true,
                    primary: signal == e.key,
                    onPressed: () => setState(() => signal = e.key),
                  ),
              ],
            ),
            SignalChart(
              [
                for (final sample in d.graph)
                  if (sample.values[signal] != null)
                    (sample.time, sample.values[signal]!),
              ],
              unit: graphSignals[signal]!.$2,
              color: teal,
            ),
            Text(
              'Up to 600 foreground samples. Missing updates leave gaps. Each chart keeps its own physical unit.',
              style: TextStyle(
                color: muted(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            GlassButton(
              d.live ? 'Pause monitor' : 'Start monitor',
              onPressed: !d.connected || d.busy
                  ? null
                  : () => d.liveMode(!d.live),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassButton(
                  'Export graph CSV',
                  compact: true,
                  onPressed: d.graph.isEmpty ? null : _exportGraph,
                ),
                GlassButton(
                  'Clear graph',
                  compact: true,
                  onPressed: d.graph.isEmpty ? null : d.clearGraph,
                ),
              ],
            ),
            if (status.isNotEmpty) Text(status),
          ],
        ),
        if (b != null && b.cells.isNotEmpty)
          Section(
            'Cell voltages',
            icon: CupertinoIcons.chart_bar_alt_fill,
            children: [
              SizedBox(height: 130, child: CellBars(b.cells)),
              Text(
                '${b.cells.length} groups · spread ${b.spreadMv.toStringAsFixed(0)} '
                'mV · lowest #${b.lowestCell}',
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
            ],
          ),
        Section(
          'Health history',
          icon: CupertinoIcons.graph_square,
          children: [
            if (d.history.points.isEmpty)
              Text(
                'No history yet. SoH and cell spread are logged over time while '
                'connected, and kept across sessions.',
                style: TextStyle(color: muted(context), fontSize: 12),
              )
            else ...[
              Text(
                'State of health (%)',
                style: TextStyle(color: muted(context), fontSize: 12),
              ),
              SignalChart(
                d.history.series((p) => p.soh),
                unit: '%',
                color: green,
              ),
              const SizedBox(height: 12),
              Text(
                'Cell spread (mV)',
                style: TextStyle(color: muted(context), fontSize: 12),
              ),
              SignalChart(
                d.history.series((p) => p.spreadMv),
                unit: 'mV',
                color: orange,
              ),
              Text(
                '${d.history.points.length} samples over time, persisted across '
                'sessions. A rising spread or falling SoH points at ageing.',
                style: TextStyle(
                  color: muted(context),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              GlassButton(
                'Clear history',
                compact: true,
                onPressed: () async {
                  await d.history.clear();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ],
        ),
      ],
      if (tab == 2) ...[
        Section(
          'Cell balancing',
          icon: CupertinoIcons.bolt_horizontal,
          children: [
            Text(
              'Balancing is managed by the BMS and normally runs only while '
              'charging with the cells imbalanced. This requests the routine; '
              'the pack decides whether to act. The BMS broadcasts overall '
              'balancing status and individual group flags when those frames '
              'are available.',
              style: TextStyle(
                color: muted(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            Text(
              'BMS balancing: ${overallBalancing == null
                  ? 'no fresh status'
                  : overallBalancing
                  ? 'active'
                  : 'inactive'}',
            ),
            Text(
              'Groups balancing: ${balancingGroups == null
                  ? 'no fresh status'
                  : balancingGroups.isEmpty
                  ? 'none reported'
                  : balancingGroups.join(', ')}',
            ),
            Text(
              d.busy
                  ? 'Unavailable while another operation is running.'
                  : !d.legacyMethodsAvailable
                  ? 'Balancing status is available above. The manual start routine (31 01 05 F8) is listed in the diagnostic catalog, but its session and response have not been verified on this Gen3 BMS.'
                  : d.mode != 'SERVICE' || !d.bench
                  ? 'Enter Service mode while parked to enable this request.'
                  : 'A request does not confirm that balancing has started; the BMS decides when conditions allow it.',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
            GlassButton(
              'Request cell balancing',
              icon: CupertinoIcons.bolt_horizontal,
              disabledReason: balanceDisabledReason,
              onPressed:
                  d.busy ||
                      !d.legacyMethodsAvailable ||
                      d.mode != 'SERVICE' ||
                      !d.bench
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Request cell balancing?',
                        'Starts the BMS cell-balancing routine (needs Service mode). '
                            'Keep the scooter parked, ideally on charge. The BMS '
                            'balances only when conditions allow.',
                      )) {
                        await d.forceBalance();
                      }
                    },
            ),
            if (d.identity.modelCode == 31) ...[
              if (status.isNotEmpty) Text(status),
              Text(
                'Gen3 compatibility test: sends the documented BMS request once, '
                'records its raw reply and compares live balancing flags. It does '
                'not unlock the BMS or prove that balancing started. Park the '
                'scooter and enter Service mode for this test. The charger may '
                'remain connected; the BMS decides whether to run it.',
                style: TextStyle(color: muted(context), fontSize: 12),
              ),
              if (!Gen3BalanceProbe.eligible(d))
                Text(
                  'To enable the test: connect model 31, confirm a fresh Park '
                  'reading, then enter Service mode. The charger may remain '
                  'connected.',
                  style: TextStyle(color: muted(context), fontSize: 12),
                ),
              GlassButton(
                'Test Gen3 balancing request',
                icon: CupertinoIcons.waveform_path,
                disabledReason: !Gen3BalanceProbe.eligible(d)
                    ? d.busy
                          ? 'Another diagnostic operation is running.'
                          : !d.connected
                          ? 'Connect the scooter first.'
                          : d.identity.modelCode != 31
                          ? 'This compatibility probe is only for Gen3 model 31.'
                          : d.mode != 'SERVICE'
                          ? 'Enter Service mode first.'
                          : !d.bench || !d.parkedFresh
                          ? 'Confirm a fresh Park state first.'
                          : 'The BMS diagnostic link is not ready.'
                    : null,
                onPressed: !Gen3BalanceProbe.eligible(d)
                    ? null
                    : () async {
                        if (!await confirmGlass(
                          context,
                          'Test Gen3 BMS response?',
                          'This sends one cell-balancing routine request to the '
                              'BMS and records its response. Keep the scooter '
                              'parked. The charger may remain connected; the test '
                              'returns the scooter to Customer mode afterward.',
                        )) {
                          return;
                        }
                        try {
                          final report = await Gen3BalanceProbe.run(d);
                          if (mounted) {
                            setState(() => gen3BalanceReport = report);
                          }
                        } catch (error) {
                          if (mounted) setState(() => status = '$error');
                        }
                      },
              ),
              if (gen3BalanceReport != null) ...[
                Text(
                  gen3BalanceReport!,
                  style: TextStyle(color: muted(context), fontSize: 12),
                ),
                GlassButton(
                  'Share Gen3 test result',
                  icon: CupertinoIcons.share,
                  onPressed: () async {
                    final box = context.findRenderObject() as RenderBox?;
                    await SharePlus.instance.share(
                      ShareParams(
                        text: gen3BalanceReport!,
                        subject: 'OpenOLA Gen3 balancing test',
                        sharePositionOrigin: box == null
                            ? null
                            : box.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  },
                ),
              ],
            ],
          ],
        ),
        IdentifiersPage(
          d: d,
          kind: IdentifierWorkspace.bmsSettings,
          embedded: true,
        ),
      ],
    ]);
  }

  Future<void> _exportGraph() async {
    final keys = graphSignals.keys.toList();
    final text = StringBuffer('\uFEFFtime_s,${keys.join(',')}\r\n');
    for (final s in widget.d.graph) {
      text.writeln('${s.time},${keys.map((k) => s.values[k] ?? '').join(',')}');
    }
    try {
      final path = await FilePicker.saveFile(
        fileName: 'OpenOLA-battery.csv',
        bytes: Uint8List.fromList(utf8.encode(text.toString())),
      );
      if (mounted) {
        setState(
          () => status = path == null ? 'Export cancelled.' : 'Graph saved.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => status = 'Export failed: $e');
    }
  }

  Future<void> _details(BatteryCell c, BatterySnapshot b) => glassSheet(
    context,
    PageStack([
      Heading(
        'Cell group ${c.index}',
        b.demo ? 'Simulated reading' : 'Battery snapshot',
      ),
      MetricGrid([
        ('Voltage', c.volts.toStringAsFixed(3), 'V'),
        (
          'Internal resistance',
          number(
            cellResistance(c, widget.d.cellDcir, widget.d.cellIrEstimate),
            2,
          ),
          'mΩ',
        ),
        (
          'Energy available',
          number(
            cellAvailableWh(c, b.cells.length, widget.d.identity.model),
            1,
          ),
          'Wh',
        ),
        ('Shared sensor', number(c.temperature, 1), '°C'),
        (
          'Voltage-only estimate',
          '~${c.chargePercent.toStringAsFixed(0)}',
          '%',
        ),
      ]),
      Text(
        '${b.observation(c)} relative to this pack. This is a comparison of readings, not a cell-health diagnosis. Series-cell Ah is not added to obtain pack capacity.',
        style: TextStyle(color: muted(context), height: 1.5),
      ),
      GlassButton(
        'Done',
        primary: true,
        onPressed: () => Navigator.pop(context),
      ),
    ]),
  );
}

String chargerLabel(Diagnostics d) {
  final data = d.raw[0x62d];
  return data == null || data.isEmpty
      ? 'Unknown'
      : ['None', 'Fast', 'Slow', 'Boost'][data[0] & 3];
}

class MetricGrid extends StatelessWidget {
  const MetricGrid(this.metrics, {super.key});
  final List<(String, String, String)> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth > 650 ? 4 : 2,
          width = (box.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 18,
        children: [
          for (final (label, value, unit) in metrics)
            SizedBox(
              width: width,
              child: MetricValue(label, value, unit: unit, compact: true),
            ),
        ],
      );
    },
  );
}

/// Internal resistance for a cell: the UDS snapshot value if it is a real
/// (positive) reading, else the passive CAN DCIR. A UDS value of 0 means "not
/// measurable at rest" on real packs, so it must not mask live DCIR or show as
/// a misleading 0.00 mΩ.
double? cellResistance(
  BatteryCell c,
  List<double?> dcir, [
  List<double?> estimate = const [],
]) => cellResistanceInfo(c, dcir, estimate).$1;

/// (value in mΩ, true when it is a live estimate from voltage sag under load).
(double?, bool) cellResistanceInfo(
  BatteryCell c,
  List<double?> dcir, [
  List<double?> estimate = const [],
]) {
  final snapshot = c.ir;
  if (snapshot != null && snapshot > 0) return (snapshot, false);
  final live = c.index - 1 < dcir.length ? dcir[c.index - 1] : null;
  if (live != null && live > 0) return (live, false);
  final est = c.index - 1 < estimate.length ? estimate[c.index - 1] : null;
  return est != null && est > 0 ? (est, true) : (null, false);
}

/// Energy currently available in one series cell group, in Wh:
/// capacity × charge % × voltage. Capacity is the UDS per-cell Ah when read;
/// otherwise a nominal share of the model's pack kWh (the pack energy named in
/// the model, split across the series groups). Returns null when neither is
/// known — never a guessed number. This is an estimate from resting-voltage
/// charge %, not a measured value.
double? cellAvailableWh(BatteryCell c, int groups, String model) {
  final pct = c.chargePercent / 100;
  final ah = c.ah;
  if (ah != null && ah > 0) return ah * c.volts * pct;
  final kwh = RegExp(r'(\d+(?:\.\d+)?)\s*kWh').firstMatch(model)?.group(1);
  // Model names without a kWh figure: the S1 Pro is sold as a 3.97 kWh pack
  // (nominal, new-battery figure). Other models stay unknown rather than guessed.
  final pack = kwh != null
      ? double.tryParse(kwh)
      : RegExp(r'S1 Pro', caseSensitive: false).hasMatch(model)
      ? 3.97
      : null;
  if (pack == null || groups <= 0) return null;
  return pack * 1000 / groups * pct;
}

String whText(double? wh) =>
    wh == null ? '— Wh' : '${wh.toStringAsFixed(wh >= 100 ? 0 : 1)} Wh';

class CellGauge extends StatelessWidget {
  const CellGauge({
    super.key,
    required this.cell,
    required this.snapshot,
    required this.resistance,
    this.availableWh,
    this.resistanceEstimated = false,
    required this.onTap,
  });
  final BatteryCell cell;
  final BatterySnapshot snapshot;
  final double? resistance, availableWh;
  final bool resistanceEstimated;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final observation = snapshot.observation(cell),
        color = observation == 'Check'
            ? danger
            : observation == 'Watch'
            ? orange
            : green;
    final c = cell;
    return Semantics(
      button: true,
      label:
          'Cell group ${c.index}, ${c.volts.toStringAsFixed(3)} volts, ${number(resistance, 2)} milliohms, ${number(c.ah, 2)} amp hours, $observation',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Text(
              '#${c.index}',
              style: TextStyle(
                color: muted(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 48,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .12),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: fill(context),
                          border: Border.all(
                            color: color.withValues(alpha: .32),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: c.chargePercent / 100),
                        duration: reduced(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, fill, _) => Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: fill.clamp(.02, 1),
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.lerp(
                                      color,
                                      Colors.white,
                                      .32,
                                    )!.withValues(alpha: .8),
                                    color.withValues(alpha: .65),
                                    Color.lerp(
                                      color,
                                      Colors.black,
                                      .12,
                                    )!.withValues(alpha: .45),
                                  ],
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: .45),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: dark(context) ? .16 : .38,
                            ),
                            width: .6,
                          ),
                          gradient: RadialGradient(
                            center: const Alignment(-.4, -.8),
                            radius: .8,
                            colors: [
                              Colors.white.withValues(
                                alpha: dark(context) ? .35 : .55,
                              ),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: const [0, .85],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      bottom: 14,
                      left: 8,
                      width: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: .4),
                              Colors.white.withValues(alpha: .04),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '~${c.chargePercent.round()}%',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              color: ink(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${c.volts.toStringAsFixed(2)}V',
              style: TextStyle(
                color: ink(context),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'IR ${resistanceEstimated ? '~' : ''}${number(resistance, 2)} mΩ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted(context),
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
            Text(
              whText(availableWh),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted(context),
                fontSize: 10.5,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bar chart of per-cell voltages, lowest cell highlighted. Bars are scaled
/// within the pack's own min/max so small differences are visible.
class CellBars extends StatelessWidget {
  const CellBars(this.cells, {super.key});
  final List<BatteryCell> cells;
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.infinite,
    painter: _CellBarsPainter(
      cells,
      bar: accent,
      low: orange,
      label: muted(context),
    ),
  );
}

class _CellBarsPainter extends CustomPainter {
  _CellBarsPainter(
    this.cells, {
    required this.bar,
    required this.low,
    required this.label,
  });
  final List<BatteryCell> cells;
  final Color bar, low, label;

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) return;
    final vs = cells.map((c) => c.volts).toList();
    final lo = vs.reduce(math.min), hi = vs.reduce(math.max);
    final span = (hi - lo) < 0.001 ? 0.05 : (hi - lo);
    final lowest = cells.reduce((a, b) => a.volts <= b.volts ? a : b).index;
    final n = cells.length;
    const gap = 3.0;
    final barW = (size.width - gap * (n - 1)) / n;
    final bottom = size.height - 14; // room for index labels
    for (var i = 0; i < n; i++) {
      final v = cells[i].volts;
      final norm = ((v - (lo - span * 0.15)) / (span * 1.15)).clamp(0.08, 1.0);
      final h = norm * (bottom - 4);
      final x = i * (barW + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, bottom - h, barW, h),
          const Radius.circular(3),
        ),
        Paint()..color = cells[i].index == lowest ? low : bar,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${cells[i].index}',
          style: TextStyle(color: label, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + (barW - tp.width) / 2, bottom + 2));
    }
  }

  @override
  bool shouldRepaint(_CellBarsPainter old) => old.cells != cells;
}
