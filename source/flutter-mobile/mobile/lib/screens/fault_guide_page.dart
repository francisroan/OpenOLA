import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../data/catalog.dart';
import '../data/vehicle_profile.dart';
import '../design/dashboard.dart';
import '../design/glass.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/fault_explanations.dart';
import '../protocol/can.dart';

class _FaultGuideEntry {
  const _FaultGuideEntry(this.code, this.description, this.source);
  final String code;
  final String description;
  final String source;
}

class FaultGuideScreen extends StatefulWidget {
  const FaultGuideScreen({super.key, required this.d});
  final Diagnostics d;

  @override
  State<FaultGuideScreen> createState() => _FaultGuideScreenState();
}

class _FaultGuideScreenState extends State<FaultGuideScreen> {
  final search = TextEditingController();
  String source = 'ALL';
  bool stopOnly = false;

  late final List<_FaultGuideEntry> entries = _entries();

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<_FaultGuideEntry> _entries() {
    final unique = <String, _FaultGuideEntry>{};
    void add(String code, String description, String source) {
      final cleanCode = code.trim().isEmpty ? 'Live flag' : code.trim();
      final cleanDescription = description.trim();
      if (cleanDescription.isEmpty) return;
      final key = '${source.toUpperCase()}|$cleanCode|$cleanDescription';
      unique[key] = _FaultGuideEntry(
        cleanCode,
        cleanDescription,
        source.toUpperCase(),
      );
    }

    for (final ecu in Ecu.values) {
      for (final row
          in widget.d.catalog.dtcs[ecu]?.entries ??
              const Iterable<MapEntry<String, String>>.empty()) {
        add(row.key, row.value, ecu.label);
      }
    }

    void addFrame(FaultFrame frame) {
      for (final bit in frame.bits) {
        add(
          '0x${frame.id.toRadixString(16).toUpperCase()} · bit ${bit.startbit}',
          bit.label,
          frame.ecu,
        );
      }
    }

    for (final frame in widget.d.catalog.faultFrames) {
      addFrame(frame);
    }
    for (final profile in VehicleProfile.values) {
      for (final frame in widget.d.catalog.faultsFor(profile)) {
        addFrame(frame);
      }
    }

    final out = unique.values.toList();
    out.sort((a, b) {
      final bySource = a.source.compareTo(b.source);
      if (bySource != 0) return bySource;
      final byCode = a.code.compareTo(b.code);
      return byCode != 0 ? byCode : a.description.compareTo(b.description);
    });
    return out;
  }

  List<_FaultGuideEntry> get shown {
    final query = search.text.trim().toLowerCase();
    return entries
        .where((entry) {
          if (source != 'ALL' && entry.source != source) return false;
          final explanation = explainFault(
            code: entry.code,
            description: entry.description,
            source: entry.source,
          );
          if (stopOnly && explanation.severity != FaultSeverity.stopSafely) {
            return false;
          }
          if (query.isEmpty) return true;
          return '${entry.code} ${entry.description} ${entry.source} ${explanation.subsystem} ${explanation.meaning}'
              .toLowerCase()
              .contains(query);
        })
        .toList(growable: false);
  }

  Color _tone(FaultSeverity severity) => switch (severity) {
    FaultSeverity.information => accent,
    FaultSeverity.attention => orange,
    FaultSeverity.stopSafely => danger,
  };

  @override
  Widget build(BuildContext context) {
    final filtered = shown;
    final sources = ['ALL', 'BMS', 'MCU', 'VCU', 'IMCU'];
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: GlassWallpaper()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Glass(
                    chrome: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back to Settings',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(CupertinoIcons.back),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Offline fault guide',
                            style: TextStyle(
                              color: ink(context),
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        StatusChip('${entries.length} entries', color: accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: Column(
                        children: [
                          Glass(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Search codes and live flags',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Bundled with the app and inferred from each code’s name, not from Ola service documentation. Guidance, not a diagnosis — if in doubt, stop riding and get it checked.',
                                  style: TextStyle(
                                    color: muted(context),
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                GlassField(
                                  controller: search,
                                  label: 'Code, fault, subsystem or symptom',
                                  onChanged: (_) => setState(() {}),
                                  suffix: search.text.isEmpty
                                      ? const Icon(CupertinoIcons.search)
                                      : IconButton(
                                          tooltip: 'Clear search',
                                          onPressed: () {
                                            search.clear();
                                            setState(() {});
                                          },
                                          icon: const Icon(
                                            CupertinoIcons.xmark,
                                          ),
                                        ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 7,
                                  runSpacing: 7,
                                  children: [
                                    for (final value in sources)
                                      _SourceChip(
                                        value == 'ALL' ? 'All' : value,
                                        selected: source == value,
                                        onTap: () =>
                                            setState(() => source = value),
                                      ),
                                    _SourceChip(
                                      'Stop safely',
                                      selected: stopOnly,
                                      onTap: () =>
                                          setState(() => stopOnly = !stopOnly),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: filtered.isEmpty
                                ? Center(
                                    child: Text(
                                      'No matching fault entries.',
                                      style: TextStyle(color: muted(context)),
                                    ),
                                  )
                                : ListView.separated(
                                    key: const ValueKey('fault-guide-list'),
                                    itemCount: filtered.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, index) {
                                      final entry = filtered[index];
                                      final explanation = explainFault(
                                        code: entry.code,
                                        description: entry.description,
                                        source: entry.source,
                                      );
                                      final tone = _tone(explanation.severity);
                                      return Glass(
                                        padding: EdgeInsets.zero,
                                        radius: 16,
                                        child: Material(
                                          type: MaterialType.transparency,
                                          child: ExpansionTile(
                                            tilePadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 4,
                                                ),
                                            childrenPadding:
                                                const EdgeInsets.fromLTRB(
                                                  14,
                                                  0,
                                                  14,
                                                  14,
                                                ),
                                            leading: Icon(
                                              CupertinoIcons
                                                  .exclamationmark_triangle,
                                              color: tone,
                                            ),
                                            title: Text(
                                              entry.code,
                                              style: TextStyle(
                                                color: tone,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '${entry.source} · ${entry.description}',
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            children: [
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Wrap(
                                                      spacing: 7,
                                                      runSpacing: 7,
                                                      children: [
                                                        StatusChip(
                                                          explanation.subsystem,
                                                          color: accent,
                                                        ),
                                                        StatusChip(
                                                          explanation
                                                              .severityLabel,
                                                          color: tone,
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      explanation.meaning,
                                                      style: const TextStyle(
                                                        height: 1.45,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      'What to do',
                                                      style: TextStyle(
                                                        color: ink(context),
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      explanation.nextStep,
                                                      style: TextStyle(
                                                        color: muted(context),
                                                        height: 1.45,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      'Offline ${explanation.inferred ? 'category guidance' : 'curated guidance'} · not a confirmed diagnosis',
                                                      style: TextStyle(
                                                        color: muted(context),
                                                        fontSize: 10.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip(this.label, {required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 42),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? accent : fill(context),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : ink(context),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
