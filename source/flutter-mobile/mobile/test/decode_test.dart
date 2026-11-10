import 'package:flutter_test/flutter_test.dart';
import 'package:openola/protocol/seed_key.dart';
import 'package:openola/protocol/can.dart';
import 'package:openola/data/catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('seed/key (security access — generation-relevant)', () {
    final seed = 'F7D6A2E3'.codeUnits;
    test('grid key is 8 ASCII-hex bytes', () {
      final key = diagnosticKey(seed, Ecu.vcu);
      expect(key.length, 8);
      expect(
        key.every((b) => (b >= 48 && b <= 57) || (b >= 65 && b <= 70)),
        isTrue,
        reason: 'key bytes should be ASCII hex',
      );
    });
    test('key differs per ECU (per-ECU constants)', () {
      expect(
        diagnosticKey(seed, Ecu.vcu),
        isNot(equals(diagnosticKey(seed, Ecu.bms))),
      );
    });
    test('non-8-byte seed uses the fallback transform', () {
      expect(diagnosticKey([1, 2, 3], Ecu.bms).length, 3);
    });
  });

  group('live fault decoding', () {
    test('set bits map to prettified labels; clear/empty yield none', () {
      const f = FaultFrame('BMS', 0x410, 'BMS00_Fault_1', [
        FaultBit('BMS00_Alpha', 1), // byte 0, bit 1
        FaultBit('BMS00_Beta', 9), // byte 1, bit 1
      ]);
      expect(f.active([0x02, 0x02, 0, 0, 0, 0, 0, 0]), ['Alpha', 'Beta']);
      expect(f.active([0, 0, 0, 0, 0, 0, 0, 0]), isEmpty);
      expect(f.active(null), isEmpty);
    });
    test('cell suffix is formatted', () {
      expect(
        const FaultBit('BMS00_Voltage_sensor_failureCell1', 0).label,
        'Voltage sensor failure (Cell 1)',
      );
    });
  });

  test('catalog loads the production data (S1/S1X share these)', () async {
    final c = await Catalog.load();
    expect(c.signals.length, greaterThan(200)); // 226-message production DBC
    expect(c.faultFrames, isNotEmpty); // bms/mcu/vcu/imcu fault maps
    expect(c.somCommands, isNotEmpty); // som_ecu_config commands
    final phase1 = c.s1xParametersForModel(12);
    final phase2 = c.s1xParametersForModel(13);
    expect(phase1.length, greaterThanOrEqualTo(190));
    expect(phase2.length, greaterThanOrEqualTo(190));
    expect(
      phase1.singleWhere((p) => p.name == 'BRAKE_L_SIGNAL').dbcName,
      'Rear_Brake_Press',
    );
    expect(
      phase2.singleWhere((p) => p.name == 'BRAKE_L_SIGNAL').dbcName,
      'Front_Brake_Press',
    );
    expect(
      c.s1xParametersForModel(7).any((p) => p.name == 'BRAKE_L_SIGNAL'),
      isFalse,
      reason: 'an unspecified S1X phase must omit the conflicting brake map',
    );
    expect(c.s1xParametersForModel(3), isEmpty);
  });
}
