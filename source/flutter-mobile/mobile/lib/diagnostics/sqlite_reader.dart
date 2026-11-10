import 'dart:convert';
import 'dart:typed_data';

final _quoteChars = RegExp(r'''[`"\[\]']''');

class SqliteFormatException implements Exception {
  const SqliteFormatException(this.message);
  final String message;
  @override
  String toString() => 'SqliteFormatException: $message';
}

/// A tiny read-only SQLite reader for a *copy* of a database file plus its
/// write-ahead log.
///
/// The scooter's head unit has no `sqlite3` binary, so the app copies the
/// profile databases off it and reads them locally. This supports exactly what
/// that needs: the WAL overlay (committed frames only), `sqlite_master`, table
/// b-trees with overflow pages, and record decoding. It never writes anything.
class SqliteSnapshot {
  SqliteSnapshot(List<int> database, [List<int> wal = const []])
    : _db = Uint8List.fromList(database) {
    if (_db.length < 100 ||
        ascii.decode(_db.sublist(0, 15), allowInvalid: true) !=
            'SQLite format 3') {
      throw const SqliteFormatException('Not a SQLite database');
    }
    final header = ByteData.sublistView(_db);
    final raw = header.getUint16(16);
    pageSize = raw == 1 ? 65536 : raw;
    _reserved = _db[20];
    pageCount = header.getUint32(28);
    if (pageCount == 0) pageCount = _db.length ~/ pageSize;
    if (wal.length > 32) _applyWal(Uint8List.fromList(wal));
  }

  final Uint8List _db;
  late final int pageSize;
  late final int _reserved;
  late int pageCount;
  final _walPages = <int, Uint8List>{};

  int get _usable => pageSize - _reserved;

  void _applyWal(Uint8List wal) {
    final w = ByteData.sublistView(wal);
    final magic = w.getUint32(0);
    if (magic != 0x377f0682 && magic != 0x377f0683) return;
    if (w.getUint32(8) != pageSize) return;
    final salt1 = w.getUint32(16), salt2 = w.getUint32(20);
    final frame = 24 + pageSize;
    final pending = <int, Uint8List>{};
    for (var off = 32; off + frame <= wal.length; off += frame) {
      final pageNo = w.getUint32(off);
      final commit = w.getUint32(off + 4);
      if (pageNo == 0 ||
          w.getUint32(off + 8) != salt1 ||
          w.getUint32(off + 12) != salt2) {
        break; // frames of an older WAL generation, or the end of the log
      }
      pending[pageNo] = Uint8List.sublistView(wal, off + 24, off + frame);
      if (commit != 0) {
        // Only frames up to a commit record are part of the database.
        _walPages.addAll(pending);
        pending.clear();
        pageCount = commit;
      }
    }
  }

  Uint8List _page(int number) {
    final fromWal = _walPages[number];
    if (fromWal != null) return fromWal;
    final start = (number - 1) * pageSize;
    if (number < 1 || start + pageSize > _db.length) {
      throw SqliteFormatException('Page $number is outside the database');
    }
    return Uint8List.sublistView(_db, start, start + pageSize);
  }

  // ---- varints and records -----------------------------------------------------
  (int, int) _varint(Uint8List b, int at) {
    var value = 0;
    for (var i = 0; i < 8; i++) {
      final byte = b[at + i];
      value = (value << 7) | (byte & 0x7f);
      if (byte & 0x80 == 0) return (value, i + 1);
    }
    return ((value << 8) | b[at + 8], 9);
  }

  List<Object?> _record(Uint8List p) {
    final (headerSize, n) = _varint(p, 0);
    final types = <int>[];
    var pos = n;
    while (pos < headerSize) {
      final (t, used) = _varint(p, pos);
      types.add(t);
      pos += used;
    }
    final values = <Object?>[];
    var data = headerSize;
    for (final t in types) {
      switch (t) {
        case 0:
          values.add(null);
        case 8:
          values.add(0);
        case 9:
          values.add(1);
        case 1 || 2 || 3 || 4 || 5 || 6:
          final size = const {1: 1, 2: 2, 3: 3, 4: 4, 5: 6, 6: 8}[t]!;
          var v = 0;
          for (var i = 0; i < size; i++) {
            v = (v << 8) | p[data + i];
          }
          if (size < 8 && p[data] & 0x80 != 0) v -= 1 << (8 * size);
          values.add(v);
          data += size;
        case 7:
          values.add(ByteData.sublistView(p, data, data + 8).getFloat64(0));
          data += 8;
        default:
          if (t < 12) throw SqliteFormatException('Bad serial type $t');
          final len = t.isEven ? (t - 12) ~/ 2 : (t - 13) ~/ 2;
          final slice = Uint8List.sublistView(p, data, data + len);
          values.add(
            t.isEven
                ? Uint8List.fromList(slice)
                : utf8.decode(slice, allowMalformed: true),
          );
          data += len;
      }
    }
    return values;
  }

  /// Reads one table-leaf cell: (rowid, record values), following overflow pages.
  (int, List<Object?>) _leafCell(Uint8List page, int at) {
    final (payloadSize, a) = _varint(page, at);
    final (rowid, b) = _varint(page, at + a);
    final start = at + a + b;
    final maxLocal = _usable - 35;
    int local;
    if (payloadSize <= maxLocal) {
      local = payloadSize;
    } else {
      final minLocal = ((_usable - 12) * 32 ~/ 255) - 23;
      final k = minLocal + ((payloadSize - minLocal) % (_usable - 4));
      local = k <= maxLocal ? k : minLocal;
    }
    final payload = BytesBuilder(copy: false)
      ..add(Uint8List.sublistView(page, start, start + local));
    if (payloadSize > local) {
      var next = ByteData.sublistView(page).getUint32(start + local);
      var remaining = payloadSize - local;
      var guard = 0;
      while (next != 0 && remaining > 0 && guard++ < 100000) {
        final overflow = _page(next);
        final take = remaining < _usable - 4 ? remaining : _usable - 4;
        payload.add(Uint8List.sublistView(overflow, 4, 4 + take));
        remaining -= take;
        next = ByteData.sublistView(overflow).getUint32(0);
      }
    }
    return (rowid, _record(payload.takeBytes()));
  }

  List<(int, List<Object?>)> _tableCells(int root) {
    final out = <(int, List<Object?>)>[];
    final seen = <int>{};
    void walk(int number) {
      if (!seen.add(number)) return; // corrupt cycle guard
      final p = _page(number);
      final base = number == 1 ? 100 : 0;
      final type = p[base];
      final count = (p[base + 3] << 8) | p[base + 4];
      final view = ByteData.sublistView(p);
      if (type == 0x0d) {
        for (var i = 0; i < count; i++) {
          out.add(_leafCell(p, view.getUint16(base + 8 + 2 * i)));
        }
      } else if (type == 0x05) {
        for (var i = 0; i < count; i++) {
          walk(view.getUint32(view.getUint16(base + 12 + 2 * i)));
        }
        walk(view.getUint32(base + 8));
      } else {
        throw SqliteFormatException('Unsupported b-tree page type $type');
      }
    }

    walk(root);
    return out;
  }

  // ---- schema ----------------------------------------------------------------------
  List<({String name, int root, String sql})>? _tables;

  List<({String name, int root, String sql})> get tables => _tables ??= [
    for (final (_, v) in _tableCells(1))
      if (v.length >= 5 && v[0] == 'table')
        (name: v[1] as String, root: v[3] as int, sql: (v[4] ?? '') as String),
  ];

  bool hasTable(String name) => tables.any((t) => t.name == name);

  /// Column names in order, and the index of an `INTEGER PRIMARY KEY` rowid
  /// alias (its stored value is NULL; the real value is the rowid).
  (List<String>, int?) _schema(String sql) {
    final open = sql.indexOf('('), close = sql.lastIndexOf(')');
    if (open < 0 || close <= open) return (const [], null);
    final parts = <String>[];
    var depth = 0, last = open + 1;
    for (var i = open + 1; i < close; i++) {
      final c = sql[i];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (c == ',' && depth == 0) {
        parts.add(sql.substring(last, i));
        last = i + 1;
      }
    }
    parts.add(sql.substring(last, close));
    final names = <String>[];
    final definitions = <String, String>{};
    String? tablePrimaryKey;
    int? alias;
    for (final raw in parts) {
      final part = raw.trim();
      final upper = part.toUpperCase();
      final table = RegExp(
        r'^PRIMARY\s+KEY\s*\(([^,)]+)\)',
        caseSensitive: false,
      ).firstMatch(part);
      if (table != null) {
        // A single-column table-level key on an INTEGER column is the rowid.
        tablePrimaryKey = table.group(1)!.trim().replaceAll(_quoteChars, '');
        continue;
      }
      if (RegExp(
        r'^(PRIMARY|UNIQUE|FOREIGN|CHECK|CONSTRAINT)',
      ).hasMatch(upper)) {
        continue;
      }
      final tokens = part.split(RegExp(r'\s+'));
      final name = tokens.first.replaceAll(_quoteChars, '');
      definitions[name] = upper;
      if (upper.contains('INTEGER') && upper.contains('PRIMARY KEY')) {
        alias = names.length;
      }
      names.add(name);
    }
    if (alias == null && tablePrimaryKey != null) {
      final definition = definitions[tablePrimaryKey] ?? '';
      final type = definition.split(RegExp(r'\s+')).skip(1).firstOrNull;
      if (type == 'INTEGER') alias = names.indexOf(tablePrimaryKey);
    }
    return (names, alias);
  }

  /// All rows of [table] as column-name maps; null when the table is absent.
  List<Map<String, Object?>>? rows(String table) {
    final match = tables.where((t) => t.name == table);
    if (match.isEmpty) return null;
    final (columns, alias) = _schema(match.first.sql);
    return [
      for (final (rowid, values) in _tableCells(match.first.root))
        {
          for (var i = 0; i < columns.length; i++)
            columns[i]: i == alias && (i >= values.length || values[i] == null)
                ? rowid
                : (i < values.length ? values[i] : null),
        },
    ];
  }
}
