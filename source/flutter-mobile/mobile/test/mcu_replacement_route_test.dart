import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/data/mcu_replacement_route.dart';
import 'package:openola/data/vehicle_profile.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/protocol/can.dart';
import 'package:openola/screens/mcu_replacement_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('routes known variants without enabling an unverified active trial', () {
    for (final (code, family) in [
      (5, McuReplacementFamily.air),
      (10, McuReplacementFamily.s1xPhase2),
      (25, McuReplacementFamily.gen3),
      (31, McuReplacementFamily.gen3),
    ]) {
      final route = McuReplacementRoute.detect(
        VehicleIdentity(
          code,
          const [1, 1, 0, 1, 0, 0],
          VehicleProfile.common,
          'test',
        ),
      );
      expect(route.family, family);
      expect(route.activeTrial, isFalse);
    }
    final gen1 = McuReplacementRoute.detect(
      const VehicleIdentity(
        2,
        [0, 0, 0, 0, 0, 0],
        VehicleProfile.legacy,
        'test',
      ),
    );
    expect(gen1.activeTrial, isTrue);
  });

  testWidgets('Gen3 replacement setup shows a read-only route', (tester) async {
    SharedPreferences.setMockInitialValues({'reduceMotion': true});
    final d = (await tester.runAsync(() async {
      return Diagnostics(
        await Catalog.load(),
        Preferences(await SharedPreferences.getInstance()),
      );
    }))!;
    addTearDown(d.dispose);
    d.connection = Connection.connected;
    d.firmware = '5.6.2.gen3.1114';
    d.acceptFrame(const CanPacket(0x211, [31, 0, 0, 0, 0, 0, 0, 0]));
    d.acceptFrame(const CanPacket(0x610, [4, 1, 0, 1, 0, 0, 0, 0]));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: McuReplacementWorkspace(d: d)),
        ),
      ),
    );
    expect(find.textContaining('Gen3 MCU / IMCU'), findsWidgets);
    expect(find.text('Read VIN, MCU software and hardware'), findsOneWidget);
    expect(find.textContaining('Flash replacement MCU'), findsNothing);
  });

  testWidgets('Air setup previews the APK HUB file without a flash action', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'reduceMotion': true});
    final d = (await tester.runAsync(() async {
      return Diagnostics(
        await Catalog.load(),
        Preferences(await SharedPreferences.getInstance()),
      );
    }))!;
    addTearDown(d.dispose);
    d.connection = Connection.connected;
    d.firmware = '5.0.0';
    d.acceptFrame(const CanPacket(0x211, [5, 0, 0, 0, 0, 0, 0, 0]));
    d.acceptFrame(const CanPacket(0x610, [1, 1, 0, 1, 0, 0, 0, 0]));
    d.mcuReplacementSurveyVin = 'P53AW123456789012';
    d.mcuReplacementSurveyAt = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: McuReplacementWorkspace(d: d)),
        ),
      ),
    );
    expect(find.textContaining('mcu_92_01_59_11.bin'), findsOneWidget);
    expect(find.textContaining('Flash replacement MCU'), findsNothing);
  });
}
