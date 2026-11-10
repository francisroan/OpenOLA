import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/design/glass.dart';
import 'package:openola/protocol/can.dart';
import 'package:openola/screens/battery_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Gen3 BMS balancing broadcasts are shown without enabling an unverified request', (tester) async {
    SharedPreferences.setMockInitialValues({'reduceMotion': true});
    final (prefs, d) = (await tester.runAsync(() async {
      final prefs = Preferences(await SharedPreferences.getInstance());
      final d = Diagnostics(await Catalog.load(), prefs);
      return (prefs, d);
    }))!;
    addTearDown(d.dispose);
    addTearDown(prefs.dispose);
    d.connection = Connection.connected;
    d.firmware = '5.6.2.gen3.1114';
    d.acceptFrame(const CanPacket(0x211, [31, 0, 0, 0, 0, 0, 0, 0]));
    d.acceptFrame(const CanPacket(0x610, [4, 1, 0, 1, 0, 0, 0, 0]));
    d.acceptFrame(const CanPacket(0x160, [1, 0, 0, 0, 0, 0, 0, 0]));
    // Gen3 DBC: group 3 is bit 2, group 12 is bit 11.
    d.acceptFrame(const CanPacket(0x170, [0x04, 0x08, 0, 0, 0, 0, 0, 0]));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: BatteryPage(d: d))),
    ));
    await tester.pump();
    await tester.tap(find.text('Settings').first);
    await tester.pump();
    expect(find.text('BMS balancing: active'), findsOneWidget);
    expect(find.text('Groups balancing: 3, 12'), findsOneWidget);
    final button = tester.widget<GlassButton>(
      find.widgetWithText(GlassButton, 'Request cell balancing'),
    );
    expect(button.onPressed, isNull);
  });
}
