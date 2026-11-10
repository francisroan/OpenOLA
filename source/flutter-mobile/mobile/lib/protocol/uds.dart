import 'dart:async';
import 'can.dart';
import 'seed_key.dart';

abstract interface class CanLink {
  Future<void> write(int id, List<int> data);
  Future<List<int>> receive(int id, Duration timeout);
  void clearQueue(int id);
}

class UdsFailure implements Exception {
  const UdsFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class Uds {
  Uds(this.link, {this.timeout = const Duration(seconds: 5)});
  final CanLink link;
  final Duration timeout;
  int _requestsInFlight = 0;
  bool get requestInFlight => _requestsInFlight != 0;
  Future<void> _send(Ecu ecu, List<int> payload) async {
    if (payload.length <= 7) {
      await link.write(ecu.requestId, singleFrame(payload));
      return;
    }
    if (payload.length > 4095) throw ArgumentError('ISO-TP payload too large');
    await link.write(ecu.requestId, [
      0x10 | (payload.length >> 8),
      payload.length & 255,
      ...payload.take(6),
    ]);
    final fc = await link.receive(ecu.responseId, timeout);
    if (fc[0] >> 4 != 3 || fc[0] & 15 != 0) {
      throw const UdsFailure('ECU did not grant flow control');
    }
    var seq = 1;
    for (var i = 6; i < payload.length; i += 7) {
      final chunk = payload.skip(i).take(7).toList();
      await link.write(ecu.requestId, [
        0x20 | seq,
        ...chunk,
        ...List.filled(7 - chunk.length, 0),
      ]);
      seq = (seq + 1) & 15;
      final st = fc[2];
      await Future<void>.delayed(
        Duration(
          microseconds: st <= 127
              ? st * 1000
              : st >= 0xf1 && st <= 0xf9
              ? (st - 0xf0) * 100
              : 0,
        ),
      );
    }
  }

  Future<List<int>> request(Ecu ecu, List<int> payload) async {
    _requestsInFlight++;
    try {
      link.clearQueue(ecu.responseId);
      await _send(ecu, payload);
      var assembler = IsoTpAssembler();
      var deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        final bytes = await link.receive(
          ecu.responseId,
          deadline.difference(DateTime.now()),
        );
        final isFirst = bytes[0] >> 4 == 1;
        final result = assembler.feed(bytes);
        if (isFirst) {
          await link.write(ecu.requestId, [0x30, 0, 0x14, 0, 0, 0, 0, 0]);
        }
        if (result == null) continue;
        if (result.length >= 3 && result[0] == 0x7f && result[2] == 0x78) {
          assembler = IsoTpAssembler();
          deadline = DateTime.now().add(timeout);
          continue;
        }
        return result;
      }
      throw UdsFailure('${ecu.label}: response timeout');
    } finally {
      _requestsInFlight--;
    }
  }

  Future<List<int>> positive(Ecu ecu, List<int> payload) async {
    final result = await request(ecu, payload);
    if (result.isEmpty) throw UdsFailure('${ecu.label}: empty response');
    if (result[0] == 0x7f) {
      throw UdsFailure(
        '${ecu.label}: NRC 0x${hex(result.skip(2).take(1).toList())}',
      );
    }
    if (result[0] != payload[0] + 0x40) {
      throw UdsFailure('${ecu.label}: unexpected service ${hex(result)}');
    }
    return result;
  }

  Future<void> unlock(Ecu ecu, {bool gen3McuKey = false}) async {
    await positive(ecu, [0x10, 3]);
    final seed = await positive(ecu, [0x27, 1]);
    if (seed.length < 3) throw const UdsFailure('Missing security seed');
    final bytes = seed.sublist(2);
    if (bytes.every((b) => b == 0)) return;
    // The Gen3 MCU uses the VCU seed-key variant in the official diagnostic
    // client. Keep the request on the MCU CAN address; only the key differs.
    final keyEcu = gen3McuKey && ecu == Ecu.mcu ? Ecu.vcu : ecu;
    await positive(ecu, [0x27, 2, ...diagnosticKey(bytes, keyEcu)]);
  }

  Future<List<int>> dtcs(Ecu ecu) => positive(ecu, [0x19, 2, 9]);

  /// Ends an extended diagnostic session (UDS 10 01) so the controller goes
  /// back to normal operation (handlebar buttons, cluster) after a read.
  Future<List<int>> defaultSession(Ecu ecu) => positive(ecu, [0x10, 1]);
  Future<List<int>> clear(Ecu ecu) => positive(ecu, [0x14, 255, 255, 255]);
  Future<List<int>> reset(Ecu ecu) => positive(ecu, [0x11, 1]);

  /// RoutineControl start (`0x31 0x01 <id>`), e.g. BMS cell balancing 0x05F8.
  Future<List<int>> routine(Ecu ecu, int id) =>
      positive(ecu, [0x31, 1, id >> 8, id & 255]);
  Future<void> testerPresent(Ecu ecu) =>
      link.write(ecu.requestId, singleFrame([0x3e, 0x80]));
  Future<List<int>> read(Ecu ecu, int did) async {
    final response = await positive(ecu, [0x22, did >> 8, did & 255]);
    if (response.length < 3 ||
        response[1] != did >> 8 ||
        response[2] != did & 255) {
      throw const UdsFailure('Unexpected DID response');
    }
    return response.sublist(3);
  }

  Future<List<int>> writeDid(Ecu ecu, int did, List<int> bytes) =>
      positive(ecu, [0x2e, did >> 8, did & 255, ...bytes]);
  Future<List<int>> io(int did, bool on, {bool release = false}) => positive(
    Ecu.vcu,
    [0x2f, did >> 8, did & 255, release ? 0 : 3, if (!release) on ? 1 : 0],
  );
}
