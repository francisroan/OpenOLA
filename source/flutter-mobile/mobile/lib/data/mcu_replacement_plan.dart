/// Reconstructed from Ola Diagnostics 0.32.215 MotorReplacementFragment.
/// This is a file-choice preview, not a replacement MCU hardware check.
enum McuMotorType { seg, hub }

class McuFirmwareCandidate {
  const McuFirmwareCandidate(this.file, this.version, this.sha256);
  final String file;
  final String version;
  final String sha256;

  static McuFirmwareCandidate? forGen1({
    required String vin,
    required String headUnitSoftware,
    required McuMotorType motor,
  }) {
    if (vin.length != 17 || !RegExp(r'^[A-Z0-9]{17}$').hasMatch(vin)) {
      return null;
    }
    if (!RegExp(r'^[345](?:\.|\b)').hasMatch(headUnitSoftware.trim())) {
      return null;
    }
    final prefix = vin.substring(0, 5);
    final is58 = prefix == 'P53AU';
    if (!is58 && prefix != 'P53BA' && prefix != 'P53BD') return null;
    if (is58) {
      return motor == McuMotorType.seg
          ? const McuFirmwareCandidate(
              'mcu_72_01_58_03.bin',
              '72.01.58.03',
              'FE5D34B522916B072189D8D0B823E85E8BEAFBE02CC6BACC66559C12CA89FAA0',
            )
          : const McuFirmwareCandidate(
              'mcu_72_01_58_02.bin',
              '72.01.58.02',
              'B6B4BB7C928CE65E1D03E1DCD6FC6BF764B65C226FF6A5C0B337E6F2430AA1A5',
            );
    }
    return motor == McuMotorType.seg
        ? const McuFirmwareCandidate(
            'mcu_72_01_53_03.bin',
            '72.01.53.03',
            '93A32064BC0470A88C0669DA23BFA3EDDB5946AA37D712D186CF2AD7B849FA83',
          )
        : const McuFirmwareCandidate(
            'mcu_72_01_53_02.bin',
            '72.01.53.02',
            '053F4766D4B03DB37A44A84F605ACA346C93596A68A918A50B68A9543B33801B',
          );
  }

  bool matchesCurrentSoftware(String? current) =>
      current != null &&
      RegExp(r'(?<!\d)' + RegExp.escape(version) + r'(?!\d)').hasMatch(current);
}
