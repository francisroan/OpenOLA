import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/identifiers.dart';
import '../diagnostics/controller.dart';
import '../protocol/can.dart';
import '../design/glass.dart';
import '../design/dashboard.dart';
import 'core.dart';

enum IdentifierWorkspace { components, firmware, bmsSettings, healthReport }

class IdentifiersPage extends StatefulWidget {
  const IdentifiersPage({
    super.key,
    required this.d,
    required this.kind,
    this.embedded = false,
  });
  final Diagnostics d;
  final IdentifierWorkspace kind;
  final bool embedded;
  @override
  State<IdentifiersPage> createState() => _IdentifiersPageState();
}

class _IdentifiersPageState extends State<IdentifiersPage> {
  final search = TextEditingController();
  int ecu = 0;
  bool full = false, identity = false, deviations = false;
  String status = '';
  static const stock = {
    0xe4c3: 'C301',
    0xe413: '1343',
    0xe462: '622E',
    0xe465: '6534',
    0xe467: '6737',
    0xe469: '693E',
    0xe449: '4955',
    0xe44a: '4A64',
    0xe44d: '4D69',
    0xe4ba: 'BA1000',
  };
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<ReadIdentifier> get definitions {
    final d = widget.d;
    if (widget.kind == IdentifierWorkspace.bmsSettings) {
      return d.catalog.bmsConfiguration;
    }
    return d.catalog.identifiers
        .where(
          (r) => switch (widget.kind) {
            IdentifierWorkspace.bmsSettings =>
              r.ecu == Ecu.bms && r.group == 'BMS configuration',
            IdentifierWorkspace.firmware => r.group == 'Identity & versions',
            IdentifierWorkspace.healthReport =>
              (identity || r.group != 'Identity & versions') &&
                  (full ||
                      ![
                        'BMS configuration',
                        'Sensor calibration',
                        'Output states',
                      ].contains(r.group)),
            IdentifierWorkspace.components => r.ecu == Ecu.values[ecu],
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final all = definitions;
    final rows = all
        .where(
          (r) =>
              '${r.title} ${r.key}'.toLowerCase().contains(
                search.text.toLowerCase(),
              ) &&
              (!deviations ||
                  (stock[r.did] != null &&
                      d.identifierResults[r.key]?.bytes != null &&
                      hex(
                            d.identifierResults[r.key]!.bytes!,
                          ).replaceAll(' ', '') !=
                          stock[r.did])),
        )
        .toList();
    final (title, subtitle) = switch (widget.kind) {
      IdentifierWorkspace.components => (
        'Components',
        'Readable identifiers from the ECU catalog.',
      ),
      IdentifierWorkspace.firmware => (
        'Firmware',
        'Module identity and software versions. Read-only.',
      ),
      IdentifierWorkspace.bmsSettings => (
        'BMS settings',
        'Current configuration and the desktop’s S1 Pro reference bytes.',
      ),
      IdentifierWorkspace.healthReport => (
        'ECU health report',
        'Decoded reads across BMS, VCU and MCU.',
      ),
    };
    return PageStack([
      if (!widget.embedded) Heading(title, subtitle),
      if (widget.kind == IdentifierWorkspace.components)
        GlassSegment<int>(
          values: const [0, 1, 2],
          selected: ecu,
          label: (v) => Ecu.values[v].label,
          onChanged: (v) => setState(() => ecu = v),
        ),
      Section(
        title,
        icon: widget.kind == IdentifierWorkspace.firmware
            ? CupertinoIcons.square_stack_3d_up
            : CupertinoIcons.doc_text_search,
        children: [
          if (widget.kind == IdentifierWorkspace.healthReport) ...[
            GlassToggle(
              'Complete read',
              'Include configuration, calibration and output states.',
              full,
              (v) => setState(() => full = v),
            ),
            GlassToggle(
              'Include identity / VIN',
              'Off by default. These values can identify the vehicle.',
              identity,
              (v) => setState(() => identity = v),
            ),
          ],
          Text(
            '${all.length} readable identifiers${widget.kind == IdentifierWorkspace.bmsSettings ? ' · read-only configuration' : ''}',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
          GlassButton(
            d.readingIdentifiers
                ? 'Reading modules…'
                : 'Read ${widget.kind == IdentifierWorkspace.healthReport
                      ? 'health report'
                      : widget.kind == IdentifierWorkspace.bmsSettings
                      ? 'settings'
                      : widget.kind == IdentifierWorkspace.firmware
                      ? 'versions'
                      : Ecu.values[ecu].label}',
            primary: true,
            icon: CupertinoIcons.arrow_clockwise,
            onPressed: d.readReady ? () => d.readIdentifiers(all) : null,
          ),
          ReadContext(d: d),
          if (widget.kind == IdentifierWorkspace.bmsSettings)
            Text(
              'References belong to the desktop’s S1 Pro preset. A match only compares bytes; it does not establish the correct limits for your pack or model.',
              style: TextStyle(
                color: muted(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          if (widget.kind == IdentifierWorkspace.firmware)
            Text(
              'Firmware identifiers are displayed exactly as decoded. Matching text alone does not prove module compatibility.',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
          GlassButton(
            'Export decoded JSON',
            icon: CupertinoIcons.square_arrow_up,
            onPressed:
                d.readingIdentifiers ||
                    !all.any((r) => d.identifierResults.containsKey(r.key))
                ? null
                : () => _export(all),
          ),
          if (status.isNotEmpty)
            Text(status, style: TextStyle(color: muted(context))),
        ],
      ),
      if (d.readingIdentifiers) ReadProgress(d: d),
      GlassField(
        controller: search,
        label: 'Search identifiers',
        onChanged: (_) => setState(() {}),
        suffix: IconButton(
          tooltip: 'Clear search',
          onPressed: () {
            search.clear();
            setState(() {});
          },
          icon: const Icon(CupertinoIcons.xmark_circle),
        ),
      ),
      if (widget.kind == IdentifierWorkspace.bmsSettings)
        GlassToggle(
          'Reference differences only',
          'Shows read values that differ from the S1 Pro preset.',
          deviations,
          (v) => setState(() => deviations = v),
        ),
      if (rows.isEmpty)
        Section(
          'No matching identifiers',
          children: [
            Text(
              deviations
                  ? 'Read the settings first. No matching reference differences are currently available.'
                  : 'Try another search.',
            ),
          ],
        ),
      for (final row in rows)
        IdentifierCard(
          key: ValueKey(row.key),
          definition: row,
          result: d.identifierResults[row.key],
          reference: widget.kind == IdentifierWorkspace.bmsSettings
              ? stock[row.did]
              : null,
          onRead: d.readReady ? () => d.readIdentifiers([row]) : null,
        ),
    ]);
  }

  Future<void> _export(List<ReadIdentifier> definitions) async {
    final rows = [
      for (final r in definitions)
        if (widget.d.identifierResults[r.key] != null)
          widget.d.identifierResults[r.key]!.toJson(),
    ];
    try {
      final path = await FilePicker.saveFile(
        fileName: 'OpenOLA-${widget.kind.name}.json',
        bytes: Uint8List.fromList(
          utf8.encode(
            const JsonEncoder.withIndent('  ').convert({
              'schema': 'openola.ecu.read.v1',
              'demo': widget.d.demo,
              'items': rows,
            }),
          ),
        ),
      );
      if (mounted) {
        setState(
          () => status = path == null
              ? 'Export cancelled.'
              : 'Decoded report saved.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => status = 'Export failed: $e');
    }
  }
}

class IdentifierCard extends StatefulWidget {
  const IdentifierCard({
    super.key,
    required this.definition,
    this.result,
    this.reference,
    this.onRead,
  });
  final ReadIdentifier definition;
  final IdentifierResult? result;
  final String? reference;
  final VoidCallback? onRead;
  @override
  State<IdentifierCard> createState() => _IdentifierCardState();
}

class _IdentifierCardState extends State<IdentifierCard> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final d = widget.definition, r = widget.result;
    return Glass(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceRow(
            d.title,
            '${d.key} · ${r == null
                ? 'Not read'
                : r.error != null
                ? 'Unavailable'
                : '${r.values.length} decoded fields'}',
            CupertinoIcons.square_stack_3d_up,
            r?.error != null ? orange : teal,
            trailing: Icon(
              expanded
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              size: 15,
              color: muted(context),
            ),
            onTap: () => setState(() => expanded = !expanded),
          ),
          if (expanded) ...[
            if (r?.error != null)
              Text(r!.error!, style: TextStyle(color: danger, fontSize: 12)),
            if (r?.bytes != null) ...[
              Text(
                r!.time.toLocal().toString().split('.').first,
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
              for (final value in r.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.name,
                        style: TextStyle(color: muted(context), fontSize: 12),
                      ),
                      const SizedBox(height: 3),
                      SelectableText(
                        '${value.value ?? 'Missing from response'}${value.unit.isEmpty ? '' : ' ${value.unit}'}',
                        style: TextStyle(
                          color: ink(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              SelectableText(
                'Raw ${hex(r.bytes!)}',
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
            ],
            if (widget.reference != null)
              Text(
                'S1 Pro reference: ${widget.reference}',
                style: TextStyle(color: muted(context), fontSize: 12),
              ),
            const SizedBox(height: 8),
            GlassButton('Read this identifier', onPressed: widget.onRead),
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class ReadContext extends StatelessWidget {
  const ReadContext({super.key, required this.d});
  final Diagnostics d;
  @override
  Widget build(BuildContext context) => Text(
    !d.connected
        ? 'Connect to a scooter, or use Try Demo.'
        : d.demo
        ? 'Demo reads are simulated.'
        : !d.bench || d.mode != 'SERVICE'
        ? 'Park, unplug the charger and enter Service mode from Connection before reading.'
        : 'Read-only requests · live monitoring resumes afterwards.',
    style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
  );
}

class ReadProgress extends StatelessWidget {
  const ReadProgress({super.key, required this.d});
  final Diagnostics d;
  @override
  Widget build(BuildContext context) => Section(
    'Reading ${d.readDone}/${d.readTotal}',
    children: [
      Text(d.readLabel, style: TextStyle(color: muted(context), fontSize: 12)),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: d.readTotal == 0 ? 0 : d.readDone / d.readTotal,
          minHeight: 5,
          backgroundColor: fill(context),
          color: accent,
        ),
      ),
      GlassButton(
        d.readCancelled ? 'Stopping after current request…' : 'Cancel read',
        onPressed: d.readCancelled ? null : d.cancelRead,
      ),
    ],
  );
}
