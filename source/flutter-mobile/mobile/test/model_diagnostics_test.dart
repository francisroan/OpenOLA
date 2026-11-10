import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/bluetooth/ble_controller.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/protocol/can.dart';
import 'package:openola/screens/advanced.dart';
import 'package:openola/screens/model_diagnostics.dart';
import 'vehicle_profile_test.dart' as fixtures;

void main() {
  testWidgets('S1X parameter reference uses exact phase or common rows only', (
    tester,
  ) async {
    final d = (await tester.runAsync(() => fixtures.fixture(13, '5.6.1')))!;
    final ble = ScooterBle();
    addTearDown(d.dispose);
    addTearDown(ble.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvancedPage(tool: Tool.parameters, d: d, ble: ble),
        ),
      ),
    );
    expect(find.text('S1X parameter reference'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'BRAKE_L_SIGNAL');
    await tester.pumpAndSettle();
    expect(find.textContaining('Front_Brake_Press'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Seat Lock Status');
    await tester.pumpAndSettle();
    expect(find.text('Reference only · no UDS read attempted'), findsOneWidget);
    expect(d.link, isNull);
  });

  testWidgets(
    'new model diagnostics show observed ABS and BBW at narrow width',
    (tester) async {
      final d = (await tester.runAsync(() => fixtures.fixture(25, '5.6.1')))!;
      addTearDown(d.dispose);
      d.acceptFrame(const CanPacket(0x270, [32, 0, 0, 0, 1, 32, 0, 0]));
      d.acceptFrame(const CanPacket(0x6df, [75, 125, 100, 0, 0, 0, 0, 0]));
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: ModelDiagnostics(d: d)),
          ),
        ),
      );
      expect(find.text('S1 Pro Gen3 4 kWh'), findsOneWidget);
      expect(find.text('ABS diagnostics'), findsOneWidget);
      expect(
        find.textContaining('ABS Front Raw Wheel Speed: 0.90'),
        findsOneWidget,
      );
      expect(find.textContaining('BBW Low Gain: 75.00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('unknown profile does not surface new controller layouts', (
    tester,
  ) async {
    final d = (await tester.runAsync(() => fixtures.fixture(25, 'Unknown')))!;
    addTearDown(d.dispose);
    d.acceptFrame(const CanPacket(0x6df, [75, 125, 100, 0, 0, 0, 0, 0]));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: ModelDiagnostics(d: d)),
        ),
      ),
    );
    expect(find.text('Common signals only'), findsOneWidget);
    expect(find.text('ABS diagnostics'), findsNothing);
    expect(find.textContaining('BBW Low Gain'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
