import '../protocol/can.dart';

class DecodedValue {
  const DecodedValue(this.name, this.value, this.unit);
  final String name, unit;
  final Object? value;
  Map<String, Object?> toJson() => {'name': name, 'value': value, 'unit': unit};
}

/// Read-only ODX definitions, distinct from the writable parameter catalog.
class ReadIdentifier {
  ReadIdentifier(this.ecu, Map<String, dynamic> json)
    : did = int.parse(
        json['RequestFormat'].toString().replaceAll(' ', '').substring(2),
        radix: 16,
      ),
      title = (json['Description'] ?? json['Command']).toString().trim(),
      fields = List<Map<String, dynamic>>.from(json['Parameters'] ?? []);
  final Ecu ecu;
  final int did;
  final String title;
  final List<Map<String, dynamic>> fields;
  String get key =>
      '${ecu.label}:${did.toRadixString(16).toUpperCase().padLeft(4, '0')}';
  String get group {
    final name = title.toLowerCase();
    if (did >= 0xf100 || name.contains('serial') || name.contains('version')) {
      return 'Identity & versions';
    }
    if (ecu == Ecu.bms) {
      if ([0xe106, 0xe108, 0xe109, 0xe10a].contains(did)) {
        return 'Battery cells';
      }
      if (did >= 0xe100 && did <= 0xe10f) return 'Battery health';
      return did >= 0xe300 && did < 0xe400
          ? 'Sensor calibration'
          : 'BMS configuration';
    }
    if (ecu == Ecu.mcu) return 'Motor & controller';
    return did >= 0x03f1 && did <= 0x0424
        ? 'Output states'
        : 'Vehicle inputs & sensors';
  }

  List<DecodedValue> decode(List<int> data) {
    var word = BigInt.zero;
    for (var i = 0; i < data.length; i++) {
      word |= BigInt.from(data[i]) << (i * 8);
    }
    final values = <DecodedValue>[];
    for (final f in fields) {
      final name = '${f['Parameter'] ?? ''}'.trim();
      final bits = int.tryParse('${f['Size (Bits)']}') ?? 0;
      final start = int.tryParse('${f['StartBit']}') ?? 0;
      if (bits <= 0 ||
          start < 0 ||
          name.isEmpty ||
          name == '-' ||
          name == '0') {
        continue;
      }
      final u = '${f['Unit'] ?? ''}'.trim();
      final unit = ['0', '-', 'None'].contains(u) ? '' : u;
      Object? value;
      if (start + bits <= data.length * 8) {
        final encoding = '${f['Encoding']}'.toLowerCase();
        if (encoding == 'ascii') {
          value = String.fromCharCodes(
            data.sublist(start ~/ 8, (start + bits) ~/ 8),
          ).replaceAll(RegExp(r'[\x00]'), '').trim();
        } else {
          var raw = (word >> start) & ((BigInt.one << bits) - BigInt.one);
          if (encoding == 'signed' &&
              (raw & (BigInt.one << (bits - 1))) != BigInt.zero) {
            raw -= BigInt.one << bits;
          }
          value =
              raw.toDouble() * (double.tryParse('${f['Resolution']}') ?? 1) +
              (double.tryParse('${f['Offset']}') ?? 0);
        }
      }
      values.add(DecodedValue(name, value, unit));
    }
    return values;
  }
}

class IdentifierResult {
  IdentifierResult(this.definition, {this.bytes, this.error, DateTime? time})
    : time = time ?? DateTime.now();
  final ReadIdentifier definition;
  final List<int>? bytes;
  final String? error;
  final DateTime time;
  List<DecodedValue> get values =>
      bytes == null ? [] : definition.decode(bytes!);
  Map<String, Object?> toJson() => {
    'ecu': definition.ecu.label,
    'did': definition.key.split(':').last,
    'title': definition.title,
    'group': definition.group,
    'read_at': time.toUtc().toIso8601String(),
    if (bytes != null) 'hex': hex(bytes!),
    'values': values.map((v) => v.toJson()).toList(),
    if (error != null) 'error': error,
  };
}
