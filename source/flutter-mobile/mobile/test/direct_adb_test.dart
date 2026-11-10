import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/protocol/direct_adb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const adb = MethodChannel('in.crossfire.openola/adb');
  const network = MethodChannel('in.crossfire.openola/network');
  final calls = <MethodCall>[];

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(network, (call) async {
          calls.add(call);
          return true;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(adb, (call) async {
          calls.add(call);
          return switch (call.method) {
            'connect' => 'Authorized & connected',
            'publicKey' => 'adb-public-key-token',
            'shell' => 'uid=2000(shell)',
            'install' => 'Success',
            _ => null,
          };
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(network, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(adb, null);
  });

  test('connect binds Wi-Fi and normalizes a bracketed IPv6 host', () async {
    final status = await DirectAdb.connect(
      '[fe80::1234%wlan0]',
      5555,
      phoneHotspot: true,
    );
    expect(status, 'Authorized & connected');
    expect(calls[0].method, 'bindProcessToWifi');
    expect(calls[0].arguments, {'phoneHotspot': true});
    expect(calls[1].method, 'connect');
    expect(calls[1].arguments, {'host': 'fe80::1234%wlan0', 'port': 5555});
  });

  test('key shell install and disconnect use the native ADB bridge', () async {
    expect(await DirectAdb.publicKey(), 'adb-public-key-token');
    expect(await DirectAdb.shell('id'), 'uid=2000(shell)');
    expect(
      await DirectAdb.install('/data/user/0/app/cache/test.apk'),
      'Success',
    );
    await DirectAdb.disconnect();
    expect(calls.map((call) => call.method), [
      'publicKey',
      'shell',
      'install',
      'disconnect',
    ]);
  });
}
