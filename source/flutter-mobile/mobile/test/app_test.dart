import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openola/main.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/bluetooth/ble_controller.dart';
import 'package:openola/design/glass.dart';
import 'package:openola/design/verify_slider.dart';
import 'package:openola/screens/core.dart';
import 'package:openola/screens/advanced.dart';
import 'package:openola/screens/battery_page.dart';
import 'package:openola/screens/live_signals.dart';
import 'package:openola/protocol/can.dart';

Future<(Preferences, Diagnostics, ScooterBle)> setup() async {
  SharedPreferences.setMockInitialValues({
    'reduceMotion': true,
    'disclaimerAccepted': true,
    'tutorialSeen': true,
  });
  final prefs = Preferences(await SharedPreferences.getInstance());
  final d = Diagnostics(await Catalog.load(), prefs);
  final ble = ScooterBle();
  return (prefs, d, ble);
}

Future<void> precacheScooterIfVisible(WidgetTester tester) async {
  final marks = find.byType(AppMark);
  if (marks.evaluate().isEmpty) return;
  await tester.runAsync(
    () => precacheImage(
      const AssetImage('assets/images/scooter.png'),
      tester.element(marks.first),
    ),
  );
}

class FaultReadDiagnostics extends Diagnostics {
  FaultReadDiagnostics(super.catalog, super.prefs);
  int reads = 0;
  bool fail = false;
  Completer<void>? pending;
  @override
  Future<void> scan({Ecu? ecu}) async {
    reads++;
    await operation('Read stored faults', () async {
      await pending?.future;
      if (fail) throw StateError('Controller did not respond');
      faults[Ecu.bms] = [const Fault('P0A80', 'Battery fault example', 9)];
      faults[Ecu.vcu] = [const Fault('P0500', 'Vehicle fault example', 9)];
      faults[Ecu.mcu] = [];
      message = 'Fault scan complete';
    }, service: true);
  }
}

void main() {
  setUp(() => debugDisableShadows = false);
  tearDown(() => debugDisableShadows = true);
  setUpAll(() async {
    final font = FontLoader('Inter')
      ..addFont(rootBundle.load('assets/Inter.ttf'));
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons')
      ..addFont(
        rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
      );
    await font.load();
    await icons.load();
  });
  for (final viewport in [
    ('phone', const Size(390, 844), 1.0),
    ('tablet', const Size(1024, 900), 1.0),
    ('large-text', const Size(360, 800), 1.6),
  ]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        '${viewport.$1} ${theme.name} glass layout and theme persistence',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = viewport.$2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final (prefs, d, ble) = (await tester.runAsync(setup))!;
          await prefs.appearance(theme);
          d.connection = Connection.connected;
          d.demo = true;
          d.mode = 'SERVICE';
          d.firmware = 'DEMO-MOCK-5.0.0';
          final now = DateTime.now();
          for (final entry in {
            'Display_SoC': 82.5,
            'Bus_Voltage_00_10ms': 52.4,
            'Overall_Battery_Current': 4.4,
          }.entries) {
            d.readings['demo:${entry.key}'] = Reading(entry.value, '', now, 0);
          }
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('capture'),
              child: OpenOla(prefs: prefs, diagnostics: d, ble: ble),
            ),
          );
          // Drive the same platform dimensions and text scale as a real device.
          tester.platformDispatcher.textScaleFactorTestValue = viewport.$3;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await tester.pumpAndSettle();
          await precacheScooterIfVisible(tester);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('OpenOLA'), findsOneWidget);
          final home = find.byKey(const ValueKey('nav-Home'));
          final settings = find.byKey(const ValueKey('open-settings'));
          expect(home, findsOneWidget);
          expect(settings, findsOneWidget);
          expect(tester.getRect(home).isEmpty, false);
          expect(tester.getRect(settings).isEmpty, false);
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile('goldens/${viewport.$1}-${theme.name}.png'),
          );
          expect(find.text('Battery temp'), findsNothing);
          expect(find.text('Enable in Settings'), findsNothing);
          await tester.ensureVisible(find.text('Battery details'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Battery details'));
          await tester.pumpAndSettle();
          expect(find.text('Battery temp'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Battery details'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Battery details'));
          await tester.pumpAndSettle();
          expect(find.text('Battery temp'), findsNothing);
          await prefs.motion(false);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Battery details'));
          await tester.pumpAndSettle();
          expect(find.text('Battery temp'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Battery details'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Battery details'));
          await tester.pumpAndSettle();
          await prefs.motion(true);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('open-settings')));
          await tester.pumpAndSettle();
          expect(find.byType(SettingsPage), findsOneWidget);
          expect(prefs.theme, theme);
          expect(Preferences(prefs.store).theme, theme);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          d.dispose();
          prefs.dispose();
          ble.dispose();
          debugDisableShadows = true;
        },
      );
    }
  }
  testWidgets(
    'demo scan, retained frozen report and categorized tools sidebar',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (prefs, d, ble) = (await tester.runAsync(setup))!;
      await tester.pumpWidget(OpenOla(prefs: prefs, diagnostics: d, ble: ble));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-Battery')), findsNothing);
      expect(find.byTooltip('Open tools menu'), findsNothing);
      expect(find.byKey(const ValueKey('manual-host')), findsNothing);
      expect(find.text('Scooter Wi-Fi'), findsWidgets);
      expect(find.text('Phone hotspot'), findsOneWidget);
      expect(find.text('Shared Wi-Fi'), findsOneWidget);
      final workspaceScroll = find
          .descendant(
            of: find.byKey(const ValueKey('connection-gate-scroll')),
            matching: find.byType(Scrollable),
          )
          .first;
      final manualButton = find.text('Enter address or scan QR');
      await tester.scrollUntilVisible(
        manualButton,
        250,
        scrollable: workspaceScroll,
      );
      await tester.tap(manualButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('manual-host')), findsOneWidget);
      final demoButton = find.byKey(const ValueKey('start-demo'));
      await tester.scrollUntilVisible(
        demoButton,
        250,
        scrollable: workspaceScroll,
      );
      await tester.ensureVisible(demoButton);
      await tester.pumpAndSettle();
      final demoLabel = find.text('Explore Demo').hitTestable();
      expect(demoLabel, findsOneWidget);
      await tester.tap(demoLabel);
      await tester.runAsync(() async {
        for (var i = 0; i < 40 && !d.connected; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
      });
      await tester.pumpAndSettle();
      expect(d.demo, true);
      expect(d.connected, true);
      expect(find.text('12345 km'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-Battery')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-Diagnose')));
      await tester.pumpAndSettle();
      // Diagnose now opens the fault scan directly.
      expect(d.faults[Ecu.bms]!.single.code, 'P0A80');
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Capture report'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Capture report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Capture report'));
      await tester.pumpAndSettle();
      expect(find.text('Capture a new snapshot'), findsOneWidget);
      final page = tester.widget<ReportsPage>(find.byType(ReportsPage));
      final frozen = page.state.report!.json;
      d.faults.clear();
      d.emit();
      await tester.pump();
      expect(page.state.report!.json, frozen);
      await tester.tap(find.byKey(const ValueKey('nav-Home')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reports').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<ReportsPage>(find.byType(ReportsPage)).state.report!.json,
        frozen,
      );
      // Compare the menu over a static settings page, rather than a report's
      // current capture timestamp. Report immutability is asserted above.
      await tester.tap(find.byKey(const ValueKey('open-settings')));
      await tester.pumpAndSettle();
      await tester.pump();
      await precacheScooterIfVisible(tester);
      await tester.pumpAndSettle();
      await prefs.setWorkspaceMode(WorkspaceMode.technician);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      expect(find.text('MONITORING'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Live signals'),
        ),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/tools-sidebar.png'),
      );
      expect(tester.getTopLeft(find.byType(Drawer)).dx, 0);
      expect(tester.getSize(find.byType(Drawer)).width, lessThan(390));
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Live signals'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(LiveSignalsSlivers), findsOneWidget);
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(LiveSignalsSlivers), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('nav-Home')));
      await tester.pumpAndSettle();
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    },
  );

  testWidgets(
    'disconnect closes open workspaces and restores connection gate',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (prefs, d, ble) = (await tester.runAsync(setup))!;
      d.connection = Connection.connected;
      d.demo = true;
      await tester.pumpWidget(OpenOla(prefs: prefs, diagnostics: d, ble: ble));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-Battery')));
      await tester.pumpAndSettle();
      expect(find.byType(BatteryPage), findsOneWidget);

      d.connection = Connection.disconnected;
      d.demo = false;
      d.emit();
      await tester.pumpAndSettle();
      expect(find.byType(ConnectPage), findsOneWidget);
      expect(find.byKey(const ValueKey('nav-Battery')), findsNothing);
      expect(find.byTooltip('Open tools menu'), findsNothing);
      expect(find.byKey(const ValueKey('start-demo')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      debugDisableShadows = true;
      d.dispose();
      prefs.dispose();
      ble.dispose();
    },
  );
  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('core pages and appearance menu ${theme.name}', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (prefs, d, ble) = (await tester.runAsync(setup))!;
      await prefs.appearance(theme);
      await tester.pumpWidget(OpenOla(prefs: prefs, diagnostics: d, ble: ble));
      await tester.pumpAndSettle();
      await precacheScooterIfVisible(tester);
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/connect-${theme.name}.png'),
      );
      d.connection = Connection.connected;
      d.demo = true;
      d.mode = 'SERVICE';
      d.firmware = 'DEMO-MOCK-5.0.0';
      d.faults[Ecu.bms] = [
        const Fault('P0A80', 'Demo: battery pack fault example', 9),
      ];
      d.emit();
      await tester.pumpAndSettle();
      for (final tab in ['Diagnose', 'Controls', 'Settings']) {
        await tester.tap(
          tab == 'Settings'
              ? find.byKey(const ValueKey('open-settings'))
              : find.byKey(ValueKey('nav-$tab')),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/${tab.toLowerCase()}-${theme.name}.png'),
        );
      }
      await prefs.setWorkspaceMode(WorkspaceMode.technician);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      expect(find.text('Recorder'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sidebar-${theme.name}.png'),
      );
      // The drawer list is long enough that Settings is built lazily.
      final drawerList = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Settings'),
        ),
        200,
        scrollable: drawerList,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('Settings'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(SettingsPage), findsOneWidget);
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Appearance').last);
      await tester.pumpAndSettle();
      expect(find.text('Follow your device'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/appearance-${theme.name}.png'),
      );
      await tester.tap(
        find.text(theme == ThemeMode.light ? 'Dark' : 'Light').last,
      );
      await tester.pumpAndSettle();
      expect(
        prefs.theme,
        theme == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    });
  }
  testWidgets(
    'faults read automatically and show every controller without repeated reads',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (prefs, base, ble) = (await tester.runAsync(setup))!;
      final d = FaultReadDiagnostics(base.catalog, prefs)
        ..connection = Connection.connected
        ..demo = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(child: FaultsPage(d: d)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(d.reads, 1);
      expect(find.text('P0A80'), findsOneWidget);
      expect(find.text('P0500'), findsOneWidget);
      expect(find.text('Scan all controllers'), findsNothing);
      d.emit();
      d.emit();
      await tester.pumpAndSettle();
      expect(d.reads, 1);
      await tester.tap(find.text('Refresh faults'));
      await tester.pumpAndSettle();
      expect(d.reads, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      base.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    },
  );
  testWidgets(
    'automatic fault read waits for connection, Service mode and idle',
    (tester) async {
      final (prefs, base, ble) = (await tester.runAsync(setup))!;
      final d = FaultReadDiagnostics(base.catalog, prefs);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: FaultsPage(d: d)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(d.reads, 0);
      expect(find.text('No stored faults returned.'), findsNothing);
      d.connection = Connection.connected;
      d.mode = 'CUST';
      d.bench = true;
      d.emit();
      await tester.pumpAndSettle();
      expect(d.reads, 0);
      d.mode = 'SERVICE';
      d.busy = true;
      d.emit();
      await tester.pumpAndSettle();
      expect(d.reads, 0);
      d.busy = false;
      d.emit();
      await tester.pumpAndSettle();
      expect(d.reads, 1);
      expect(find.text('P0500'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      base.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    },
  );
  testWidgets(
    'automatic fault read shows loading and error; retry is explicit',
    (tester) async {
      final (prefs, base, ble) = (await tester.runAsync(setup))!;
      final gate = Completer<void>();
      final d = FaultReadDiagnostics(base.catalog, prefs)
        ..connection = Connection.connected
        ..demo = true
        ..fail = true
        ..pending = gate;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: FaultsPage(d: d)),
          ),
        ),
      );
      await tester.pump();
      expect(d.reads, 1);
      expect(find.text('Reading stored faults…'), findsOneWidget);
      expect(find.text('No stored faults returned.'), findsNothing);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Controller did not respond'), findsOneWidget);
      d.emit();
      d.emit();
      await tester.pumpAndSettle();
      expect(d.reads, 1);
      d.fail = false;
      d.pending = null;
      await tester.tap(find.text('Refresh faults'));
      await tester.pumpAndSettle();
      expect(d.reads, 2);
      expect(find.text('P0A80'), findsOneWidget);
      expect(find.textContaining('Controller did not respond'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      base.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    },
  );
  testWidgets(
    'fault page can close during reading and refreshes on a new entry',
    (tester) async {
      final (prefs, base, ble) = (await tester.runAsync(setup))!;
      final gate = Completer<void>();
      final d = FaultReadDiagnostics(base.catalog, prefs)
        ..connection = Connection.connected
        ..demo = true
        ..pending = gate;
      Widget page() => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FaultsPage(d: d)),
        ),
      );
      await tester.pumpWidget(page());
      await tester.pump();
      expect(d.reads, 1);
      await tester.pumpWidget(const SizedBox());
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      d.pending = null;
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(d.reads, 2);
      expect(find.text('P0A80'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      base.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    },
  );
  testWidgets('verification completes only after the full slide', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: glassTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (c) => GlassButton(
              'Open',
              onPressed: () async {
                result = await confirmGlass(
                  c,
                  'Restart BMS?',
                  'Hardware testing remains pending.',
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final slider = find.byType(SlideToVerify);
    final start = tester.getTopLeft(slider) + const Offset(25, 31);
    await tester.dragFrom(start, Offset(tester.getSize(slider).width, 0));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(find.text('Restart BMS?'), findsNothing);
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
  });
  testWidgets(
    'service mode changes only after verification; cancelling preserves mode',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (prefs, d, ble) = (await tester.runAsync(setup))!;
      await prefs.appearance(ThemeMode.dark);
      await prefs.setDeveloperMode(true);
      d.connection = Connection.connected;
      d.demo = true;
      d.mode = 'CUST';
      await tester.pumpWidget(OpenOla(prefs: prefs, diagnostics: d, ble: ble));
      await tester.pumpAndSettle();
      await precacheScooterIfVisible(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter Service'));
      await tester.pumpAndSettle();
      expect(d.mode, 'CUST');
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/confirmation-phone.png'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(d.mode, 'CUST');
      await tester.tap(find.text('Demo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter Service'));
      await tester.pumpAndSettle();
      final slider = find.byType(SlideToVerify);
      await tester.dragFrom(
        tester.getTopLeft(slider) + const Offset(25, 31),
        Offset(tester.getSize(slider).width, 0),
      );
      await tester.pumpAndSettle();
      expect(d.mode, 'SERVICE');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    },
  );
  for (final viewport in [
    ('narrow', const Size(360, 800), 1.6),
    ('tablet', const Size(1024, 900), 1.0),
  ]) {
    testWidgets('${viewport.$1} sidebar exposes enabled tools and dismisses', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = viewport.$2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = viewport.$3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (prefs, d, ble) = (await tester.runAsync(setup))!;
      await prefs.appearance(ThemeMode.dark);
      await prefs.setDeveloperMode(true); // reveal all advanced windows
      d.connection = Connection.connected;
      d.demo = true;
      await tester.pumpWidget(OpenOla(prefs: prefs, diagnostics: d, ble: ble));
      await tester.pumpAndSettle();
      await precacheScooterIfVisible(tester);
      await tester.pumpAndSettle();
      expect(find.text('Bluetooth controls'), findsNothing);
      if (viewport.$1 == 'narrow') {
        await tester.dragFrom(const Offset(1, 200), const Offset(240, 0));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsOneWidget);
        // The drawer has its own logo; wait for it to decode so the screenshot
        // is deterministic.
        await precacheScooterIfVisible(tester);
        await tester.pumpAndSettle();
      } else {
        expect(find.byTooltip('Open tools menu'), findsNothing);
        expect(find.byType(Drawer), findsNothing);
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/sidebar-${viewport.$1}-all.png'),
      );
      final menuScroll = viewport.$1 == 'narrow'
          ? find
                .descendant(
                  of: find.byType(Drawer),
                  matching: find.byType(Scrollable),
                )
                .first
          : find.byType(Scrollable).first;
      for (final tool in [
        for (final group in Tool.values.map((t) => t.group).toSet())
          ...Tool.values.where(
            (t) =>
                t.group == group &&
                t.visibleIn(WorkspaceMode.service) &&
                t != Tool.features &&
                t != Tool.controls &&
                t != Tool.recovery &&
                t != Tool.componentTests,
          ),
      ]) {
        await tester.scrollUntilVisible(
          find.text(tool.label),
          150,
          scrollable: menuScroll,
        );
        await tester.ensureVisible(find.text(tool.label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: tool.label);
      }
      await tester.tap(find.text(Tool.engineering.label));
      await tester.pumpAndSettle();
      expect(find.byType(AdvancedPage), findsOneWidget);
      if (viewport.$1 == 'narrow') {
        expect(find.byType(Drawer), findsNothing);
        await tester.tap(find.byTooltip('Open tools menu'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(350, 400));
        await tester.pumpAndSettle();
        expect(find.byType(Drawer), findsNothing);
        expect(find.byType(AdvancedPage), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    });
  }
  for (final viewport in [
    ('phone', const Size(390, 844), 1.0, ThemeMode.dark),
    ('phone', const Size(390, 844), 1.0, ThemeMode.light),
    ('large-text', const Size(360, 800), 1.6, ThemeMode.dark),
    ('tablet', const Size(1024, 900), 1.0, ThemeMode.dark),
  ]) {
    testWidgets(
      'live signals ${viewport.$1} ${viewport.$4.name} scroll as one full page',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = viewport.$2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = viewport.$3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final (prefs, d, ble) = (await tester.runAsync(setup))!;
        await prefs.appearance(viewport.$4);
        await prefs.setWorkspaceMode(WorkspaceMode.technician);
        d.connection = Connection.connected;
        d.demo = true;
        d.live = true;
        for (var i = 0; i < 120; i++) {
          d.readings['demo:Signal_${i.toString().padLeft(3, '0')}'] = Reading(
            i.toDouble(),
            'V',
            DateTime.now(),
            0x123,
          );
        }
        await tester.pumpWidget(
          OpenOla(prefs: prefs, diagnostics: d, ble: ble),
        );
        await tester.pumpAndSettle();
        await precacheScooterIfVisible(tester);
        await tester.pumpAndSettle();
        if (viewport.$1 != 'tablet') {
          expect(find.byTooltip('Open tools menu'), findsOneWidget);
          await tester.tap(find.byTooltip('Open tools menu'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Live signals'));
        await tester.pumpAndSettle();
        expect(find.byType(LiveSignalsSlivers), findsOneWidget);
        expect(find.text('Back to Home'), findsNothing);
        final workspace = find.byKey(const ValueKey('workspace-scroll'));
        final scrolling = find.descendant(
          of: workspace,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          ),
        );
        expect(scrolling, findsOneWidget);
        final bounds = tester.getRect(workspace);
        expect(bounds.height, greaterThan(viewport.$2.height * .68));
        expect(
          bounds.bottom - tester.getTopLeft(find.text('Signal_000')).dy,
          greaterThan(bounds.height * .5),
        );
        expect(
          find.text('Signal_119'),
          findsNothing,
          reason: 'Off-screen rows should be built lazily.',
        );
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/live-${viewport.$1}-${viewport.$4.name}.png',
          ),
        );
        await tester.dragFrom(
          Offset(bounds.center.dx, bounds.top + 25),
          const Offset(0, -350),
        );
        await tester.pumpAndSettle();
        expect(
          tester.state<ScrollableState>(scrolling).position.pixels,
          greaterThan(200),
        );
        expect(
          find
              .descendant(of: workspace, matching: find.text('Live signals'))
              .hitTestable(),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          find.text('Signal_100'),
          450,
          scrollable: scrolling,
          maxScrolls: 30,
        );
        await tester.ensureVisible(find.text('Signal_100'));
        await tester.pumpAndSettle();
        expect(find.text('Signal_100').hitTestable(), findsOneWidget);
        expect(find.textContaining('Show 40 more'), findsNothing);
        d.readings['demo:Signal_100'] = Reading(
          12345.6,
          'mV',
          DateTime.now(),
          0x123,
        );
        d.emit();
        await tester.pumpAndSettle();
        expect(find.text('12345.6 mV'), findsOneWidget);
        tester.state<ScrollableState>(scrolling).position.jumpTo(0);
        await tester.pumpAndSettle();
        final field = find.descendant(
          of: workspace,
          matching: find.byType(TextField),
        );
        await tester.enterText(field, 'Signal_119');
        await tester.pumpAndSettle();
        expect(
          find
              .byWidgetPredicate(
                (widget) => widget is Text && widget.data == 'Signal_119',
              )
              .hitTestable(),
          findsOneWidget,
        );
        await tester.enterText(field, 'does-not-exist');
        await tester.pumpAndSettle();
        expect(find.text('No matching signals'), findsOneWidget);
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        expect(find.text('Signal_000'), findsOneWidget);
        d.live = false;
        d.readings.clear();
        d.emit();
        await tester.pumpAndSettle();
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('No signals yet'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        d.dispose();
        prefs.dispose();
        ble.dispose();
        debugDisableShadows = true;
      },
    );
  }
  testWidgets('advanced screens render in a narrow dark viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (prefs, d, ble) = (await tester.runAsync(setup))!;
    d.connection = Connection.connected;
    d.demo = true;
    d.mode = 'SERVICE';
    for (final tool in Tool.values.where((t) => t != Tool.recovery)) {
      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme(Brightness.dark),
          home: Scaffold(
            body: tool == Tool.live
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: AdvancedPage(tool: tool, d: d, ble: ble),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: AdvancedPage(tool: tool, d: d, ble: ble),
                  ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tool.label);
    }
    await tester.pumpWidget(const SizedBox());
    d.dispose();
    prefs.dispose();
    ble.dispose();
    debugDisableShadows = true;
  });
  testWidgets(
    'head-unit console exposes terminal launcher HMI and installer safely',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final (prefs, d, ble) = (await tester.runAsync(setup))!;
      d.connection = Connection.connected;
      d.demo = true;
      d.mode = 'SERVICE';
      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme(Brightness.dark),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: AdvancedPage(tool: Tool.headUnit, d: d, ble: ble),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Head-unit console'), findsOneWidget);
      // gRPC root bridge only: the old ADB host/authorize controls are gone.
      expect(find.byKey(const ValueKey('direct-adb-host')), findsNothing);
      expect(find.byKey(const ValueKey('connect-direct-adb')), findsNothing);
      expect(find.byKey(const ValueKey('head-unit-transport')), findsNothing);
      expect(find.byKey(const ValueKey('head-unit-command')), findsOneWidget);
      expect(find.byKey(const ValueKey('launch-ola-hmi')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('choose-head-unit-apk')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('install-head-unit-apk')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byTooltip('Refresh installed apps'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh installed apps'));
      await tester.pumpAndSettle();
      expect(find.text('Diagnostic Mode'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('launch-ola-hmi')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('launch-ola-hmi')));
      await tester.pumpAndSettle();
      expect(d.message, 'OLA HMI brought to front');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      prefs.dispose();
      ble.dispose();
      debugDisableShadows = true;
    },
  );
  testWidgets(
    'partial verification slides reset; taps and cancel do not confirm',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: glassTheme(Brightness.dark),
          home: Scaffold(
            body: Builder(
              builder: (c) => GlassButton(
                'Open',
                onPressed: () => confirmGlass(
                  c,
                  'Restart BMS?',
                  'Deep-sleep wake is unverified.',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Slide to verify'), findsOneWidget);
      final slider = find.byType(SlideToVerify);
      await tester.tap(slider);
      await tester.pumpAndSettle();
      expect(find.text('Restart BMS?'), findsOneWidget);
      await tester.dragFrom(
        tester.getTopLeft(slider) + const Offset(25, 31),
        const Offset(65, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Restart BMS?'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/confirmation.png'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Restart BMS?'), findsNothing);
      expect(tester.takeException(), isNull);
      debugDisableShadows = true;
    },
  );
}
