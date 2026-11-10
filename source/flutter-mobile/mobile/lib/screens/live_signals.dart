import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design/glass.dart';
import '../diagnostics/controller.dart';
import 'core.dart';

/// Slivers for the page's primary scroll view, never a nested signal viewport.
class LiveSignalsSlivers extends StatefulWidget {
  const LiveSignalsSlivers({super.key, required this.d});
  final Diagnostics d;

  @override
  State<LiveSignalsSlivers> createState() => _LiveSignalsSliversState();
}

class _LiveSignalsSliversState extends State<LiveSignalsSlivers> {
  final search = TextEditingController();
  String category = 'All';

  // Keyword groups so the (now ~1,200-signal) list is easier to navigate.
  static const categories = <String, String>{
    'All': '',
    'Battery': r'soc|cell|pack|bms|batt|voltage|current|dcir|balanc|contactor',
    'Brakes': r'abs|bbw|brak|regen_energy',
    'Motor': r'motor|mcu|speed|torque|rpm|\bdrive|regen|throttle',
    'Charging': r'charger|charge|evse|plug|fast_charg',
    'Temp': r'temp|thermal|degc|°c',
    'Faults':
        r'fault|error|warn|protect|fail|mismatch|abnormal|overcurrent|overvolt',
    'Vehicle':
        r'vehicle|vcu|lock|indicator|light|\bmode|variant|config|stand|seat',
  };

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.d,
    builder: (context, _) {
      final d = widget.d;
      final query = search.text.trim().toLowerCase();
      final catRe = category == 'All'
          ? null
          : RegExp(categories[category]!, caseSensitive: false);
      final rows =
          d.readings.entries
              .where(
                (entry) =>
                    '${entry.key} ${entry.value.unit} ${entry.value.id.toRadixString(16)}'
                        .toLowerCase()
                        .contains(query) &&
                    (catRe == null || catRe.hasMatch(entry.key)),
              )
              .toList()
            ..sort((a, b) => a.key.compareTo(b.key));
      final indices = {
        for (var i = 0; i < rows.length; i++) 'signal:${rows[i].key}': i,
      };

      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Heading(
                    'Live signals',
                    '${rows.length} signals${query.isEmpty ? '' : ' matching'} · ${d.demo
                        ? 'Demo readings'
                        : d.live
                        ? 'Streaming'
                        : 'Stream paused'}',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: GlassField(
                          controller: search,
                          label: 'Search signals',
                          onChanged: (_) => setState(() {}),
                          suffix: IconButton(
                            tooltip: query.isEmpty
                                ? 'Search signals'
                                : 'Clear search',
                            onPressed: query.isEmpty
                                ? null
                                : () => setState(search.clear),
                            icon: Icon(
                              query.isEmpty
                                  ? CupertinoIcons.search
                                  : CupertinoIcons.xmark_circle_fill,
                              size: 19,
                              color: muted(context),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassButton(
                        d.live ? 'Pause' : 'Start',
                        compact: true,
                        icon: d.live
                            ? CupertinoIcons.pause
                            : CupertinoIcons.play,
                        onPressed: d.busy ? null : () => d.liveMode(!d.live),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final c in categories.keys)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => category = c),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: category == c ? accent : fill(context),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  c,
                                  style: TextStyle(
                                    color: category == c
                                        ? Colors.white
                                        : ink(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverToBoxAdapter(
              child: Section(
                query.isEmpty ? 'No signals yet' : 'No matching signals',
                children: [
                  Text(
                    query.isEmpty
                        ? 'Start the stream and wait for CAN frames. Missing data is not a zero reading.'
                        : 'Try a different signal name, unit or CAN ID.',
                  ),
                ],
              ),
            ),
          SliverList.builder(
            itemCount: rows.length,
            findChildIndexCallback: (key) =>
                key is ValueKey<String> ? indices[key.value] : null,
            itemBuilder: (context, index) {
              final row = rows[index];
              final age = DateTime.now()
                  .difference(row.value.receivedAt)
                  .inSeconds;
              return Padding(
                key: ValueKey('signal:${row.key}'),
                padding: const EdgeInsets.only(bottom: 10),
                child: Glass(
                  radius: 18,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.key.split(':').last,
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              d.demo
                                  ? 'Demo reading'
                                  : '0x${row.value.id.toRadixString(16)} · ${age < 0 ? 0 : age}s ago',
                              style: TextStyle(
                                color: muted(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '${number(row.value.value)} ${row.value.unit}'.trim(),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: ink(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 18)),
        ],
      );
    },
  );
}
