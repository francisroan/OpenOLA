import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class SessionSample {
  const SessionSample(this.time, this.values);
  final double time;
  final Map<String, double> values;
}

class SignalSummary {
  SignalSummary(double value) : minimum = value, maximum = value, last = value;
  int count = 0;
  double minimum, maximum, last;
  void add(double value) {
    count++;
    if (value < minimum) minimum = value;
    if (value > maximum) maximum = value;
    last = value;
  }
}

class SessionSummary {
  SessionSummary(
    this.file,
    this.meta,
    this.samples,
    this.duration,
    this.signals,
  );
  final File file;
  final Map<String, dynamic> meta;
  final int samples;
  final double duration;
  final Map<String, SignalSummary> signals;
  String get name => file.uri.pathSegments.last;
}

/// Durable foreground JSONL recorder, compatible with the desktop SessionRecorder.
class SessionRecorder extends ChangeNotifier {
  SessionRecorder({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;
  File? file;
  IOSink? _sink;
  bool active = false, closing = false;
  bool starting = false;
  int _epoch = 0;
  int samples = 0;
  double duration = 0;
  String? error;
  final signals = <String, SignalSummary>{};
  DateTime? _first;
  bool _disposed = false;
  Future<void> _writes = Future.value();
  Future<File?>? _stopping;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  Future<Directory> folder() async {
    final root = await _directory();
    return Directory('${root.path}${Platform.pathSeparator}recordings')
      ..createSync(recursive: true);
  }

  Future<List<File>> library() async {
    final files = await (await folder())
        .list()
        .where((e) => e is File && e.path.endsWith('.jsonl'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<void> start(Map<String, Object?> meta, {DateTime? now}) async {
    if (active || closing || starting) {
      throw StateError('Stop the current recording first');
    }
    final token = ++_epoch;
    starting = true;
    _stopping = null;
    try {
      now ??= DateTime.now();
      final directory = await folder();
      if (token != _epoch) throw StateError('Recording start cancelled');
      file = File(
        '${directory.path}${Platform.pathSeparator}OpenOLA-${now.microsecondsSinceEpoch}.jsonl',
      );
      _sink = file!.openWrite();
      error = null;
      samples = 0;
      duration = 0;
      signals.clear();
      _first = null;
      _writes = Future.value();
      _sink!.add(
        utf8.encode(
          '${jsonEncode({'recorder': 1, 'started': now.millisecondsSinceEpoch / 1000, 'meta': meta})}\n',
        ),
      );
      try {
        await _sink!.flush();
      } catch (e) {
        await _fail(e);
        rethrow;
      }
      active = true;
      if (token != _epoch) {
        active = false;
        await _sink?.close();
        _sink = null;
        throw StateError('Recording start cancelled');
      }
      _emit();
    } finally {
      starting = false;
      _emit();
    }
  }

  void sample(Map<String, double> values, {DateTime? now}) {
    if (!active || closing) return;
    final clean = Map<String, double>.fromEntries(
      values.entries.where((e) => e.value.isFinite),
    );
    if (clean.isEmpty) return;
    now ??= DateTime.now();
    _first ??= now;
    duration = now.difference(_first!).inMilliseconds / 1000;
    for (final e in clean.entries) {
      signals.putIfAbsent(e.key, () => SignalSummary(e.value)).add(e.value);
    }
    samples++;
    final sink = _sink!;
    final line = utf8.encode(
      '${jsonEncode({'t': double.parse(duration.toStringAsFixed(2)), 'v': clean})}\n',
    );
    final flush = samples % 20 == 0;
    _writes = _writes
        .then((_) async {
          sink.add(line);
          if (flush) await sink.flush();
        })
        .catchError((Object e) async {
          await _fail(e);
        });
    _emit();
  }

  Future<void> _fail(Object e) async {
    active = false;
    error = 'Recording stopped: $e';
    final sink = _sink;
    _sink = null;
    try {
      await sink?.close();
    } catch (_) {
      /* The original write error is retained. */
    }
    _emit();
  }

  Future<File?> stop() {
    ++_epoch;
    return _stopping ??= _finish();
  }

  Future<File?> _finish() async {
    closing = true;
    active = false;
    _emit();
    try {
      await _writes;
      await _sink?.flush();
      await _sink?.close();
    } catch (e) {
      error = 'Recording could not finish saving: $e';
    } finally {
      _sink = null;
      closing = false;
      _emit();
    }
    return file;
  }

  static Map<String, double> _values(Object? raw) {
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.key is String &&
            e.value is num &&
            (e.value as num).toDouble().isFinite)
          e.key as String: (e.value as num).toDouble(),
    };
  }

  static Stream<Map<String, dynamic>> rows(File file) async* {
    var first = true;
    await for (var line
        in file
            .openRead()
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (first) {
        line = line.replaceFirst('\uFEFF', '');
        first = false;
      }
      try {
        final row = jsonDecode(line);
        if (row is Map<String, dynamic>) yield row;
      } on FormatException {
        /* tolerate incomplete last lines */
      }
    }
  }

  static Future<SessionSummary> summarize(File file) async {
    Map<String, dynamic> meta = {};
    var samples = 0;
    var duration = 0.0;
    var header = false;
    final signals = <String, SignalSummary>{};
    await for (final row in rows(file)) {
      if (row['recorder'] == 1) {
        header = true;
        meta = Map<String, dynamic>.from(row['meta'] as Map? ?? {});
        continue;
      }
      final time = row['t'];
      final values = _values(row['v']);
      if (time is! num || !time.toDouble().isFinite || values.isEmpty) continue;
      samples++;
      if (time > duration) duration = time.toDouble();
      for (final e in values.entries) {
        signals.putIfAbsent(e.key, () => SignalSummary(e.value)).add(e.value);
      }
    }
    if (!header || samples == 0) {
      throw const FormatException(
        'Choose a desktop/OpenOLA session JSONL with numeric samples.',
      );
    }
    return SessionSummary(file, meta, samples, duration, signals);
  }

  static Future<Map<String, List<(double, double)>>> series(
    File file,
    Iterable<String> names, {
    int maxPoints = 1500,
  }) async {
    final result = {
      for (final name in names.take(6)) name: <(double, double)>[],
    };
    final stride = {for (final name in result.keys) name: 1},
        count = {for (final name in result.keys) name: 0};
    await for (final row in rows(file)) {
      final time = row['t'];
      if (time is! num || !time.toDouble().isFinite) continue;
      final values = _values(row['v']);
      for (final name in result.keys) {
        final value = values[name];
        if (value == null) continue;
        final n = count[name]!;
        count[name] = n + 1;
        if (n % stride[name]! != 0) continue;
        result[name]!.add((time.toDouble(), value));
        if (result[name]!.length > maxPoints) {
          final reduced = [
            for (var i = 0; i < result[name]!.length; i += 2) result[name]![i],
          ];
          result[name] = reduced;
          stride[name] = stride[name]! * 2;
        }
      }
    }
    return result;
  }

  static String _csv(Object value) =>
      '"${value.toString().replaceAll('"', '""')}"';
  static Future<void> exportCsv(SessionSummary summary, File target) async {
    final names = summary.signals.keys.toList()..sort();
    final sink = target.openWrite();
    try {
      sink.write('\uFEFF${['time_s', ...names].map(_csv).join(',')}\r\n');
      await for (final row in rows(summary.file)) {
        final time = row['t'];
        final values = _values(row['v']);
        if (time is! num || values.isEmpty) continue;
        sink.write(
          [time, ...names.map((n) => values[n] ?? '')].map(_csv).join(','),
        );
        sink.write('\r\n');
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
