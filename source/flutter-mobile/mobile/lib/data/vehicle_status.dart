class VehicleNotification {
  const VehicleNotification(this.code, this.name, this.time);
  final int code;
  final String name;
  final DateTime time;
  bool get alert => RegExp(
    r'DERATE|DISABLED|FAULT|FAIL|ERROR|THERMAL|REVOKED|CUTOFF|MISMATCH|CANT_|CANNOT|_NA\b|UPGRADE_FOR',
  ).hasMatch(name);
}

/// Desktop's reconstructed 0x660 map; ? labels retain source uncertainty.
Map<String, int?> featureStatus(List<int>? data) {
  const flags = [
    ('Boost mode', 0, 0),
    ('Fall detection', 0, 1),
    ('Tow/tamper detect', 0, 2),
    ('Proximity lock', 0, 3),
    ('Hill hold', 0, 4),
    ('Smart headlight', 0, 5),
    ('Smart DRL', 0, 6),
    ('Auto headlight', 0, 7),
    ('Hazard light', 1, 0),
    ('Auto-indicator off', 1, 1),
    ('Motor cutoff delay?', 1, 2),
    ('Vacation mode', 1, 3),
  ];
  const packs = [
    ('Advanced regen (TP)', 1, 4),
    ('Fast charger (TP)', 1, 6),
    ('Hyper charger (TP)', 2, 0),
    ('Energy insights (TP)', 2, 2),
    ('Proximity L/U (TP)', 2, 4),
    ('Geo-fencing (TP)', 2, 6),
    ('Time-fencing (TP)', 3, 0),
    ('Mode-fencing (TP)', 3, 2),
    ('New upgrades (TP)', 3, 4),
    ('Hill-hold (TP)?', 3, 6),
    ('Early-beta (TP)?', 4, 0),
    ('Tow protection (TP)', 4, 2),
    ('Smart park (TP)', 4, 4),
  ];
  return {
    for (final (name, byte, bit) in flags)
      name: data == null || data.length <= byte
          ? null
          : (data[byte] >> bit) & 1,
    for (final (name, byte, bit) in packs)
      name: data == null || data.length <= byte
          ? null
          : (data[byte] >> bit) & 3,
  };
}
