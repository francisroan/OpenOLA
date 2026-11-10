import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openola/protocol/wifi_can.dart';

void main() {
  group('IPv4 scooter discovery', () {
    test(
      'scans the /24 of Wi-Fi and hotspot interfaces, never mobile or tunnels',
      () {
        final hosts = WifiCan.subnetHosts([
          (name: 'wlan0', address: '192.168.43.149'),
          (name: 'wlan2', address: '10.224.236.62'), // phone hotspot
          (name: 'rmnet_data2', address: '10.50.1.8'), // mobile data
          (name: 'tun0', address: '172.31.237.15'), // VPN
          (name: 'rndis0', address: '10.234.48.106'), // USB tethering
          (name: 'wlan1', address: '8.8.8.8'), // public: never scanned
        ]);
        expect(hosts, contains('192.168.43.252'));
        expect(hosts, contains('10.224.236.70'));
        expect(hosts, isNot(contains('192.168.43.149')), reason: 'own address');
        expect(hosts, isNot(contains('10.224.236.62')), reason: 'own address');
        expect(hosts.any((h) => h.startsWith('10.50.1.')), isFalse);
        expect(hosts.any((h) => h.startsWith('172.31.')), isFalse);
        expect(hosts.any((h) => h.startsWith('10.234.48.')), isFalse);
        expect(hosts.any((h) => h.startsWith('8.8.8.')), isFalse);
        expect(hosts.length, 253 + 253);
      },
    );

    test('the same subnet on two interfaces is scanned once', () {
      final hosts = WifiCan.subnetHosts([
        (name: 'wlan0', address: '192.168.1.20'),
        (name: 'wlan1', address: '192.168.1.21'),
      ]);
      expect(hosts.toSet().length, hosts.length);
    });

    test('probeHosts returns only hosts with the port open', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final open = await WifiCan.probeHosts(
        ['127.0.0.1', '127.0.0.2'],
        server.port,
        timeout: const Duration(milliseconds: 400),
      );
      expect(open, contains('127.0.0.1'));
    });

    test('probeHosts is empty when nothing listens', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      final open = await WifiCan.probeHosts(
        ['127.0.0.1'],
        port,
        timeout: const Duration(milliseconds: 400),
      );
      expect(open, isEmpty);
    });
  });
}
