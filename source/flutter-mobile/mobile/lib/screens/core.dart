import 'model_diagnostics.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'identifiers_page.dart';
import 'fault_guide_page.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../design/glass.dart';
import '../design/glass_quality.dart';
import '../design/dashboard.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/fault_explanations.dart';
import '../diagnostics/preferences.dart';
import '../diagnostics/report.dart';
import '../protocol/can.dart';
import '../protocol/wifi_can.dart';

/// Ensures the scooter is in Service mode before a gated action. Returns true
/// when already in Service mode (or demo). Otherwise it explains what is needed
/// and, if the user agrees, switches the scooter into Service mode and returns
/// whether that took — so callers prompt the user instead of silently disabling
/// a control.
Future<bool> requireServiceMode(BuildContext context, Diagnostics d) async {
  if (d.demo || (d.bench && d.mode == 'SERVICE')) return true;
  if (!d.connected) {
    await confirmGlass(
      context,
      'Connect first',
      'Connect to your scooter before using this — join its Wi-Fi and connect '
          'from the Home screen.',
    );
    return false;
  }
  final ok = await confirmGlass(
    context,
    'Enter Service mode?',
    'This needs the scooter in Service mode. Park it, keep the charger '
        'unplugged, then continue to switch it into Service mode now.',
  );
  if (!ok) return false;
  await d.serviceMode(true);
  return d.bench && d.mode == 'SERVICE';
}

class PageStack extends StatelessWidget {
  const PageStack(this.children, {super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 16),
        children[i],
      ],
    ],
  );
}

String number(double? value, [int digits = 1]) =>
    value == null ? '—' : value.toStringAsFixed(digits);
String codeCount(int count) => '$count ${count == 1 ? 'code' : 'codes'}';

Color faultSeverityColor(FaultSeverity severity) => switch (severity) {
  FaultSeverity.information => accent,
  FaultSeverity.attention => orange,
  FaultSeverity.stopSafely => danger,
};

Future<void> showFaultExplanation(
  BuildContext context, {
  required String code,
  required String description,
  required String source,
  bool meaningVerified = true,
}) {
  final explanation = explainFault(
    code: code,
    description: description,
    source: source,
  );
  final tone = faultSeverityColor(explanation.severity);
  return glassSheet(
    context,
    PageStack([
      Heading(code, description),
      if (!meaningVerified)
        const Text(
          '(i) Catalog meaning unverified for this scooter model and software. Use the raw code and status for service diagnosis.',
        ),
      Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          StatusChip(explanation.subsystem, color: accent),
          StatusChip(explanation.severityLabel, color: tone),
        ],
      ),
      Section(
        'What it may mean',
        icon: CupertinoIcons.info_circle,
        children: [
          Text(explanation.meaning, style: const TextStyle(height: 1.5)),
        ],
      ),
      Section(
        'What to do',
        icon: CupertinoIcons.checkmark_shield,
        children: [
          Text(explanation.nextStep, style: const TextStyle(height: 1.5)),
          Text(
            'Offline ${explanation.inferred ? 'category guidance' : 'curated guidance'} from the bundled fault library. This is not a confirmed diagnosis.',
            style: TextStyle(color: muted(context), fontSize: 11, height: 1.4),
          ),
        ],
      ),
      GlassButton(
        'Done',
        primary: true,
        onPressed: () => Navigator.pop(context),
      ),
    ]),
  );
}

class ConnectPage extends StatefulWidget {
  const ConnectPage({super.key, required this.d});
  final Diagnostics d;
  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

enum _ConnectionSetup { scooterWifi, phoneHotspot, sharedWifi }

class _ConnectPageState extends State<ConnectPage> {
  late final TextEditingController host = TextEditingController(
    // No baked-in address — scan the scooter QR or type it; the last one used
    // is remembered. (Never ship a personal scooter IP in the source.)
    text: widget.d.prefs.store.getString('host') ?? '',
  );
  late final TextEditingController port = TextEditingController(
    text: '${widget.d.prefs.store.getInt('port') ?? 50005}',
  );
  late bool secure = widget.d.prefs.store.getBool('secure') ?? false;
  late bool s1xTcp = widget.d.prefs.store.getBool('s1xTcp') ?? false;
  late bool phoneHotspot =
      widget.d.prefs.store.getBool('phoneHotspot') ?? false;
  late _ConnectionSetup setup = _restoreSetup();
  bool options = false;
  bool discovering = false;
  String error = '';

  _ConnectionSetup _restoreSetup() {
    final saved = widget.d.prefs.store.getString('connectionSetup');
    return _ConnectionSetup.values
            .where((value) => value.name == saved)
            .firstOrNull ??
        ((widget.d.prefs.store.getBool('phoneHotspot') ?? false)
            ? _ConnectionSetup.phoneHotspot
            : _ConnectionSetup.scooterWifi);
  }

  Future<void> selectSetup(_ConnectionSetup value) async {
    setState(() {
      setup = value;
      phoneHotspot = value == _ConnectionSetup.phoneHotspot;
      error = '';
    });
    await widget.d.prefs.store.setString('connectionSetup', value.name);
    await widget.d.prefs.store.setBool('phoneHotspot', phoneHotspot);
  }

  (String, String, IconData) get setupCopy => switch (setup) {
    _ConnectionSetup.scooterWifi => (
      'Scooter Wi-Fi',
      '1. Turn on the scooter’s diagnostic hotspot.\n'
          '2. Join that Wi-Fi in your phone settings.\n'
          '3. Return here and connect.',
      CupertinoIcons.wifi,
    ),
    _ConnectionSetup.phoneHotspot => (
      'Phone hotspot',
      '1. Turn on this phone’s hotspot.\n'
          '2. Let the scooter join the hotspot.\n'
          '3. Return here and connect.',
      CupertinoIcons.antenna_radiowaves_left_right,
    ),
    _ConnectionSetup.sharedWifi => (
      'Shared Wi-Fi',
      '1. Connect the phone and scooter to the same Wi-Fi.\n'
          '2. Keep mobile data available if needed.\n'
          '3. Return here and connect.',
      CupertinoIcons.globe,
    ),
  };
  @override
  void dispose() {
    host.dispose();
    port.dispose();
    super.dispose();
  }

  Future<void> connect(bool demo) async {
    final p = int.tryParse(port.text);
    // Demo is fully simulated — no scooter address needed.
    if (!demo &&
        (host.text.trim().isEmpty ||
            host.text.contains(RegExp(r'\s')) ||
            p == null ||
            p < 1 ||
            p > 65535)) {
      setState(() => error = 'Enter a valid address and port (1–65535).');
      return;
    }
    setState(() => error = '');
    await widget.d.connect(
      host.text,
      p ?? 0,
      secure: secure,
      simulated: demo,
      phoneHotspot: phoneHotspot,
      s1xTcp: s1xTcp,
    );
  }

  Future<void> discoverAndConnect() async {
    setState(() {
      discovering = true;
      error = '';
    });
    try {
      final p = int.tryParse(port.text) ?? 50005;
      // IPv4 first (Gen1: scooter hotspot, phone hotspot, shared Wi-Fi), then
      // IPv6 (Gen2/3). Either list may be empty or fail without blocking the other.
      var ipv4 = const <String>[];
      var ipv6 = const <String>[];
      try {
        ipv4 = await WifiCan.discoverIpv4Hosts(
          port: p,
          phoneHotspot: phoneHotspot,
        );
      } catch (_) {}
      try {
        ipv6 = await WifiCan.discoverIpv6Hosts(port: p);
      } catch (_) {}
      final candidates = [...ipv4, ...ipv6];
      if (candidates.isEmpty) {
        setState(() {
          error = switch (setup) {
            _ConnectionSetup.phoneHotspot =>
              'No scooter found yet. Wait for it to join this phone’s hotspot, then retry.',
            _ConnectionSetup.sharedWifi =>
              'No scooter found. Check that the phone and scooter are on the same Wi-Fi.',
            _ConnectionSetup.scooterWifi =>
              'No scooter found. Join the scooter Wi-Fi in phone settings, then retry.',
          };
        });
        return;
      }
      for (final candidate in candidates) {
        if (!mounted) return;
        setState(() => host.text = candidate);
        await widget.d.connect(
          candidate,
          p,
          secure: secure,
          phoneHotspot: phoneHotspot,
          s1xTcp: s1xTcp,
        );
        if (widget.d.connected) return;
      }
      if (mounted) {
        setState(() {
          error =
              'Found ${candidates.length} possible scooter address${candidates.length == 1 ? '' : 'es'}, but none answered on port $p.';
        });
      }
    } on PlatformException catch (exception) {
      if (mounted) {
        setState(() => error = exception.message ?? 'IPv6 discovery failed.');
      }
    } finally {
      if (mounted) setState(() => discovering = false);
    }
  }

  /// Every connect searches the whole local network (IPv4 first, then IPv6), so
  /// a stale remembered address can never get in the way. Typing an address in
  /// the manual section still connects to exactly that address.
  Future<void> primaryConnect() => discoverAndConnect();

  @override
  Widget build(BuildContext context) {
    final connecting = widget.d.connection == Connection.connecting;
    final copy = setupCopy;
    return SingleChildScrollView(
      child: PageStack([
        const Heading(
          'Connect your scooter',
          'Choose how the phone and scooter are on the same network.',
        ),
        Glass(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const AppMark(size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OpenOLA',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Local scooter health and diagnostics',
                          style: TextStyle(color: muted(context)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'How is your scooter connected?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ConnectionChoice(
                        key: const ValueKey('setup-scooter-wifi'),
                        label: 'Scooter Wi-Fi',
                        icon: CupertinoIcons.wifi,
                        selected: setup == _ConnectionSetup.scooterWifi,
                        onTap: connecting
                            ? null
                            : () => selectSetup(_ConnectionSetup.scooterWifi),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ConnectionChoice(
                        key: const ValueKey('setup-phone-hotspot'),
                        label: 'Phone hotspot',
                        icon: CupertinoIcons.antenna_radiowaves_left_right,
                        selected: setup == _ConnectionSetup.phoneHotspot,
                        onTap: connecting
                            ? null
                            : () => selectSetup(_ConnectionSetup.phoneHotspot),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ConnectionChoice(
                        key: const ValueKey('setup-shared-wifi'),
                        label: 'Shared Wi-Fi',
                        icon: CupertinoIcons.globe,
                        selected: setup == _ConnectionSetup.sharedWifi,
                        onTap: connecting
                            ? null
                            : () => selectSetup(_ConnectionSetup.sharedWifi),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(copy.$3, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            copy.$1,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            copy.$2,
                            style: TextStyle(
                              color: muted(context),
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GlassToggle(
                'S1X Plus Phase 2 (TCP)',
                'Read-only live monitoring. ECU reads and scooter commands are disabled. Use this only for the Phase 2 S1X Plus.',
                s1xTcp,
                connecting
                    ? null
                    : (value) => setState(() {
                        s1xTcp = value;
                        if (value) secure = false;
                      }),
              ),
              const SizedBox(height: 16),
              if (error.isNotEmpty) ...[
                Text(error, style: const TextStyle(color: danger)),
                const SizedBox(height: 10),
              ],
              GlassButton(
                connecting
                    ? 'Connecting…'
                    : discovering
                    ? 'Searching…'
                    : 'Find scooter automatically',
                key: const ValueKey('primary-connect'),
                primary: true,
                icon: CupertinoIcons.search,
                onPressed: connecting || discovering ? null : primaryConnect,
              ),
              if (connecting)
                GlassButton(
                  'Cancel connection',
                  onPressed: widget.d.disconnect,
                ),
            ],
          ),
        ),
        Section(
          'Explore first',
          icon: CupertinoIcons.play_circle,
          children: [
            Text(
              'See every workspace with simulated readings. Demo never connects to or controls a scooter.',
              style: TextStyle(color: muted(context)),
            ),
            GlassButton(
              'Explore Demo',
              key: const ValueKey('start-demo'),
              icon: CupertinoIcons.play_circle,
              onPressed: connecting ? null : () => connect(true),
            ),
          ],
        ),
        Section(
          'Manual connection',
          icon: CupertinoIcons.slider_horizontal_3,
          children: [
            GlassButton(
              options ? 'Hide manual options' : 'Enter address or scan QR',
              compact: true,
              icon: options
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
              onPressed: connecting
                  ? null
                  : () => setState(() => options = !options),
            ),
            if (options) ...[
              GlassField(
                key: const ValueKey('manual-host'),
                controller: host,
                label: 'Scooter address',
                enabled: !connecting,
                onChanged: (_) => setState(() => error = ''),
                suffix: IconButton(
                  tooltip: 'Scan scooter QR',
                  icon: const Icon(
                    CupertinoIcons.qrcode_viewfinder,
                    color: accent,
                  ),
                  onPressed: connecting ? null : _scanQr,
                ),
              ),
              GlassField(
                controller: port,
                label: 'Port',
                keyboard: TextInputType.number,
                enabled: !connecting,
              ),
              GlassToggle(
                'Secure connection',
                'Use mutual TLS when required by your scooter.',
                secure,
                connecting || s1xTcp ? null : (v) => setState(() => secure = v),
              ),
              Text(
                'Use port 50005 unless your setup requires another value. Gen2/3 '
                'addresses may look like [fe80::1%wlan0].',
                style: TextStyle(
                  color: muted(context),
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              GlassButton(
                'Connect to this address',
                key: const ValueKey('manual-connect'),
                primary: true,
                icon: CupertinoIcons.link,
                onPressed: connecting ? null : () => connect(false),
              ),
            ],
          ],
        ),
      ]),
    );
  }

  Future<void> _scanQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _QrScanner()),
    );
    if (!mounted || result == null) return;
    final ip = RegExp(
      r'\b(?:\d{1,3}\.){3}\d{1,3}\b',
    ).firstMatch(result)?.group(0);
    setState(() {
      if (ip != null && ip.split('.').every((part) => int.parse(part) <= 255)) {
        host.text = ip;
        error = '';
      } else {
        error = 'No valid diagnostic address was found in this QR.';
      }
    });
  }
}

class _ConnectionChoice extends StatelessWidget {
  const _ConnectionChoice({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: motion(context),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: .14) : fill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : separator(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? accent : muted(context)),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? accent : ink(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _QrScanner extends StatefulWidget {
  const _QrScanner();
  @override
  State<_QrScanner> createState() => _QrScannerState();
}

class _QrScannerState extends State<_QrScanner> {
  final scanner = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool returned = false;
  @override
  void dispose() {
    scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      children: [
        const Positioned.fill(child: GlassWallpaper()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Glass(
                  chrome: true,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(CupertinoIcons.chevron_left),
                      ),
                      const Expanded(child: Text('Scan scooter QR')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: MobileScanner(
                      controller: scanner,
                      onDetect: (capture) {
                        for (final code in capture.barcodes) {
                          if (code.rawValue != null && !returned) {
                            returned = true;
                            Navigator.pop(context, code.rawValue);
                            break;
                          }
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Glass(
                  child: Text(
                    'Align the scooter QR in the camera. You can enter its address manually if scanning is unavailable.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Home-screen universal search across every live parameter (the ~1200 decoded
/// CAN signals, incl. odometer, SoC, temps, voltages and fault bits), with the
/// current value shown inline — so users find a reading without hunting through
/// each tool section.
class UniversalSearch extends StatefulWidget {
  const UniversalSearch({super.key, required this.d});
  final Diagnostics d;
  @override
  State<UniversalSearch> createState() => _UniversalSearchState();
}

class _UniversalSearchState extends State<UniversalSearch> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final q = _c.text.trim().toLowerCase();
    final qid = q.replaceFirst('0x', '');
    // Search the full catalog — every known CAN signal plus UDS parameters — not
    // just signals that happen to have a live value right now. That way any
    // parameter (e.g. the odometer) is findable even before/without a live
    // reading; the current value is shown alongside when it is streaming.
    final hits = <(String, int, bool)>[]; // name, id/did, isUds
    if (q.isNotEmpty) {
      d.catalog.signals.forEach((id, sigs) {
        for (final s in sigs) {
          if (s.name.toLowerCase().contains(q) ||
              id.toRadixString(16).contains(qid)) {
            hits.add((s.name, id, false));
          }
        }
      });
      for (final p in d.catalog.parameters) {
        if (p.name.toLowerCase().contains(q) ||
            p.did.toRadixString(16).contains(qid)) {
          hits.add((p.name, p.did, true));
        }
      }
      hits.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
    }
    final shown = hits.take(40).toList();
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.search, size: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Search all parameters',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GlassField(
            controller: _c,
            label: 'e.g. odometer, SoC, temperature, 0x356',
            onChanged: (_) => setState(() {}),
            suffix: q.isEmpty
                ? null
                : IconButton(
                    onPressed: () => setState(_c.clear),
                    icon: Icon(
                      CupertinoIcons.xmark_circle_fill,
                      size: 18,
                      color: muted(context),
                    ),
                  ),
          ),
          if (q.isNotEmpty) ...[
            const SizedBox(height: 10),
            if (shown.isEmpty)
              Text(
                'No parameter matches "$q". Try a shorter or different term.',
                style: TextStyle(
                  color: muted(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              )
            else
              for (final h in shown)
                Builder(
                  builder: (context) {
                    final reading = h.$3 ? null : d.readings['${h.$2}:${h.$1}'];
                    final value = reading != null
                        ? '${number(reading.value)} ${reading.unit}'.trim()
                        : h.$3
                        ? 'UDS · read in Engineering'
                        : d.connected
                        ? 'no live value yet'
                        : '—';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  h.$1,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(
                                  '${h.$3 ? 'UDS DID' : 'CAN'} '
                                  '0x${h.$2.toRadixString(16)}',
                                  style: TextStyle(
                                    color: muted(context),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Text(
                              value,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: reading != null
                                    ? ink(context)
                                    : muted(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            if (hits.length > 40)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Showing the first 40 of ${hits.length} — refine your search.',
                  style: TextStyle(color: muted(context), fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.d, required this.navigate});
  final Diagnostics d;
  final ValueChanged<int> navigate;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool details = false;
  Diagnostics get d => widget.d;

  /// Decoded vehicle-state card: drive mode, safety states, motor + charge-time
  /// signals from CAN. Hidden when asleep or nothing is reported yet.
  Widget _vehicleStateCard(BuildContext context) {
    final shown = d.vehicleState.entries.where((e) => e.value != '—').toList();
    if (d.vehicleAsleep || shown.isEmpty) return const SizedBox.shrink();
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.car_detailed, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Vehicle state',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in shown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(color: muted(context), fontSize: 13),
                  ),
                  Text(
                    e.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget disclosure(Widget child) => reduced(context)
      ? child
      : AnimatedSize(
          duration: motion(context),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: child,
        );
  @override
  Widget build(BuildContext context) {
    final m = d.metrics;
    final total = d.faults.values.fold<int>(0, (n, f) => n + f.length);
    final scanned = d.faults.length;
    final udsBattery = d.battery, canBattery = d.canBattery;
    final battery = udsBattery != null && udsBattery.cells.isNotEmpty
        ? udsBattery
        : canBattery != null && canBattery.cells.isNotEmpty
        ? canBattery
        : (udsBattery ?? canBattery);
    final assessment = battery?.healthAssessment;
    final healthLabel = assessment?.$1 ?? 'Waiting for battery data';
    final healthColor = healthLabel.startsWith('Attention')
        ? danger
        : healthLabel.startsWith('Monitor')
        ? orange
        : healthLabel == 'Healthy'
        ? green
        : muted(context);
    return PageStack([
      const Heading('Your scooter', 'Health, charge and important alerts.'),
      Glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            WorkspaceRow(
              'Battery health',
              healthLabel,
              CupertinoIcons.heart_fill,
              healthColor,
              onTap: () => widget.navigate(1),
            ),
            Divider(height: 1, color: separator(context)),
            WorkspaceRow(
              'Scooter health',
              scanned == 0
                  ? 'Run a health scan'
                  : total == 0
                  ? 'No stored controller faults'
                  : '$total stored ${total == 1 ? 'fault' : 'faults'} need attention',
              total > 0
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.checkmark_shield_fill,
              total > 0 ? danger : green,
              onTap: () => widget.navigate(2),
            ),
          ],
        ),
      ),
      Glass(
        child: Row(
          children: [
            const Icon(CupertinoIcons.gauge, color: accent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Odometer',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    d.odometerKm != null
                        ? '${d.odometerKm} km'
                        : d.vehicleAsleep
                        ? 'Wake the scooter to read automatically'
                        : d.odometerNotBroadcast
                        ? (d.busy
                              ? 'Reading from the vehicle controller…'
                              : d.odometerFallbackSafe
                              ? 'Not available from this scooter'
                              : 'Park and unplug the charger to read the odometer')
                        : 'Reading automatically…',
                    style: TextStyle(
                      color: d.odometerKm != null
                          ? ink(context)
                          : muted(context),
                      fontSize: d.odometerKm != null ? 20 : 12,
                      fontWeight: d.odometerKm != null
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (d.odometerKm == null)
              Icon(
                d.vehicleAsleep
                    ? CupertinoIcons.moon_zzz
                    : CupertinoIcons.ellipsis,
                color: muted(context),
                size: 20,
              ),
          ],
        ),
      ),
      if (d.rideMode != null)
        Glass(
          child: Row(
            children: [
              const Icon(CupertinoIcons.speedometer, color: accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ride mode',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              Text(
                d.rideMode!,
                style: TextStyle(
                  color: ink(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                final bigText = MediaQuery.textScalerOf(context).scale(14) > 20;
                final stats = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MetricValue(
                      'Reported range',
                      number(m['Reported range (km)'], 0),
                      unit: 'km',
                      compact: true,
                    ),
                    const SizedBox(height: 14),
                    MetricValue(
                      'Battery health',
                      number(battery?.healthValue('soh'), 0),
                      unit: '%',
                      compact: true,
                    ),
                    const SizedBox(height: 14),
                    MetricValue(
                      'Temperature',
                      number(d.batteryTemperature, 0),
                      unit: '°C',
                      compact: true,
                    ),
                  ],
                );
                if (bigText && box.maxWidth < 350) {
                  return Column(
                    children: [
                      BatteryRing(m['State of charge (%)'], size: 154),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: MetricValue(
                              'Range',
                              number(m['Reported range (km)'], 0),
                              unit: 'km',
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: MetricValue(
                              'Battery health',
                              number(battery?.healthValue('soh'), 0),
                              unit: '%',
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    BatteryRing(
                      m['State of charge (%)'],
                      size: box.maxWidth > 650 ? 168 : 144,
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: box.maxWidth > 650
                          ? Row(
                              children: [
                                Expanded(
                                  child: MetricValue(
                                    'Reported range',
                                    number(m['Reported range (km)'], 0),
                                    unit: 'km',
                                  ),
                                ),
                                Expanded(
                                  child: MetricValue(
                                    'Battery health',
                                    number(battery?.healthValue('soh'), 0),
                                    unit: '%',
                                  ),
                                ),
                                Expanded(
                                  child: MetricValue(
                                    'Temperature',
                                    number(
                                      battery?.healthValue('effective temp'),
                                      0,
                                    ),
                                    unit: '°C',
                                  ),
                                ),
                              ],
                            )
                          : stats,
                    ),
                  ],
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, color: separator(context)),
            ),
            Text(
              d.demo ? 'Simulated readings' : d.freshness,
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
          ],
        ),
      ),
      _vehicleStateCard(context),
      Glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            WorkspaceRow(
              'Inspect faults',
              scanned == 0
                  ? 'Run a complete health scan'
                  : '${codeCount(total)} · $scanned/3 scanned',
              CupertinoIcons.waveform_path_ecg,
              green,
              onTap: () => widget.navigate(2),
            ),
            Divider(height: 1, color: separator(context)),
            WorkspaceRow(
              'Create a report',
              'Save a diagnostic snapshot',
              CupertinoIcons.doc_text,
              purple,
              onTap: () => widget.navigate(3),
            ),
          ],
        ),
      ),
      ModelDiagnostics(d: d, identityOnly: true),
      Glass(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: disclosure(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                expanded: details,
                child: WorkspaceRow(
                  'Battery details',
                  details ? '' : 'Current and temperatures',
                  CupertinoIcons.battery_100,
                  teal,
                  trailing: Icon(
                    details
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    color: muted(context),
                    size: 16,
                  ),
                  onTap: () => setState(() => details = !details),
                ),
              ),
              if (details)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LayoutBuilder(
                        builder: (_, box) {
                          final cols = box.maxWidth > 650 ? 3 : 2;
                          const fields = [
                            ('Pack voltage (V)', 'Voltage', 'V'),
                            ('Pack current (A)', 'Current', 'A'),
                            ('Battery temperature (°C)', 'Battery temp', '°C'),
                            ('Motor temperature (°C)', 'Motor temp', '°C'),
                            (
                              'Controller temperature (°C)',
                              'Controller temp',
                              '°C',
                            ),
                            ('Vehicle speed (km/h)', 'Speed', 'km/h'),
                          ];
                          return Wrap(
                            spacing: 14,
                            runSpacing: 20,
                            children: [
                              for (final f in fields)
                                SizedBox(
                                  width:
                                      (box.maxWidth - 14 * (cols - 1)) / cols,
                                  child: MetricValue(
                                    f.$2,
                                    number(m[f.$1]),
                                    unit: f.$3,
                                    compact: true,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      Text(
                        '— means unavailable. State of charge is not a battery-health result. Per-signal freshness is unknown.',
                        style: TextStyle(color: muted(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class FaultsPage extends StatefulWidget {
  const FaultsPage({super.key, required this.d});
  final Diagnostics d;
  @override
  State<FaultsPage> createState() => _FaultsPageState();
}

class _FaultsPageState extends State<FaultsPage> {
  Ecu ecu = Ecu.bms;
  bool attempted = false, scheduled = false, loading = false;
  String? readError;
  bool get permitted =>
      widget.d.connected &&
      (widget.d.demo ||
          !widget.d.identity.legacyMethods ||
          widget.d.bench && widget.d.mode == 'SERVICE');

  @override
  void initState() {
    super.initState();
    widget.d.addListener(changed);
    queueRead();
  }

  @override
  void didUpdateWidget(FaultsPage old) {
    super.didUpdateWidget(old);
    if (old.d != widget.d) {
      old.d.removeListener(changed);
      attempted = false;
      scheduled = false;
      loading = false;
      readError = null;
      widget.d.addListener(changed);
      queueRead();
    }
  }

  @override
  void dispose() {
    widget.d.removeListener(changed);
    super.dispose();
  }

  void changed() {
    if (!mounted) return;
    if (!widget.d.connected) attempted = false;
    setState(() {});
    queueRead();
  }

  void queueRead() {
    if (attempted || scheduled || loading || !permitted || widget.d.busy) {
      return;
    }
    scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scheduled = false;
      if (!mounted || attempted || loading || !permitted || widget.d.busy) {
        return;
      }
      readFaults();
    });
  }

  Future<void> readFaults() async {
    if (!permitted || widget.d.busy || loading) return;
    final d = widget.d;
    setState(() {
      attempted = true;
      loading = true;
      readError = null;
    });
    String? error;
    try {
      await d.scan();
      if (!d.message.startsWith('Fault scan complete')) {
        error = d.message.isEmpty
            ? 'Faults could not be refreshed. Tap Refresh faults to try again.'
            : d.message;
      }
    } catch (e) {
      error = 'Fault read failed: $e';
    }
    if (!mounted || widget.d != d) return;
    setState(() {
      loading = false;
      readError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final hasCodes = d.faults.values.any((codes) => codes.isNotEmpty);
    final allRead = Ecu.values.every(
      (target) =>
          d.faults.containsKey(target) || d.faultScanErrors.containsKey(target),
    );
    final live = d.liveFaults();
    final faultSeen = d.activeFaultFrames.any((f) => d.frameFresh(f.id));
    return PageStack([
      const Heading('Faults', 'Stored codes from your scooter’s controllers.'),
      Section(
        'Stored faults',
        icon: CupertinoIcons.waveform_path_ecg,
        children: [
          Row(
            children: [
              if (loading) ...[
                CupertinoActivityIndicator(animating: !reduced(context)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  !d.connected
                      ? 'Connect to load faults automatically.'
                      : !permitted
                      ? d.identity.matched && !d.identity.legacyMethods
                            ? 'Waiting for the modern vehicle profile to become ready.'
                            : 'Tap Connected, then Enter Service after parking and disconnecting the charger. Faults will load automatically.'
                      : loading
                      ? 'Reading stored faults…'
                      : !attempted && d.busy
                      ? 'Waiting for the current operation to finish.'
                      : readError != null
                      ? 'The latest fault read did not complete.'
                      : allRead
                      ? d.faultScanErrors.isEmpty
                            ? 'All three controllers read${d.demo ? ' · simulated' : ''}.'
                            : 'Best-effort scan finished; ${d.faultScanErrors.length} controller${d.faultScanErrors.length == 1 ? '' : 's'} did not answer.'
                      : 'Faults load automatically when this page opens.',
                  style: TextStyle(color: muted(context)),
                ),
              ),
            ],
          ),
          GlassButton(
            'Refresh faults',
            compact: true,
            icon: CupertinoIcons.arrow_clockwise,
            onPressed: !permitted || d.busy || loading ? null : readFaults,
          ),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final target in Ecu.values)
                StatusChip(
                  '${target.label} · ${d.faults.containsKey(target)
                      ? codeCount(d.faults[target]!.length)
                      : d.faultScanErrors.containsKey(target)
                      ? 'Unavailable'
                      : 'Not read'}',
                  color: d.faults[target]?.isNotEmpty == true ? danger : null,
                ),
            ],
          ),
          if (d.faultScanErrors.isNotEmpty)
            for (final entry in d.faultScanErrors.entries)
              SelectableText(
                '${entry.key.label} stored-fault read: ${entry.value}',
                style: TextStyle(color: muted(context), fontSize: 12),
              ),
          if (readError != null)
            Text(readError!, style: const TextStyle(color: danger)),
          if (d.faults.isNotEmpty && (loading || readError != null))
            Text(
              'Last returned controller results; the latest read is ${loading ? 'in progress' : 'incomplete'}.',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
          if (hasCodes) ...[
            for (final target in Ecu.values)
              if (d.faults[target]?.isNotEmpty == true) ...[
                Text(
                  target.description,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                for (final fault in d.faults[target]!)
                  Builder(
                    builder: (context) {
                      final explanation = explainFault(
                        code: fault.code,
                        description: fault.description,
                        source: target.description,
                      );
                      final tone = faultSeverityColor(explanation.severity);
                      return Glass(
                        radius: 18,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fault.code,
                                    style: const TextStyle(
                                      color: danger,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                StatusChip(
                                  explanation.severityLabel,
                                  color: tone,
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Text(fault.description),
                            if (!fault.meaningVerified)
                              Text(
                                '(i) Meaning unverified for this model and software',
                                style: TextStyle(
                                  color: muted(context),
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Status 0x${fault.status.toRadixString(16).padLeft(2, '0')} · latest returned code',
                                    style: TextStyle(
                                      color: muted(context),
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Explain ${fault.code}',
                                  onPressed: () => showFaultExplanation(
                                    context,
                                    code: fault.code,
                                    description: fault.description,
                                    source: target.description,
                                    meaningVerified: fault.meaningVerified,
                                  ),
                                  icon: const Icon(
                                    CupertinoIcons.info_circle,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
          ] else if (!loading && readError == null && allRead) ...[
            const Text('No stored faults returned.'),
            Text(
              'This does not prove battery health or repair.',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
          ] else if (!loading)
            Text(
              readError == null
                  ? 'Faults have not been read for all controllers.'
                  : 'The latest read is incomplete. Refresh to try again.',
            ),
        ],
      ),
      if (d.connected)
        Section(
          'Live fault flags',
          icon: CupertinoIcons.exclamationmark_triangle,
          children: [
            Text(
              live.isNotEmpty
                  ? '${d.demo ? 'Simulated — d' : 'D'}ecoded live from the BMS / MCU / VCU broadcast frames.'
                  : faultSeen
                  ? 'No active fault flags in the frames received.'
                  : 'Fault frames not received yet — start the live stream and wait. This is not the same as "no faults".',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
            for (final entry in live.entries)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      color: muted(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .6,
                    ),
                  ),
                  for (final f in entry.value.toSet())
                    Builder(
                      builder: (context) {
                        final explanation = explainFault(
                          code: f,
                          description: f,
                          source: entry.key,
                        );
                        final tone = faultSeverityColor(explanation.severity);
                        return Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Row(
                            children: [
                              Icon(
                                CupertinoIcons.circle_fill,
                                color: tone,
                                size: 7,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    color: tone,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 32,
                                ),
                                tooltip: 'Explain $f',
                                onPressed: () => showFaultExplanation(
                                  context,
                                  code: f,
                                  description: f,
                                  source: entry.key,
                                ),
                                icon: const Icon(
                                  CupertinoIcons.info_circle,
                                  color: accent,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
          ],
        ),
      if (d.broadcast.isNotEmpty)
        Section(
          'Broadcast fault flags',
          children: [
            Text(
              'These are live fault/status bits the controllers (BMS / MCU / VCU) '
              'are broadcasting on CAN right now — not stored trouble codes. A '
              'flag means the bit is set at this moment; some are warnings or '
              'reset/acknowledge pulses rather than hard faults. Use "Read stored '
              'faults" below for the exact codes.',
              style: TextStyle(
                color: muted(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final flag in d.broadcast)
                  Builder(
                    builder: (context) {
                      final name =
                          (flag.contains('/') ? flag.split('/').last : flag)
                              .trim();
                      final explanation = explainFault(
                        code: flag,
                        description: name,
                        source: 'Live CAN flag',
                      );
                      final tone = faultSeverityColor(explanation.severity);
                      return Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                flag,
                                style: TextStyle(
                                  color: tone,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 32,
                              ),
                              tooltip: 'Explain $name',
                              onPressed: () => showFaultExplanation(
                                context,
                                code: flag,
                                description: name,
                                source: 'Live CAN flag',
                              ),
                              icon: const Icon(
                                CupertinoIcons.info_circle,
                                color: accent,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      if (d.prefs.has(Tool.recovery))
        Section(
          'Service & recovery',
          children: [
            GlassSegment<Ecu>(
              values: Ecu.values,
              selected: ecu,
              label: (e) => e.label,
              onChanged: (e) => setState(() => ecu = e),
            ),
            Text(
              'Choose the controller for clearing or restart.',
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
            Text(
              'Export a report first. ECU restart is separate from unvalidated deep-sleep BMS wake.',
              style: TextStyle(color: muted(context), fontSize: 13),
            ),
            GlassButton(
              'Clear ${ecu.label} fault history',
              destructive: true,
              onPressed: !d.connected || d.busy
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Clear ${ecu.label} history?',
                        'Erases stored trouble codes. Save a report first; history will be lost.',
                      )) {
                        await d.faultAction(ecu, false);
                      }
                    },
            ),
            GlassButton(
              'Restart ${ecu.label}',
              destructive: true,
              onPressed: !d.connected || d.busy
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Restart ${ecu.label}?',
                        'Sends the existing hard ECU reset (11 01). Deep-sleep BMS wake has not been validated.',
                      )) {
                        await d.faultAction(ecu, true);
                      }
                    },
            ),
            GlassButton(
              'Existing fault recovery',
              destructive: true,
              onPressed: !d.connected || d.busy
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Run fault recovery?',
                        'Save a report first. Reads all controllers, clears and resets controllers with faults (or VCU if none), then returns to Customer mode. Deep-sleep wake is unvalidated.',
                      )) {
                        await d.recover();
                      }
                    },
            ),
            GlassButton(
              'Restart head unit',
              destructive: true,
              onPressed: !d.connected || d.busy
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Restart head unit?',
                        'Ends this connection. Reconnect manually when the head unit is ready. A dropped connection does not prove the restart completed.',
                      )) {
                        await d.restartHeadUnit();
                      }
                    },
            ),
          ],
        ),
    ]);
  }
}

class GlassSegment<T> extends StatelessWidget {
  const GlassSegment({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: fill(context),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        for (final value in values)
          Expanded(
            child: Semantics(
              selected: value == selected,
              button: true,
              child: GestureDetector(
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: motion(context),
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    color: value == selected
                        ? Colors.white.withValues(
                            alpha: dark(context) ? .10 : .86,
                          )
                        : Colors.transparent,
                    border: Border.all(
                      color: value == selected
                          ? Colors.white.withValues(
                              alpha: dark(context) ? .06 : .45,
                            )
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    label(value),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == selected ? ink(context) : muted(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// Plain-language meaning for a broadcast fault/status flag ("0x6bf / Name").
/// These are live CAN bits, so this explains the category, not a verified
/// diagnosis — stored codes remain the source of truth.
String broadcastFlagMeaning(String flag) {
  final name = (flag.contains('/') ? flag.split('/').last : flag).trim();
  final addr = flag.startsWith('0x') ? flag.split(' ').first : null;
  final n = name.toLowerCase();
  String base;
  if (n.contains('reset') || n.contains('ack') || n.contains('clear')) {
    base =
        'A reset/acknowledge signal, not an active fault — it pulses when a '
        'controller clears or acknowledges faults.';
  } else if (n.contains('overcurrent')) {
    base =
        'Current above the safe limit; the pack or motor may cut power to '
        'protect itself.';
  } else if (n.contains('overvolt')) {
    base = 'Voltage above the safe limit (a cell, the pack or the bus).';
  } else if (n.contains('undervolt')) {
    base =
        'Voltage below the safe limit — usually a low or weak cell; charge the '
        'pack.';
  } else if (n.contains('overtemp') ||
      (n.contains('temp') &&
          (n.contains('high') || n.contains('fault') || n.contains('warn')))) {
    base =
        'A temperature outside the safe range; the system may limit power until '
        'it cools.';
  } else if (n.contains('short')) {
    base = 'A short-circuit condition was detected — have it inspected.';
  } else if (n.contains('isolation') || n.contains('leak')) {
    base =
        'High-voltage isolation fault — a safety-critical insulation problem; '
        'stop and get it checked.';
  } else if (n.contains('comm') ||
      n.contains('timeout') ||
      n.contains('disconnect') ||
      n.contains('mismatch')) {
    base =
        'Lost or inconsistent communication between controllers or a sensor.';
  } else if (n.contains('deviation') ||
      n.contains('imbalance') ||
      n.contains('balanc')) {
    base =
        'Cells are drifting apart in voltage; balancing (while charging) may '
        'help.';
  } else if (n.contains('stall')) {
    base = 'The motor stalled or did not turn as commanded.';
  } else if (n.contains('fall') || n.contains('tow') || n.contains('theft')) {
    base =
        'A safety/security state (fall, tow or theft detection), not a hardware '
        'fault.';
  } else if (n.contains('regen')) {
    base =
        'Regenerative braking is being limited right now — commonly because the '
        'battery is too full to accept charge, or a protection is active. Often '
        'normal at a high state of charge.';
  } else if (n.contains('ac_v') || n.contains('mains')) {
    base =
        'The AC input / charger supply voltage is out of range — a charging-'
        'supply issue (wall outlet or charger), not the battery pack.';
  } else if (n.contains('charg')) {
    base = 'A charging-related protection bit (charger or charge current).';
  } else if (n.contains('volt')) {
    base = 'A voltage reading is outside its expected range.';
  } else if (n.contains('warn')) {
    base =
        'A warning bit — a limit is being approached, not necessarily a hard '
        'fault.';
  } else {
    base =
        'A fault/status bit the controller is broadcasting. Read stored faults '
        'for the exact code.';
  }
  return addr == null ? base : 'From $addr. $base';
}

class ReportState {
  DiagnosticReport? report;
  bool identifiers = false, activity = false, ecuExpanded = false;
}

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.d, required this.state});
  final Diagnostics d;
  final ReportState state;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String status = '';
  bool exporting = false;
  Future<void> save(String extension) async {
    final report = widget.state.report;
    if (report == null || exporting) return;
    setState(() => exporting = true);
    try {
      final result = await FilePicker.saveFile(
        dialogTitle: 'Save diagnostic report',
        fileName: report.filename(extension),
        bytes: Uint8List.fromList(
          utf8.encode(extension == 'json' ? report.json : report.text),
        ),
      );
      if (mounted) {
        setState(
          () => status = result == null ? 'Save cancelled.' : 'Report saved.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => status = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return PageStack([
      const Heading(
        'Diagnostic reports',
        'A clear snapshot of this diagnostic session.',
      ),
      Glass(
        child: Column(
          children: [
            WorkspaceRow(
              'Read ECU health report',
              'Battery, drive inputs and component data',
              CupertinoIcons.doc_text_search,
              teal,
              trailing: Icon(
                state.ecuExpanded
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 16,
                color: muted(context),
              ),
              onTap: () =>
                  setState(() => state.ecuExpanded = !state.ecuExpanded),
            ),
            if (state.ecuExpanded)
              IdentifiersPage(
                d: widget.d,
                kind: IdentifierWorkspace.healthReport,
                embedded: true,
              ),
          ],
        ),
      ),
      Section(
        'Session activity',
        icon: CupertinoIcons.clock,
        children: [
          Text(
            '${widget.d.activity.length} entries in this session.',
            style: TextStyle(color: muted(context)),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              GlassButton(
                'View activity',
                compact: true,
                onPressed: () => glassSheet(
                  context,
                  SelectableText(
                    widget.d.activity.join('\n').isEmpty
                        ? 'No activity yet.'
                        : widget.d.activity.join('\n'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              GlassButton(
                'Clear view',
                compact: true,
                onPressed: () {
                  widget.d.activity.clear();
                  widget.d.emit();
                  setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
      Section(
        'Capture',
        icon: CupertinoIcons.doc_text,
        children: [
          GlassToggle(
            'Include identifiers / VIN',
            'Off by default. Read identifiers in Engineering tools first.',
            state.identifiers,
            (v) => setState(() {
              state.identifiers = v;
              state.report = null;
            }),
          ),
          GlassToggle(
            'Include activity log',
            'Command history can contain identifying information.',
            state.activity,
            (v) => setState(() {
              state.activity = v;
              state.report = null;
            }),
          ),
          GlassButton(
            state.report == null ? 'Capture report' : 'Capture a new snapshot',
            primary: true,
            icon: CupertinoIcons.camera,
            onPressed: widget.d.busy
                ? null
                : () => setState(() {
                    state.report = DiagnosticReport.capture(
                      widget.d,
                      includeVin: state.identifiers,
                      includeActivity: state.activity,
                    );
                    status = 'Snapshot captured.';
                  }),
          ),
          Text(
            'Unknown fields and unscanned controllers remain explicit. Demo reports are labelled simulated.',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
        ],
      ),
      if (state.report != null) ...[
        Section(
          'Export snapshot',
          children: [
            Text(
              state.report!.data['captured_at'].toString(),
              style: TextStyle(color: muted(context), fontSize: 12),
            ),
            GlassButton(
              'Save JSON',
              onPressed: exporting ? null : () => save('json'),
            ),
            GlassButton(
              'Save TXT',
              onPressed: exporting ? null : () => save('txt'),
            ),
            GlassButton(
              'Share report',
              icon: CupertinoIcons.square_arrow_up,
              onPressed: exporting
                  ? null
                  : () async {
                      try {
                        final box = context.findRenderObject() as RenderBox?;
                        await SharePlus.instance.share(
                          ShareParams(
                            text: state.report!.text,
                            subject: 'OpenOLA diagnostic report',
                            sharePositionOrigin: box == null
                                ? null
                                : box.localToGlobal(Offset.zero) & box.size,
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          setState(() => status = 'Share unavailable: $e');
                        }
                      }
                    },
            ),
            if (status.isNotEmpty)
              Text(status, style: TextStyle(color: muted(context))),
          ],
        ),
        Section(
          'Preview',
          children: [
            SelectableText(
              state.report!.text,
              style: TextStyle(
                color: muted(context),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ],
      if (!widget.d.demo)
        Builder(
          builder: (context) {
            final d = widget.d;
            final b = d.battery ?? d.canBattery;
            return Section(
              'Read status',
              icon: CupertinoIcons.ant,
              children: [
                Text(
                  'connected=${d.connected}  mode=${d.mode}  bench=${d.bench}\n'
                  'readReady=${d.readReady}  busy=${d.busy}\n'
                  'model=${d.identity.model}\n'
                  'profile=${d.identity.profileLabel}',
                  style: TextStyle(
                    color: muted(context),
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                if (b == null)
                  Text(
                    'snapshot: none — read has not run (or returned nothing). '
                    'Tap "Read battery & cells" on the Battery tab.',
                    style: TextStyle(color: muted(context), fontSize: 11),
                  )
                else ...[
                  Text(
                    'snapshot: cells=${b.cells.length}  '
                    'healthRows=${b.health.length}  errors=${b.errors.length}',
                    style: TextStyle(color: muted(context), fontSize: 11),
                  ),
                  if (b.health.isNotEmpty)
                    Text(
                      'rows: ${b.health.map((h) => '${h.name}=${h.value}${h.unit}').join(' · ')}',
                      style: TextStyle(
                        color: muted(context),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                ],
                if (d.message.isNotEmpty)
                  Text(
                    'last message: ${d.message}',
                    style: TextStyle(color: muted(context), fontSize: 10),
                  ),
              ],
            );
          },
        ),
    ]);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.d,
    required this.prefs,
    required this.onShowTutorial,
    required this.onEnterDeveloper,
    required this.onWorkspaceSelected,
  });
  final Diagnostics d;
  final Preferences prefs;
  final VoidCallback onShowTutorial;
  final Future<bool> Function() onEnterDeveloper;
  final Future<void> Function(WorkspaceMode) onWorkspaceSelected;
  @override
  Widget build(BuildContext context) => PageStack([
    const Heading('Settings', 'Workspace, appearance and accessibility.'),
    Section(
      'Workspace',
      icon: CupertinoIcons.person_2,
      children: [
        GlassSegment<WorkspaceMode>(
          values: WorkspaceMode.values,
          selected: prefs.workspaceMode,
          label: (mode) => mode.label,
          onChanged: onWorkspaceSelected,
        ),
        Text(
          prefs.workspaceMode.description,
          style: TextStyle(color: muted(context), fontSize: 12),
        ),
        if (prefs.workspaceMode == WorkspaceMode.service)
          const Text(
            'Service workspace is unlocked. Active commands still require their own confirmation.',
            style: TextStyle(color: danger, fontSize: 12),
          ),
      ],
    ),
    Section(
      'Appearance',
      icon: CupertinoIcons.circle_lefthalf_fill,
      children: [
        GlassSegment<ThemeMode>(
          values: ThemeMode.values,
          selected: prefs.theme,
          label: (m) => switch (m) {
            ThemeMode.system => 'System',
            ThemeMode.light => 'Light',
            ThemeMode.dark => 'Dark',
          },
          onChanged: prefs.appearance,
        ),
        GlassToggle(
          'Reduce motion',
          'Keep transitions and control feedback simple.',
          prefs.reduceMotion,
          prefs.motion,
        ),
      ],
    ),
    Section(
      'Feedback',
      icon: CupertinoIcons.hand_draw,
      children: [
        GlassToggle(
          'Haptics',
          'Vibrate on taps, confirmations and slide-to-verify.',
          prefs.haptics,
          prefs.setHaptics,
        ),
      ],
    ),
    // Glass quality listens to its own notifier so the segment reflects
    // auto-downgrades live.
    ListenableBuilder(
      listenable: prefs.quality,
      builder: (context, _) => Section(
        'Display quality',
        icon: CupertinoIcons.sparkles,
        children: [
          GlassToggle(
            'Adapt automatically',
            'Full glass on capable phones; lighten the blur automatically when '
                'frames drop. Now: ${prefs.quality.tier.label}.',
            prefs.quality.auto,
            (v) => prefs.quality.setAuto(v),
          ),
          if (!prefs.quality.auto)
            GlassSegment<GlassTier>(
              values: GlassTier.values,
              selected: prefs.quality.manual,
              label: (t) => t.label,
              onChanged: prefs.quality.setManual,
            ),
        ],
      ),
    ),
    Section(
      'Advanced',
      icon: CupertinoIcons.wrench,
      children: [
        GlassToggle(
          'Developer Mode',
          prefs.developerMode
              ? 'The Service workspace is available.'
              : 'Unlock Service mode, ADB, APK installation, ECU writes and passcode health. Requires slide-to-confirm.',
          prefs.developerMode,
          (v) {
            if (v) {
              onEnterDeveloper();
            } else {
              prefs.setDeveloperMode(false);
            }
          },
        ),
      ],
    ),
    Section(
      'Help',
      icon: CupertinoIcons.question_circle,
      children: [
        GlassButton(
          'Browse offline fault guide',
          icon: CupertinoIcons.book,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => FaultGuideScreen(d: d)),
          ),
        ),
        GlassButton(
          'Show tutorial',
          icon: CupertinoIcons.sparkles,
          onPressed: onShowTutorial,
        ),
      ],
    ),
    Section(
      'OpenOLA',
      children: [
        const AppMark(size: 64),
        const Text('Open diagnostics for owners and independent technicians.'),
        Text(
          'Local Android and iPhone diagnostics. Deep-sleep BMS wake remains unvalidated. Developer: ola hecker.',
          style: TextStyle(color: muted(context), fontSize: 12),
        ),
      ],
    ),
  ]);
}
