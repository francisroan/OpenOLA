import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Visual quality tiers for the glass material. Lower tiers cost less GPU time:
/// `high` is the full frosted blur, `balanced` is a lighter blur, and `lite`
/// drops the `BackdropFilter` entirely (translucent fill only) for low-end
/// phones or when frames are dropping.
enum GlassTier { high, balanced, lite }

extension GlassTierX on GlassTier {
  /// Backdrop blur sigma for this tier. 0 means "no BackdropFilter".
  double get sigma => switch (this) {
    GlassTier.high => 18,
    GlassTier.balanced => 9,
    GlassTier.lite => 0,
  };

  String get label => switch (this) {
    GlassTier.high => 'High',
    GlassTier.balanced => 'Balanced',
    GlassTier.lite => 'Battery saver',
  };
}

/// Chooses the active [GlassTier].
///
/// In `auto` mode it watches real frame timings and steps the tier down one
/// level whenever a run of frames misses the refresh budget, so the UI stays
/// smooth on weaker hardware without anyone changing a setting. It never steps
/// back up on its own (to avoid oscillation); a relaunch or a manual change
/// resets it. A manual tier pins the quality and disables monitoring.
class GlassQuality extends ChangeNotifier {
  GlassQuality({bool auto = true, GlassTier manual = GlassTier.high})
    : _auto = auto,
      _manual = manual {
    if (_auto) _startSampling();
  }

  bool _auto;
  GlassTier _manual;
  GlassTier _effective = GlassTier.high;

  bool get auto => _auto;
  GlassTier get manual => _manual;
  GlassTier get tier => _auto ? _effective : _manual;
  double get sigma => tier.sigma;

  void setAuto(bool value) {
    if (value == _auto) return;
    _auto = value;
    if (_auto) {
      _effective = GlassTier.high;
      _startSampling();
    } else {
      _stopSampling();
    }
    notifyListeners();
  }

  void setManual(GlassTier value) {
    _manual = value;
    if (_auto) {
      _auto = false;
      _stopSampling();
    }
    notifyListeners();
  }

  // --- frame-timing watchdog -------------------------------------------------
  //
  // Only *sustained, severe* jank steps the tier down. We look at the actual
  // build+raster work per frame (not totalSpan, which includes vsync waiting and
  // is noisy at 90/120Hz), flag a frame only when that work exceeds ~30ms (well
  // under 30fps), and downgrade a single tier only when a large fraction of a
  // multi-second window is that heavy. A cooldown then prevents a second
  // downgrade until things have had time to settle. The effect: capable phones
  // keep full glass through normal transition spikes; only genuinely struggling
  // devices drop, and reaching "lite" takes two separate bad windows.
  bool _sampling = false;
  final List<bool> _window = []; // per-frame: was it severely janky?
  int _cooldown = 0;

  static const _windowSize = 240; // ~2–4s depending on refresh rate
  static const _severeMicros = 30000; // 30ms of real build+raster work
  static const _jankFraction = 0.45; // >45% of the window must be janky

  void _startSampling() {
    if (_sampling) return;
    _sampling = true;
    _window.clear();
    _cooldown = _windowSize; // grace period right after (re)starting
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  void _stopSampling() {
    if (!_sampling) return;
    _sampling = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_auto || _effective == GlassTier.lite) {
      _stopSampling();
      return;
    }
    for (final t in timings) {
      final work =
          t.buildDuration.inMicroseconds + t.rasterDuration.inMicroseconds;
      _window.add(work > _severeMicros);
      if (_window.length > _windowSize) _window.removeAt(0);
      if (_cooldown > 0) {
        _cooldown--;
        continue;
      }
      if (_window.length < _windowSize) continue;
      final jank = _window.where((b) => b).length / _window.length;
      if (jank <= _jankFraction) continue;
      final next = _effective == GlassTier.high
          ? GlassTier.balanced
          : GlassTier.lite;
      if (next != _effective) {
        _effective = next;
        scheduleMicrotask(notifyListeners); // not inside the timing callback
      }
      _window.clear();
      _cooldown = _windowSize; // wait a full window before re-evaluating
      if (_effective == GlassTier.lite) {
        _stopSampling();
        break;
      }
    }
  }

  @override
  void dispose() {
    _stopSampling();
    super.dispose();
  }
}

/// Exposes the active [GlassQuality] to the widget tree. Glass surfaces depend
/// on it so a tier change repaints them (an infrequent event).
class GlassQualityScope extends InheritedNotifier<GlassQuality> {
  const GlassQualityScope({
    super.key,
    required GlassQuality quality,
    required super.child,
  }) : super(notifier: quality);

  static GlassQuality? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassQualityScope>()?.notifier;

  /// Active blur sigma, defaulting to the full value when no scope is present
  /// (e.g. the startup/error screens before the app is wired up).
  static double sigmaOf(BuildContext context) =>
      maybeOf(context)?.sigma ?? GlassTier.high.sigma;
}
