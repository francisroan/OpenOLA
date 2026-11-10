import '../data/mcu_replacement_plan.dart';

enum McuTrialStage {
  prepared,
  flashReportedComplete,
  firstResetRequested,
  flashVerified,
  calibrated,
  finalResetRequested,
  postchecked,
}

/// State retained across the two scooter reconnects in one app session.
/// Every transition is driven by a fresh observation, never by a timer alone.
class McuReplacementTrial {
  McuReplacementTrial({
    required this.vin,
    required this.motor,
    required this.partNumber,
    required this.candidate,
    required this.filePath,
  });

  final String vin;
  final McuMotorType motor;
  final String partNumber;
  final McuFirmwareCandidate candidate;
  final String filePath;
  McuTrialStage stage = McuTrialStage.prepared;
  String? lastError;
  final events = <String>[];

  void advance(McuTrialStage expected, McuTrialStage next, String evidence) {
    if (stage != expected) {
      throw StateError('Expected ${expected.name}; trial is ${stage.name}.');
    }
    stage = next;
    lastError = null;
    events.add(
      '${DateTime.now().toUtc().toIso8601String()} ${next.name}: $evidence',
    );
  }

  void fail(Object error) {
    lastError = '$error';
    events.add('${DateTime.now().toUtc().toIso8601String()} STOP: $error');
  }

  static bool flashReportedComplete(String output) {
    final upper = output.toUpperCase();
    return !upper.contains('FLASH_STATE_TRANSFER_FAILURE') &&
        upper.contains('FLASH_STATE_TRANSFER_COMPLETE');
  }

  String report() =>
      '''OpenOLA Gen1 MCU replacement trial
VIN: $vin
Motor selected: ${motor.name.toUpperCase()}
Replacement MCU part label: $partNumber
Firmware: ${candidate.file} (${candidate.version})
Expected SHA-256: ${candidate.sha256}
Stage: ${stage.name}
Last error: ${lastError ?? 'none'}
${events.join('\n')}
Flash completion is a tool report. Physical pairing and safe motor operation require the final scooter-side checks.
''';
}
