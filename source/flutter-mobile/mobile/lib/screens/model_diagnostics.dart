import 'package:flutter/cupertino.dart';
import '../data/vehicle_profile.dart';
import '../diagnostics/controller.dart';
import '../design/glass.dart';

class ModelDiagnostics extends StatelessWidget {
  const ModelDiagnostics({
    super.key,
    required this.d,
    this.identityOnly = false,
  });
  final Diagnostics d;
  final bool identityOnly;
  static const groups = <String, List<int>>{
    'ABS diagnostics': [0x270, 0x271, 0x272, 0x273],
    'Brake-by-wire diagnostics': [0x6df, 0x6dd, 0x6e8, 0x321, 0x322, 0x305],
    'Custom ride mode': [0x68a, 0x68b],
    'Battery hardware diagnostics': [0x417, 0x419],
  };
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: d,
    builder: (context, _) {
      final identity = d.identity;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Section(
            'Detected scooter',
            icon: CupertinoIcons.cube_box,
            children: [
              Text(
                identity.model,
                style: TextStyle(
                  color: ink(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                identity.profileLabel,
                style: TextStyle(color: muted(context)),
              ),
              if (d.connected && !d.demo && !d.frameFresh(0x211))
                const Text(
                  'Identity updates paused. Service commands are unavailable.',
                ),
              if (d.hardwareVariants.entries.any((e) => (e.value ?? 0) != 0))
                Text(
                  // Only codes the scooter actually reports (zero means "not
                  // set"), on one line instead of a tall list.
                  [
                    for (final e in d.hardwareVariants.entries)
                      if ((e.value ?? 0) != 0) '${e.key} ${e.value}',
                  ].join(' · '),
                  style: TextStyle(color: muted(context), fontSize: 12),
                ),
              if (d.demo) const Text('Simulated scooter'),
            ],
          ),
          if (!identityOnly) ...[
            if (identity.profile != VehicleProfile.moveos561)
              Section(
                'Model-specific diagnostics',
                children: [
                  Text(
                    identity.profile == VehicleProfile.legacy
                        ? 'Using the older S1 methods. ABS and IMCU layouts are not applied to this scooter.'
                        : '${identity.reason} Only shared signal definitions are used.',
                  ),
                ],
              )
            else ...[
              for (final group in groups.entries)
                Section(
                  group.key,
                  children: [
                    Text(
                      group.value.any((id) => d.raw.containsKey(id))
                          ? 'Read-only telemetry from this scooter.'
                          : 'Not observed. This does not prove that the hardware is absent.',
                      style: TextStyle(color: muted(context), fontSize: 12),
                    ),
                    for (final id in group.value)
                      if (d.raw.containsKey(id)) ...[
                        const SizedBox(height: 8),
                        Text(
                          d.catalog
                              .nameFor(identity.profile, id)
                              .replaceAll('_', ' '),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (!d.frameFresh(id))
                          const Text(
                            'Updates paused — last values are unavailable.',
                          ),
                        for (final signal in d.catalog.signalsFor(
                          identity.profile,
                          id,
                        ))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${signal.name.replaceAll('_', ' ')}: ${d.frameFresh(id) ? signal.decode(d.raw[id]!).toStringAsFixed(2) : '—'} ${signal.unit}',
                              style: TextStyle(
                                color: ink(context),
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                  ],
                ),
              const Section(
                'Service functions',
                children: [
                  Text(
                    'ABS bleeding, braking adjustments and IMCU calibration are not available: their complete controller-specific service procedures still need validation. No older controller procedure is substituted.',
                  ),
                ],
              ),
            ],
          ],
        ],
      );
    },
  );
}
