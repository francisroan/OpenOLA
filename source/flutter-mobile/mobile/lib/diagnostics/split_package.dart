import 'package:archive/archive.dart';

/// One installable APK inside a package (a base APK or a split).
class ApkPart {
  const ApkPart(this.name, this.bytes);
  final String name;
  final List<int> bytes;
}

/// An installable Android package: a single `.apk`, or the APKs inside a
/// split bundle (`.apks` from bundletool, `.xapk`, `.apkm`).
///
/// Only `*.apk` entries are ever read. OBB/expansion files, manifests, and
/// bundletool metadata are ignored, and nothing is written using names from
/// inside the archive (names are replaced by indexed temp names on install), so
/// a hostile archive cannot choose file paths.
class ApkPackage {
  const ApkPackage(this.name, this.parts, {this.ignoredEntries = 0});

  static const maxParts = 64;
  static const maxTotalBytes = 300 * 1024 * 1024;
  static const extensions = ['.apk', '.apks', '.xapk', '.apkm'];

  final String name;
  final List<ApkPart> parts;
  final int ignoredEntries;

  bool get isSplit => parts.length > 1;
  int get totalBytes => parts.fold(0, (n, p) => n + p.bytes.length);

  static bool supports(String fileName) =>
      extensions.any(fileName.toLowerCase().endsWith);

  static bool _looksLikeZip(List<int> b) =>
      b.length > 4 && b[0] == 0x50 && b[1] == 0x4b;

  /// Parses [bytes] according to the extension of [fileName].
  /// Throws [FormatException] with a user-readable reason when unusable.
  static ApkPackage parse(String fileName, List<int> bytes) {
    final lower = fileName.toLowerCase();
    if (!supports(lower)) {
      throw const FormatException('Choose an .apk, .apks, .xapk or .apkm file');
    }
    if (bytes.isEmpty) throw const FormatException('The file is empty');
    if (!_looksLikeZip(bytes)) {
      throw const FormatException('The file is not a valid Android package');
    }
    if (lower.endsWith('.apk')) {
      return ApkPackage(fileName, [ApkPart(fileName, bytes)]);
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('The bundle could not be read as a zip file');
    }
    final apks = [
      for (final f in archive)
        if (f.isFile && f.name.toLowerCase().endsWith('.apk')) f,
    ];
    final ignored = archive.where((f) => f.isFile).length - apks.length;
    if (apks.isEmpty) {
      throw const FormatException('The bundle contains no APK files');
    }

    String base(ArchiveFile f) => f.name.split('/').last.toLowerCase();
    List<ArchiveFile> chosen;
    final universal = apks.where((f) => base(f) == 'universal.apk').toList();
    final splits = apks
        .where((f) => f.name.toLowerCase().startsWith('splits/'))
        .toList();
    final standalones = apks
        .where((f) => f.name.toLowerCase().startsWith('standalones/'))
        .toList();
    if (universal.isNotEmpty) {
      chosen = [universal.first];
    } else if (splits.isNotEmpty) {
      chosen = splits;
    } else if (standalones.isNotEmpty) {
      if (standalones.length > 1) {
        throw const FormatException(
          'This bundle has several device-specific standalone APKs. Extract '
          'the one for the head unit and install it as a single .apk.',
        );
      }
      chosen = standalones;
    } else {
      // .xapk / .apkm: base + split_config.* at the archive root.
      chosen = apks.where((f) => !f.name.contains('/')).toList();
      if (chosen.isEmpty) chosen = apks;
    }

    if (chosen.length > maxParts) {
      throw const FormatException('The bundle has too many split APKs');
    }
    final parts = <ApkPart>[];
    var total = 0;
    for (final f in chosen) {
      final content = f.content;
      if (!_looksLikeZip(content)) {
        throw FormatException('${f.name} is not a valid APK');
      }
      total += content.length;
      if (total > maxTotalBytes) {
        throw const FormatException('The bundle exceeds the 300 MB limit');
      }
      parts.add(ApkPart(f.name.split('/').last, content));
    }
    // Base APK first: package managers accept any order, but humans read it.
    parts.sort((a, b) {
      int rank(ApkPart p) => p.name.toLowerCase().contains('base') ? 0 : 1;
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.compareTo(b.name);
    });
    return ApkPackage(fileName, parts, ignoredEntries: ignored);
  }
}

/// Elapsed / remaining time text for a progress readout.
String formatDuration(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "42% · 1:12 elapsed · ~1:40 left". The ETA is only shown once there is
/// enough progress to extrapolate from (≥5 %), otherwise it would be noise.
String progressLine(double fraction, Duration elapsed, {bool showEta = true}) {
  final pct = (fraction * 100).clamp(0, 100).round();
  final eta = showEta && fraction >= .05 && fraction < 1
      ? Duration(
          milliseconds: (elapsed.inMilliseconds * (1 - fraction) / fraction)
              .round(),
        )
      : null;
  return '$pct% · ${formatDuration(elapsed)} elapsed'
      '${eta == null ? '' : ' · ~${formatDuration(eta)} left'}';
}
