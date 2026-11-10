import 'package:flutter/services.dart';

/// Haptic feedback that honours the user's Haptics setting.
///
/// Prefers the native Vibrator service (reliable on ColorOS/MIUI and other
/// skins that mute Flutter's [HapticFeedback]); falls back to [HapticFeedback]
/// if the platform call isn't available (e.g. iOS or an older build).
///
/// [enabled] is mirrored from `Preferences.haptics` so any call site can fire
/// feedback without plumbing the preference through the widget tree. Each
/// method is a no-op when haptics are off, and failures (e.g. a device with no
/// vibrator) are swallowed so callers never need a try/catch.
class AppHaptics {
  AppHaptics._();

  static const _channel = MethodChannel('in.crossfire.openola/haptics');
  static bool enabled = true;

  /// [ms] duration, [amplitude] 1–255 (or -1 for the device default). Falls
  /// back to the matching platform haptic if the native call fails.
  static void _buzz(int ms, int amplitude, Future<void> Function() fallback) {
    if (!enabled) return;
    _channel
        .invokeMethod<bool>('vibrate', {'ms': ms, 'amplitude': amplitude})
        .catchError((_) {
          fallback().catchError((_) {});
          return null;
        });
  }

  /// Light tick for navigation / selection changes.
  static void selection() => _buzz(22, 170, HapticFeedback.selectionClick);

  /// Small bump for a primary tap or toggle.
  static void light() => _buzz(40, 220, HapticFeedback.mediumImpact);

  /// Confirmation of a completed action (e.g. slide-to-verify success).
  static void success() => _buzz(70, 255, HapticFeedback.heavyImpact);

  /// Stronger feedback for entering a guarded/dangerous mode or an error.
  static void warning() => _buzz(130, 255, HapticFeedback.heavyImpact);
}
