import '../protocol/can.dart';

/// Complete Gen1 records from the official diagnostic app's VersionControl.
/// These are 37-byte DID 0100 payloads, not one-byte model labels.
class VcuVariantRecord {
  static const s1Pro =
      '02030301010100000701010100000000003F0F010101010000000000010100010000000000';
  static const s1ProUpgrade =
      '03070301010100000701010100000100003F0F010101010000000000010100010000000000';

  static List<int> parse(String value) {
    if (value.length != 74 || !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
      throw const FormatException('Expected a complete 37-byte variant record');
    }
    return [
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ];
  }

  static List<int> get standard => parse(s1Pro);
  static List<int> get upgrade => parse(s1ProUpgrade);

  static bool isStandard(List<int> bytes) =>
      hex(bytes).toLowerCase() == s1Pro.toLowerCase();

  static String describe(List<int> bytes) {
    final value = hex(bytes).toLowerCase();
    if (value == s1Pro.toLowerCase()) {
      return 'S1 4 kWh / S1 Pro (official Gen1 non-upgrade template)';
    }
    if (value == s1ProUpgrade.toLowerCase()) {
      return 'S1 Pro with upgrade (official Gen1 template)';
    }
    if (bytes.length == 37 && bytes[0] == 0x01) {
      return 'S1 without upgrade (customized VCU record)';
    }
    if (bytes.length == 37 && bytes[0] == 0x02 && bytes[1] == 0x03) {
      return 'S1 4 kWh / S1 Pro without upgrade (customized VCU record)';
    }
    if (bytes.length == 37 && bytes[0] == 0x03 && bytes[1] == 0x07) {
      return 'S1 Pro with upgrade (customized VCU record)';
    }
    return 'Unknown or customized record (${bytes.length} bytes)';
  }
}
