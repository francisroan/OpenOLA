import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/protocol/can.dart';
import 'package:openola/screens/mcu_replacement_guide.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Gen1 S1 Pro guide shows candidate and keeps flash gated', (
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
    d.acceptFrame(const CanPacket(0x211, [2, 0, 0, 0, 0, 0, 0, 0]));
    d.acceptFrame(const CanPacket(0x610, [0, 0, 0, 0, 0, 0, 0, 0]));
    d.mcuReplacementVin = 'P53BA123456789012';
    d.mcuReplacementSoftware = '72.01.53.02';
    d.mcuReplacementPreflightAt = DateTime.now();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: McuReplacementGuide(d: d)),
        ),
      ),
    );
    expect(find.textContaining('mcu_72_01_53_03.bin'), findsWidgets);
    expect(find.textContaining('Replacement MCU part number'), findsWidgets);
    expect(find.textContaining('Flash replacement MCU'), findsNothing);
  });
}
