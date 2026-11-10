/// Read-only decoder for the 18-byte S1X Plus Phase 2 TCP frame observed in
/// the official diagnostic app. Its ByteHelper reads CAN ID from bytes 2..5
/// and passes bytes 8..17 to the CAN signal parser. The first two bytes and
/// bytes 6..7 are preserved as metadata until their meaning is verified.
class S1xTcpFrame {
  const S1xTcpFrame(this.prefix, this.canId, this.metadata, this.data);
  final List<int> prefix;
  final int canId;
  final List<int> metadata;
  final List<int> data;

  static S1xTcpFrame decode(List<int> bytes) {
    if (bytes.length != 18) {
      throw const FormatException('Expected an 18-byte S1X TCP frame');
    }
    if (bytes[0] == 0x24) {
      throw const FormatException('S1X TCP control frame, not CAN telemetry');
    }
    final id = bytes[2] << 24 | bytes[3] << 16 | bytes[4] << 8 | bytes[5];
    if (id < 0 || id > 0x1FFFFFFF) {
      throw const FormatException('Invalid CAN ID in S1X TCP frame');
    }
    return S1xTcpFrame(
      List<int>.unmodifiable(bytes.sublist(0, 2)),
      id,
      List<int>.unmodifiable(bytes.sublist(6, 8)),
      List<int>.unmodifiable(bytes.sublist(8, 18)),
    );
  }
}

/// TCP delivers arbitrary chunks, so never assume one socket read is one frame.
class S1xTcpFramer {
  final _pending = <int>[];

  List<S1xTcpFrame> add(List<int> chunk) {
    _pending.addAll(chunk);
    final frames = <S1xTcpFrame>[];
    while (_pending.length >= 18) {
      final bytes = _pending.sublist(0, 18);
      _pending.removeRange(0, 18);
      // The official TCP stream also carries control envelopes. They are not
      // CAN telemetry and must not stop later telemetry in the same chunk.
      if (bytes[0] == 0x24) continue;
      frames.add(S1xTcpFrame.decode(bytes));
    }
    return frames;
  }

  void clear() => _pending.clear();
}
