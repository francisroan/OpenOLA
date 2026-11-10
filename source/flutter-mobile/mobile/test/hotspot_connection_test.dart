import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/screens/core.dart';
import 'vehicle_profile_test.dart' as fixtures;

class ConnectionSpy extends Diagnostics {
  ConnectionSpy(super.catalog, super.prefs);
  bool? requestedHotspot;
  bool? requestedS1xTcp;
  final requestedHosts = <String>[];
  @override
  Future<void> connect(
    String host,
    int port, {
    bool secure = false,
    bool simulated = false,
    bool phoneHotspot = false,
    bool s1xTcp = false,
  }) async {
    requestedHotspot = phoneHotspot;
    requestedS1xTcp = s1xTcp;
    requestedHosts.add(host);
    if (host.contains(':')) connection = Connection.connected;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('S1X TCP choice reaches connection setup', (tester) async {
    final original = (await tester.runAsync(
      () => fixtures.fixture(10, '5.0.0'),
    ))!;
    await original.prefs.store.setString('host', '192.168.43.50');
    final d = ConnectionSpy(original.catalog, original.prefs);
    addTearDown(original.dispose);
    addTearDown(d.dispose);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectPage(d: d)),
      ),
    );
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pump();
    await tester.tap(find.text('Enter address or scan QR'));
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('manual-connect'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(d.requestedS1xTcp, isTrue);
    expect(tester.takeException(), isNull);
  });

  for (final saved in [false, true]) {
    testWidgets('hotspot routing restores $saved and forwards user selection', (
      tester,
    ) async {
      final original = (await tester.runAsync(
        () => fixtures.fixture(3, '5.0.0'),
      ))!;
      await original.prefs.store.setBool('phoneHotspot', saved);
      await original.prefs.store.setString('host', '192.168.43.50');
      final d = ConnectionSpy(original.catalog, original.prefs);
      addTearDown(original.dispose);
      addTearDown(d.dispose);
      tester.view.physicalSize = const Size(500, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ConnectPage(d: d)),
        ),
      );
      await tester.tap(find.text('Enter address or scan QR'));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('manual-connect'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(d.requestedHotspot, saved);
      final alternate = find.byKey(
        ValueKey(saved ? 'setup-scooter-wifi' : 'setup-phone-hotspot'),
      );
      await tester.ensureVisible(alternate);
      await tester.tap(alternate);
      await tester.pump();
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(d.requestedHotspot, !saved);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('IPv6 discovery connects to a scoped Gen2 candidate', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('in.crossfire.openola/network');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'discoverIpv6Hosts');
      return <String>['[fe80::207%wlan0]'];
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    final original = (await tester.runAsync(
      () => fixtures.fixture(3, '5.0.0'),
    ))!;
    final d = ConnectionSpy(original.catalog, original.prefs);
    addTearDown(original.dispose);
    addTearDown(d.dispose);
    tester.view.physicalSize = const Size(500, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectPage(d: d)),
      ),
    );
    final button = find.byKey(const ValueKey('primary-connect'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
    expect(d.requestedHosts, ['[fe80::207%wlan0]']);
    expect(d.connection, Connection.connected);
    expect(tester.takeException(), isNull);
  });
}
