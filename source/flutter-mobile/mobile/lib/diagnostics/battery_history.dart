import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// One persisted battery-health sample. SoH and spread come from CAN; usable Ah
/// only when a UDS deep read has run, so it is often null.
class BatteryHistoryPoint {
  const BatteryHistoryPoint(this.t, this.soh, this.spreadMv, this.ah);
  final DateTime t;
  final double? soh, spreadMv, ah;

  Map<String, Object?> toJson() => {
    't': t.millisecondsSinceEpoch,
    'soh': soh,
    'spread': spreadMv,
    'ah': ah,
  };

  static BatteryHistoryPoint fromJson(Map<String, dynamic> j) =>
      BatteryHistoryPoint(
        DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
        (j['soh'] as num?)?.toDouble(),
        (j['spread'] as num?)?.toDouble(),
        (j['ah'] as num?)?.toDouble(),
      );
}

/// Cross-session battery-health history, persisted to a JSON file in the app's
/// documents directory. Lets the UI chart SoH, cell spread and capacity trends
/// over time (the olamate-style history the live-only recorder lacked).
class BatteryHistory {
  BatteryHistory({Future<Directory> Function()? directory})
    : _dir = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _dir;
  final List<BatteryHistoryPoint> points = [];
  DateTime? _lastRecord;
  bool _loaded = false;
  static const _max = 2000;

  Future<File> _file() async =>
      File('${(await _dir()).path}/battery_history.json');

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final f = await _file();
      if (await f.exists()) {
        final list = jsonDecode(await f.readAsString()) as List;
        points
          ..clear()
          ..addAll(
            list.map(
              (e) => BatteryHistoryPoint.fromJson(e as Map<String, dynamic>),
            ),
          );
      }
    } catch (_) {
      /* corrupt or unreadable history is non-fatal */
    }
  }

  /// Records a sample at most once per [minGap]. No-op when nothing is reported.
  Future<bool> record(
    double? soh,
    double? spreadMv,
    double? ah, {
    Duration minGap = const Duration(seconds: 60),
  }) async {
    if (soh == null && spreadMv == null && ah == null) return false;
    final now = DateTime.now();
    if (_lastRecord != null && now.difference(_lastRecord!) < minGap) {
      return false;
    }
    _lastRecord = now;
    points.add(BatteryHistoryPoint(now, soh, spreadMv, ah));
    if (points.length > _max) points.removeRange(0, points.length - _max);
    await _save();
    return true;
  }

  Future<void> _save() async {
    try {
      await (await _file()).writeAsString(
        jsonEncode(points.map((p) => p.toJson()).toList()),
      );
    } catch (_) {
      /* best-effort persistence */
    }
  }

  /// Time-series points (ms-epoch, value) for a chosen field, nulls skipped.
  List<(double, double)> series(double? Function(BatteryHistoryPoint) pick) {
    final out = <(double, double)>[];
    for (final p in points) {
      final v = pick(p);
      if (v != null) out.add((p.t.millisecondsSinceEpoch.toDouble(), v));
    }
    return out;
  }

  Future<void> clear() async {
    points.clear();
    _lastRecord = null;
    await _save();
  }
}
