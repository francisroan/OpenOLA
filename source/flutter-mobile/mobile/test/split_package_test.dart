import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openola/diagnostics/head_unit_tools.dart';
import 'package:openola/diagnostics/split_package.dart';

List<int> apkBytes(int n) => [0x50, 0x4b, 3, 4, ...List.filled(n, 7)];

List<int> zip(Map<String, List<int>> files) {
  final archive = Archive();
  files.forEach(
    (name, bytes) => archive.addFile(ArchiveFile(name, bytes.length, bytes)),
  );
  return ZipEncoder().encode(archive);
}

void main() {
  group('ApkPackage', () {
    test('single apk passes through', () {
      final pkg = ApkPackage.parse('app.apk', apkBytes(10));
      expect(pkg.parts, hasLength(1));
      expect(pkg.isSplit, isFalse);
    });

    test('rejects unsupported names, empty and non-zip content', () {
      expect(
        () => ApkPackage.parse('a.zip', apkBytes(4)),
        throwsFormatException,
      );
      expect(() => ApkPackage.parse('a.apk', []), throwsFormatException);
      expect(
        () => ApkPackage.parse('a.apk', [1, 2, 3, 4, 5, 6]),
        throwsFormatException,
      );
      expect(
        () => ApkPackage.parse('a.apks', [0x50, 0x4b, 9, 9, 9, 9]),
        throwsFormatException,
      );
    });

    test(
      'bundletool .apks installs every split, base first, ignores metadata',
      () {
        final bytes = zip({
          'toc.pb': [1, 2, 3],
          'splits/split_config.en.apk': apkBytes(3),
          'splits/base-master.apk': apkBytes(5),
          'splits/split_config.arm64_v8a.apk': apkBytes(4),
        });
        final pkg = ApkPackage.parse('app.apks', bytes);
        expect(pkg.isSplit, isTrue);
        expect(pkg.parts.map((p) => p.name).first, 'base-master.apk');
        expect(pkg.parts, hasLength(3));
        expect(pkg.ignoredEntries, 1);
      },
    );

    test('universal.apk wins over splits', () {
      final pkg = ApkPackage.parse(
        'app.apks',
        zip({
          'universal.apk': apkBytes(8),
          'splits/base-master.apk': apkBytes(5),
        }),
      );
      expect(pkg.parts.single.name, 'universal.apk');
    });

    test('xapk root apks are used; obb and manifest are ignored', () {
      final pkg = ApkPackage.parse(
        'app.xapk',
        zip({
          'manifest.json': [123, 125],
          'com.x.base.apk': apkBytes(5),
          'config.arm64_v8a.apk': apkBytes(4),
          'Android/obb/com.x/main.1.com.x.obb': [1, 2, 3],
        }),
      );
      expect(pkg.parts, hasLength(2));
      expect(pkg.ignoredEntries, 2);
    });

    test('several standalone APKs are refused as ambiguous', () {
      expect(
        () => ApkPackage.parse(
          'app.apks',
          zip({
            'standalones/standalone-xhdpi.apk': apkBytes(4),
            'standalones/standalone-xxhdpi.apk': apkBytes(4),
          }),
        ),
        throwsFormatException,
      );
    });

    test('an entry that is not an APK is refused', () {
      expect(
        () => ApkPackage.parse(
          'app.apks',
          zip({
            'splits/base.apk': [1, 2, 3, 4, 5],
          }),
        ),
        throwsFormatException,
      );
    });

    test('hostile entry paths are never used as install paths', () {
      final pkg = ApkPackage.parse(
        'app.xapk',
        zip({'../../evil.apk': apkBytes(5)}),
      );
      expect(pkg.parts.single.name, 'evil.apk');
    });
  });

  group('progress text', () {
    test('shows percent, elapsed and ETA once enough progress exists', () {
      expect(
        progressLine(.5, const Duration(seconds: 60)),
        '50% · 1:00 elapsed · ~1:00 left',
      );
      expect(
        progressLine(.02, const Duration(seconds: 5)),
        '2% · 0:05 elapsed',
      );
      expect(
        progressLine(1, const Duration(seconds: 90)),
        '100% · 1:30 elapsed',
      );
      expect(formatDuration(const Duration(seconds: 125)), '2:05');
    });
  });

  group('head-unit commands', () {
    test('multi-part upload and install use indexed temp files only', () {
      expect(HeadUnitCommands.uploadApkPath(0), HeadUnitCommands.apkPath);
      expect(
        HeadUnitCommands.uploadApkPath(2),
        '/data/local/tmp/openola_upload_2.apk',
      );
      expect(HeadUnitCommands.installCreate, 'pm install-create -r');
      expect(
        HeadUnitCommands.parseSessionId(
          'Success: created install session [987]',
        ),
        987,
      );
      expect(
        () => HeadUnitCommands.parseSessionId('Error'),
        throwsFormatException,
      );
      expect(
        HeadUnitCommands.installWrite(987, 1, 1234),
        'pm install-write -S 1234 987 split_1.apk /data/local/tmp/openola_upload_1.apk',
      );
      expect(
        HeadUnitCommands.installWrite(987, 0, 99),
        startsWith('pm install-write -S 99 987 base.apk '),
      );
      expect(HeadUnitCommands.installCommit(987), 'pm install-commit 987');
      expect(
        HeadUnitCommands.appendApkChunk([1, 2], index: 1),
        contains('/data/local/tmp/openola_upload_1.b64'),
      );
      expect(HeadUnitCommands.clearApkUploads(2), startsWith('rm -f '));
    });

    test('pull commands validate package names and paths', () {
      expect(
        HeadUnitCommands.packagePaths('com.olaelectric.hmiclient'),
        'pm path com.olaelectric.hmiclient',
      );
      expect(
        () => HeadUnitCommands.packagePaths('x; rm -rf /'),
        throwsFormatException,
      );
      expect(
        () => HeadUnitCommands.fileSize('/data/app/../etc/passwd'),
        throwsFormatException,
      );
      expect(
        () => HeadUnitCommands.fileHash('/data/app/a b.apk'),
        throwsFormatException,
      );
      expect(
        HeadUnitCommands.readChunk('/data/app/x/base.apk', 100, 50),
        contains('+101'),
      );
    });

    test('pm path output parsing keeps only clean .apk paths', () {
      final paths = HeadUnitCommands.parsePackagePaths('''
package:/data/app/~~abc/com.x-1/base.apk
package:/data/app/~~abc/com.x-1/split_config.arm64_v8a.apk
package:/data/app/x;reboot.apk
warning: something
package:/data/app/~~abc/com.x-1/notes.txt
''');
      expect(paths, [
        '/data/app/~~abc/com.x-1/base.apk',
        '/data/app/~~abc/com.x-1/split_config.arm64_v8a.apk',
      ]);
    });
  });
}
