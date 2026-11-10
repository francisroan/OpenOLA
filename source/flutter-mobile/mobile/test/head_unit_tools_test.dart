import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openola/diagnostics/head_unit_tools.dart';

void main() {
  test('restriction state and verified broadcasts are strict', () {
    final state = RestrictionState.parse('1,0\n');
    expect(state.sportEnabled, true);
    expect(state.hyperEnabled, false);
    const uuid = '11111111-2222-3333-4444-555555555555';
    final command = HeadUnitCommands.restrictionBroadcast(
      uuid,
      RestrictionMode.sportAndHyperEnabled,
    );
    expect(command, contains(' -p com.olaelectric.profilemanagerservice '));
    expect(command, contains('--es uuid $uuid'));
    expect(command, endsWith('--es drive_status 2'));
    expect(
      () => HeadUnitCommands.restrictionBroadcast(
        'bad uuid',
        RestrictionMode.sportAndHyperDisabled,
      ),
      throwsFormatException,
    );
  });

  test('passcode health exposes aggregates and never a verifier', () {
    final health = PasscodeHealth.parse('5|5|3\n', 'absent\n');
    expect(health.profileCount, 5);
    expect(health.allVerifiersExpected, true);
    expect(health.minimumRemainingAttempts, 3);
    expect(health.vsmCachePresent, false);
    expect(HeadUnitCommands.passcodeHealth, isNot(contains('select passcode')));
    expect(HeadUnitCommands.passcodeHealth, isNot(contains('uda_uuid')));
  });

  test('APK upload commands stay in the fixed temporary path', () {
    final append = HeadUnitCommands.appendApkChunk([0, 1, 2, 255]);
    expect(append, contains('AAEC/w=='));
    expect(append, contains('/data/local/tmp/openola_upload.b64'));
    expect(HeadUnitCommands.decodeApk, contains(HeadUnitCommands.apkPath));
    expect(
      HeadUnitCommands.installApk,
      'pm install -r /data/local/tmp/openola_upload.apk',
    );
  });

  test('launchable apps ignore command noise and receive stable labels', () {
    final apps = HeadUnitCommands.parseLaunchableApps('''
priority=0 preferredOrder=0 match=0x108000 specificIndex=-1 isDefault=true
com.olaelectric.hmiclient/.MainActivity
com.example.utility/com.example.utility.StartActivity
com.ola.mfgapp/.MainActivity
com.example.utility/com.example.utility.StartActivity
No activities found
''');

    expect(apps.map((app) => app.packageName), [
      'com.olaelectric.hmiclient',
      'com.ola.mfgapp',
      'com.example.utility',
    ]);
    expect(apps[0].label, 'OLA HMI');
    expect(apps[1].label, 'Diagnostic Mode');
    expect(apps[2].label, 'utility');
    expect(
      HeadUnitCommands.launchComponent(apps.first.component),
      'am start -n com.olaelectric.hmiclient/.MainActivity',
    );
  });

  test('app launch components cannot inject shell arguments', () {
    expect(
      () => HeadUnitCommands.launchComponent(
        'com.olaelectric.hmiclient/.MainActivity;reboot',
      ),
      throwsFormatException,
    );
    expect(
      HeadUnitCommands.listLaunchableApps,
      contains('android.intent.category.LAUNCHER'),
    );
    expect(
      HeadUnitCommands.olaHmiComponent,
      'com.olaelectric.hmiclient/.MainActivity',
    );
  });

  test('ADB authorization accepts only an encoded Android public key', () {
    final bytes = List<int>.filled(524, 0)..[0] = 64;
    final token = base64Encode(bytes);
    final install = HeadUnitCommands.provisionAdbKey(token);
    expect(install, contains('/data/misc/adb/adb_keys'));
    expect(install, contains('OpenOLA@android'));
    expect(install, contains(r'chmod${IFS}640'));
    expect(install, contains(r'chown${IFS}system:shell'));
    expect(install, contains(r'echo${IFS}installed'));
    expect(
      HeadUnitCommands.removeAdbKey(token),
      contains(r'echo${IFS}removed'),
    );
    expect(HeadUnitCommands.restartAdbd, 'setprop ctl.restart adbd');
    expect(
      () => HeadUnitCommands.provisionAdbKey('key;reboot'),
      throwsFormatException,
    );
  });
}
