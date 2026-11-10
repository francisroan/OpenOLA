import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:share_plus/share_plus.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/session.dart';
import '../design/glass.dart';
import '../design/dashboard.dart';
import '../design/signal_chart.dart';
import 'core.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key, required this.d});
  final Diagnostics d;
  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  final search = TextEditingController();
  List<File> files = [];
  Map<String, List<(double, double)>> plots = {};
  final selected = <String>{};
  String status = '';
  bool working = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _refresh();
    final loaded = widget.d.openedSession;
    if (loaded != null) {
      selected.addAll(loaded.signals.keys.take(2));
      _plot();
    }
  }

  @override
  void dispose() {
    generation++;
    search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final result = await widget.d.session.library();
      if (mounted) setState(() => files = result);
    } catch (e) {
      if (mounted) setState(() => status = 'Session storage unavailable: $e');
    }
  }

  Future<void> _work(Future<void> Function() run) async {
    if (working) return;
    setState(() {
      working = true;
      status = '';
    });
    try {
      await run();
    } catch (e) {
      if (mounted) setState(() => status = '$e');
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  Future<void> _open(File file) async {
    final summary = await SessionRecorder.summarize(file);
    if (!mounted) return;
    setState(() {
      widget.d.openedSession = summary;
      selected.clear();
      selected.addAll(summary.signals.keys.take(2));
      plots = {};
    });
    await _plot();
  }

  Future<void> _plot() async {
    final loaded = widget.d.openedSession;
    if (loaded == null) return;
    final token = ++generation;
    try {
      final result = await SessionRecorder.series(loaded.file, selected);
      if (mounted && token == generation) setState(() => plots = result);
    } catch (e) {
      if (mounted && token == generation) {
        setState(() => status = 'Could not load plot: $e');
      }
    }
  }

  Future<void> _import() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jsonl'],
    );
    if (picked.isEmpty) return;
    final row = picked.single;
    if (row.path == null) {
      throw const FormatException(
        'This provider did not return a local session file.',
      );
    }
    final source = File(row.path!);
    await SessionRecorder.summarize(
      source,
    ); // Reject other JSONL formats before copying.
    final folder = await widget.d.session.folder();
    final copy = await source.copy(
      '${folder.path}${Platform.pathSeparator}Imported-${DateTime.now().microsecondsSinceEpoch}.jsonl',
    );
    await _open(copy);
    await _refresh();
  }

  Future<void> _export(bool csv) async {
    final summary = widget.d.openedSession;
    if (summary == null) return;
    File source = summary.file;
    if (csv) {
      source = File(
        '${(await widget.d.session.folder()).path}${Platform.pathSeparator}export.csv',
      );
      await SessionRecorder.exportCsv(summary, source);
    }
    if (await source.length() > 64 * 1024 * 1024) {
      throw const FormatException(
        'Use Share session for recordings above 64 MB.',
      );
    }
    final path = await FilePicker.saveFile(
      fileName: summary.name.replaceAll('.jsonl', csv ? '.csv' : '.jsonl'),
      bytes: Uint8List.fromList(await source.readAsBytes()),
    );
    if (mounted) {
      setState(
        () => status = path == null
            ? 'Export cancelled.'
            : '${csv ? 'CSV' : 'Session'} saved.',
      );
    }
  }

  Future<void> _share() async {
    final file = widget.d.openedSession?.file;
    if (file == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'OpenOLA session',
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d, r = d.session, loaded = d.openedSession;
    final names = (loaded?.signals.keys.toList() ?? [])..sort();
    final filtered = names.where(
      (name) => name.toLowerCase().contains(search.text.toLowerCase()),
    );
    return PageStack([
      const Heading(
        'Recorder',
        'Capture a ride or diagnosis. Reopen it here or on your computer.',
      ),
      Section(
        r.active ? 'Recording session' : 'Record a session',
        icon: CupertinoIcons.recordingtape,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                r.active
                    ? 'Recording'
                    : r.closing
                    ? 'Saving'
                    : 'Ready',
                color: r.active ? danger : teal,
              ),
              StatusChip('${r.samples} samples'),
              StatusChip('${r.signals.length} signals'),
              StatusChip('${r.duration.toStringAsFixed(0)} s'),
            ],
          ),
          GlassButton(
            r.active ? 'Stop & save' : 'Start recording',
            primary: true,
            icon: r.active
                ? CupertinoIcons.stop_circle
                : CupertinoIcons.recordingtape,
            onPressed:
                working || r.closing || d.busy || (!r.active && !d.connected)
                ? null
                : () => _work(() async {
                    if (r.active) {
                      await d.stopSession();
                      if (r.file != null && r.samples > 0) await _open(r.file!);
                      await _refresh();
                    } else {
                      await d.startSession();
                    }
                  }),
          ),
          Text(
            'Every fresh numeric broadcast is saved each second as desktop-compatible JSONL. Keep the app in the foreground; leaving it stops and saves the session. A paused stream leaves gaps.',
            style: TextStyle(color: muted(context), fontSize: 12, height: 1.5),
          ),
          if (r.active && !d.live)
            Text(
              'Live monitor is paused. Resume it to capture all broadcasts.',
              style: TextStyle(color: orange, fontSize: 12),
            ),
          if (r.active)
            GlassButton(
              d.live ? 'Pause live capture' : 'Resume live capture',
              onPressed: d.busy ? null : () => d.liveMode(!d.live),
            ),
          if (r.error != null)
            Text(r.error!, style: const TextStyle(color: danger)),
        ],
      ),
      Section(
        'Session library',
        icon: CupertinoIcons.folder,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassButton(
                'Open JSONL',
                compact: true,
                icon: CupertinoIcons.folder,
                onPressed: working ? null : () => _work(_import),
              ),
              GlassButton(
                'Refresh',
                compact: true,
                onPressed: working ? null : _refresh,
              ),
            ],
          ),
          if (files.isEmpty)
            Text(
              'Saved recordings will appear here. You can also open a desktop recording without connecting.',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
          for (final file in files)
            WorkspaceRow(
              file.uri.pathSegments.last,
              'Saved on this device',
              CupertinoIcons.doc,
              teal,
              onTap: working || (r.active && file.path == r.file?.path)
                  ? null
                  : () => _work(() => _open(file)),
            ),
        ],
      ),
      if (working)
        const Glass(
          child: Row(
            children: [
              CupertinoActivityIndicator(),
              SizedBox(width: 12),
              Expanded(child: Text('Preparing session…')),
            ],
          ),
        ),
      if (status.isNotEmpty)
        Glass(
          child: Text(status, style: TextStyle(color: muted(context))),
        ),
      if (loaded != null) ...[
        Section(
          'Opened recording',
          icon: CupertinoIcons.chart_bar,
          children: [
            Text(
              loaded.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                StatusChip('${loaded.samples} samples'),
                StatusChip('${loaded.duration.toStringAsFixed(1)} s'),
                StatusChip('${loaded.signals.length} signals'),
                if (loaded.meta['demo'] == true)
                  const StatusChip('Simulated', color: purple),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                GlassButton(
                  'Save JSONL',
                  compact: true,
                  onPressed: working ? null : () => _work(() => _export(false)),
                ),
                GlassButton(
                  'Export CSV',
                  compact: true,
                  onPressed: working ? null : () => _work(() => _export(true)),
                ),
                GlassButton(
                  'Share session',
                  compact: true,
                  onPressed: working ? null : () => _work(_share),
                ),
              ],
            ),
          ],
        ),
        for (final name in selected)
          Section(
            name,
            children: [
              SignalChart(
                plots[name] ?? [],
                unit: ((loaded.meta['units'] as Map?)?[name] ?? '').toString(),
                color: teal,
              ),
            ],
          ),
        GlassField(
          controller: search,
          label: 'Find a recorded signal',
          onChanged: (_) => setState(() {}),
        ),
        Text(
          'Select up to six signals. Each plot has its own scale. Preview is reduced to at most 1,500 points; exports keep every sample.',
          style: TextStyle(color: muted(context), fontSize: 12, height: 1.5),
        ),
        for (final name in filtered)
          Glass(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: GlassToggle(
              name,
              '${loaded.signals[name]!.count} samples · min ${loaded.signals[name]!.minimum.toStringAsFixed(2)} · max ${loaded.signals[name]!.maximum.toStringAsFixed(2)} · last ${loaded.signals[name]!.last.toStringAsFixed(2)}',
              selected.contains(name),
              working || (!selected.contains(name) && selected.length >= 6)
                  ? null
                  : (v) {
                      setState(() {
                        v ? selected.add(name) : selected.remove(name);
                      });
                      _plot();
                    },
            ),
          ),
      ],
    ]);
  }
}
