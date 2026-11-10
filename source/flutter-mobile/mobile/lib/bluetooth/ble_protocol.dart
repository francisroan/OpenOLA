import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';
import '../protocol/seed_key.dart';

class BleProtocol {
  static const fixedIv = [
    0x2f,
    0xb1,
    0x9e,
    0x76,
    0x6b,
    0xa2,
    0x5d,
    0x80,
    0x4e,
    0xf4,
    0xd7,
    0xc1,
    0x53,
    0x17,
    0x68,
    0x3e,
  ];
  int _id = 0;
  static List<int> seedKey(List<int> seed) => gridKey(seed, [78, 99, 67, 22]);
  static List<int> sessionKey(List<int> seed, List<int> key) {
    final prk = Hmac(sha256, fixedIv).convert([...seed, ...key]).bytes;
    return Hmac(sha256, prk).convert([1]).bytes.take(16).toList();
  }

  static int crc(List<int> bytes) {
    var value = 0xffff;
    for (final b in bytes) {
      value ^= b << 8;
      for (var i = 0; i < 8; i++) {
        value = ((value << 1) ^ (value & 0x8000 != 0 ? 0x1021 : 0)) & 0xffff;
      }
    }
    return value;
  }

  static List<int> crypt(List<int> key, List<int> data, List<int> random) {
    final cipher = SICStreamCipher(AESEngine())
      ..init(
        true,
        ParametersWithIV(
          KeyParameter(Uint8List.fromList(key)),
          Uint8List.fromList([...fixedIv.take(14), ...random]),
        ),
      );
    return cipher.process(Uint8List.fromList(data));
  }

  List<int> _assemble(
    int type,
    List<int> iv,
    List<int> body,
    bool eof, {
    int? seconds,
  }) {
    final t = seconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    _id = (_id + 1) & 255;
    final inner = [
      _id,
      (t >> 24) & 255,
      (t >> 16) & 255,
      (t >> 8) & 255,
      t & 255,
      ...iv,
      type,
      ...body,
      if (eof) 1,
    ];
    final head = [inner.length + 2, ...inner];
    final check = crc(head);
    return [...head, check >> 8, check & 255];
  }

  List<int> plain(int type, [List<int> body = const []]) =>
      _assemble(type, [1, 2], body, body.isNotEmpty);
  List<int> encrypted(
    List<int> key,
    int type,
    List<int> body, {
    List<int>? iv,
  }) {
    final random = iv ?? List.generate(2, (_) => Random.secure().nextInt(256));
    final encrypted = crypt(key, [type, ...body], random);
    return _assemble(encrypted[0], random, encrypted.sublist(1), true);
  }
}

class BleAssembler {
  final _bytes = <int>[];
  List<List<int>> feed(List<int> bytes) {
    _bytes.addAll(bytes);
    final out = <List<int>>[];
    while (_bytes.length >= 11) {
      final total = _bytes.first + 1;
      if (total < 11 || total > 255) {
        _bytes.removeAt(0);
        continue;
      }
      if (_bytes.length < total) break;
      final frame = _bytes.take(total).toList();
      final check = (frame[total - 2] << 8) | frame.last;
      if (BleProtocol.crc(frame.sublist(0, total - 2)) != check) {
        _bytes.removeAt(0);
        continue;
      }
      _bytes.removeRange(0, total);
      out.add(frame);
    }
    return out;
  }
}
