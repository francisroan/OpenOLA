import 'dart:convert';

enum HeadUnitTransport { grpc, adb }

class HeadUnitApp {
  const HeadUnitApp({
    required this.label,
    required this.packageName,
    required this.component,
  });

  final String label;
  final String packageName;
  final String component;
}

enum RestrictionMode {
  sportAndHyperDisabled(0, false, false, 146),
  sportOnly(1, true, false, 147),
  sportAndHyperEnabled(2, true, true, 148);

  const RestrictionMode(
    this.driveStatus,
    this.sportEnabled,
    this.hyperEnabled,
    this.responseCode,
  );
  final int driveStatus;
  final bool sportEnabled;
  final bool hyperEnabled;
  final int responseCode;
}

class RestrictionState {
  const RestrictionState({
    required this.sportEnabled,
    required this.hyperEnabled,
  });
  final bool sportEnabled;
  final bool hyperEnabled;

  static RestrictionState parse(String output) {
    final match = RegExp(
      r'(^|\n)([01]),([01])($|\n)',
    ).firstMatch(output.trim());
    if (match == null) {
      throw const FormatException('Restriction flags were not returned');
    }
    return RestrictionState(
      sportEnabled: match.group(2) == '1',
      hyperEnabled: match.group(3) == '1',
    );
  }
}

class PasscodeHealth {
  const PasscodeHealth({
    required this.profileCount,
    required this.scryptVerifierCount,
    required this.minimumRemainingAttempts,
    required this.vsmCachePresent,
  });
  final int profileCount;
  final int scryptVerifierCount;
  final int minimumRemainingAttempts;
  final bool vsmCachePresent;
  bool get allVerifiersExpected =>
      profileCount > 0 && profileCount == scryptVerifierCount;

  /// Aggregates computed from the `user_profile` rows of a database copy. Only
  /// counts are kept: PINs, hashes and identifiers never leave this function.
  static PasscodeHealth fromRows(
    List<Map<String, Object?>> rows,
    bool vsmCachePresent,
  ) {
    var scrypt = 0;
    int? lowest;
    for (final row in rows) {
      final passcode = row['passcode'];
      if (passcode is String &&
          passcode.startsWith(r'$s0$') &&
          passcode.length == 79) {
        scrypt++;
      }
      final attempts = row['remaining_attempts'];
      if (attempts is int && (lowest == null || attempts < lowest)) {
        lowest = attempts;
      }
    }
    return PasscodeHealth(
      profileCount: rows.length,
      scryptVerifierCount: scrypt,
      minimumRemainingAttempts: lowest ?? 0,
      vsmCachePresent: vsmCachePresent,
    );
  }

  static PasscodeHealth parse(String databaseOutput, String cacheOutput) {
    final line = databaseOutput
        .trim()
        .split('\n')
        .map((value) => value.trim())
        .firstWhere(
          (value) => RegExp(r'^\d+\|\d+\|\d+$').hasMatch(value),
          orElse: () => throw FormatException(
            databaseOutput.trim().isEmpty
                ? 'empty reply'
                : databaseOutput.trim().split('\n').first,
          ),
        );
    final fields = line.split('|').map(int.parse).toList(growable: false);
    return PasscodeHealth(
      profileCount: fields[0],
      scryptVerifierCount: fields[1],
      minimumRemainingAttempts: fields[2],
      vsmCachePresent: cacheOutput.trim() == 'present',
    );
  }
}

class HeadUnitCommands {
  static const profilePackage = 'com.olaelectric.profilemanagerservice';
  static const profileDatabase =
      '/data/data/$profilePackage/databases/profile-manager-database';
  static const restrictionDatabase =
      '/data/data/$profilePackage/databases/profile-manager-database-4';
  static const profilePreferences =
      '/data/data/$profilePackage/shared_prefs/$profilePackage.xml';
  static const vehicleStatePreferences =
      '/data/data/com.olaelectric.vehiclestatemanager/shared_prefs/'
      'com.olaelectric.vehiclestatemanager.xml';
  static const restrictionAction =
      '$profilePackage.broadcast.update_drive_mode_restriction_broadcast';
  static const apkBase64Path = '/data/local/tmp/openola_upload.b64';
  static const apkPath = '/data/local/tmp/openola_upload.apk';
  static const olaHmiComponent = 'com.olaelectric.hmiclient/.MainActivity';

  /// Android 10's package shell prints one launchable component per line. The
  /// IFS form keeps the complete `sh -c` script in the single argv slot that
  /// diagnostics_server expects.
  static const listLaunchableApps =
      r'''sh -c cmd${IFS}package${IFS}query-activities${IFS}--brief${IFS}-a${IFS}android.intent.action.MAIN${IFS}-c${IFS}android.intent.category.LAUNCHER''';

  static final _uuid = RegExp(r'^[A-Za-z0-9_-]{8,80}$');
  static final _base64 = RegExp(r'^[A-Za-z0-9+/]*={0,2}$');
  static final _adbPublicKey = RegExp(r'^[A-Za-z0-9+/]+={0,2}$');
  static final _component = RegExp(r'^[A-Za-z0-9_.]+/[A-Za-z0-9_.$]+$');

  static const _knownLabels = <String, String>{
    'com.olaelectric.hmiclient': 'OLA HMI',
    // The app the head unit itself labels "Diagnostic Mode" is the
    // manufacturing app (HMFG): it hosts the LCD/GPS/BT/speaker/mic tests.
    'com.ola.mfgapp': 'Diagnostic Mode',
    'com.olaelectric.udstestapp': 'UDS test tool',
  };

  static const _knownOrder = <String, int>{
    'com.olaelectric.hmiclient': 0,
    'com.ola.mfgapp': 1,
    'com.olaelectric.udstestapp': 2,
  };

  static List<HeadUnitApp> parseLaunchableApps(String output) {
    final components = <String>{};
    for (final rawLine in const LineSplitter().convert(output)) {
      final line = rawLine.trim();
      if (_component.hasMatch(line)) components.add(line);
    }
    final apps = components.map((component) {
      final packageName = component.substring(0, component.indexOf('/'));
      return HeadUnitApp(
        label: _knownLabels[packageName] ?? packageName.split('.').last,
        packageName: packageName,
        component: component,
      );
    }).toList();
    apps.sort((a, b) {
      final rank = (_knownOrder[a.packageName] ?? 100).compareTo(
        _knownOrder[b.packageName] ?? 100,
      );
      return rank != 0
          ? rank
          : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return List.unmodifiable(apps);
  }

  static String launchComponent(String component) {
    if (!_component.hasMatch(component)) {
      throw const FormatException('Invalid Android activity component');
    }
    return 'am start -n $component';
  }

  static const currentProfileUuid =
      r'''sh -c sed${IFS}-n${IFS}'s/.*name="com.olaelectric.profilemanagerservice.UDA_UUID_CURRENT"[^>]*>\([^<]*\)<.*/\1/p'${IFS}/data/data/com.olaelectric.profilemanagerservice/shared_prefs/com.olaelectric.profilemanagerservice.xml''';

  static String parseUuid(String output) {
    final value = output.trim();
    if (!_uuid.hasMatch(value)) {
      throw const FormatException('Current profile UUID is unavailable');
    }
    return value;
  }

  static String restrictionRead(String uuid, {String? database}) {
    _requireUuid(uuid);
    final db = database ?? restrictionDatabase;
    if (!isRemotePath(db)) throw const FormatException('Invalid database path');
    return '''sh -c sqlite3\${IFS}$db\${IFS}"select\${IFS}sports_mode_enabled||','||hyper_mode_enabled\${IFS}from\${IFS}drive_mode_restriction\${IFS}where\${IFS}udaUuid='$uuid';"''';
  }

  static String restrictionBroadcast(String uuid, RestrictionMode mode) {
    _requireUuid(uuid);
    return 'am broadcast -a $restrictionAction -p $profilePackage '
        '--es uuid $uuid --es drive_status ${mode.driveStatus}';
  }

  static const passcodeHealth =
      r'''sh -c sqlite3${IFS}/data/data/com.olaelectric.profilemanagerservice/databases/profile-manager-database${IFS}"select${IFS}count(*),sum(substr(passcode,1,4)=char(36)||'s0'||char(36)${IFS}and${IFS}length(passcode)=79),min(remaining_attempts)${IFS}from${IFS}user_profile;"''';

  static String passcodeHealthFrom(String database) {
    if (!isRemotePath(database)) {
      throw const FormatException('Invalid database path');
    }
    return passcodeHealth.replaceFirst(profileDatabase, database);
  }

  static const vsmProfileCache =
      r'''sh -c grep${IFS}-q${IFS}'name="com.olaelectric.vehiclestatemanager.PROFILE"'${IFS}/data/data/com.olaelectric.vehiclestatemanager/shared_prefs/com.olaelectric.vehiclestatemanager.xml&&echo${IFS}present||echo${IFS}absent''';

  /// Upload paths. Index 0 keeps the original single-APK names so existing
  /// behaviour is unchanged; further splits use `_N` suffixes.
  static String uploadBase64Path(int index) =>
      index == 0 ? apkBase64Path : '/data/local/tmp/openola_upload_$index.b64';
  static String uploadApkPath(int index) =>
      index == 0 ? apkPath : '/data/local/tmp/openola_upload_$index.apk';

  static const clearApkUpload = 'rm -f $apkBase64Path $apkPath';

  // ---- parallel upload: each chunk is its own numbered file, written with
  // several calls in flight; one decode step joins them in order (the 5-digit
  // zero-padded names make the shell glob sort correctly).
  static const partDir = '/data/local/tmp/ola_p';
  static const preparePartDir = 'mkdir -p $partDir';
  static const removePartDir = 'rm -rf $partDir';

  static String writeApkPart(int file, int chunk, List<int> bytes) {
    final b64 = base64Encode(bytes);
    if (!_base64.hasMatch(b64) || file < 0 || chunk < 0 || chunk > 99999) {
      throw const FormatException('Invalid upload chunk');
    }
    final name = '$partDir/${file}_${chunk.toString().padLeft(5, '0')}';
    return "sh -c echo\${IFS}'$b64'|tee\${IFS}$name|wc\${IFS}-c";
  }

  static String clearParts(int file) =>
      'sh -c rm\${IFS}-f\${IFS}$partDir/${file}_*';

  static String decodeParts(int file) =>
      'sh -c cat\${IFS}$partDir/${file}_*|base64\${IFS}-d|tee\${IFS}${uploadApkPath(file)}|wc\${IFS}-c';

  static String clearApkUploads(int count) =>
      'rm -f ${[for (var i = 0; i < count; i++) '${uploadBase64Path(i)} ${uploadApkPath(i)}'].join(' ')}';

  static String appendApkChunk(List<int> bytes, {int index = 0}) {
    final chunk = base64Encode(bytes);
    if (!_base64.hasMatch(chunk)) {
      throw const FormatException('Invalid base64 upload chunk');
    }
    return r'''sh -c echo${IFS}'''
        "'$chunk'"
        '|tee\${IFS}-a\${IFS}${uploadBase64Path(index)}|wc\${IFS}-c';
  }

  static const decodeApk =
      r'''sh -c base64${IFS}-d${IFS}/data/local/tmp/openola_upload.b64|tee${IFS}/data/local/tmp/openola_upload.apk|wc${IFS}-c''';
  static String decodeApkAt(int index) =>
      'sh -c base64\${IFS}-d\${IFS}${uploadBase64Path(index)}|tee\${IFS}${uploadApkPath(index)}|wc\${IFS}-c';
  static const hashApk = 'sha256sum $apkPath';
  static String hashApkAt(int index) => 'sha256sum ${uploadApkPath(index)}';
  static const installApk = 'pm install -r $apkPath';

  // `pm` has no install-multiple (that is an adb *client* feature); a split
  // install is a session: install-create, one install-write per file, commit.
  static const installCreate = 'pm install-create -r';

  /// The session id printed by `pm install-create` ("... created install session [123]").
  static int parseSessionId(String output) {
    final match = RegExp(r'\[(\d+)\]').firstMatch(output);
    if (match == null) {
      throw FormatException(
        'Package manager did not open a session: ${output.trim()}',
      );
    }
    return int.parse(match.group(1)!);
  }

  static String installWrite(int session, int index, int size) {
    if (session < 0 || index < 0 || size <= 0) {
      throw const FormatException('Invalid install-write arguments');
    }
    final name = index == 0 ? 'base.apk' : 'split_$index.apk';
    return 'pm install-write -S $size $session $name ${uploadApkPath(index)}';
  }

  static String installCommit(int session) => 'pm install-commit $session';
  static String installAbandon(int session) => 'pm install-abandon $session';

  // ---- APK pull (read-only) -------------------------------------------
  static final _packageName = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$',
  );
  static final _remotePath = RegExp(r'^/[A-Za-z0-9._@=+~/-]+$');

  static bool isPackageName(String value) => _packageName.hasMatch(value);
  static bool isRemotePath(String value) =>
      _remotePath.hasMatch(value) && !value.contains('..');

  static String packagePaths(String package) {
    if (!isPackageName(package)) {
      throw const FormatException('Invalid package name');
    }
    return 'pm path $package';
  }

  /// `pm path` prints one `package:/data/app/.../base.apk` line per APK
  /// (base plus every split). Anything that is not a clean absolute path ending
  /// in .apk is dropped.
  static List<String> parsePackagePaths(String output) => [
    for (final line in output.split('\n'))
      if (line.trim().startsWith('package:'))
        if (isRemotePath(line.trim().substring(8)) &&
            line.trim().endsWith('.apk'))
          line.trim().substring(8),
  ];

  static String fileSize(String path) {
    if (!isRemotePath(path)) throw const FormatException('Invalid path');
    return 'stat -c %s $path';
  }

  static String fileHash(String path) {
    if (!isRemotePath(path)) throw const FormatException('Invalid path');
    return 'sha256sum $path';
  }

  /// Reads [count] bytes from [offset] as base64 through the one-shot shell.
  static String readChunk(String path, int offset, int count) {
    if (!isRemotePath(path)) throw const FormatException('Invalid path');
    if (offset < 0 || count <= 0) throw const FormatException('Invalid range');
    return 'sh -c tail\${IFS}-c\${IFS}+${offset + 1}\${IFS}$path|head\${IFS}-c\${IFS}$count|base64';
  }

  static const listProfileDatabases = 'ls /data/data/$profilePackage/databases';

  /// Candidate profile databases from an `ls`, base databases only (no -wal,
  /// -shm, -journal), the known one first.
  static List<String> parseProfileDatabases(String output) {
    final names = <String>{
      for (final line in output.split('\n'))
        if (RegExp(
              r'^profile-manager-database[A-Za-z0-9._-]*$',
            ).hasMatch(line.trim()) &&
            !RegExp(r'-(wal|shm|journal)$').hasMatch(line.trim()))
          line.trim(),
    };
    final paths = [
      for (final n in names) '/data/data/$profilePackage/databases/$n',
    ];
    paths.sort((a, b) {
      int rank(String p) => p == restrictionDatabase ? 0 : 1;
      return rank(a).compareTo(rank(b));
    });
    return paths;
  }

  static String uninstallPackage(String package) {
    if (!isPackageName(package)) {
      throw const FormatException('Invalid package name');
    }
    return 'pm uninstall $package';
  }

  /// Only apps installed under /data/app can be uninstalled from the app; a
  /// package with any APK on the read-only system partitions is refused.
  static bool isUserInstalled(List<String> apkPaths) =>
      apkPaths.isNotEmpty && apkPaths.every((p) => p.startsWith('/data/app/'));

  static const restartAdbd = 'setprop ctl.restart adbd';

  static String provisionAdbKey(String token) {
    _requireAdbPublicKey(token);
    return r'''sh -c key='''
        "'$token'"
        r'''$(printf${IFS}'\040')OpenOLA@android;file=/data/misc/adb/adb_keys;mkdir${IFS}-p${IFS}/data/misc/adb;touch${IFS}"$file";grep${IFS}-qxF${IFS}"$key"${IFS}"$file"||printf${IFS}'%s\n'${IFS}"$key"|tee${IFS}-a${IFS}"$file";chown${IFS}system:shell${IFS}"$file";chmod${IFS}640${IFS}"$file";restorecon${IFS}"$file";grep${IFS}-qxF${IFS}"$key"${IFS}"$file"&&echo${IFS}installed''';
  }

  static String removeAdbKey(String token) {
    _requireAdbPublicKey(token);
    return r'''sh -c key='''
        "'$token'"
        r'''$(printf${IFS}'\040')OpenOLA@android;file=/data/misc/adb/adb_keys;tmp=/data/misc/adb/adb_keys.openola.tmp;touch${IFS}"$file";grep${IFS}-vxF${IFS}"$key"${IFS}"$file"|tee${IFS}"$tmp";cat${IFS}"$tmp"|tee${IFS}"$file";rm${IFS}-f${IFS}"$tmp";chown${IFS}system:shell${IFS}"$file";chmod${IFS}640${IFS}"$file";restorecon${IFS}"$file";grep${IFS}-qxF${IFS}"$key"${IFS}"$file"||echo${IFS}removed''';
  }

  static void _requireUuid(String uuid) {
    if (!_uuid.hasMatch(uuid)) {
      throw const FormatException('Invalid profile UUID');
    }
  }

  static void _requireAdbPublicKey(String token) {
    if (!_adbPublicKey.hasMatch(token)) {
      throw const FormatException('Invalid Android ADB public key');
    }
    try {
      final decoded = base64Decode(token);
      if (decoded.length != 524 ||
          decoded[0] != 64 ||
          decoded[1] != 0 ||
          decoded[2] != 0 ||
          decoded[3] != 0) {
        throw const FormatException('Invalid Android ADB public key');
      }
    } on FormatException {
      throw const FormatException('Invalid Android ADB public key');
    }
  }
}
