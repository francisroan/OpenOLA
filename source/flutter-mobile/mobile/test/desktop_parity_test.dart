import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/data/identifiers.dart';
import 'package:openola/data/vehicle_status.dart';
import 'package:openola/diagnostics/battery.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/diagnostics/report.dart';
import 'package:openola/diagnostics/session.dart';
import 'package:openola/bluetooth/ble_controller.dart';
import 'package:openola/main.dart';
import 'package:openola/design/glass.dart';
import 'package:openola/screens/battery_page.dart';
import 'package:openola/screens/recorder_page.dart';
import 'package:openola/screens/identifiers_page.dart';
import 'package:openola/protocol/can.dart';

class ReadSpy extends Diagnostics {
  ReadSpy(super.catalog, super.prefs, {super.recorder});
  final calls = <String>[];
  Completer<void>? pending;
  bool failure = false;
  @override
  Future<void> identifierStream(bool monitor) async {
    calls.add(monitor ? 'monitor' : 'diag');
  }

  @override
  Future<List<int>> readIdentifierBytes(ReadIdentifier d) async {
    calls.add(d.key);
    await pending?.future;
    if (failure && d.did == 0xe109) throw StateError('BMS did not return IR');
    return List.generate(28, (i) => i.isEven ? 32 : 0);
  }
}

Future<(Preferences, Diagnostics, ScooterBle, Directory)> fixture() async {
  SharedPreferences.setMockInitialValues({
    'reduceMotion': true,
    'disclaimerAccepted': true,
    'tutorialSeen': true,
  });
  final prefs = Preferences(await SharedPreferences.getInstance());
  final folder = await Directory.systemTemp.createTemp('openola-parity-');
  final d = Diagnostics(
    await Catalog.load(),
    prefs,
    recorder: SessionRecorder(directory: () async => folder),
  );
  final ble = ScooterBle();
  return (prefs, d, ble, folder);
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'Inter',
    )..addFont(rootBundle.load('assets/Inter.ttf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
  test(
    'ODX cells preserve scaling, missing bytes, ASCII and signed values',
    () async {
      final c = await Catalog.load();
      ReadIdentifier did(int id) =>
          c.identifiers.firstWhere((r) => r.ecu == Ecu.bms && r.did == id);
      final voltage = did(0xe106).decode([0xa0, 0x0f]);
      expect(voltage.first.value, 4.0);
      expect(voltage[1].value, isNull);
      expect(did(0xe108).decode([32, 0]).first.value, 3.2);
      expect(did(0xe109).decode([21, 0]).first.value, 2.1);
      final data = ReadIdentifier(Ecu.bms, {
        'RequestFormat': '22F181',
        'Description': 'Version',
        'Parameters': [
          {
            'Parameter': 'Version',
            'Size (Bits)': 16,
            'StartBit': 0,
            'Encoding': 'ASCII',
          },
          {
            'Parameter': 'Signed',
            'Size (Bits)': 8,
            'StartBit': 16,
            'Encoding': 'Signed',
            'Resolution': .1,
            'Offset': 0,
          },
        ],
      });
      final values = data.decode([65, 66, 246]);
      expect(values.first.value, 'AB');
      expect(values.last.value, -1);
      final b = BatterySnapshot.fromResults([
        IdentifierResult(did(0xe106), bytes: [0xa0, 0x0f]),
        IdentifierResult(did(0xe108), bytes: [32, 0]),
        IdentifierResult(did(0xe109), error: 'unsupported'),
      ], demo: false);
      expect(b.cells.length, 1);
      expect(b.cells.first.estimatedWh, closeTo(12.8, .001));
      expect(b.cells.first.ir, isNull);
      expect(b.errors, hasLength(1));
      expect(b.lowestCell, 1);
    },
  );
  test(
    'Read batches require service guard, tolerate individual failure and restore monitor',
    () async {
      final (p, d, ble, folder) = await fixture();
      final spy = ReadSpy(d.catalog, p);
      d.dispose();
      ble.dispose();
      addTearDown(() async {
        spy.dispose();
        await folder.delete(recursive: true);
      });
      spy.connection = Connection.connected;
      spy.firmware = '5.0.0';
      spy.acceptFrame(const CanPacket(0x211, [3, 0, 0, 0, 0, 0, 0, 0]));
      spy.acceptFrame(const CanPacket(0x610, [0, 0, 0, 0, 0, 0, 0, 0]));
      spy.live = true;
      final definitions = spy.catalog.identifiers
          .where((r) => r.ecu == Ecu.bms && [0xe106, 0xe109].contains(r.did))
          .toList();
      expect(await spy.readIdentifiers(definitions), isEmpty);
      expect(spy.calls, isEmpty);
      spy.bench = true;
      spy.mode = 'SERVICE';
      spy.failure = true;
      final rows = await spy.readIdentifiers(definitions);
      expect(rows.length, 2);
      expect(rows.last.error, contains('IR'));
      expect(spy.live, isTrue);
      expect(spy.calls.first, 'diag');
      expect(spy.calls.last, 'monitor');
      expect(spy.calls.where((x) => x.startsWith('BMS:')).length, 2);
    },
  );
  test(
    'Batch cancellation finishes one request; disconnect discards late results',
    () async {
      final (p, d, ble, folder) = await fixture();
      final spy = ReadSpy(d.catalog, p);
      d.dispose();
      ble.dispose();
      addTearDown(() async {
        spy.dispose();
        await folder.delete(recursive: true);
      });
      spy.connection = Connection.connected;
      spy.firmware = '5.0.0';
      spy.acceptFrame(const CanPacket(0x211, [3, 0, 0, 0, 0, 0, 0, 0]));
      spy.acceptFrame(const CanPacket(0x610, [0, 0, 0, 0, 0, 0, 0, 0]));
      spy.bench = true;
      spy.mode = 'SERVICE';
      spy.pending = Completer();
      final defs = spy.catalog.identifiers.take(3).toList();
      final future = spy.readIdentifiers(defs);
      await Future<void>.delayed(Duration.zero);
      spy.cancelRead();
      spy.pending!.complete();
      expect((await future).length, 1);
      spy.pending = Completer();
      final later = spy.readIdentifiers(defs);
      await Future<void>.delayed(Duration.zero);
      await spy.disconnect();
      spy.pending!.complete();
      expect(await later, isEmpty);
      expect(spy.identifierResults, isEmpty);
    },
  );
  test(
    'Recorder writes desktop JSONL; summaries, selected plots and CSV keep all samples',
    () async {
      final (p, d, ble, folder) = await fixture();
      addTearDown(() async {
        d.dispose();
        ble.dispose();
        await folder.delete(recursive: true);
      });
      final start = DateTime.utc(2026, 10, 8);
      await d.session.start({'demo': true}, now: start);
      for (var i = 0; i < 3200; i++) {
        d.session.sample({
          'SOC': 100 - i * .01,
          'Name,quoted': i.toDouble(),
          'bad': double.nan,
        }, now: start.add(Duration(seconds: i)));
      }
      final file = (await d.session.stop())!;
      final first = jsonDecode(
        await file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first,
      );
      expect(first['recorder'], 1);
      expect(first['meta']['demo'], true);
      final summary = await SessionRecorder.summarize(file);
      expect(summary.samples, 3200);
      expect(summary.duration, 3199);
      expect(summary.signals['SOC']!.count, 3200);
      expect(summary.signals.containsKey('bad'), false);
      final series = await SessionRecorder.series(file, [
        'SOC',
      ], maxPoints: 100);
      expect(series['SOC']!.length, lessThanOrEqualTo(100));
      expect(series['SOC']!.first.$1, 0);
      expect(series['SOC']!.last.$1, greaterThan(3000));
      final csv = File('${folder.path}/session.csv');
      await SessionRecorder.exportCsv(summary, csv);
      final lines = await csv.readAsLines();
      expect(lines.length, 3201);
      expect(lines.first, contains('"Name,quoted"'));
      expect(lines.last, contains('"3199.0"'));
      expect((await d.session.library()).length, 1);
    },
  );
  test(
    'Desktop recording imports tolerate damaged rows and preserve zero',
    () async {
      final file = File(
        '${(await Directory.systemTemp.createTemp('openola-import-')).path}/desktop.jsonl',
      );
      addTearDown(() => file.parent.delete(recursive: true));
      await file.writeAsString(
        '{"recorder":1,"started":0,"meta":{"demo":false}}\n{"t":0,"v":{"Current":0,"SOC":80}}\ninvalid\n{"t":1,"v":{"Current":2}}\n',
      );
      final summary = await SessionRecorder.summarize(file);
      expect(summary.samples, 2);
      expect(summary.signals['Current']!.minimum, 0);
      expect(summary.signals['Current']!.last, 2);
      expect((await SessionRecorder.series(file, ['Current']))['Current'], [
        (0.0, 0.0),
        (1.0, 2.0),
      ]);
    },
  );
  test(
    'Recording excludes stale signals and derives power only from fresh voltage and current',
    () async {
      final (p, d, ble, folder) = await fixture();
      addTearDown(() async {
        d.dispose();
        ble.dispose();
        await folder.delete(recursive: true);
      });
      d.connection = Connection.connected;
      d.lastFrame = DateTime.now();
      d.readings['1600:Bus_Voltage_00_10ms'] = Reading(
        52,
        'V',
        DateTime.now().subtract(const Duration(seconds: 20)),
        0x640,
      );
      d.readings['288:Overall_Battery_Current'] = Reading(
        4,
        'A',
        DateTime.now(),
        0x120,
      );
      expect(d.telemetryValues['batt_volts'], isNull);
      expect(d.telemetryValues['power_w'], isNull);
      expect(d.telemetryValues['batt_amps'], 4);
      d.sampleTelemetry();
      expect(d.graph.length, 1);
      d.foreground = false;
      d.sampleTelemetry();
      expect(d.graph.length, 1);
      d.readings.clear();
      d.foreground = true;
      await d.session.start({'demo': false});
      d.sampleTelemetry();
      await d.session.stop();
      expect(d.session.samples, 0);
    },
  );
  test(
    'Reports omit decoded identity by default and freeze cell readings',
    () async {
      final (p, d, ble, folder) = await fixture();
      addTearDown(() async {
        d.dispose();
        ble.dispose();
        await folder.delete(recursive: true);
      });
      d.connection = Connection.connected;
      d.demo = true;
      await d.readBattery();
      final identity = d.catalog.identifiers.firstWhere(
        (r) => r.group == 'Identity & versions',
      );
      await d.readIdentifiers([identity]);
      final report = DiagnosticReport.capture(d);
      expect(
        (report.data['ecu_reads'] as List).any(
          (r) => r['group'] == 'Identity & versions',
        ),
        false,
      );
      expect((report.data['battery_cells'] as List).length, 14);
      d.battery = null;
      expect((report.data['battery_cells'] as List).length, 14);
      expect(
        (DiagnosticReport.capture(d, includeVin: true).data['ecu_reads']
                as List)
            .any((r) => r['group'] == 'Identity & versions'),
        true,
      );
    },
  );

  test(
    'Notification feed deduplicates and reconstructed features retain missing data',
    () async {
      final (p, d, ble, folder) = await fixture();
      addTearDown(() async {
        d.dispose();
        ble.dispose();
        await folder.delete(recursive: true);
      });
      d.observeNotification([1]);
      d.observeNotification([1]);
      expect(d.notifications.length, 1);
      d.observeNotification([0]);
      d.observeNotification([1]);
      expect(d.notifications.length, 2);
      d.observeNotification([255]);
      expect(d.notifications.first.code, 255);
      expect(featureStatus(null).values.every((v) => v == null), true);
      expect(featureStatus([1])['Boost mode'], 1);
      expect(featureStatus([1])['Vacation mode'], isNull);
      expect(featureStatus([0, 0xc0, 0, 0, 0])['Fast charger (TP)'], 3);
      d.connection = Connection.connected;
      d.demo = true;
      await d.readSoftware('Android version');
      expect(d.softwareResponses['Android version'], contains('simulated'));
    },
  );
  test(
    'Stopping during asynchronous storage setup cancels recorder creation',
    () async {
      final folder = await Directory.systemTemp.createTemp('openola-start-');
      addTearDown(() => folder.delete(recursive: true));
      final pending = Completer<Directory>();
      final recorder = SessionRecorder(directory: () => pending.future);
      final started = recorder.start({'demo': true});
      final expectation = expectLater(started, throwsStateError);
      await recorder.stop();
      pending.complete(folder);
      await expectation;
      expect(recorder.active, false);
      expect(recorder.file, isNull);
      recorder.dispose();
    },
  );
  for (final (label, size, scale) in [
    ('phone', const Size(390, 844), 1.0),
    ('tablet', const Size(1024, 900), 1.0),
    ('large-text', const Size(360, 800), 1.6),
  ]) {
    for (final theme in [ThemeMode.dark, ThemeMode.light]) {
      testWidgets(
        '$label ${theme.name} Battery cells, graphs and settings scroll normally',
        (tester) async {
          debugDisableShadows = false;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final (p, d, ble, folder) = (await tester.runAsync(fixture))!;
          await p.appearance(theme);
          d.connection = Connection.connected;
          d.demo = true;
          d.battery = BatterySnapshot.simulated();
          d.readings['demo:Display_SoC'] = Reading(
            82.5,
            '%',
            DateTime.now(),
            0,
          );
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('capture'),
              child: OpenOla(prefs: p, diagnostics: d, ble: ble),
            ),
          );
          await precacheScooterIfVisible(tester);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('nav-Battery')));
          await tester.pumpAndSettle();
          expect(find.byType(BatteryPage), findsOneWidget);
          final viewport = find.byKey(const ValueKey('workspace-scroll'));
          final cells = find.byType(CellGauge);
          await tester.ensureVisible(cells.first);
          await tester.pumpAndSettle();
          expect(find.textContaining('IR '), findsWidgets);
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const ValueKey('capture')),
            matchesGoldenFile('goldens/battery-$label-${theme.name}.png'),
          );
          await tester.tap(cells.first);
          await tester.pumpAndSettle();
          expect(find.text('Cell group 1'), findsOneWidget);
          expect(find.text('Energy available'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Done'));
          await tester.tap(find.text('Done'));
          await tester.pumpAndSettle();
          await tester.ensureVisible(cells.last);
          await tester.pumpAndSettle();
          expect(find.text('#14'), findsOneWidget);
          expect(
            tester.getSize(viewport).height,
            greaterThan(size.height * .65),
          );
          await tester.ensureVisible(find.text('Graphs'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Graphs'));
          await tester.pumpAndSettle();
          expect(find.text('Live trends'), findsOneWidget);
          await tester.tap(
            find.descendant(
              of: find.byType(BatteryPage),
              matching: find.text('Settings'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('BMS settings'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          d.dispose();
          ble.dispose();
          await tester.runAsync(() => folder.delete(recursive: true));
          debugDisableShadows = true;
        },
      );
    }
  }
  testWidgets(
    'Demo unlocks Recorder; reopens file, plots and searches every signal',
    (tester) async {
      debugDisableShadows = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (p, d, ble, folder) = (await tester.runAsync(fixture))!;
      await p.appearance(ThemeMode.dark);
      await p.setWorkspaceMode(WorkspaceMode.technician);
      d.connection = Connection.connected;
      d.demo = true;
      await tester.runAsync(() async {
        await d.session.start({'demo': true}, now: DateTime.utc(2026, 10, 8));
        d.session.sample({'SOC': 80, 'Current': 2});
        d.session.sample({
          'SOC': 79,
          'Current': 3,
        }, now: DateTime.now().add(const Duration(seconds: 1)));
        await d.session.stop();
      });
      await tester.pumpWidget(
        RepaintBoundary(
          key: const ValueKey('capture'),
          child: OpenOla(prefs: p, diagnostics: d, ble: ble),
        ),
      );
      await precacheScooterIfVisible(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      expect(find.text('Recorder'), findsOneWidget);
      await tester.tap(find.text('Recorder'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect((await d.session.library()).length, 1);
        await tester.tap(find.text('Refresh'));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pumpAndSettle();
      }
      final name = d.session.file!.uri.pathSegments.last;
      expect(find.text(name), findsOneWidget);
      await tester.runAsync(() async {
        await tester.tap(find.text(name));
        await Future<void>.delayed(const Duration(milliseconds: 80));
      });
      await tester.pumpAndSettle();
      expect(d.openedSession?.samples, 2);
      expect(find.byType(RecorderPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('capture')),
        matchesGoldenFile('goldens/recorder-phone-dark.png'),
      );
      await tester.ensureVisible(find.text('Find a recorded signal'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'SOC');
      await tester.pumpAndSettle();
      expect(find.text('SOC').last, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      ble.dispose();
      await tester.runAsync(() => folder.delete(recursive: true));
      debugDisableShadows = true;
    },
  );
  testWidgets(
    'Demo Battery read, full recording lifecycle and decoded Components read',
    (tester) async {
      debugDisableShadows = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (p, d, ble, folder) = (await tester.runAsync(fixture))!;
      await p.setWorkspaceMode(WorkspaceMode.technician);
      d.connection = Connection.connected;
      d.demo = true;
      await tester.pumpWidget(OpenOla(prefs: p, diagnostics: d, ble: ble));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-Battery')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read battery & cells'));
      await tester.pumpAndSettle();
      expect(d.battery!.cells.length, 14);
      expect(d.battery!.healthUnit('soh'), 'mΩ');
      expect(d.battery!.estimatedPackWh, closeTo(3152.1, .1));
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recorder'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => d.startSession());
      await tester.pumpAndSettle();
      expect(d.session.active, true);
      expect(d.live, true);
      d.readings['demo:Overall_SOC'] = Reading(82, '%', DateTime.now(), 0);
      await tester.runAsync(() async {
        d.sampleTelemetry();
        await d.stopSession();
      });
      await tester.pumpAndSettle();
      expect(d.session.active, false);
      expect(d.session.samples, 1);
      await tester.tap(find.byTooltip('Open tools menu'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Components'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Components'));
      await tester.pumpAndSettle();
      expect(find.byType(IdentifiersPage), findsOneWidget);
      await tester.tap(find.text('Read BMS'));
      await tester.pumpAndSettle();
      expect(d.identifierResults.length, greaterThan(20));
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpWidget(const SizedBox());
      d.dispose();
      ble.dispose();
      await tester.runAsync(() => folder.delete(recursive: true));
      debugDisableShadows = true;
    },
  );
}
