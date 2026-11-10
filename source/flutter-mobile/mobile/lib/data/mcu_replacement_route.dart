import 'vehicle_profile.dart';

enum McuReplacementFamily {
  gen1S1Pro,
  gen1S1,
  air,
  gen2Pro,
  s1x,
  s1xPhase2,
  gen3,
  m3x,
  unknown,
}

class McuReplacementRoute {
  const McuReplacementRoute(
    this.family,
    this.title,
    this.detail,
    this.activeTrial,
  );
  final McuReplacementFamily family;
  final String title;
  final String detail;
  final bool activeTrial;

  static McuReplacementRoute detect(VehicleIdentity identity) {
    final code = identity.modelCode;
    if (code == 2 || code == 3) {
      return McuReplacementRoute(
        McuReplacementFamily.gen1S1Pro,
        'Gen1 S1 Pro · SEG MCU',
        identity.legacyMethods
            ? 'Supervised local flash, reset and AutoTune trial available.'
            : 'Gen1 procedure identified; wait for a verified legacy hardware/software profile before writes.',
        identity.legacyMethods,
      );
    }
    if (code == 1 || code == 4) {
      return const McuReplacementRoute(
        McuReplacementFamily.gen1S1,
        'Gen1 S1 · SEG MCU',
        'The official app routes this model through its legacy wizard; the exact VIN-to-firmware and replacement part match still need verification.',
        false,
      );
    }
    if (code == 5 || code == 8) {
      return const McuReplacementRoute(
        McuReplacementFamily.air,
        'S1 Air · HUB MCU',
        'The official app routes non-TCP Air scooters through its legacy wizard. HUB firmware is included, but the part and file choice are not verified here.',
        false,
      );
    }
    if (code == 6 || code == 9) {
      return const McuReplacementRoute(
        McuReplacementFamily.gen2Pro,
        'Gen2 S1 Pro',
        'The official app uses its legacy wizard on non-Gen3 Gen2 scooters. Controller, motor and firmware compatibility must be checked separately.',
        false,
      );
    }
    if (code == 10 || code == 13) {
      return const McuReplacementRoute(
        McuReplacementFamily.s1xPhase2,
        'S1X Plus Phase 2 · TCP',
        'The official Phase 2 screen uses an OTA trigger. Passive TCP intake works, but OTA replacement is not implemented in OpenOLA.',
        false,
      );
    }
    if ({7, 12, 14, 15, 16}.contains(code)) {
      return const McuReplacementRoute(
        McuReplacementFamily.s1x,
        'S1X / S1X Plus',
        'The official non-TCP route enters the legacy wizard; S1X motor, firmware and calibration compatibility are not verified in OpenOLA.',
        false,
      );
    }
    if (code != null && (code >= 20 && code <= 26 || code == 31)) {
      return const McuReplacementRoute(
        McuReplacementFamily.gen3,
        'Gen3 MCU / IMCU',
        'Gen3 uses integrated-MCU firmware, an Id/Iq table and a different calibration sequence. The Gen1 flash command is not offered.',
        false,
      );
    }
    if (code != null && code >= 17 && code <= 19) {
      return const McuReplacementRoute(
        McuReplacementFamily.m3x,
        'M3X',
        'No MCU replacement procedure has been verified for this model.',
        false,
      );
    }
    return const McuReplacementRoute(
      McuReplacementFamily.unknown,
      'Unidentified scooter',
      'Wait for fresh model and hardware CAN data before choosing a replacement flow.',
      false,
    );
  }
}
