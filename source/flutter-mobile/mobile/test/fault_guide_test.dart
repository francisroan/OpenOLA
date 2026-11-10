import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/fault_explanations.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/screens/battery_page.dart';
import 'package:openola/diagnostics/battery.dart';
import 'package:openola/screens/core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  cellEnergyTests();
  faultPassTwoTests();

  testWidgets('Settings opens the fault guide: search, filter, expand, back', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final (prefs, d) = (await tester.runAsync(() async {
      SharedPreferences.setMockInitialValues({'reduceMotion': true});
      final prefs = Preferences(await SharedPreferences.getInstance());
      return (prefs, Diagnostics(await Catalog.load(), prefs));
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: SettingsPage(
              d: d,
              prefs: prefs,
              onShowTutorial: () {},
              onEnterDeveloper: () async => false,
              onWorkspaceSelected: (_) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.descendant(
      of: find.byType(ExpansionTile),
      matching: find.text('114CF2'),
    );
    final open = find.text('Browse offline fault guide');
    await tester.ensureVisible(open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('Search codes and live flags'), findsOneWidget);

    // Search a known catalogued code.
    await tester.enterText(find.byType(TextField), '114CF2');
    await tester.pumpAndSettle();
    expect(row, findsOneWidget);
    expect(find.text('No matching fault entries.'), findsNothing);

    // Filtering to another ECU hides it.
    await tester.tap(find.text('MCU').first);
    await tester.pumpAndSettle();
    expect(row, findsNothing);
    expect(find.text('No matching fault entries.'), findsOneWidget);
    await tester.tap(find.text('BMS').first);
    await tester.pumpAndSettle();

    // Expand: cell-vent entry is a stop-safely explanation.
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ExpansionTile),
        matching: find.text('Stop safely'),
      ),
      findsOneWidget,
    );

    // "Stop safely" filter: stop-safely entries stay, others are hidden.
    await tester.tap(find.widgetWithText(GestureDetector, 'Stop safely').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '114CF2');
    await tester.pumpAndSettle();
    expect(row, findsOneWidget); // cell-vent entry is stop-safely
    await tester.enterText(find.byType(TextField), '110109');
    await tester.pumpAndSettle();
    expect(find.text('No matching fault entries.'), findsOneWidget);
    await tester.tap(find.widgetWithText(GestureDetector, 'Stop safely').first);
    await tester.pumpAndSettle();

    // Back to Settings.
    await tester.tap(find.byTooltip('Back to Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    d.dispose();
    prefs.dispose();
  });

  test('catalog classification: sensors, hall, cell vent, open circuits', () {
    FaultExplanation x(String c, String t, String s) =>
        explainFault(code: c, description: t, source: s);
    expect(
      x('113111', 'Current sensor failure - Short circuit', 'BMS').severity,
      FaultSeverity.attention,
    );
    expect(
      x('114CF3', 'Over temperature due to Cell vent Failure', 'BMS').severity,
      FaultSeverity.stopSafely,
    );
    expect(
      x('1324F0', 'U-phase Hall disconnection fault', 'MCU').subsystem,
      'Motor drive',
    );
    expect(
      x(
        '131BF1',
        'Motor temperature sensor disconnection fault',
        'MCU',
      ).subsystem,
      'Sensor or wiring',
    );
    expect(
      x('920A13', 'Plate Lamp Open', 'VCU').subsystem,
      'Lighting or accessory circuit',
    );
    expect(
      x('11011C', 'Voltage out of range - Cell1', 'BMS').subsystem,
      'Battery limits',
    );
    // Substring traps: "install" is not a stall, "scan" is not CAN.
    expect(
      x('X1', 'Software installation pending', 'VCU').subsystem,
      isNot('Motor drive'),
    );
    expect(
      x('X2', 'Scan tool attached', 'VCU').subsystem,
      isNot('Controller communication'),
    );
  });

  test(
    'cell resistance ignores zero UDS values and falls back to CAN DCIR',
    () {
      final zero = BatteryCell(1, 3.9, ir: 0);
      expect(cellResistance(zero, [1.2]), 1.2);
      expect(cellResistance(zero, [0.0]), isNull);
      expect(cellResistance(BatteryCell(1, 3.9, ir: 2.5), [1.2]), 2.5);
      expect(cellResistance(BatteryCell(3, 3.9), [1.2]), isNull);
    },
  );
}

void cellEnergyTests() {
  test('cell available Wh: UDS Ah, nominal model share, or unknown', () {
    final full = BatteryCell(1, 4.2, ah: 3.0); // 100 %
    expect(cellAvailableWh(full, 14, ''), closeTo(3.0 * 4.2, 1e-6));
    final noAh = BatteryCell(1, 4.2); // 100 %
    expect(
      cellAvailableWh(noAh, 14, 'S1 Pro Gen3 4 kWh'),
      closeTo(4000 / 14, 1e-6),
    );
    expect(
      cellAvailableWh(noAh, 14, 'S1 Pro with upgrade'),
      closeTo(3970 / 14, 1e-6),
    );
    expect(cellAvailableWh(noAh, 14, 'S1 Air'), isNull);
    expect(whText(null), '— Wh');
    expect(whText(12.34), '12.3 Wh');
  });
}

void faultPassTwoTests() {
  FaultExplanation x(String c, String t, String s) =>
      explainFault(code: c, description: t, source: s);
  test('permanent faults escalate to stop-safely and say so', () {
    for (final t in [
      'Over voltage charge Permanent Fault',
      'Under voltage Permanent Fault',
      'Cell failure permanent fault',
      'Short circuit detection permanent fault',
    ]) {
      final r = x('X', t, 'BMS');
      expect(r.severity, FaultSeverity.stopSafely, reason: t);
      expect(r.subsystem, startsWith('Permanent fault'), reason: t);
    }
    // An accessory "permanent" wording must not become a stop-safely alert.
    expect(
      x('Y', 'Horn permanent fault', 'VCU').severity,
      isNot(FaultSeverity.stopSafely),
    );
  });

  test('brake light and previously generic entries get specific guidance', () {
    expect(x('920B11', 'Brake lamp Short', 'VCU').subsystem, 'Brake light');
    expect(
      x('1146F1', 'PDU temperature - error', 'BMS').subsystem,
      'Thermal protection',
    );
    expect(
      x('1152F0', 'Over time to fast charge -Error', 'BMS').subsystem,
      'Charging',
    );
    expect(
      x('D10108', 'VCU bus signal/message failure', 'BMS').subsystem,
      'Controller communication',
    );
    for (final t in [
      'Drive Protection',
      'Drive Overload (Grade 3)',
      'Motor over speed fault (Grade 3)',
      'Failure for motor parameter tuning',
    ]) {
      expect(x('M', t, 'MCU').subsystem, 'Motor controller', reason: t);
    }
  });
}
