import 'package:flutter_test/flutter_test.dart';
import 'package:openola/data/mcu_replacement_plan.dart';
import 'package:openola/diagnostics/mcu_replacement_trial.dart';

void main() {
  final candidate = McuFirmwareCandidate.forGen1(
    vin: 'P53BA123456789012',
    headUnitSoftware: '5.0.0',
    motor: McuMotorType.seg,
  )!;

  test('flash parser rejects missing or conflicting completion', () {
    expect(
      McuReplacementTrial.flashReportedComplete('FLASH_STATE_START'),
      isFalse,
    );
    expect(
      McuReplacementTrial.flashReportedComplete(
        'FLASH_STATE_TRANSFER_COMPLETE',
      ),
      isTrue,
    );
    expect(
      McuReplacementTrial.flashReportedComplete(
        'FLASH_STATE_TRANSFER_FAILURE\nFLASH_STATE_TRANSFER_COMPLETE',
      ),
      isFalse,
    );
  });

  test('trial cannot skip a reset or firmware readback', () {
    final trial = McuReplacementTrial(
      vin: 'P53BA123456789012',
      motor: McuMotorType.seg,
      partNumber: 'PART-1234',
      candidate: candidate,
      filePath: '/tmp/mcu_72_01_53_03.bin',
    );
    expect(
      () => trial.advance(
        McuTrialStage.flashVerified,
        McuTrialStage.calibrated,
        'counter',
      ),
      throwsStateError,
    );
    trial.advance(
      McuTrialStage.prepared,
      McuTrialStage.flashReportedComplete,
      'tool reported complete',
    );
    expect(trial.stage, McuTrialStage.flashReportedComplete);
    expect(trial.report(), contains('Physical'));
  });
}
