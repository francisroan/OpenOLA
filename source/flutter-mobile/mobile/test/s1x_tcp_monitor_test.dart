import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/protocol/s1x_tcp_monitor.dart';
import 'vehicle_profile_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'S1X raw TCP receives split 18-byte telemetry without sending',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final peer = Completer<Socket>();
      final receivedFromApp = <int>[];
      server.listen((socket) {
        peer.complete(socket);
        socket.listen(receivedFromApp.addAll);
      });
      final monitor = S1xTcpMonitor();
      addTearDown(monitor.close);
      final frame = Completer<List<int>>();
      monitor.onFrame = (packet) {
        expect(packet.id, 0x333);
        frame.complete(packet.data);
      };
      await monitor.connect('127.0.0.1', server.port, bindNetwork: false);
      final socket = await peer.future.timeout(const Duration(seconds: 2));
      final raw = <int>[
        1,
        0,
        0,
        0,
        3,
        0x33,
        8,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ];
      socket.add(raw.sublist(0, 7));
      await socket.flush();
      socket.add(raw.sublist(7));
      await socket.flush();
      expect(await frame.future.timeout(const Duration(seconds: 2)), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(receivedFromApp, isEmpty);
      await monitor.close();
      socket.destroy();
    },
  );

  test(
    'S1X TCP controller accepts telemetry and blocks ECU operations',
    () async {
      final records = await Directory.systemTemp.createTemp(
        'openola-s1x-test-',
      );
      addTearDown(() => records.delete(recursive: true));
      const pathProvider = MethodChannel('plugins.flutter.io/path_provider');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathProvider, (_) async => records.path);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProvider, null),
      );
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final peer = Completer<Socket>();
      server.listen(peer.complete);
      final d = await fixtures.fixture(10, '5.0.0');
      addTearDown(d.dispose);
      d.connection = Connection.disconnected;
      await d.connect('127.0.0.1', server.port, s1xTcp: true);
      expect(d.connection, Connection.connected);
      expect(d.s1xTcpReadOnly, isTrue);
      final socket = await peer.future.timeout(const Duration(seconds: 2));
      socket.add(<int>[
        1,
        0,
        0,
        0,
        3,
        0x33,
        8,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(d.raw[0x333], [1, 2, 3, 4, 5, 6, 7, 8]);
      await d.liveMode(true);
      expect(d.live, isTrue);
      await d.startSession();
      expect(d.session.active, isTrue, reason: d.message);
      await d.stopSession();
      await d.liveMode(false);
      expect(d.live, isFalse);
      var ran = false;
      await d.operation('test command', () async {
        ran = true;
      });
      expect(ran, isFalse);
      expect(d.message, contains('read-only'));
      await d.disconnect();
      socket.destroy();
    },
  );
}
