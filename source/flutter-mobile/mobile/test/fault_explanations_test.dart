import 'package:flutter_test/flutter_test.dart';
import 'package:openola/data/catalog.dart';
import 'package:openola/diagnostics/fault_explanations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled guide source contains every catalogued stored DTC', () async {
    final catalog = await Catalog.load();
    expect(catalog.dtcs.values.fold<int>(0, (n, rows) => n + rows.length), 201);
    expect(catalog.faultFrames, isNotEmpty);
  });

  test('known pack code uses curated offline guidance', () {
    final result = explainFault(
      code: 'P0A80',
      description: 'Battery pack performance',
      source: 'BMS',
    );
    expect(result.subsystem, 'High-voltage battery');
    expect(result.inferred, isFalse);
    expect(result.severity, FaultSeverity.attention);
  });

  test('safety and accessory faults receive different severity', () {
    expect(
      explainFault(
        code: 'X',
        description: 'HV isolation leakage fault',
      ).severity,
      FaultSeverity.stopSafely,
    );
    expect(
      explainFault(code: '920711', description: 'Head lamp low Short').severity,
      FaultSeverity.attention,
    );
  });

  test('unknown catalog entries still receive non-diagnostic guidance', () {
    final result = explainFault(
      code: 'ABC123',
      description: 'Unclassified controller condition',
      source: 'VCU',
    );
    expect(result.meaning, contains('does not define'));
    expect(result.nextStep, isNotEmpty);
    expect(result.inferred, isTrue);
  });
}
