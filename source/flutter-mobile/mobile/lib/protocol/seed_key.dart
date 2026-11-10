import 'can.dart';

/// Direct grid ASCII, as used by the working Kotlin/Python implementation.
List<int> gridKey(List<int> seed, List<int> constants) {
  if (seed.length != 8) {
    throw ArgumentError('Grid seed must be eight ASCII bytes');
  }
  final grid = List.generate(4, (i) => [seed[i * 2], seed[i * 2 + 1]]);
  final first = grid[0][0];
  for (var i = 0; i < 3; i++) {
    grid[i][0] = grid[i + 1][0];
  }
  grid[3][0] = first;
  int digit(int c) => c >= 48 && c <= 57
      ? c - 48
      : c >= 65 && c <= 70
      ? c - 55
      : 0;
  final p = List.generate(4, (i) {
    final x = digit(grid[i][0]) + 16 * digit(grid[i][1]);
    final y = (x - constants[i] + 127) % 127;
    return (y * 91 + 202) % 127;
  });
  final a = (p[0] * 7 % 255) ^ 23;
  final b = (p[1] * 5 % 255) ^ 67;
  final c = (p[2] % 255) ^ 8;
  final d = (p[3] * 8 % 255) ^ 45;
  return [a ^ b, b ^ c, c ^ d, d ^ a].expand((v) {
    int ascii(int n) => n >= 10 ? n + 55 : n + 48;
    return [ascii(v % 16), ascii(v ~/ 16 % 16)];
  }).toList();
}

List<int> diagnosticKey(List<int> seed, Ecu ecu, {bool levelOne = true}) {
  if (seed.length != 8) {
    return seed.map((b) => (((b ^ 0x33) + 1) ^ 0x96) & 255).toList();
  }
  final constants = switch (ecu) {
    Ecu.bms => levelOne ? [54, 43, 79, 19] : [77, 13, 53, 47],
    Ecu.vcu => levelOne ? [99, 61, 69, 19] : [30, 43, 5, 62],
    Ecu.mcu => [39, 67, 2, 23],
  };
  return gridKey(seed, constants);
}
