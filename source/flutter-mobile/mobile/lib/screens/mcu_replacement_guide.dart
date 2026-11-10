import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/mcu_replacement_plan.dart';
import '../data/mcu_firmware_import.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/mcu_replacement_trial.dart';
import '../design/glass.dart';
import 'core.dart';

/// A guarded Gen1 service-centre MCU replacement trial. The APK branch is
/// replicated, but every physical result still requires technician review.
class McuReplacementGuide extends StatefulWidget {
  const McuReplacementGuide({super.key, required this.d});
  final Diagnostics d;

  @override
  State<McuReplacementGuide> createState() => _McuReplacementGuideState();
}

class _McuReplacementGuideState extends State<McuReplacementGuide> {
  McuMotorType motor = McuMotorType.seg;
  String? verifiedFile;
  String? verifiedFilePath;
  String fileStatus = '';
  bool selectingFile = false;
  final partNumber = TextEditingController();
  bool partMatchConfirmed = false;
  bool recoveryConfirmed = false;
  bool wheelClearConfirmed = false;
  String trialError = '';

  @override
  void dispose() {
    partNumber.dispose();
    super.dispose();
  }

  McuFirmwareCandidate? get candidate {
    final d = widget.d;
    if (d.identity.modelCode != 2 && d.identity.modelCode != 3) return null;
    return McuFirmwareCandidate.forGen1(
      vin: d.mcuReplacementVin ?? '',
      headUnitSoftware: d.firmware,
      motor: motor,
    );
  }

  Future<void> _checkFirmware() async {
    final expected = candidate;
    if (expected == null || selectingFile) return;
    setState(() {
      selectingFile = true;
      verifiedFile = null;
      verifiedFilePath = null;
      fileStatus = '';
    });
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['apk', 'bin'],
      );
      if (picked.isEmpty) {
        if (mounted) setState(() => fileStatus = 'File check cancelled.');
        return;
      }
      final file = picked.single;
      if (file.path == null) {
        throw StateError('The picker did not return a local file.');
      }
      final imported = await McuFirmwareImport.verify(file.path!, expected);
      if (mounted) {
        setState(() {
          verifiedFile = expected.file;
          verifiedFilePath = imported.path;
          fileStatus =
              'Exact MCU firmware verified from ${imported.source} (98,304 bytes).';
        });
      }
    } catch (error) {
      if (mounted) setState(() => fileStatus = '$error');
    } finally {
      if (mounted) setState(() => selectingFile = false);
    }
  }

  Future<void> _useBundledFirmware() async {
    final expected = candidate;
    if (expected == null || selectingFile) return;
    setState(() {
      selectingFile = true;
      verifiedFile = null;
      verifiedFilePath = null;
      fileStatus = '';
    });
    try {
      final imported = await McuFirmwareImport.bundled(expected);
      if (mounted) {
        setState(() {
          verifiedFile = expected.file;
          verifiedFilePath = imported.path;
          fileStatus =
              'Included manufacturer firmware verified (98,304 bytes).';
        });
      }
    } catch (error) {
      if (mounted) setState(() => fileStatus = '$error');
    } finally {
      if (mounted) setState(() => selectingFile = false);
    }
  }

  String _report(McuFirmwareCandidate? selected) {
    final d = widget.d;
    final trial = d.mcuReplacementTrial;
    if (trial != null) return trial.report();
    return '''OpenOLA Gen1 MCU replacement preparation
Read at: ${d.mcuReplacementPreflightAt?.toUtc().toIso8601String() ?? 'not read'} UTC
Model: ${d.identity.model}
VIN: ${d.mcuReplacementVin ?? 'unavailable'}
Head-unit software: ${d.firmware}
Current MCU software: ${d.mcuReplacementSoftware ?? 'unavailable'}
MCU hardware broadcast: ${d.mcuReplacementPreflight['MCU hardware broadcast'] ?? 'unavailable'}
Motor selected by operator: ${motor.name.toUpperCase()}
APK firmware candidate: ${selected?.file ?? 'none; stop'}
Target software: ${selected?.version ?? 'unknown'}
Firmware file verified: ${verifiedFile == selected?.file ? 'yes' : 'no'}
Replacement MCU part number and pinout: not verified by OpenOLA
Flash, BMS reset, AutoTune, post-check: not performed
This is a preparation report, not proof of MCU pairing or physical compatibility.
''';
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => trialError = '');
    } catch (error) {
      if (mounted) setState(() => trialError = '$error');
    }
  }

  void _prepare(McuFirmwareCandidate selected) {
    try {
      final d = widget.d;
      if (!partMatchConfirmed || !recoveryConfirmed || !wheelClearConfirmed) {
        throw StateError('Complete the part, recovery and wheel-clear checks.');
      }
      final path = verifiedFilePath;
      if (verifiedFile != selected.file || path == null) {
        throw StateError('Verify the exact firmware file first.');
      }
      d.prepareMcuReplacementTrial(
        McuReplacementTrial(
          vin: d.mcuReplacementVin ?? '',
          motor: motor,
          partNumber: partNumber.text.trim(),
          candidate: selected,
          filePath: path,
        ),
      );
      setState(() => trialError = '');
    } catch (error) {
      setState(() => trialError = '$error');
    }
  }

  Widget _check(String label, bool value, ValueChanged<bool> onChanged) => Row(
    children: [
      Checkbox(value: value, onChanged: (next) => onChanged(next ?? false)),
      Expanded(child: Text(label)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final trial = d.mcuReplacementTrial;
    final selected = trial?.candidate ?? candidate;
    final hasRead = d.mcuReplacementPreflightAt != null;
    return Section(
      'MCU replacement · Gen1 service trial',
      icon: CupertinoIcons.gauge,
      children: [
        const Text(
          'The official replacement wizard reads vehicle identity, selects a '
          'firmware file, flashes the MCU, resets the scooter, runs AutoTune and '
          'checks the result. Follow these steps with a service technician and '
          'a physically compatible replacement MCU. A tool acknowledgement '
          'alone does not prove safe motor operation.',
        ),
        GlassButton(
          '1 · Read replacement inputs',
          onPressed:
              d.busy ||
                  !d.legacyMethodsAvailable ||
                  d.mode != 'SERVICE' ||
                  !d.bench
              ? null
              : () async {
                  await d.readMcuReplacementPreflight();
                  if (mounted) {
                    setState(() {
                      if (d.mcuReplacementTrial == null) {
                        verifiedFile = null;
                        verifiedFilePath = null;
                        fileStatus = '';
                      }
                    });
                  }
                },
        ),
        if (!d.legacyMethodsAvailable)
          const Text('Requires a verified older S1 profile.'),
        if (d.legacyMethodsAvailable && (d.mode != 'SERVICE' || !d.bench))
          const Text('Enter Service mode while parked to read the MCU inputs.'),
        for (final entry in d.mcuReplacementPreflight.entries)
          SelectableText('${entry.key}: ${entry.value}'),
        const Text(
          '2 · Confirm the physical motor type. S1 Pro normally uses SEG; the official app requires an operator choice.',
        ),
        GlassSegment<McuMotorType>(
          values: const [McuMotorType.seg, McuMotorType.hub],
          selected: trial?.motor ?? motor,
          label: (value) =>
              value == McuMotorType.seg ? 'SEG motor' : 'HUB motor',
          onChanged: (value) => setState(() {
            if (trial != null) return;
            motor = value;
            verifiedFile = null;
            verifiedFilePath = null;
            fileStatus = '';
          }),
        ),
        Text(
          !hasRead
              ? '3 · Read the scooter before selecting firmware.'
              : selected == null
              ? '3 · No supported Gen1 S1 Pro firmware candidate for these inputs. Stop here.'
              : '3 · APK candidate: ${selected.file} · target ${selected.version}${selected.matchesCurrentSoftware(d.mcuReplacementSoftware) ? ' · current software already matches' : ''}',
        ),
        if (selected != null) ...[
          SelectableText('Expected SHA-256: ${selected.sha256}'),
          if (trial == null)
            GlassButton(
              '4 · Verify included MCU firmware',
              onPressed: selectingFile ? null : _useBundledFirmware,
            ),
          if (trial == null)
            GlassButton(
              'Use diagnostic APK instead',
              onPressed: selectingFile ? null : _checkFirmware,
            ),
        ],
        if (fileStatus.isNotEmpty) Text(fileStatus),
        if (trial == null) ...[
          const Text(
            '5 · Compare the replacement MCU label, board and pinout with a '
            'service record. The diagnostic APK does not check these for you.',
          ),
          GlassField(
            controller: partNumber,
            label: 'Replacement MCU part number',
          ),
          _check(
            'Part number, board and motor type match the service record',
            partMatchConfirmed,
            (value) => setState(() => partMatchConfirmed = value),
          ),
          _check(
            'Technician has a flash recovery procedure and stable power',
            recoveryConfirmed,
            (value) => setState(() => recoveryConfirmed = value),
          ),
          _check(
            'Scooter on centre stand; rear wheel clear',
            wheelClearConfirmed,
            (value) => setState(() => wheelClearConfirmed = value),
          ),
          GlassButton(
            'Prepare replacement trial',
            onPressed:
                selected == null || verifiedFile != selected.file || d.busy
                ? null
                : () => _prepare(selected),
          ),
        ] else ...[
          Text('Stage: ${trial.stage.name}'),
          Text(d.mcuReplacementTrialStatus),
          if (trial.lastError != null) Text('Stopped: ${trial.lastError}'),
          if (trial.stage == McuTrialStage.prepared &&
              trial.lastError == null) ...[
            const Text(
              '6 · Keep the scooter Wi-Fi connection open. The app uses its '
              'existing gRPC head-unit bridge for transfer and flashing; '
              'a separate ADB connection is not needed.',
            ),
            GlassButton(
              '7 · Flash replacement MCU',
              destructive: true,
              onPressed:
                  d.link == null || d.busy || d.mode != 'SERVICE' || !d.bench
                  ? null
                  : () => _run(() async {
                      if (await confirmGlass(
                        context,
                        'Flash the replacement MCU?',
                        'This writes ${trial.candidate.file} to the MCU. Confirm '
                            'the replacement part, clear rear wheel, stable power '
                            'and recovery procedure. Do not disconnect during flash.',
                      )) {
                        await d.flashMcuReplacementTrial();
                      }
                    }),
            ),
          ],
          if (trial.stage == McuTrialStage.flashReportedComplete)
            GlassButton(
              '8 · Request first BMS reset',
              destructive: true,
              onPressed: d.busy || d.mode != 'SERVICE' || !d.bench
                  ? null
                  : () => _run(() async {
                      if (await confirmGlass(
                        context,
                        'Reset scooter?',
                        'The BMS will power-cycle the scooter. Reconnect and verify the MCU software afterward.',
                      )) {
                        await d.resetForMcuReplacementTrial(finalReset: false);
                      }
                    }),
            ),
          if (trial.stage == McuTrialStage.firstResetRequested)
            GlassButton(
              '9 · Read and verify flashed MCU',
              onPressed: d.busy || d.mode != 'SERVICE' || !d.bench
                  ? null
                  : () => _run(() async {
                      await d.readMcuReplacementPreflight();
                      d.verifyMcuReplacementFlash();
                    }),
            ),
          if (trial.stage == McuTrialStage.flashVerified) ...[
            _check(
              'Centre stand stable and rear wheel clear for AutoTune',
              wheelClearConfirmed,
              (value) => setState(() => wheelClearConfirmed = value),
            ),
            GlassButton(
              '10 · Run motor AutoTune',
              destructive: true,
              onPressed:
                  !wheelClearConfirmed ||
                      d.busy ||
                      d.mode != 'SERVICE' ||
                      !d.bench
                  ? null
                  : () => _run(() async {
                      if (await confirmGlass(
                        context,
                        'Start motor AutoTune?',
                        'The rear wheel may spin. Keep clear until the app reports the calibration counter.',
                      )) {
                        await d.calibrateMcuReplacementTrial();
                      }
                    }),
            ),
          ],
          if (trial.stage == McuTrialStage.calibrated)
            GlassButton(
              '11 · Request final BMS reset',
              destructive: true,
              onPressed: d.busy || d.mode != 'SERVICE' || !d.bench
                  ? null
                  : () => _run(() async {
                      if (await confirmGlass(
                        context,
                        'Final scooter reset?',
                        'The BMS will power-cycle the scooter again. Reconnect for final readback.',
                      )) {
                        await d.resetForMcuReplacementTrial(finalReset: true);
                      }
                    }),
            ),
          if (trial.stage == McuTrialStage.finalResetRequested)
            GlassButton(
              '12 · Read final MCU checks',
              onPressed: d.busy || d.mode != 'SERVICE' || !d.bench
                  ? null
                  : () => _run(() async {
                      await d.readMcuReplacementPreflight();
                      d.verifyMcuReplacementPostcheck();
                    }),
            ),
          if (trial.stage == McuTrialStage.postchecked)
            const Text(
              'Software checks passed. Technician must still read stored faults and verify physical motor operation before returning the scooter to use.',
            ),
          GlassButton(
            'End this trial',
            destructive: true,
            onPressed: d.busy
                ? null
                : () => _run(() async {
                    if (await confirmGlass(
                      context,
                      'End MCU trial?',
                      'Save or share the report first. Ending clears the in-app step state.',
                    )) {
                      d.discardMcuReplacementTrial();
                    }
                  }),
          ),
        ],
        if (trialError.isNotEmpty) Text(trialError),
        GlassButton(
          trial == null ? 'Share preparation report' : 'Share trial report',
          icon: CupertinoIcons.share,
          onPressed: !hasRead && trial == null
              ? null
              : () async {
                  final box = context.findRenderObject() as RenderBox?;
                  await SharePlus.instance.share(
                    ShareParams(
                      text: _report(selected),
                      subject: 'OpenOLA MCU replacement preparation',
                      sharePositionOrigin: box == null
                          ? null
                          : box.localToGlobal(Offset.zero) & box.size,
                    ),
                  );
                },
        ),
      ],
    );
  }
}
