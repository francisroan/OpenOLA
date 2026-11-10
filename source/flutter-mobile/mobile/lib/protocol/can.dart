import 'dart:typed_data';

enum Ecu {
  bms(0x78e, 0x7b1, 'Battery management'),
  vcu(0x786, 0x7b0, 'Vehicle controller'),
  mcu(0x7a6, 0x7b4, 'Motor controller');

  const Ecu(this.requestId, this.responseId, this.description);
  final int requestId, responseId;
  final String description;
  String get label => name.toUpperCase();
}

class CanPacket {
  const CanPacket(this.id, this.data);
  final int id;
  final List<int> data;
  static Uint8List encode(int id, List<int> data) {
    if (data.length > 8) throw ArgumentError('CAN data exceeds eight bytes');
    final raw = Uint8List(16);
    ByteData.sublistView(raw).setUint32(0, id, Endian.big);
    raw[4] = 8;
    raw.setRange(8, 8 + data.length, data);
    return raw;
  }

  static CanPacket decode(List<int> frame) {
    if (frame.length < 16) throw const FormatException('Short CAN packet');
    final raw = Uint8List.fromList(frame.sublist(frame.length - 16));
    final bytes = ByteData.sublistView(raw);
    final be = bytes.getUint32(0, Endian.big) & 0x1fffffff;
    final le = bytes.getUint32(0, Endian.little) & 0x1fffffff;
    final id = be >= 0x600 && be <= 0x7ff
        ? be
        : le >= 0x600 && le <= 0x7ff
        ? le
        : be;
    return CanPacket(id, raw.sublist(8));
  }
}

String hex(List<int> data) =>
    data.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
List<int> singleFrame(List<int> payload) {
  if (payload.length > 7) {
    throw ArgumentError('Single frame exceeds seven bytes');
  }
  return [payload.length, ...payload, ...List.filled(7 - payload.length, 0)];
}

class IsoTpAssembler {
  List<int> _buffer = [];
  int _length = 0;
  bool get waiting => _length > 0;
  List<int>? feed(List<int> bytes) {
    if (bytes.length != 8) {
      throw const FormatException('ISO-TP frame must be eight bytes');
    }
    switch (bytes[0] >> 4) {
      case 0:
        final length = bytes[0] & 15;
        if (length > 7) {
          throw const FormatException('Invalid single-frame length');
        }
        _length = 0;
        return bytes.sublist(1, length + 1);
      case 1:
        _length = ((bytes[0] & 15) << 8) | bytes[1];
        // `bytes` is often a Uint8List, whose sublist() returns another
        // fixed-length Uint8List — addAll() on the consecutive frames below
        // would then throw "Cannot add to a fixed-length list". Copy into a
        // growable List<int> so multi-frame reassembly (e.g. DTC reads) works.
        _buffer = List<int>.from(bytes.sublist(2));
        return null;
      case 2:
        if (!waiting) return null;
        _buffer.addAll(bytes.sublist(1));
        if (_buffer.length >= _length) {
          final result = _buffer.sublist(0, _length);
          _length = 0;
          return result;
        }
    }
    return null;
  }
}
