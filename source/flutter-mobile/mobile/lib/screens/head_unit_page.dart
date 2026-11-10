import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design/glass.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/head_unit_tools.dart';
import '../diagnostics/split_package.dart';
import 'core.dart';

class HeadUnitPage extends StatefulWidget {
  const HeadUnitPage({super.key, required this.d});

  final Diagnostics d;

  @override
  State<HeadUnitPage> createState() => _HeadUnitPageState();
}

class _HeadUnitPageState extends State<HeadUnitPage> {
  final command = TextEditingController();
  final appSearch = TextEditingController();
  String? apkName;
  String? apkPath;
  ApkPackage? package;

  final selectedApps = <String>{};

  Diagnostics get d => widget.d;

  @override
  void dispose() {
    command.dispose();
    appSearch.dispose();
    super.dispose();
  }

  Iterable<HeadUnitApp> get visibleApps {
    final query = appSearch.text.trim().toLowerCase();
    if (query.isEmpty) return d.headUnitApps;
    return d.headUnitApps.where(
      (app) =>
          app.label.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query) ||
          app.component.toLowerCase().contains(query),
    );
  }

  Future<void> pickApk() async {
    final picked = await FilePicker.pickFiles();
    if (picked.isEmpty || picked.single.path == null || !mounted) return;
    final file = picked.single;
    if (!ApkPackage.supports(file.name)) {
      d.message = 'Choose an .apk, .apks, .xapk or .apkm file';
      d.emit();
      return;
    }
    try {
      final bytes = await File(file.path!).readAsBytes();
      final parsed = ApkPackage.parse(file.name, bytes);
      if (!mounted) return;
      setState(() {
        apkName = file.name;
        apkPath = file.path;
        package = parsed;
      });
    } on FormatException catch (error) {
      d.message = error.message;
      d.emit();
    }
  }

  Future<void> installPackage() async {
    await d.installHeadUnitPackage(package!);
  }

  Future<void> uninstallApp(HeadUnitApp app) async {
    final ok = await confirmGlass(
      context,
      'Uninstall ${app.label}?',
      'Removes ${app.packageName} from the scooter head unit. Ola, Android and '
          'vendor system apps are refused. Slide to uninstall.',
    );
    if (!ok || !mounted) return;
    await d.uninstallHeadUnitApp(app.packageName, app.label);
    if (mounted) setState(() {});
  }

  /// Pulls every ticked app into one folder (chosen once).
  Future<void> pullSelected() async {
    final apps = d.headUnitApps
        .where((a) => selectedApps.contains(a.packageName))
        .toList();
    if (apps.isEmpty) return;
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Save ${apps.length} APK${apps.length == 1 ? '' : 's'} to…',
    );
    if (folder == null || !mounted) return;
    for (final app in apps) {
      if (!mounted) return;
      await d.pullHeadUnitApp(app.packageName, folder, app.label);
      if (d.message.toLowerCase().contains('cancel')) break;
      if (mounted) setState(() {});
    }
  }

  /// Uninstalls every ticked app after one slide confirmation.
  Future<void> uninstallSelected() async {
    final apps = d.headUnitApps
        .where((a) => selectedApps.contains(a.packageName))
        .toList();
    if (apps.isEmpty) return;
    final ok = await confirmGlass(
      context,
      'Uninstall ${apps.length} app${apps.length == 1 ? '' : 's'}?',
      '${apps.map((a) => a.label).join(', ')}\n\nOla, Android and vendor '
          'system apps are refused. Slide to uninstall.',
    );
    if (!ok || !mounted) return;
    for (final app in apps) {
      await d.uninstallHeadUnitApp(app.packageName, app.label);
      selectedApps.remove(app.packageName);
      if (mounted) setState(() {});
    }
  }

  Future<void> pullApp(HeadUnitApp app) async {
    final folder = await FilePicker.getDirectoryPath(
      dialogTitle: 'Save ${app.label} APK to…',
    );
    if (folder == null || !mounted) return;
    await d.pullHeadUnitApp(app.packageName, folder, app.label);
    if (mounted) setState(() {});
  }

  Future<void> runCommand() async {
    final value = command.text.trim();
    if (value.isEmpty) return;
    final confirmed = await confirmGlass(
      context,
      d.headUnitTransport == HeadUnitTransport.grpc
          ? 'Run as root on the head unit?'
          : 'Run through direct ADB?',
      d.headUnitTransport == HeadUnitTransport.grpc
          ? 'This runs `$value` as uid 0 through the scooter diagnostic service. '
                'A wrong command can stop the dashboard or alter system data. Slide to run.'
          : 'This runs `$value` through the authenticated adbd shell. Its privilege '
                'depends on the scooter build. A wrong command can stop the dashboard '
                'or alter system data. Slide to run.',
    );
    if (!confirmed || !mounted) return;
    await d.adbCommand(value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => PageStack([
    const Heading(
      'Head-unit console',
      'Terminal, app launcher and verified APK installer.',
    ),
    Section(
      'Connection',
      icon: CupertinoIcons.link,
      children: [
        Text(
          d.demo
              ? 'Demo · root bridge simulated'
              : d.connected
              ? 'Connected · root bridge'
              : 'Not connected',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Text(
          'Commands, installs, APK pulls and uninstalls run through the scooter’s '
          'diagnostic service (WifiCanRpc.ExecuteADBCommand) as root. No separate '
          'ADB setup is needed.',
          style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
        ),
      ],
    ),
    Section(
      'Head-unit terminal',
      icon: CupertinoIcons.chevron_left_slash_chevron_right,
      children: [
        GlassField(
          key: const ValueKey('head-unit-command'),
          controller: command,
          label: 'One-shot shell command',
          enabled: !d.busy,
          suffix: IconButton(
            tooltip: 'Run shell command',
            onPressed: d.busy || !d.headUnitReady ? null : runCommand,
            icon: const Icon(CupertinoIcons.play_fill),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GlassButton(
              'Check identity',
              compact: true,
              onPressed: d.busy || !d.headUnitReady
                  ? null
                  : () async {
                      await d.adbCommand('id');
                      if (mounted) setState(() {});
                    },
            ),
            GlassButton(
              'Run command',
              primary: true,
              compact: true,
              onPressed: d.busy || !d.headUnitReady ? null : runCommand,
            ),
          ],
        ),
        if (d.adbOutput.isNotEmpty)
          Container(
            key: const ValueKey('head-unit-output'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fill(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              d.adbOutput,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
      ],
    ),
    Section(
      'App launcher',
      icon: CupertinoIcons.square_grid_2x2,
      children: [
        Text(
          'Discover launcher activities installed on the scooter, bring one '
          'to the foreground, or pull its APK (all splits) to a folder you '
          'choose on this phone. Pulling only reads from the scooter.',
          style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
        ),
        GlassButton(
          'Launch OLA HMI',
          key: const ValueKey('launch-ola-hmi'),
          icon: CupertinoIcons.play_fill,
          primary: true,
          onPressed: d.busy || !d.headUnitReady ? null : d.launchOlaHmi,
        ),
        Row(
          children: [
            Expanded(
              child: GlassField(
                controller: appSearch,
                label: 'Search by app or package',
                enabled: !d.busy,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 19),
              child: IconButton(
                tooltip: 'Refresh installed apps',
                onPressed: d.busy || !d.headUnitReady
                    ? null
                    : () async {
                        await d.refreshHeadUnitApps();
                        if (mounted) setState(() {});
                      },
                icon: const Icon(CupertinoIcons.refresh),
              ),
            ),
          ],
        ),
        if (d.pullStartedAt != null) ...[
          _TransferBar(
            key: const ValueKey('pull-progress'),
            fraction: d.pullProgress,
            status: d.pullStatus,
            detail: d.pullDetail,
            indeterminate: d.pullIndeterminate,
            started: d.pullStartedAt!,
            finished: d.pullFinishedAt,
            onCancel: d.cancelOperation,
          ),
          if (d.pulledFiles.isNotEmpty)
            Text(
              d.pulledFiles.length == 1
                  ? d.pulledFiles.single
                  : '${d.pulledFiles.length} files in ${d.pulledFiles.first.substring(0, d.pulledFiles.first.lastIndexOf(RegExp(r'[\\/]')))}',
              style: TextStyle(color: muted(context), fontSize: 11),
            ),
        ],
        if (d.headUnitApps.isEmpty)
          Text(
            'Tap refresh to read launchable apps.',
            style: TextStyle(color: muted(context)),
          )
        else if (visibleApps.isEmpty)
          Text('No matching apps.', style: TextStyle(color: muted(context)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(
                onPressed: d.busy
                    ? null
                    : () => setState(
                        () => selectedApps.addAll(
                          visibleApps.map((a) => a.packageName),
                        ),
                      ),
                child: const Text('Select all'),
              ),
              TextButton(
                onPressed: selectedApps.isEmpty || d.busy
                    ? null
                    : () => setState(selectedApps.clear),
                child: const Text('Clear'),
              ),
              TextButton(
                key: const ValueKey('pull-selected'),
                onPressed: selectedApps.isEmpty || d.busy || !d.headUnitReady
                    ? null
                    : pullSelected,
                child: Text('Pull selected (${selectedApps.length})'),
              ),
              TextButton(
                key: const ValueKey('uninstall-selected'),
                onPressed: selectedApps.isEmpty || d.busy || !d.headUnitReady
                    ? null
                    : uninstallSelected,
                child: Text(
                  'Uninstall selected (${selectedApps.length})',
                  style: TextStyle(color: selectedApps.isEmpty ? null : danger),
                ),
              ),
            ],
          ),
        ConstrainedBox(
          // About five rows tall; the list scrolls inside instead of
          // stretching the whole page.
          constraints: const BoxConstraints(maxHeight: 340),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final app in visibleApps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: BoxDecoration(
                      color: fill(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          key: ValueKey('select-${app.packageName}'),
                          value: selectedApps.contains(app.packageName),
                          visualDensity: VisualDensity.compact,
                          onChanged: d.busy
                              ? null
                              : (value) => setState(() {
                                  if (value == true) {
                                    selectedApps.add(app.packageName);
                                  } else {
                                    selectedApps.remove(app.packageName);
                                  }
                                }),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                app.packageName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: muted(context),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Launch ${app.label}',
                          onPressed: d.busy || !d.headUnitReady
                              ? null
                              : () => d.launchHeadUnitApp(app),
                          icon: const Icon(CupertinoIcons.play_fill),
                        ),
                        PopupMenuButton<String>(
                          key: ValueKey('actions-${app.packageName}'),
                          tooltip: 'More actions for ${app.label}',
                          enabled: !d.busy && d.headUnitReady,
                          icon: const Icon(CupertinoIcons.ellipsis_circle),
                          onSelected: (value) {
                            if (value == 'pull') pullApp(app);
                            if (value == 'uninstall') uninstallApp(app);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'pull',
                              child: Text('Pull APK to this phone'),
                            ),
                            PopupMenuItem(
                              value: 'uninstall',
                              child: Text('Uninstall from scooter…'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
    Section(
      'App installer',
      icon: CupertinoIcons.square_arrow_down,
      children: [
        Text(
          d.headUnitTransport == HeadUnitTransport.grpc
              ? 'Supports .apk and split bundles (.apks, .xapk, .apkm). Uploads '
                    'through the gRPC root bridge, verifies size and SHA-256 of '
                    'every file on the head unit, installs them in one '
                    'package-manager session (`-r`), then removes only OpenOLA '
                    'upload files.'
              : 'Supports .apk and split bundles (.apks, .xapk, .apkm). Streams '
                    'the files over the authenticated ADB protocol with a live '
                    'byte counter, then installs them in one session (`-r`).',
          style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
        ),
        GlassButton(
          apkName == null ? 'Choose APK or bundle' : 'Selected: $apkName',
          key: const ValueKey('choose-head-unit-apk'),
          icon: CupertinoIcons.doc,
          onPressed: d.busy ? null : pickApk,
        ),
        if (package != null)
          Text(
            package!.isSplit
                ? '${package!.parts.length} APK files · ${(package!.totalBytes / 1048576).toStringAsFixed(1)} MB'
                      '${package!.ignoredEntries > 0 ? ' · ${package!.ignoredEntries} non-APK entries ignored' : ''}'
                : '${(package!.totalBytes / 1048576).toStringAsFixed(1)} MB',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
        if (d.apkInstallStartedAt != null)
          _TransferBar(
            key: const ValueKey('install-progress'),
            fraction: d.apkInstallProgress,
            status: d.apkInstallStatus,
            detail: d.apkInstallDetail,
            indeterminate: d.apkInstallIndeterminate,
            started: d.apkInstallStartedAt!,
            finished: d.apkInstallFinishedAt,
            onCancel: d.cancelOperation,
          ),
        GlassButton(
          'Upload, verify and install',
          key: const ValueKey('install-head-unit-apk'),
          destructive: true,
          onPressed: d.busy || apkName == null || package == null
              ? null
              : () async {
                  if (await confirmGlass(
                    context,
                    'Install $apkName on the scooter head unit?',
                    'This changes Android software on the scooter. Confirm the '
                        'APK source, keep the scooter parked, and do not '
                        'disconnect Wi-Fi during the upload. Slide to install.',
                  )) {
                    await installPackage();
                    if (mounted) setState(() {});
                  }
                },
        ),
      ],
    ),
  ]);
}

/// Progress readout for a transfer: bar, status, and "42% · 1:12 elapsed ·
/// ~1:40 left". Updates every second while running; the ETA is hidden for
/// steps with no measurable progress (package-manager install, verification).
class _TransferBar extends StatefulWidget {
  const _TransferBar({
    super.key,
    this.onCancel,
    required this.fraction,
    required this.status,
    required this.detail,
    required this.indeterminate,
    required this.started,
    required this.finished,
  });

  final double fraction;
  final String status, detail;
  final bool indeterminate;
  final DateTime started;
  final DateTime? finished;
  final VoidCallback? onCancel;

  @override
  State<_TransferBar> createState() => _TransferBarState();
}

class _TransferBarState extends State<_TransferBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.finished == null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final running = widget.finished == null;
    final elapsed = (widget.finished ?? DateTime.now()).difference(
      widget.started,
    );
    final line = running
        ? progressLine(
            widget.fraction,
            elapsed,
            showEta: !widget.indeterminate,
          ).replaceFirst(
            widget.indeterminate ? RegExp(r'^\d+% · ') : RegExp(r'^$'),
            '',
          )
        : '${widget.fraction >= 1 ? 'Finished' : 'Stopped'} in ${formatDuration(elapsed)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (running || widget.fraction < 1)
          LinearProgressIndicator(
            value: running && widget.indeterminate ? null : widget.fraction,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        const SizedBox(height: 6),
        Text(
          widget.status,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (widget.detail.isNotEmpty)
          Text(
            widget.detail,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
        Text(line, style: TextStyle(color: muted(context), fontSize: 12)),
        if (running && widget.onCancel != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onCancel,
              child: const Text('Cancel', style: TextStyle(color: danger)),
            ),
          ),
      ],
    );
  }
}
