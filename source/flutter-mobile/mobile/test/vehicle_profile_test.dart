import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/data/vehicle_profile.dart';
import 'package:openola/diagnostics/controller.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:openola/diagnostics/report.dart';
import 'package:openola/protocol/can.dart';

Map<int, List<int>> frames(int model) => {
  0x211: [model, 0, 0, 0, 0, 0, 0, 0],
  0x610: model <= 4 ? [0, 0, 0, 0, 0, 0, 0, 0] : [1, 1, 0, 1, 0, 0, 0, 0],
};

Future<Diagnostics> fixture(int model, String release) async {
  SharedPreferences.setMockInitialValues({});
  final d = Diagnostics(
    await Catalog.load(),
    Preferences(await SharedPreferences.getInstance()),
  );
  d.connection = Connection.connected;
  d.firmware = release;
  for (final e in frames(model).entries) {
    d.acceptFrame(CanPacket(e.key, e.value));
  }
  return d;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('source-derived models include Gen2 and all known Gen3 variants', () {
    expect(VehicleIdentity.detect(frames(6), '5.6.1').model, contains('Gen2'));
    for (var model = 20; model <= 26; model++) {
      final id = VehicleIdentity.detect(frames(model), '5.6.1 / 5.6.1');
      expect(id.model, contains('Gen3'));
      expect(id.profile, VehicleProfile.moveos561);
      expect(id.legacyMethods, isFalse);
    }
    expect(
      VehicleIdentity.detect(frames(3), '5.0.0').profile,
      VehicleProfile.legacy,
    );
  });
  test('S1 Air and Air Fleet are identified without enabling unverified writes', () {
    for (final (code, label) in [(5, 'S1 Air'), (8, 'S1 Air Fleet')]) {
      final identity = VehicleIdentity.detect(frames(code), '5.6.1');
      expect(identity.model, label);
      expect(identity.profile, VehicleProfile.common);
      expect(identity.legacyMethods, isFalse);
    }
  });
  test('missing, reserved, unknown and conflicting identities fail closed', () {
    final observedGen3 = VehicleIdentity.detect(
      frames(31),
      '5.6.2.gen3.1114',
    );
    expect(observedGen3.model, contains('Gen3 model 31'));
    expect(observedGen3.profile, VehicleProfile.common);
    expect(observedGen3.legacyMethods, isFalse);
    for (final model in [0, 11, 27, 255]) {
      expect(
        VehicleIdentity.detect(frames(model), '5.6.1').profile,
        VehicleProfile.common,
      );
    }
    for (final version in ['Unknown', '5.6.10', '5.6.1 / 5.0.0', '7.1.15']) {
      expect(
        VehicleIdentity.detect(frames(25), version).profile,
        VehicleProfile.common,
      );
    }
    expect(
      VehicleIdentity.detect({
        0x211: [25],
      }, '5.6.1').profile,
      VehicleProfile.common,
    );
    expect(
      VehicleIdentity.detect({0x211: frames(25)[0x211]!}, '5.6.1').profile,
      VehicleProfile.common,
    );
    expect(
      VehicleIdentity.detect(frames(25), '5.0.0').profile,
      VehicleProfile.common,
    );
    expect(
      VehicleIdentity.detect(frames(3), '5.6.1').profile,
      VehicleProfile.common,
    );
    expect(
      VehicleIdentity.detect(
        frames(25),
        '5.6.1',
        aosp: 'Android 10 msm8953',
      ).profile,
      VehicleProfile.common,
    );
    expect(
      VehicleIdentity.detect(
        frames(3),
        '5.0.0',
        aosp: 'Mediatek Android 13',
      ).profile,
      VehicleProfile.common,
    );
  });
  test('hardware mismatch cannot select a profile from its model name', () {
    final modern = frames(25);
    modern[0x610] = [2, 1, 0, 1, 0, 0, 0, 0];
    expect(
      VehicleIdentity.detect(modern, '5.6.1').profile,
      VehicleProfile.common,
    );
    modern[0x610] = [1, 1, 4, 1, 0, 0, 0, 0];
    expect(
      VehicleIdentity.detect(modern, '5.6.1').profile,
      VehicleProfile.common,
    );
    final old = frames(3);
    old[0x610] = [1, 1, 0, 1, 0, 0, 0, 0];
    expect(VehicleIdentity.detect(old, '5.0.0').profile, VehicleProfile.common);
  });
  test(
    'model-specific decode changes only after identity; conflicts stay raw',
    () async {
      final d = await fixture(25, 'Unknown');
      addTearDown(d.dispose);
      d.acceptFrame(const CanPacket(0x6df, [75, 125, 100, 0, 0, 0, 0, 0]));
      expect(d.signal(['BBW_Low_Gain']), isNull);
      d.firmware = '5.6.1';
      d.refreshVehicleProfile();
      expect(d.signal(['BBW_Low_Gain']), 75);
      expect(d.signal(['BBW_High_Gain']), 125);
      expect(d.signal(['BBW_Medium_Gain']), 100);
      for (final id in [0x333, 0x274, 0x657, 0x658, 0x223]) {
        expect(d.catalog.signalsFor(d.identity.profile, id), isEmpty);
      }
      d.firmware = 'Unknown';
      d.refreshVehicleProfile();
      expect(d.signal(['BBW_Low_Gain']), isNull);
      expect(d.readings.keys.any((k) => k.contains('BBW')), isFalse);
    },
  );
  test('old and new latch layouts cannot cross-contaminate', () async {
    final d = await fixture(3, '5.0.0');
    addTearDown(d.dispose);
    d.acceptFrame(const CanPacket(0x508, [0, 0x80, 0, 0, 0, 0, 0, 0]));
    expect(d.signal(['Vehicle_connector_latched']), 1);
    d.firmware = '5.6.1';
    d.acceptFrame(CanPacket(0x211, frames(25)[0x211]!));
    d.acceptFrame(CanPacket(0x610, frames(25)[0x610]!));
    expect(d.signal(['Vehicle_connector_latched']), 0);
    d.acceptFrame(const CanPacket(0x508, [0, 4, 0, 0, 0, 0, 0, 0]));
    expect(d.signal(['Vehicle_connector_latched']), 1);
  });
  test('broadcast odometer populates automatically in kilometres', () async {
    final d = await fixture(3, '5.0.0');
    addTearDown(d.dispose);
    // 123,456 metres, little-endian on CAN 0x356.
    d.acceptFrame(const CanPacket(0x356, [0x40, 0xe2, 0x01, 0, 0, 0, 0, 0]));
    expect(d.odometerKm, 123);
    await d.disconnect();
    expect(d.odometerKm, isNull);
  });
  test(
    'short frames rejected and stale values unavailable in diagnostics',
    () async {
      final d = await fixture(25, '5.6.1');
      addTearDown(d.dispose);
      d.acceptFrame(const CanPacket(0x270, [1]));
      expect(d.raw[0x270], isNull);
      d.acceptFrame(
        const CanPacket(0x270, [32, 0, 0, 0, 1, 32, 0, 0]),
        receivedAt: DateTime.now().subtract(const Duration(seconds: 20)),
      );
      expect(d.frameFresh(0x270), isFalse);
      final entry = (d.modelDiagnostics['signals'] as Map)['0x270'] as Map;
      expect((entry['values'] as Map).values, everyElement(isNull));
    },
  );
  test(
    'new and unknown models never run legacy security/calibration commands',
    () async {
      final d = await fixture(25, '5.6.1');
      addTearDown(d.dispose);
      expect(() => d.requireLegacyMethod('Calibration'), throwsStateError);
      d.bench = true;
      d.mode = 'SERVICE';
      await d.hmi(1, 'Command');
      expect(d.message, contains('unavailable'));
      d.firmware = 'Unknown';
      d.refreshVehicleProfile();
      expect(() => d.requireLegacyMethod('Calibration'), throwsStateError);
    },
  );
  test(
    'disconnect removes identity, capabilities and prior scooter snapshots',
    () async {
      final d = await fixture(25, '5.6.1');
      addTearDown(d.dispose);
      d.acceptFrame(const CanPacket(0x273, [1, 2, 3, 4, 5, 6, 7, 8]));
      final report = DiagnosticReport.capture(d);
      expect((report.data['vehicle_profile'] as Map)['profile'], 'moveos561');
      await d.disconnect();
      expect(d.identity.profile, VehicleProfile.common);
      expect(d.identity.modelCode, isNull);
      expect(d.frameTimes, isEmpty);
      expect(d.readings, isEmpty);
      expect(d.firmware, 'Unknown');
      expect((report.data['vehicle_profile'] as Map)['profile'], 'moveos561');
    },
  );
}
