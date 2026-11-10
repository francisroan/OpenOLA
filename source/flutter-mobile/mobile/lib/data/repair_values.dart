import 'dart:convert';

/// Encodings used by the official Gen1 replacement procedures.
class RepairValues {
  static List<int> vin(String input) {
    final value = input.trim().toUpperCase();
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(value)) {
      throw const FormatException('VIN must be 17 valid ASCII characters');
    }
    return ascii.encode(value);
  }

  static List<int> odometerKm(int value) {
    if (value < 0 || value > 0xFFFFFFFF) {
      throw const FormatException('Odometer is outside the four-byte range');
    }
    return [
      value & 255,
      (value >> 8) & 255,
      (value >> 16) & 255,
      (value >> 24) & 255,
    ];
  }

  static int decodeOdometerKm(List<int> bytes) {
    if (bytes.length != 4) {
      throw const FormatException('Expected a four-byte odometer value');
    }
    return bytes[0] | bytes[1] << 8 | bytes[2] << 16 | bytes[3] << 24;
  }

  static List<int> batteryId(String input, {required int expectedLength}) {
    final value = input.trim().toUpperCase();
    if (expectedLength < 1 ||
        expectedLength > 64 ||
        value.length != expectedLength ||
        !RegExp(r'^[A-Z0-9]+$').hasMatch(value)) {
      throw FormatException(
        'Battery ID must have $expectedLength ASCII letters or digits',
      );
    }
    return ascii.encode(value);
  }

  static List<int> grade(int value) {
    if (value != 1 && value != 2) {
      throw const FormatException('Battery grade must be 01 or 02');
    }
    return [value];
  }
}
