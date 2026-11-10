import 'dart:async';

import '../protocol/can.dart';
import 'controller.dart';

/// One documented RoutineControl request, with the unmodified BMS reply kept
/// for review. This does not attempt an unknown Gen3 security key or session.
class Gen3BalanceProbe {
  static bool eligible(Diagnostics d) =>
      !d.demo &&
      d.connected &&
      d.identity.modelCode == 31 &&
      d.mode == 'SERVICE' &&
      d.bench &&
      d.parkedFresh &&
      !d.busy &&
      d.link != null &&
      d.uds != null;

  static Future<String> run(Diagnostics d) async {
    if (!eligible(d)) {
      throw StateError(
        'Connect model 31, confirm Park, then enter Service mode. The charger may remain connected; the BMS decides when balancing can run.',
      );
    }
    final started = DateTime.now().toUtc();
    final before = _snapshot(d);
    var outcome = 'No request sent';
    await d.operation(
      'Gen3 balancing compatibility test',
      () async {
        // The default UDS session is intentional. A session/security rejection
        // is useful evidence and must not be bypassed with an unverified key.
        try {
          if (d.link!.streamMode != 'dump') await d.link!.reader(dump: true);
          final reply = await d.uds!
              .request(Ecu.bms, const [0x31, 0x01, 0x05, 0xf8])
              .timeout(const Duration(seconds: 7));
          outcome = describeResponse(reply);
        } catch (error) {
          outcome = 'Request error: $error';
        }
        await Future<void>.delayed(const Duration(seconds: 5));
      },
      service: true,
      cancellable: false,
      restoreCustomer: true,
    );
    final after = _snapshot(d);
    final report =
        '''OpenOLA Gen3 balancing compatibility test
UTC: ${started.toIso8601String()}
Model: ${d.identity.model} (code ${d.identity.modelCode})
MoveOS: ${d.firmware}
Request to BMS: 31 01 05 F8 (one attempt, default UDS session)
$outcome
Before: $before
After 5 s: $after
An acknowledgement does not prove balancing started. A rejection or timeout does not prove the routine is unsupported; it may require a different session or conditions. No Gen3 security key was attempted.
''';
    d.log(report.replaceAll('\n', ' | '));
    return report;
  }

  static String _snapshot(Diagnostics d) {
    String frame(int id) => d.frameFresh(id) ? hex(d.raw[id]!) : 'unavailable';
    final battery = d.canBattery ?? d.battery;
    final spread = battery == null || battery.cells.isEmpty
        ? 'unavailable'
        : '${battery.spreadMv.toStringAsFixed(0)} mV';
    return 'BMS 0x160=${frame(0x160)}, cell flags 0x170=${frame(0x170)}, cell spread=$spread';
  }

  static String describeResponse(List<int> reply) {
    final raw = 'BMS response: ${hex(reply)}';
    if (reply.length >= 5 &&
        reply[0] == 0x71 &&
        reply[1] == 0x01 &&
        reply[2] == 0x05 &&
        reply[3] == 0xf8) {
      return '$raw (acknowledged; routine result 0x${reply[4].toRadixString(16).padLeft(2, '0')})';
    }
    if (reply.length >= 3 && reply[0] == 0x7f && reply[1] == 0x31) {
      return '$raw (rejected; NRC 0x${reply[2].toRadixString(16).padLeft(2, '0')})';
    }
    return '$raw (unexpected response)';
  }
}
