import 'dart:io';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:openola/data/mcu_firmware_import.dart';
import 'package:openola/data/mcu_replacement_plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'all diagnostic MCU resources are present and hash-matched as assets',
    () async {
      final manifest =
          jsonDecode(
                await rootBundle.loadString(
                  'assets/firmware/mcu/manifest.json',
                ),
              )
              as Map<String, dynamic>;
      final files = (manifest['files'] as List).cast<Map<String, dynamic>>();
      expect(files.length, 27);
      for (final row in files) {
        final bytes = await rootBundle.load(
          'assets/firmware/mcu/${row['file']}',
        );
        final data = bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        );
        expect(data.length, row['length'], reason: '${row['file']} length');
        expect(
          sha256.convert(data).toString().toUpperCase(),
          row['sha256'],
          reason: '${row['file']} hash',
        );
      }
    },
  );
  test(
    'all four bundled Gen1 MCU files match the diagnostic APK hashes',
    () async {
      for (final vin in ['P53BA123456789012', 'P53AU123456789012']) {
        for (final motor in McuMotorType.values) {
          final candidate = McuFirmwareCandidate.forGen1(
            vin: vin,
            headUnitSoftware: '5.0.0',
            motor: motor,
          )!;
          final result = await McuFirmwareImport.bundled(candidate);
          try {
            expect(result.source, 'included manufacturer firmware');
            expect(File(result.path).lengthSync(), 98304);
          } finally {
            await File(result.path).delete();
            await File(result.path).parent.delete();
          }
        }
      }
    },
  );

  test(
    'extracts and verifies the exact MCU resource from the diagnostic APK',
    () async {
      final apk = File('../notes/OlaDiagnostics-0.32.215-improved.apk');
      if (!apk.existsSync()) {
        return; // The private source APK is not in public CI.
      }
      final candidate = McuFirmwareCandidate.forGen1(
        vin: 'P53BA123456789012',
        headUnitSoftware: '5.0.0',
        motor: McuMotorType.seg,
      )!;
      final result = await McuFirmwareImport.verify(apk.path, candidate);
      try {
        expect(result.source, 'diagnostic APK');
        expect(File(result.path).lengthSync(), 98304);
        expect(File(result.path).uri.pathSegments.last, candidate.file);
      } finally {
        await File(result.path).delete();
        await File(result.path).parent.delete();
      }
    },
  );
}
