import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../diagnostics/controller.dart';
import '../diagnostics/head_unit_tools.dart';
import '../diagnostics/preferences.dart';
import '../design/glass.dart';
import '../design/dashboard.dart';
import 'core.dart';

class DiagnosticsHubPage extends StatelessWidget {
  const DiagnosticsHubPage({
    super.key,
    required this.d,
    required this.workspace,
    required this.openTool,
    required this.openFaults,
    required this.openReports,
  });

  final Diagnostics d;
  final WorkspaceMode workspace;
  final ValueChanged<Tool> openTool;
  final VoidCallback openFaults;
  final VoidCallback openReports;

  Widget _links(
    BuildContext context,
    List<(String, String, IconData, Color, VoidCallback)> rows,
  ) => Glass(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: separator(context)),
          WorkspaceRow(
            rows[i].$1,
            rows[i].$2,
            rows[i].$3,
            rows[i].$4,
            onTap: rows[i].$5,
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final technical = workspace != WorkspaceMode.owner;
    return PageStack([
      Heading(
        'Diagnose',
        technical
            ? 'Faults, live vehicle data and diagnostic records.'
            : 'Check scooter health and review important alerts.',
      ),
      if (technical) UniversalSearch(d: d),
      Section(
        'Health and records',
        icon: CupertinoIcons.heart,
        children: [
          _links(context, [
            (
              'Fault scan',
              d.faults.isEmpty
                  ? 'Check the scooter’s controllers'
                  : '${d.faults.values.fold<int>(0, (n, rows) => n + rows.length)} stored codes',
              CupertinoIcons.waveform_path_ecg,
              orange,
              openFaults,
            ),
            (
              'Reports and activity',
              'Save and review diagnostic snapshots',
              CupertinoIcons.doc_text,
              purple,
              openReports,
            ),
          ]),
        ],
      ),
      if (technical || d.demo) ...[
        Section(
          'Live diagnosis',
          icon: CupertinoIcons.waveform,
          children: [
            _links(context, [
              (
                'Vehicle status',
                'Decoded operating state',
                CupertinoIcons.gauge,
                accent,
                () => openTool(Tool.status),
              ),
              (
                'Live signals',
                'Search and monitor CAN values',
                CupertinoIcons.waveform,
                accent,
                () => openTool(Tool.live),
              ),
              (
                'Charging',
                'Charge path and session state',
                CupertinoIcons.bolt,
                orange,
                () => openTool(Tool.charging),
              ),
              (
                'Recorder',
                'Capture, plot and export signals',
                CupertinoIcons.recordingtape,
                teal,
                () => openTool(Tool.recorder),
              ),
            ]),
          ],
        ),
        Section(
          'Vehicle information',
          icon: CupertinoIcons.info_circle,
          children: [
            _links(context, [
              (
                'Components',
                'Controller identifiers',
                CupertinoIcons.square_stack_3d_up,
                accent,
                () => openTool(Tool.components),
              ),
              (
                'Firmware',
                'ECU firmware versions',
                CupertinoIcons.square_stack_3d_up,
                accent,
                () => openTool(Tool.firmware),
              ),
              (
                'Head-unit software',
                'Android and installed software',
                CupertinoIcons.square_arrow_down,
                accent,
                () => openTool(Tool.software),
              ),
            ]),
          ],
        ),
        Section(
          'TechPack evidence (S1 test)',
          icon: CupertinoIcons.lock_shield,
          children: [
            Text(
              'Reads the daemon ECOS/Dyno state, profile restrictions, shared-preference keys and raw 0x660/0x6D0/0x113 evidence. It does not change configuration.',
              style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
            ),
            GlassButton(
              'Read TechPack evidence',
              onPressed: d.busy || !d.connected ? null : d.readTechPackEvidence,
            ),
            if (d.techPackFlags != null)
              Text(
                'ECOS1: ${d.techPackFlags!.ecos1}\nECOS2: ${d.techPackFlags!.ecos2}\nDyno: ${d.techPackFlags!.dyno}',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            if (d.techPackEvidence.isNotEmpty)
              ExpansionTile(
                title: const Text('Evidence details'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      d.techPackEvidence,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
              ),
            GlassButton(
              'Re-apply provisioned TechPack',
              compact: true,
              destructive: true,
              onPressed: d.demo ||
                      d.busy ||
                      !d.connected ||
                      !d.prefs.developerMode
                  ? null
                  : () async {
                      if (await confirmGlass(
                        context,
                        'Send TechPack re-apply request?',
                        'This calls the scooter daemon’s official TechPackUpdate path. It does not fabricate an entitlement, but it is a live vehicle configuration request. Park, disconnect the charger and slide to confirm.',
                      )) {
                        await d.techPackUpdateProbe('techpack');
                      }
                    },
            ),
            if (d.techPackProbeResult.isNotEmpty)
              ExpansionTile(
                title: const Text('Probe result'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      d.techPackProbeResult,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    ]);
  }
}

class OwnerControlsPage extends StatelessWidget {
  const OwnerControlsPage({super.key, required this.d, required this.openTool});

  final Diagnostics d;
  final ValueChanged<Tool> openTool;

  bool get _restrictionReady =>
      !d.busy &&
      !d.restrictionUnsupported &&
      (d.demo || d.parkedFresh && d.chargerDisconnectedFresh);

  Future<void> _setRestriction(
    BuildContext context,
    RestrictionMode mode,
    String label,
  ) async {
    if (await confirmGlass(
      context,
      '$label?',
      'Owner parental-control change. OpenOLA uses the current profile and requires matching database readback and vehicle acknowledgement. Slide to confirm.',
    )) {
      await d.setRestrictions(mode);
    }
  }

  @override
  Widget build(BuildContext context) => PageStack([
    const Heading(
      'Controls',
      'Everyday owner controls and verified ride-mode access.',
    ),
    Section(
      'Sport and Hyper access',
      icon: CupertinoIcons.speedometer,
      children: [
        Text(
          d.restrictionState == null
              ? 'Read the current owner-control status before changing it.'
              : 'Sport: ${d.restrictionState!.sportEnabled ? 'Enabled' : 'Disabled'} · Hyper: ${d.restrictionState!.hyperEnabled ? 'Enabled' : 'Disabled'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        if (d.restrictionUnsupported)
          Text(
            'Not available on this scooter’s software release: it has no '
            'Sport/Hyper restriction flags to read or change (an older release). '
            'Nothing was changed.',
            style: const TextStyle(color: orange, fontSize: 12, height: 1.4),
          ),
        Text(
          'Requires a freshly confirmed Park state and disconnected charger. This does not modify paid feature entitlements.',
          style: TextStyle(color: muted(context), fontSize: 12, height: 1.4),
        ),
        GlassButton(
          'Read current status',
          onPressed: d.busy || !d.connected ? null : d.readRestrictions,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            GlassButton(
              'Enable Sport + Hyper',
              compact: true,
              onPressed: _restrictionReady
                  ? () => _setRestriction(
                      context,
                      RestrictionMode.sportAndHyperEnabled,
                      'Enable Sport and Hyper',
                    )
                  : null,
            ),
            GlassButton(
              'Sport only',
              compact: true,
              onPressed: _restrictionReady
                  ? () => _setRestriction(
                      context,
                      RestrictionMode.sportOnly,
                      'Enable Sport and disable Hyper',
                    )
                  : null,
            ),
            GlassButton(
              'Disable both',
              compact: true,
              destructive: true,
              onPressed: _restrictionReady
                  ? () => _setRestriction(
                      context,
                      RestrictionMode.sportAndHyperDisabled,
                      'Disable Sport and Hyper',
                    )
                  : null,
            ),
          ],
        ),
      ],
    ),
    Glass(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          WorkspaceRow(
            'Component tests',
            'Trunk, lights, indicators and horn',
            CupertinoIcons.lightbulb_fill,
            orange,
            onTap: () => openTool(Tool.componentTests),
          ),
          Divider(height: 1, color: separator(context)),
          WorkspaceRow(
            'Vehicle features',
            'Hill hold, proximity lock, alerts and more',
            CupertinoIcons.car_detailed,
            teal,
            onTap: () => openTool(Tool.features),
          ),
        ],
      ),
    ),
  ]);
}
