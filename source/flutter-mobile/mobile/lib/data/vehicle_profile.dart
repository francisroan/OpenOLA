/// Model codes from IMCU13 HVDP 7.1.19 `VehicleTypes.<clinit>`.
/// A model name is not sufficient evidence for a protocol or an actuator.
enum VehicleProfile { common, legacy, moveos561 }

class VehicleIdentity {
  const VehicleIdentity(
    this.modelCode,
    this.hardware,
    this.profile,
    this.reason,
  );
  final int? modelCode;
  final List<int> hardware;
  final VehicleProfile profile;
  final String reason;
  static const models = <int, String>{
    1: 'Ola S1',
    2: 'S1 Pro without upgrade',
    3: 'S1 Pro with upgrade',
    4: 'S1 2 kWh',
    5: 'S1 Air',
    6: 'S1 Pro Gen2 with upgrade',
    7: 'S1X Plus',
    8: 'S1 Air Fleet',
    9: 'S1 Pro Gen2 without upgrade',
    10: 'S1X Plus Phase 2',
    12: 'S1X Plus Phase 1 4 kWh',
    13: 'S1X Plus Phase 2 4 kWh',
    14: 'S1X 2 kWh',
    15: 'S1X 3 kWh',
    16: 'S1X 4 kWh',
    17: 'M3X 2.5 kWh',
    18: 'M3X 3.5 kWh',
    19: 'M3X 4.5 kWh',
    20: 'S1X Gen3 2 kWh',
    21: 'S1X Gen3 3 kWh',
    22: 'S1X Gen3 4 kWh',
    23: 'S1X Plus Gen3 4 kWh',
    24: 'S1 Pro Gen3 3 kWh',
    25: 'S1 Pro Gen3 4 kWh',
    26: 'S1 Pro Plus Gen3 4 kWh',
    31: 'Gen3 model 31 (variant unverified)',
  };
  String get model =>
      models[modelCode] ??
      (modelCode == null
          ? 'Waiting for scooter identity'
          : 'Unknown model ($modelCode)');
  String get profileLabel => switch (profile) {
    VehicleProfile.common => 'Common signals only',
    VehicleProfile.legacy => 'Legacy S1 diagnostics',
    VehicleProfile.moveos561 => 'MoveOS 5.6.1 diagnostics',
  };
  bool get matched => profile != VehicleProfile.common;
  bool get legacyMethods => profile == VehicleProfile.legacy;
  Map<String, Object?> toJson() => {
    'model_code': modelCode,
    'model': model,
    'hardware_codes': hardware,
    'profile': profile.name,
    'reason': reason,
  };

  static VehicleIdentity detect(
    Map<int, List<int>> frames,
    String firmware, {
    String aosp = '',
  }) {
    final vehicle = frames[0x211];
    final code = vehicle != null && vehicle.length == 8 ? vehicle[0] : null;
    final hw = frames[0x610];
    final hardware = hw != null && hw.length == 8
        ? List<int>.unmodifiable(hw.take(6))
        : <int>[];
    VehicleIdentity result(VehicleProfile p, String why) =>
        VehicleIdentity(code, hardware, p, why);
    if (!models.containsKey(code)) {
      return result(
        VehicleProfile.common,
        'Model is missing, reserved or unrecognised. No model-specific commands.',
      );
    }
    if (code == 31) {
      return result(
        VehicleProfile.common,
        'Model 31 and the 5.6.2 Gen3 build were observed on a connected scooter; its controller command map is not yet verified.',
      );
    }
    if (hardware.length != 6 || hardware.take(4).any((v) => v == 255)) {
      return result(
        VehicleProfile.common,
        'Waiting for complete controller hardware identity.',
      );
    }
    // Require one unambiguous release token. Do not match 5.6.10 or guess from
    // the model, an ABS frame, a VIN, or a user-selected name.
    final releases = RegExp(
      r'(?<![\d.])\d+\.\d+\.\d+(?![\d.])',
    ).allMatches(firmware).map((m) => m.group(0)!).toSet();
    if (releases.length != 1) {
      return result(
        VehicleProfile.common,
        'Software release is missing or ambiguous.',
      );
    }
    final release = releases.single;
    final modernModel = code == 6 || code == 9 || (code! >= 20 && code <= 26);
    if (release == '5.6.1' && modernModel) {
      if (hardware[0] != 1 || hardware[1] != 1 || hardware[2] > 3) {
        return result(
          VehicleProfile.common,
          'Controller hardware does not match the inspected 5.6.1 BCM/BMS variants.',
        );
      }
      if (RegExp(
        r'msm8953|Android\s*10\b',
        caseSensitive: false,
      ).hasMatch(aosp)) {
        return result(
          VehicleProfile.common,
          'Platform metadata conflicts with the 5.6.1 profile.',
        );
      }
      return result(
        VehicleProfile.moveos561,
        'Model, controller identity and 5.6.1 release received.',
      );
    }
    if (code! >= 1 && code <= 4 && (release == '3.0.0' || release == '5.0.0')) {
      if (hardware.take(4).any((v) => v != 0)) {
        return result(
          VehicleProfile.common,
          'Controller hardware differs from the captured legacy S1 profile.',
        );
      }
      if (RegExp(
        r'tb8768|Mediatek|Android\s*13\b',
        caseSensitive: false,
      ).hasMatch(aosp)) {
        return result(
          VehicleProfile.common,
          'Platform metadata conflicts with the legacy profile.',
        );
      }
      return result(
        VehicleProfile.legacy,
        'Older S1 model and known software release received.',
      );
    }
    return result(
      VehicleProfile.common,
      'Model recognised; this model/software combination has no verified profile.',
    );
  }
}
