import 'package:flutter_test/flutter_test.dart';
import 'package:openola/data/mcu_legacy_preview.dart';
import 'package:openola/data/mcu_replacement_plan.dart';

void main() {
  test('legacy candidates follow VIN, motor and head-unit major branches', () {
    String? choose(String prefix, String release, McuMotorType motor) =>
        McuLegacyPreview.file(
          vin: '${prefix}123456789012',
          headUnitSoftware: release,
          motor: motor,
        );
    expect(choose('P53AW', '3.0.0', McuMotorType.hub), 'mcu_92_01_35_11.bin');
    expect(choose('P53AW', '4.0.0', McuMotorType.hub), 'mcu_92_01_49_11.bin');
    expect(choose('P53AW', '5.0.0', McuMotorType.hub), 'mcu_92_01_59_11.bin');
    expect(choose('P53AF', '3.0.0', McuMotorType.seg), 'mcu_92_01_24.bin');
    expect(choose('P53AF', '5.0.0', McuMotorType.hub), 'mcu_92_01_35_01.bin');
    expect(choose('P53CC', 'Unknown', McuMotorType.hub), 'mcu_52_02_126.bin');
    expect(choose('P53BW', 'Unknown', McuMotorType.hub), 'mcu_52_02_54_02.bin');
    expect(choose('P53AW', '5.0.0', McuMotorType.seg), isNull);
    expect(choose('P53XX', '5.0.0', McuMotorType.hub), isNull);
  });
}
