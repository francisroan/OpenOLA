import 'dart:convert';
import '../protocol/can.dart';
import 'controller.dart';

class DiagnosticReport {
  DiagnosticReport._(this.data);
  final Map<String, dynamic> data;
  factory DiagnosticReport.capture(
    Diagnostics d, {
    bool includeVin = false,
    bool includeActivity = false,
  }) {
    final data = <String, Object?>{
      'schema': 'openola.diagnostic.v1',
      'captured_at': DateTime.now().toUtc().toIso8601String(),
      'demo': d.demo,
      'connection': d.connection.name,
      'telemetry_status': d.freshness,
      'last_can_frame_at': d.lastFrame?.toUtc().toIso8601String(),
      'firmware': d.firmware,
      'vehicle_profile': d.identity.toJson(),
      'model_diagnostics': d.modelDiagnostics,
      'mode': d.mode,
      'identifiers_included': includeVin,
      'identifiers': includeVin ? d.manifest : null,
      'metrics': d.metrics.map(
        (k, v) => MapEntry(k, v != null && v.isFinite ? v : null),
      ),
      'ecu_reads': d.identifierResults.values
          .where(
            (r) => includeVin || r.definition.group != 'Identity & versions',
          )
          .map((r) => r.toJson())
          .toList(),
      'battery_cells': [
        for (final c in d.battery?.cells ?? [])
          {
            'group': c.index,
            'voltage_v': c.volts,
            'ir_mohm': c.ir,
            'capacity_ah': c.ah,
            'estimated_wh': c.estimatedWh,
            'shared_sensor_c': c.temperature,
          },
      ],
      'battery_read_at': d.battery?.time.toUtc().toIso8601String(),
      'controllers': [
        for (final ecu in Ecu.values)
          {
            'ecu': ecu.label,
            'scanned': d.faults.containsKey(ecu),
            'scan_time': null,
            'faults': d.faults[ecu]?.map((f) => f.toJson()).toList() ?? [],
          },
      ],
      'broadcast_faults': d.broadcast.toList(),
      'per_signal_freshness_known': false,
      'deep_sleep_bms_wake_validated': false,
      'activity_log': includeActivity ? d.activity.toList() : null,
    };
    return DiagnosticReport._(
      jsonDecode(jsonEncode(data)) as Map<String, dynamic>,
    );
  }
  String get json => const JsonEncoder.withIndent('  ').convert(data);
  String get text {
    final out = StringBuffer('OpenOLA diagnostic report\n');
    if (data['demo'] == true) out.writeln('DEMO — SIMULATED DATA');
    out.writeln('Snapshot captured: ${data['captured_at']}');
    final profile = data['vehicle_profile'] as Map;
    out.writeln(
      'Detected scooter: ${profile['model']}\nDiagnostic profile: ${profile['profile']}\n${profile['reason']}',
    );
    out.writeln(
      'Capture time is not ECU scan time.\nConnection: ${data['connection']}\nTelemetry: ${data['telemetry_status']}\nFirmware: ${data['firmware']}\nMode: ${data['mode']}',
    );
    out.writeln(
      'Identifiers / VIN: ${data['identifiers_included'] == true ? data['identifiers'] : 'Excluded'}\n\nBATTERY / VEHICLE SNAPSHOT',
    );
    (data['metrics'] as Map).forEach(
      (k, v) => out.writeln('$k: ${v ?? 'Unavailable'}'),
    );
    out.writeln('\nSTORED FAULTS — latest reads in this app session');
    out.writeln('\nBATTERY CELLS — ${data['battery_read_at'] ?? 'Not read'}');
    for (final c in data['battery_cells'] as List) {
      out.writeln(
        'Group ${c['group']}: ${c['voltage_v']} V · ${c['ir_mohm'] ?? 'Unavailable'} mΩ · ${c['capacity_ah'] ?? 'Unavailable'} Ah · estimated ${c['estimated_wh'] ?? 'Unavailable'} Wh',
      );
    }
    out.writeln('\nDECODED ECU READS');
    for (final r in data['ecu_reads'] as List) {
      out.writeln('${r['ecu']} ${r['did']} ${r['title']}: ${r['error'] ?? ''}');
      for (final v in r['values'] as List) {
        out.writeln(
          '  ${v['name']}: ${v['value'] ?? 'Unavailable'} ${v['unit']}',
        );
      }
    }
    for (final c in data['controllers'] as List) {
      out.writeln(
        '${c['ecu']}: ${c['scanned'] ? '${(c['faults'] as List).length} codes' : 'NOT SCANNED'}',
      );
      for (final f in c['faults'] as List) {
        out.writeln(
          '  ${f['code']}: ${f['description']} (status ${f['status']})',
        );
      }
    }
    out.writeln(
      '\nBROADCAST FLAGS\n${(data['broadcast_faults'] as List).join('\n')}',
    );
    out.writeln(
      '\nPer-signal freshness and battery health are not established. Zero codes does not prove repair.\nDeep-sleep BMS wake/reset has NOT been validated by this report.',
    );
    if (data['activity_log'] != null) {
      out.writeln('\nACTIVITY\n${(data['activity_log'] as List).join('\n')}');
    }
    return out.toString();
  }

  String filename(String extension) =>
      'OpenOLA-${data['captured_at'].toString().replaceAll(RegExp('[^0-9]'), '')}.$extension';
}
