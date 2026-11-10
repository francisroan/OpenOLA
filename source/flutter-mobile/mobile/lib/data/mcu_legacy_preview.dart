import 'mcu_replacement_plan.dart';

/// File-choice branches in the official app's non-TCP, non-Gen3 replacement
/// fragment. A returned name is a read-only candidate, not part approval.
class McuLegacyPreview {
  static String? file({
    required String vin,
    required String headUnitSoftware,
    required McuMotorType motor,
  }) {
    if (!RegExp(r'^[A-Z0-9]{17}$').hasMatch(vin)) return null;
    final prefix = vin.substring(0, 5);
    final release = headUnitSoftware.trim();
    final major = release.isEmpty
        ? null
        : int.tryParse(release.substring(0, 1));
    final supportedMajor = major == 3 || major == 4 || major == 5;
    if (motor == McuMotorType.seg) {
      if (!supportedMajor) return null;
      if (prefix == 'P53AU') return 'mcu_72_01_58_03.bin';
      if (prefix == 'P53BA' || prefix == 'P53BD') return 'mcu_72_01_53_03.bin';
      if ({'P53AF', 'P53AB', 'P53AC'}.contains(prefix)) {
        return major == 3 ? 'mcu_92_01_24.bin' : 'mcu_92_01_35_00.bin';
      }
      return null;
    }
    if (prefix == 'P53CC') return 'mcu_52_02_126.bin';
    if ({
      'P53BW',
      'P53BV',
      'P53BU',
      'P53BT',
      'P53BS',
      'P53BR',
      'P53BP',
    }.contains(prefix)) {
      return 'mcu_52_02_54_02.bin';
    }
    if (!supportedMajor) return null;
    if (prefix == 'P53AU') return 'mcu_72_01_58_02.bin';
    if (prefix == 'P53BA' || prefix == 'P53BD') return 'mcu_72_01_53_02.bin';
    if (prefix == 'P53AW') {
      return switch (major) {
        3 => 'mcu_92_01_35_11.bin',
        4 => 'mcu_92_01_49_11.bin',
        5 => 'mcu_92_01_59_11.bin',
        _ => null,
      };
    }
    if ({'P53AF', 'P53AB', 'P53AC'}.contains(prefix)) {
      return major == 3 ? 'mcu_92_01_28_01.bin' : 'mcu_92_01_35_01.bin';
    }
    return null;
  }
}
