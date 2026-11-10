import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'mcu_replacement_plan.dart';

class McuImportedFirmware {
  const McuImportedFirmware(this.path, this.source);
  final String path;
  final String source;
}

/// Verifies one selected MCU binary, either bundled or from a diagnostic APK.
class McuFirmwareImport {
  static Future<McuImportedFirmware> bundled(
    McuFirmwareCandidate candidate,
  ) async {
    final data = await rootBundle.load('assets/firmware/mcu/${candidate.file}');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    _checkHash(bytes, candidate);
    return _store(bytes, candidate, 'included manufacturer firmware');
  }

  static Future<McuImportedFirmware> verify(
    String selectedPath,
    McuFirmwareCandidate candidate,
  ) async {
    final source = File(selectedPath);
    if (!await source.exists()) {
      throw StateError('Selected file is unavailable.');
    }
    Uint8List bytes;
    String label;
    if (selectedPath.toLowerCase().endsWith('.apk')) {
      final size = await source.length();
      if (size <= 0 || size > 300 * 1024 * 1024) {
        throw StateError('Diagnostic APK is empty or exceeds 300 MB.');
      }
      final input = InputFileStream(selectedPath);
      try {
        final archive = ZipDecoder().decodeStream(input);
        final entry = archive.find('res/raw/${candidate.file}');
        if (entry == null || !entry.isFile || entry.size != 98304) {
          throw StateError(
            'Diagnostic APK does not contain ${candidate.file}.',
          );
        }
        bytes =
            entry.readBytes() ??
            (throw StateError(
              'Could not read ${candidate.file} from the APK.',
            ));
      } finally {
        await input.close();
      }
      label = 'diagnostic APK';
    } else if (selectedPath.toLowerCase().endsWith('.bin')) {
      if (source.uri.pathSegments.last != candidate.file) {
        throw StateError(
          'Select ${candidate.file}, or select the diagnostic APK.',
        );
      }
      bytes = await source.readAsBytes();
      label = 'firmware binary';
    } else {
      throw StateError('Select a diagnostic APK or ${candidate.file}.');
    }
    _checkHash(bytes, candidate);
    if (label == 'firmware binary') {
      return McuImportedFirmware(selectedPath, label);
    }
    return _store(bytes, candidate, label);
  }

  static void _checkHash(Uint8List bytes, McuFirmwareCandidate candidate) {
    if (bytes.length != 98304 ||
        sha256.convert(bytes).toString().toUpperCase() != candidate.sha256) {
      throw StateError(
        'Firmware does not match the exact diagnostic APK resource SHA-256.',
      );
    }
  }

  static Future<McuImportedFirmware> _store(
    Uint8List bytes,
    McuFirmwareCandidate candidate,
    String label,
  ) async {
    final dir = await Directory.systemTemp.createTemp('openola_mcu_');
    final extracted = File(
      '${dir.path}${Platform.pathSeparator}${candidate.file}',
    );
    await extracted.writeAsBytes(bytes, flush: true);
    return McuImportedFirmware(extracted.path, label);
  }
}
