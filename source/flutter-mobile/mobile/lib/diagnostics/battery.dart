import '../data/identifiers.dart';

class BatteryCell {
  const BatteryCell(
    this.index,
    this.volts, {
    this.ir,
    this.ah,
    this.temperature,
  });
  final int index;
  final double volts;
  final double? ir, ah, temperature;
  double? get estimatedWh => ah == null ? null : ah! * volts;
  double get chargePercent {
    const curve = [
      (3.00, 0.0),
      (3.45, 8.0),
      (3.55, 15.0),
      (3.65, 28.0),
      (3.72, 42.0),
      (3.80, 58.0),
      (3.88, 72.0),
      (3.95, 83.0),
      (4.05, 92.0),
      (4.12, 97.0),
      (4.20, 100.0),
    ];
    if (volts <= curve.first.$1) return 0;
    for (var i = 1; i < curve.length; i++) {
      if (volts <= curve[i].$1) {
        final a = curve[i - 1], b = curve[i];
        return a.$2 + (volts - a.$1) / (b.$1 - a.$1) * (b.$2 - a.$2);
      }
    }
    return 100;
  }
}

class BatterySnapshot {
  BatterySnapshot(this.cells, this.health, this.errors, this.time, this.demo);
  final List<BatteryCell> cells;
  final List<DecodedValue> health;
  final List<String> errors;
  final DateTime time;
  final bool demo;
  double? healthValue(String pattern) {
    for (final row in health) {
      if (row.name.toLowerCase().contains(pattern) && row.value is num) {
        return (row.value as num).toDouble();
      }
    }
    return null;
  }

  String healthUnit(String pattern) {
    final row = health
        .where((v) => v.name.toLowerCase().contains(pattern))
        .firstOrNull;
    return switch (row?.unit) {
      'm-ohms' || 'mOhm' => 'mΩ',
      'degC' => '°C',
      'COUNT' => '',
      _ => row?.unit ?? '',
    };
  }

  double? get usableAh => healthValue('usable capacity');
  double? get estimatedPackWh {
    final voltageMv = healthValue('pack voltage');
    return usableAh == null || voltageMv == null || voltageMv <= 0
        ? null
        : usableAh! * voltageMv / 1000;
  }

  double? get cycleWh {
    final energy = healthValue('kwhr');
    return energy == null ? null : energy * 1000;
  }

  double get average =>
      cells.isEmpty ? 0 : cells.fold(0.0, (s, c) => s + c.volts) / cells.length;
  double get spreadMv => cells.isEmpty
      ? 0
      : (cells.map((c) => c.volts).reduce((a, b) => a > b ? a : b) -
                cells.map((c) => c.volts).reduce((a, b) => a < b ? a : b)) *
            1000;
  int? get lowestCell => cells.isEmpty
      ? null
      : cells.reduce((a, b) => a.volts <= b.volts ? a : b).index;
  double? get medianIr {
    final values = cells.map((c) => c.ir).whereType<double>().toList()..sort();
    if (values.isEmpty) return null;
    final mid = values.length ~/ 2;
    return values.length.isOdd
        ? values[mid]
        : (values[mid - 1] + values[mid]) / 2;
  }

  // Relative observations, never a diagnosis or safety verdict.
  String observation(BatteryCell c) =>
      c.volts < average - .030 ||
          (medianIr != null &&
              medianIr! > 0 &&
              c.ir != null &&
              c.ir! > medianIr! * 1.4)
      ? 'Check'
      : c.volts < average - .015 || (c.temperature ?? 0) > 45
      ? 'Watch'
      : 'Typical';

  /// Plain-language, non-diagnostic read of pack health from the live cell data.
  /// Returns (verdict, detail). Never a safety judgement — it points the user at
  /// what to check, and says plainly when a reading looks off (e.g. a low cell).
  (String, String) get healthAssessment {
    if (cells.isEmpty) {
      return ('Not enough data', 'Read the battery to assess cell balance.');
    }
    final checks = cells.where((c) => observation(c) == 'Check').toList();
    final watches = cells.where((c) => observation(c) == 'Watch').toList();
    if (checks.isNotEmpty) {
      final c = checks.reduce((a, b) => a.volts <= b.volts ? a : b);
      final deltaMv = ((average - c.volts) * 1000).round();
      return (
        'Attention — possible weak cell',
        'Cell group ${c.index} reads about $deltaMv mV below the pack average '
            '(overall spread ${spreadMv.toStringAsFixed(0)} mV). A persistently '
            'low cell group can point to a weak or ageing pack. This is not a '
            'verified diagnosis — run a full charge with balancing and recheck; '
            'if the gap stays or grows, have the battery inspected.',
      );
    }
    if (spreadMv >= 50 || watches.isNotEmpty) {
      return (
        'Monitor',
        'Cells vary by ${spreadMv.toStringAsFixed(0)} mV'
            '${lowestCell == null ? '' : ' (lowest #$lowestCell)'}. A little wide '
            'but not a fault — keep an eye on it and run a balancing charge.',
      );
    }
    return (
      'Healthy',
      'Cells are well balanced (${spreadMv.toStringAsFixed(0)} mV spread'
          '${lowestCell == null ? '' : ', lowest #$lowestCell'}). No cell-level '
          'concerns from the live data.',
    );
  }

  factory BatterySnapshot.fromResults(
    List<IdentifierResult> results, {
    required bool demo,
  }) {
    List<double?> numbers(int did) {
      final r = results.where((r) => r.definition.did == did).firstOrNull;
      return r?.values
              .map((v) => v.value is num ? (v.value as num).toDouble() : null)
              .toList() ??
          [];
    }

    final v = numbers(0xe106),
        ir = numbers(0xe109),
        ah = numbers(0xe108),
        temps = numbers(0xe107);
    final cells = <BatteryCell>[];
    for (var i = 0; i < v.length; i++) {
      if (v[i] == null) continue;
      final sensor = temps.isEmpty
          ? null
          : temps[(i * (temps.length - 1) / (v.length > 1 ? v.length - 1 : 1))
                .round()];
      cells.add(
        BatteryCell(
          i + 1,
          v[i]!,
          ir: i < ir.length ? ir[i] : null,
          ah: i < ah.length ? ah[i] : null,
          temperature: sensor,
        ),
      );
    }
    return BatterySnapshot(
      cells,
      results
          .where(
            (r) => [
              0xe100,
              0xe101,
              0xe102,
              0xe103,
              0xe434,
            ].contains(r.definition.did),
          )
          .expand((r) => r.values)
          .toList(),
      results
          .where((r) => r.error != null)
          .map((r) => '${r.definition.title}: ${r.error}')
          .toList(),
      DateTime.now(),
      demo,
    );
  }
  factory BatterySnapshot.simulated() => BatterySnapshot(
    List.generate(
      14,
      (i) => BatteryCell(
        i + 1,
        i == 8 ? 3.858 : 3.90 + (i % 5) * .004,
        ir: i == 8 ? 3.1 : 1.8 + (i % 3) * .1,
        ah: 3.2,
        temperature: 31.0 + i ~/ 3,
      ),
    ),
    [
      const DecodedValue('SOH', 96.2, '%'),
      const DecodedValue('Cycle count', 148.0, ''),
      const DecodedValue('Effective temperature', 33.0, '°C'),
      // Illustrative demo values kept internally consistent: usable Ah ×
      // pack V ≈ estimated Wh. Real packs vary by model (2/3/4 kWh); on a live
      // scooter the usable Ah comes from the BMS, not this constant.
      const DecodedValue('Usable capacity', 73.1, 'Ah'),
      const DecodedValue('Pack voltage', 54724.0, 'mV'),
      const DecodedValue('KwHr Accumalated - current cycle', 1.2, 'KwHr'),
    ],
    [],
    DateTime.now(),
    true,
  );
}
