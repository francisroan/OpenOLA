import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openola/diagnostics/head_unit_tools.dart';
import 'package:openola/diagnostics/sqlite_reader.dart';

// Synthetic fixtures (no real data): a main file with 400 profile rows, one of
// them 6000 bytes of text (overflow pages), and a WAL holding newer commits.
List<int> fixture(String name) => File('test/fixtures/$name').readAsBytesSync();

void main() {
  const uuid = '11111111-2222-3333-4444-555555555555';

  test('reads tables and rows from the main file alone', () {
    final db = SqliteSnapshot(fixture('sample.db'));
    expect(db.hasTable('drive_mode_restriction'), isTrue);
    expect(db.hasTable('user_profile'), isTrue);
    expect(db.hasTable('nope'), isFalse);
    final restriction = db.rows('drive_mode_restriction')!.single;
    expect(restriction['udaUuid'], uuid);
    expect(restriction['sports_mode_enabled'], 1);
    expect(restriction['hyper_mode_enabled'], 1);
    final profiles = db.rows('user_profile')!;
    expect(profiles, hasLength(400)); // multi-level b-tree
  });

  test('overlays committed WAL frames on top of the main file', () {
    final db = SqliteSnapshot(fixture('sample.db'), fixture('sample.db-wal'));
    final restriction = db.rows('drive_mode_restriction')!.single;
    expect(
      restriction['sports_mode_enabled'],
      0,
      reason: 'changed only in WAL',
    );
    expect(restriction['hyper_mode_enabled'], 0);
    final profiles = db.rows('user_profile')!;
    expect(profiles, hasLength(401));
    expect(profiles.last['passcode'], 'late-row');
  });

  test('follows overflow pages for long values', () {
    final db = SqliteSnapshot(fixture('sample.db'), fixture('sample.db-wal'));
    final long = db
        .rows('user_profile')!
        .firstWhere((r) => r['user_id'] == 399);
    expect((long['notes'] as String).length, 6000);
    expect((long['notes'] as String).replaceAll('x', ''), isEmpty);
  });

  test('uses the INTEGER PRIMARY KEY as the rowid alias', () {
    final db = SqliteSnapshot(fixture('sample.db'));
    final ids = db.rows('user_profile')!.map((r) => r['user_id']).toList();
    expect(ids.first, 0);
    expect(ids[10], 10);
    expect(ids.toSet(), hasLength(400));
  });

  test('ignores a truncated or foreign WAL instead of crashing', () {
    final base = fixture('sample.db');
    expect(
      SqliteSnapshot(base, [1, 2, 3, 4, 5]).rows('drive_mode_restriction'),
      isNotNull,
    );
    final wal = fixture(
      'sample.db-wal',
    ).sublist(0, 40); // header + partial frame
    expect(
      SqliteSnapshot(
        base,
        wal,
      ).rows('drive_mode_restriction')!.single['sports_mode_enabled'],
      1,
    );
  });

  test('rejects non-SQLite input', () {
    expect(
      () => SqliteSnapshot([1, 2, 3]),
      throwsA(isA<SqliteFormatException>()),
    );
    expect(
      () => SqliteSnapshot(List.filled(200, 0)),
      throwsA(isA<SqliteFormatException>()),
    );
  });

  test('passcode health is computed from rows and keeps no secrets', () {
    final rows = SqliteSnapshot(
      fixture('sample.db'),
      fixture('sample.db-wal'),
    ).rows('user_profile')!;
    final health = PasscodeHealth.fromRows(rows, true);
    expect(health.profileCount, 401);
    // 300 of the first 400 use the 79-character scrypt format.
    expect(health.scryptVerifierCount, 300);
    expect(health.minimumRemainingAttempts, 1);
    expect(health.vsmCachePresent, isTrue);
    expect(health.allVerifiersExpected, isFalse);
  });
}
