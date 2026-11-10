import 'package:flutter_test/flutter_test.dart';
import 'package:openola/data/mcu_replacement_plan.dart';

void main() {
  test('Gen1 S1 Pro SEG candidate follows APK VIN family and OS major', () {
    for (final vin in ['P53BA123456789012', 'P53BD123456789012']) {
      final candidate = McuFirmwareCandidate.forGen1(
        vin: vin,
        headUnitSoftware: '5.0.0',
        motor: McuMotorType.seg,
      );
      expect(candidate?.file, 'mcu_72_01_53_03.bin');
      expect(candidate?.matchesCurrentSoftware('72.01.53.03'), isTrue);
      expect(candidate?.matchesCurrentSoftware('72.01.53.02'), isFalse);
    }
  });

  test('P53AU branches distinguish operator-selected motor', () {
    const vin = 'P53AU123456789012';
    expect(
      McuFirmwareCandidate.forGen1(
        vin: vin,
        headUnitSoftware: '4.0.0',
        motor: McuMotorType.seg,
      )?.file,
      'mcu_72_01_58_03.bin',
    );
    expect(
      McuFirmwareCandidate.forGen1(
        vin: vin,
        headUnitSoftware: '4.0.0',
        motor: McuMotorType.hub,
      )?.file,
      'mcu_72_01_58_02.bin',
    );
  });

  test('unknown identity or release never produces a flash candidate', () {
    for (final (vin, release) in [
      ('', '5.0.0'),
      ('P53BA123456789012', 'Unknown'),
      ('P53BA123456789012', '6.0.0'),
      ('P53XX123456789012', '5.0.0'),
    ]) {
      expect(
        McuFirmwareCandidate.forGen1(
          vin: vin,
          headUnitSoftware: release,
          motor: McuMotorType.seg,
        ),
        isNull,
      );
    }
  });
}
