import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openola/protocol/can.dart';
import 'package:openola/protocol/seed_key.dart';
import 'package:openola/protocol/uds.dart';
import 'package:openola/protocol/wifi_can.dart';
import 'package:openola/protocol/s1x_tcp_frame.dart';
import 'package:openola/bluetooth/ble_protocol.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/data/vehicle_profile.dart';
import 'package:openola/data/vcu_variant.dart';
import 'package:openola/data/repair_values.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/report.dart';

class FakeCan implements CanLink {
  final writes = <CanPacket>[];
  final replies = <List<int>>[];
  @override
  void clearQueue(int id) {}
  @override
  Future<void> write(int id, List<int> data) async {
    writes.add(CanPacket(id, data));
  }

  @override
  Future<List<int>> receive(int id, Duration timeout) async {
    if (replies.isEmpty) throw TimeoutException('No simulated reply');
    return replies.removeAt(0);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'CAN packet matches Kotlin big-endian wire layout and classic LE reply',
    () {
      final bytes = CanPacket.encode(0x78e, [3, 0x19, 2, 9]);
      expect(hex(bytes), '0000078E080000000319020900000000');
      expect(CanPacket.decode(bytes).id, 0x78e);
      final little = bytes.toList()..setRange(0, 4, [0x8e, 7, 0, 0]);
      expect(CanPacket.decode(little).id, 0x78e);
      expect(() => CanPacket.decode([1]), throwsFormatException);
    },
  );
  test('verified VCU grid ASCII vector and old seed fallback', () {
    expect(
      ascii.decode(diagnosticKey(ascii.encode('F7D6A2E3'), Ecu.vcu)),
      '48153568',
    );
    expect(diagnosticKey([0, 255], Ecu.vcu), [0xa2, 0x5b]);
  });
  test(
    'legacy S1 TLS handshake failures are eligible for one insecure retry',
    () {
      expect(
        WifiCan.isTlsHandshakeError(
          StateError('gRPC Error (code: 14): HandshakeException'),
        ),
        isTrue,
      );
      expect(
        WifiCan.isTlsHandshakeError(StateError('connection refused')),
        false,
      );
    },
  );
  test(
    'ISO-TP reassembly and response-pending flow-control wire bytes',
    () async {
      final link = FakeCan()
        ..replies.addAll([
          [0x10, 9, 0x59, 2, 255, 0x12, 0x34, 0x56],
          [0x21, 9, 0x78, 0x9a, 0, 0, 0, 0],
        ]);
      final response = await Uds(link).dtcs(Ecu.bms);
      expect(response, [0x59, 2, 255, 0x12, 0x34, 0x56, 9, 0x78, 0x9a]);
      expect(link.writes.first.id, 0x78e);
      expect(link.writes.first.data, [3, 0x19, 2, 9, 0, 0, 0, 0]);
      expect(link.writes.last.data, [0x30, 0, 0x14, 0, 0, 0, 0, 0]);
    },
  );
  test(
    'UDS negative responses stay errors and pending response extends receive',
    () async {
      final denied = FakeCan()..replies.add(singleFrame([0x7f, 0x19, 0x33]));
      await expectLater(Uds(denied).dtcs(Ecu.bms), throwsA(isA<UdsFailure>()));
      final pending = FakeCan()
        ..replies.addAll([
          singleFrame([0x7f, 0x19, 0x78]),
          singleFrame([0x59, 2, 255]),
        ]);
      expect(await Uds(pending).dtcs(Ecu.vcu), [0x59, 2, 255]);
    },
  );
  test(
    'multi-frame security key waits for flow control and sequence is preserved',
    () async {
      final link = FakeCan()
        ..replies.addAll([
          singleFrame([0x50, 3]),
          [0x10, 10, 0x67, 1, ...ascii.encode('F7D6')],
          [0x21, ...ascii.encode('A2E3'), 0, 0, 0],
          [0x30, 0, 0, 0, 0, 0, 0, 0],
          singleFrame([0x67, 2]),
        ]);
      await Uds(link).unlock(Ecu.vcu);
      final first = link.writes.firstWhere((f) => f.data[0] == 0x10);
      expect(first.data, [0x10, 10, 0x27, 2, ...ascii.encode('4815')]);
      expect(link.writes.last.data.take(5), [0x21, ...ascii.encode('3568')]);
    },
  );
  test(
    'Gen3 MCU unlock keeps MCU addressing and uses VCU key variant',
    () async {
      final link = FakeCan()
        ..replies.addAll([
          singleFrame([0x50, 3]),
          [0x10, 10, 0x67, 1, ...ascii.encode('F7D6')],
          [0x21, ...ascii.encode('A2E3'), 0, 0, 0],
          [0x30, 0, 0, 0, 0, 0, 0, 0],
          singleFrame([0x67, 2]),
        ]);
      await Uds(link).unlock(Ecu.mcu, gen3McuKey: true);
      final keyRequest = link.writes.firstWhere((f) => f.data[0] == 0x10);
      expect(keyRequest.id, Ecu.mcu.requestId);
      expect(keyRequest.data, [0x10, 10, 0x27, 2, ...ascii.encode('4815')]);
    },
  );
  test('Gen1 live faults use the dedicated per-ECU bit maps', () async {
    final catalog = await Catalog.load();
    final frames = catalog.faultsFor(VehicleProfile.legacy).toList();
    expect(
      frames.where((f) => f.ecu == 'BMS').expand((f) => f.bits).length,
      109,
    );
    expect(
      frames.where((f) => f.ecu == 'MCU').expand((f) => f.bits).length,
      32,
    );
    expect(frames.where((f) => f.ecu == 'VCU').expand((f) => f.bits).length, 9);
    expect(frames.any((f) => f.ecu == 'IMCU'), isFalse);
    final cellFault = frames.firstWhere((f) => f.id == 1040);
    expect(
      cellFault.active([1, 0, 0, 0, 0, 0, 0, 0]),
      contains('Voltage sensor failure (Cell 1)'),
    );
  });
  test(
    'stored MCU codes retain catalog meaning and verification status',
    () async {
      final catalog = await Catalog.load();
      final faults = catalog.parseFaults(Ecu.mcu, [
        0x59,
        0x02,
        0xff,
        0x13,
        0x01,
        0xf0,
        0x08,
        0x13,
        0x0e,
        0xf0,
        0x08,
        0x13,
        0x18,
        0xf0,
        0x08,
        0xff,
        0xff,
        0xff,
        0x08,
      ]);
      expect(faults.map((fault) => fault.description), [
        'Software overcurrent protection (Grade 3)',
        'Encoder disconnection (Grade 3)',
        'DC Bus undervoltage fault (Grade 3)',
        'Unknown code — absent from catalog',
      ]);
      expect(faults.map((fault) => fault.meaningVerified), [
        true,
        true,
        true,
        false,
      ]);
    },
  );
  test('official S1 Pro VCU templates are complete and distinct', () {
    final standard = VcuVariantRecord.standard;
    final upgrade = VcuVariantRecord.upgrade;
    expect(standard.length, 37);
    expect(upgrade.length, 37);
    expect(VcuVariantRecord.describe(standard), contains('S1 4 kWh / S1 Pro'));
    expect(VcuVariantRecord.describe(upgrade), contains('with upgrade'));
    expect([
      for (var i = 0; i < 37; i++)
        if (standard[i] != upgrade[i]) i,
    ], isNotEmpty);
    expect(() => VcuVariantRecord.parse('03'), throwsFormatException);
  });
  test('Gen1 VCU headers identify family when the body is customized', () {
    final customized = [...VcuVariantRecord.standard]..[20] = 0x02;
    expect(
      VcuVariantRecord.describe(customized),
      'S1 4 kWh / S1 Pro without upgrade (customized VCU record)',
    );
    expect(
      VcuVariantRecord.describe([0x03, 0x07, ...customized.sublist(2)]),
      'S1 Pro with upgrade (customized VCU record)',
    );
    expect(
      VcuVariantRecord.describe([0x01, 0x07, ...customized.sublist(2)]),
      'S1 without upgrade (customized VCU record)',
    );
  });
  test('replacement values use VIN ASCII and four-byte LE odometer', () {
    expect(
      RepairValues.vin('TESTVAN1234567890'),
      ascii.encode('TESTVAN1234567890'),
    );
    expect(() => RepairValues.vin('SHORTVIN'), throwsFormatException);
    expect(RepairValues.odometerKm(123456), [0x40, 0xE2, 0x01, 0x00]);
    expect(RepairValues.decodeOdometerKm([0x40, 0xE2, 0x01, 0]), 123456);
    expect(
      RepairValues.batteryId('PACK1234', expectedLength: 8),
      ascii.encode('PACK1234'),
    );
    expect(
      () => RepairValues.batteryId('PACK!', expectedLength: 5),
      throwsFormatException,
    );
    expect(RepairValues.grade(2), [2]);
    expect(() => RepairValues.grade(3), throwsFormatException);
  });
  test(
    'S1X TCP telemetry keeps the official 18-byte offsets across chunks',
    () {
      final raw = [
        0x01,
        0x00,
        0x00,
        0x00,
        0x03,
        0x33,
        0x08,
        0x00,
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
      final framer = S1xTcpFramer();
      expect(framer.add(raw.sublist(0, 5)), isEmpty);
      final frame = framer.add(raw.sublist(5)).single;
      expect(frame.canId, 0x333);
      expect(frame.prefix, [1, 0]);
      expect(frame.metadata, [8, 0]);
      expect(frame.data, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(framer.add([0x24, ...raw.skip(1), ...raw]).single.canId, 0x333);
      expect(
        () => S1xTcpFrame.decode([0x24, ...raw.skip(1)]),
        throwsFormatException,
      );
    },
  );
  test('BLE CRC, chunk reassembly and AES-CTR roundtrip', () {
    expect(BleProtocol.crc(ascii.encode('123456789')), 0x29b1);
    final frame = BleProtocol().plain(48);
    final assembler = BleAssembler();
    expect(assembler.feed(frame.take(4).toList()), isEmpty);
    expect(assembler.feed(frame.skip(4).toList()).single, frame);
    final seed = ascii.encode('F7D6A2E3');
    final key = BleProtocol.sessionKey(seed, BleProtocol.seedKey(seed));
    final bytes = ascii.encode('D_ALIVE');
    expect(
      BleProtocol.crypt(key, BleProtocol.crypt(key, bytes, [1, 2]), [1, 2]),
      bytes,
    );
    final corrupt = frame.toList()..[5] ^= 1;
    expect(BleAssembler().feed(corrupt), isEmpty);
  });
  test(
    'catalogs load and wide parameter patch preserves unedited bits',
    () async {
      final c = await Catalog.load();
      expect(c.actuators.length, greaterThanOrEqualTo(40));
      expect(c.parameters.length, greaterThanOrEqualTo(180));
      expect(c.signals, isNotEmpty);
      expect(
        c.parameters
            .singleWhere(
              (p) => p.name == 'WxB111_Acceleration_Time_Configuration',
            )
            .did,
        0xb111,
      );
      final p = Parameter(Ecu.bms, {
        'Command': 'wide',
        'RequestFormat': '2EB110',
        'AttachedDatalength (Bytes)': 14,
        'Parameters': [
          {
            'Parameter': 'one',
            'Size (Bits)': '8',
            'StartBit': '80',
            'Resolution': '1',
            'Offset': '0',
          },
        ],
      });
      final original = List.filled(14, 0x55);
      final patched = p.encode(original, {'one': 3});
      expect(patched[10], 3);
      expect(patched.take(10), original.take(10));
      expect(p.decode(patched)['one'], 3);
      expect(() => p.encode(original, {'one': 3.5}), throwsArgumentError);
    },
  );
  test(
    'reports freeze state and distinguish zero, unknown, demo and privacy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = Preferences(await SharedPreferences.getInstance());
      final d = Diagnostics(Catalog(), prefs)..demo = true;
      d.faults[Ecu.vcu] = [];
      d.activity.add('private activity');
      d.manifest = 'private VIN';
      final report = DiagnosticReport.capture(d);
      d.faults[Ecu.bms] = [const Fault('123456', 'new fault', 9)];
      final data = jsonDecode(report.json);
      expect(data['demo'], true);
      expect(data['identifiers'], isNull);
      expect(data['activity_log'], isNull);
      expect(data['controllers'][0]['scanned'], false);
      expect(data['controllers'][1]['scanned'], true);
      expect(data['deep_sleep_bms_wake_validated'], false);
      expect(report.text, contains('DEMO — SIMULATED DATA'));
      expect(report.text, isNot(contains('private VIN')));
      d.dispose();
      prefs.dispose();
    },
  );
  test(
    'demo recovery invalidates scans and returns to Customer mode',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = Preferences(await SharedPreferences.getInstance());
      final d = Diagnostics(Catalog(), prefs)
        ..connection = Connection.connected
        ..demo = true
        ..mode = 'SERVICE';
      await d.recover();
      expect(d.mode, 'CUST');
      expect(d.faults.containsKey(Ecu.bms), false);
      expect(d.message, contains('deep-sleep wake is unvalidated'));
      d.dispose();
      prefs.dispose();
    },
  );
  test(
    'local credential provider loads and iOS PKCS12 identity exists',
    () async {
      final creds = await MutualTlsCredentials.load();
      expect(creds.authority, 'ola.scooter.diag');
      expect(creds.securityContext, isA<SecurityContext>());
      expect(File('assets/certs/ecos-ios.p12').existsSync(), true);
    },
    skip: File('assets/certs/ecos-ios.p12').existsSync()
        ? false
        : 'Personal mTLS identity is intentionally omitted from public source.',
  );
}
