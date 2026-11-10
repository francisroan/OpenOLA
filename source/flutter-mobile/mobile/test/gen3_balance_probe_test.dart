import 'package:flutter_test/flutter_test.dart';
import 'package:openola/diagnostics/gen3_balance_probe.dart';

void main() {
  test('records an exact Gen3 balancing acknowledgement without claiming action', () {
    final result = Gen3BalanceProbe.describeResponse([0x71, 0x01, 0x05, 0xf8, 0x01]);
    expect(result, contains('acknowledged; routine result 0x01'));
    expect(result, isNot(contains('started')));
  });

  test('preserves the BMS rejection code', () {
    expect(
      Gen3BalanceProbe.describeResponse([0x7f, 0x31, 0x33]),
      contains('rejected; NRC 0x33'),
    );
  });

  test('does not accept a different routine acknowledgement', () {
    expect(
      Gen3BalanceProbe.describeResponse([0x71, 0x01, 0x05, 0xf7, 0x01]),
      contains('unexpected response'),
    );
  });
}
