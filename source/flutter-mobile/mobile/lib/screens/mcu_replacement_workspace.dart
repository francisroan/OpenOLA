import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../data/mcu_replacement_route.dart';
import '../data/mcu_legacy_preview.dart';
import '../data/mcu_replacement_plan.dart';
import '../diagnostics/controller.dart';
import '../design/glass.dart';
import 'mcu_replacement_guide.dart';

/// One entry point for model-aware MCU replacement intake. Active procedures
/// are offered only after their transport and ECU behavior are verified.
class McuReplacementWorkspace extends StatelessWidget {
  const McuReplacementWorkspace({super.key, required this.d});
  final Diagnostics d;

  bool _legacyPreview(McuReplacementRoute route) => {
    McuReplacementFamily.gen1S1,
    McuReplacementFamily.air,
    McuReplacementFamily.gen2Pro,
    McuReplacementFamily.s1x,
  }.contains(route.family);

  String _candidate(McuMotorType motor) =>
      McuLegacyPreview.file(
        vin: d.mcuReplacementSurveyVin ?? '',
        headUnitSoftware: d.firmware,
        motor: motor,
      ) ??
      'no matching local file';

  String _report(McuReplacementRoute route) =>
      '''OpenOLA MCU replacement setup
Route: ${route.title}
Model: ${d.identity.model} (code ${d.identity.modelCode ?? 'unavailable'})
Profile: ${d.identity.profileLabel}
MoveOS: ${d.firmware}
Connected transport: ${d.s1xTcpReadOnly ? 'S1X passive TCP' : 'Wi-Fi gRPC'}
Read at: ${d.mcuReplacementSurveyAt?.toUtc().toIso8601String() ?? 'not read'} UTC
${d.mcuReplacementSurvey.entries.map((row) => '${row.key}: ${row.value}').join('\n')}
${_legacyPreview(route) ? 'APK legacy file candidate if SEG: ${_candidate(McuMotorType.seg)}\nAPK legacy file candidate if HUB: ${_candidate(McuMotorType.hub)}' : 'Legacy file selection does not apply to this route.'}
Active replacement trial: ${route.activeTrial ? 'Gen1 S1 Pro only' : 'unavailable for this profile'}
No firmware was selected for an unsupported route and no write was sent by setup.
''';

  @override
  Widget build(BuildContext context) {
    final route = McuReplacementRoute.detect(d.identity);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Section(
          'MCU replacement setup',
          icon: CupertinoIcons.gear_alt,
          children: [
            Text('Detected: ${d.identity.model}'),
            Text('Procedure: ${route.title}'),
            Text(route.detail),
            Text('Software: ${d.firmware} · ${d.identity.profileLabel}'),
            const Text(
              'OpenOLA includes 27 MCU and motor-related files from the '
              'diagnostic APK. File presence alone does not establish a safe '
              'replacement procedure for every model.',
            ),
            GlassButton(
              'Read VIN, MCU software and hardware',
              onPressed: d.busy ? null : d.readMcuReplacementSurvey,
            ),
            for (final row in d.mcuReplacementSurvey.entries)
              SelectableText('${row.key}: ${row.value}'),
            if (_legacyPreview(route) && d.mcuReplacementSurveyAt != null) ...[
              const Text(
                'Official APK legacy file candidates · read-only. Confirm the physical motor and replacement MCU before any flash.',
              ),
              Text('If SEG motor: ${_candidate(McuMotorType.seg)}'),
              Text('If HUB motor: ${_candidate(McuMotorType.hub)}'),
            ],
            GlassButton(
              'Share replacement setup',
              icon: CupertinoIcons.share,
              onPressed: d.mcuReplacementSurveyAt == null
                  ? null
                  : () async {
                      final box = context.findRenderObject() as RenderBox?;
                      await SharePlus.instance.share(
                        ShareParams(
                          text: _report(route),
                          subject: 'OpenOLA MCU replacement setup',
                          sharePositionOrigin: box == null
                              ? null
                              : box.localToGlobal(Offset.zero) & box.size,
                        ),
                      );
                    },
            ),
          ],
        ),
        if (route.activeTrial) McuReplacementGuide(d: d),
      ],
    );
  }
}
