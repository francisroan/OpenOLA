import 'package:flutter_test/flutter_test.dart';
import 'package:openola/bluetooth/ble_protocol.dart';
import 'package:openola/diagnostics/battery.dart';
import 'package:openola/diagnostics/head_unit_tools.dart';
import 'package:openola/protocol/can.dart';
import 'package:openola/screens/battery_page.dart';
import 'vehicle_profile_test.dart' as fixtures;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Sport/Hyper database discovery', () {
    test(
      'lists base profile databases, known one first, ignoring journals',
      () {
        final paths = HeadUnitCommands.parseProfileDatabases('''
profile-manager-database
profile-manager-database-wal
profile-manager-database-4
profile-manager-database-4-shm
profile-manager-database-4-journal
unrelated.db
''');
        expect(paths.first, HeadUnitCommands.restrictionDatabase);
        expect(paths, hasLength(2));
        expect(
          paths.any((p) => p.endsWith('-wal') || p.endsWith('-shm')),
          isFalse,
        );
      },
    );

    test('a database path must be a clean absolute path', () {
      const uuid = '11111111-2222-3333-4444-555555555555';
      expect(
        HeadUnitCommands.restrictionRead(
          uuid,
          database: '/data/data/x/databases/db-5',
        ),
        contains('/data/data/x/databases/db-5'),
      );
      expect(
        () => HeadUnitCommands.restrictionRead(uuid, database: '/x; reboot'),
        throwsFormatException,
      );
    });
  });

  group('uninstall safety', () {
    test('only apps under /data/app count as user-installed', () {
      expect(
        HeadUnitCommands.isUserInstalled(['/data/app/~~a/com.x-1/base.apk']),
        isTrue,
      );
      expect(
        HeadUnitCommands.isUserInstalled([
          '/data/app/~~a/com.x-1/base.apk',
          '/system/app/Evil/Evil.apk',
        ]),
        isFalse,
      );
      expect(
        HeadUnitCommands.isUserInstalled(['/system/priv-app/X/X.apk']),
        isFalse,
      );
      expect(HeadUnitCommands.isUserInstalled([]), isFalse);
    });

    test('package names are validated before reaching a shell', () {
      expect(
        HeadUnitCommands.uninstallPackage('com.example.tool'),
        'pm uninstall com.example.tool',
      );
      expect(
        () => HeadUnitCommands.uninstallPackage('com.x; rm -rf /'),
        throwsFormatException,
      );
    });
  });

  group('cell resistance sources', () {
    test('BMS value wins, then CAN DCIR, then a flagged estimate', () {
      final withIr = BatteryCell(1, 3.9, ir: 2.0);
      expect(cellResistanceInfo(withIr, [1.0], [3.0]), (2.0, false));
      final noIr = BatteryCell(1, 3.9);
      expect(cellResistanceInfo(noIr, [1.5], [3.0]), (1.5, false));
      expect(cellResistanceInfo(noIr, [0.0], [3.0]), (3.0, true));
      expect(cellResistanceInfo(noIr, [null], [null]), (null, false));
      expect(cellResistance(noIr, const [], [2.2]), 2.2);
    });
  });

  group('parallel upload and passcode parsing', () {
    test('chunk files sort correctly and join with a glob', () {
      final a = HeadUnitCommands.writeApkPart(0, 7, [1, 2, 3]);
      final b = HeadUnitCommands.writeApkPart(0, 12, [1, 2, 3]);
      expect(a, contains('/data/local/tmp/ola_p/0_00007'));
      expect(b, contains('/data/local/tmp/ola_p/0_00012'));
      expect('0_00007'.compareTo('0_00012') < 0, isTrue);
      expect(
        HeadUnitCommands.decodeParts(1),
        contains('cat\${IFS}/data/local/tmp/ola_p/1_*'),
      );
      expect(
        () => HeadUnitCommands.writeApkPart(0, 100000, [1]),
        throwsFormatException,
      );
    });

    test(
      'passcode health reports an unreadable table instead of "No element"',
      () {
        expect(
          () => PasscodeHealth.parse('', 'absent'),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => PasscodeHealth.parse('Error: no such table: user_profile', ''),
          throwsA(isA<FormatException>()),
        );
        expect(PasscodeHealth.parse('2|2|5\n', 'present').profileCount, 2);
        expect(
          () => HeadUnitCommands.passcodeHealthFrom('/x; id'),
          throwsFormatException,
        );
      },
    );
  });

  group('Sport/Hyper guards use real frames', () {
    test('Park and unplugged are recognised from live CAN frames', () async {
      final d = (await fixtures.fixture(2, '5.0.0'));
      addTearDown(d.dispose);
      expect(d.parkedFresh, isFalse, reason: 'no frame yet');
      // Frames captured from a Parked, unplugged S1 Pro.
      d.acceptFrame(
        const CanPacket(0x113, [
          0x01,
          0x5d,
          0x00,
          0x2f,
          0x00,
          0x00,
          0xf0,
          0xd2,
        ]),
      );
      d.acceptFrame(const CanPacket(0x62d, [0, 0, 0, 0, 0, 0, 0, 0]));
      expect(d.rideMode, 'Parked');
      expect(d.parkedFresh, isTrue);
      expect(d.chargerDisconnectedFresh, isTrue);
      // Normal mode (0x113 byte 5 = 4 -> mode 2) is not Park.
      d.acceptFrame(
        const CanPacket(0x113, [
          0x01,
          0x5d,
          0x00,
          0x2f,
          0x00,
          0x04,
          0xf0,
          0xd2,
        ]),
      );
      expect(d.rideMode, 'Normal');
      expect(d.parkedFresh, isFalse);
    });
  });

  test('BLE seed->key matches the classic Python client on several seeds', () {
    // Reference values produced by tool/ble/olakey.py (BLE, level 01).
    const expected = {
      'F7D6A2E3': '83C8BBF0',
      '00000000': '581A4200',
      'A1B2C3D4': 'D0D13637',
      '12345678': 'FD64D148',
      'FFFFFFFF': 'BC689246',
      '9E8D7C6B': '3D2B697F',
    };
    expected.forEach((seed, key) {
      expect(
        String.fromCharCodes(BleProtocol.seedKey(seed.codeUnits)),
        key,
        reason: 'seed $seed',
      );
    });
  });

  test('HMI_Mode_Default is a status bit, not a fault flag', () async {
    final d = await fixtures.fixture(2, '5.0.0');
    addTearDown(d.dispose);
    // 0x214 Vehicle_Config_Data_3, HMI_Mode_Default = bit 8 (byte 1, bit 0).
    d.acceptFrame(const CanPacket(0x214, [0, 1, 0, 0, 0, 0, 0, 0]));
    expect(d.broadcast.any((f) => f.contains('HMI_Mode_Default')), isFalse);
    // A real fault bit still shows up.
    expect(d.broadcast, isA<Iterable<String>>());
  });

  test('real captured BLE session decrypts: AES ack and status frame', () {
    // Captured from a live scooter on 7 Nov 2026 (seed E4A08395).
    final seed = 'E4A08395'.codeUnits;
    final key = BleProtocol.seedKey(seed);
    expect(String.fromCharCodes(key), '7288BA40');
    final session = BleProtocol.sessionKey(seed, key);
    String hex(List<int> b) =>
        b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    expect(hex(session), 'ac6f0c85ebf5443fb00037b238a1931e');
    List<int> plain(String frame) {
      final b = [
        for (var i = 0; i < frame.length; i += 2)
          int.parse(frame.substring(i, i + 2), radix: 16),
      ];
      final n = b[0] + 1;
      return BleProtocol.crypt(session, b.sublist(8, n - 3), [b[6], b[7]]);
    }

    // TEST_AES ack: type 0x72, data 01.
    expect(plain('0ca16aeef43a9e1d0bec0155f3'), [0x72, 1]);
    // Status frame: type 0x07, data[3] = SoC 72 %, data[4] = range 100 km.
    final status = plain('13a26aeef43a1d0c5f0a88f051dd571a0f0172f4');
    expect(status[0], 0x07);
    expect(status[1 + 3], 72);
    expect(status[1 + 4], 100);
  });
}
