enum FaultSeverity { information, attention, stopSafely }

class FaultExplanation {
  const FaultExplanation({
    required this.subsystem,
    required this.meaning,
    required this.nextStep,
    required this.severity,
    this.inferred = true,
  });

  final String subsystem;
  final String meaning;
  final String nextStep;
  final FaultSeverity severity;
  final bool inferred;

  String get severityLabel => switch (severity) {
    FaultSeverity.information => 'Information',
    FaultSeverity.attention => 'Needs attention',
    FaultSeverity.stopSafely => 'Stop safely',
  };
}

bool _has(String text, List<String> terms) => terms.any(text.contains);

/// Whole-word match for short terms that would otherwise hit inside other
/// words ("can" in "scan", "stall" in "install", "horn" in "thorn").
bool _word(String text, List<String> words) => words.any(
  (w) =>
      RegExp('(^|[^a-z0-9])${RegExp.escape(w)}([^a-z0-9]|\$)').hasMatch(text),
);

String _controllerName(String source) => switch (source.toUpperCase()) {
  'BMS' => 'Battery management system',
  'MCU' => 'Motor controller',
  'VCU' => 'Vehicle controller',
  '' => 'Vehicle controller',
  _ => source,
};

/// Deterministic, offline explanation for stored DTCs and live fault names.
///
/// It never diagnoses a failed part. Exact curated entries take priority;
/// everything else is classified from the code/description and clearly marked
/// as inferred guidance. This guarantees a useful fallback for every catalogued
/// fault without a network service or a generative model.
FaultExplanation explainFault({
  required String code,
  required String description,
  String source = '',
}) {
  final text = '$code $description $source'
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll('-', ' ');

  if (code.toUpperCase() == 'P0A80') {
    return const FaultExplanation(
      subsystem: 'High-voltage battery',
      meaning:
          'The battery controller detected pack performance or cell-balance behaviour outside its expected range.',
      nextStep:
          'Avoid hard riding or charging unattended. Save a report, compare cell voltages after a full balanced charge, and arrange battery inspection if the code returns.',
      severity: FaultSeverity.attention,
      inferred: false,
    );
  }

  if (_has(text, ['permanent fault', 'permanent failure']) &&
      !_has(text, ['lamp', 'horn', 'speaker', 'microphone'])) {
    return FaultExplanation(
      subsystem: 'Permanent fault · ${_controllerName(source)}',
      meaning:
          'The controller reported a permanent (latched) fault. It will not clear by itself, and the protection it triggered may keep power or charging disabled.',
      nextStep:
          'Do not keep riding or charging. Save a report with the code and have the scooter inspected; a permanent fault normally needs a service reset after the cause is fixed.',
      severity: FaultSeverity.stopSafely,
    );
  }
  if (_has(text, ['brake lamp', 'brake light'])) {
    return const FaultExplanation(
      subsystem: 'Brake light',
      meaning:
          'The brake light circuit appears open, shorted, overloaded or too hot. Riders behind you may not see you braking.',
      nextStep:
          'Check that the brake light comes on when you squeeze each brake, then inspect its connector, wiring and fuse before riding in traffic.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['isolation', 'insulation', 'leakage', 'hv leak'])) {
    return const FaultExplanation(
      subsystem: 'High-voltage safety',
      meaning:
          'The scooter detected possible electrical leakage or reduced insulation between the high-voltage system and chassis.',
      nextStep:
          'Stop riding, switch the scooter off, do not charge it, and have the high-voltage system inspected.',
      severity: FaultSeverity.stopSafely,
    );
  }
  if ((_has(text, [
            'lamp',
            'indicator',
            'speaker',
            'microphone',
            'usb charger',
            'seat lock',
          ]) ||
          _word(text, ['horn'])) &&
      (_has(text, ['overcurrent', 'overtemperature', 'fault', 'error']) ||
          _word(text, ['short', 'open']))) {
    return const FaultExplanation(
      subsystem: 'Lighting or accessory circuit',
      meaning:
          'An exterior light or accessory circuit appears open, shorted, overloaded or too hot.',
      nextStep:
          'Check that the affected lamp or accessory works, then inspect its connector, wiring and fuse. Avoid night riding if required lighting is unavailable.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['cell vent', 'venting'])) {
    return const FaultExplanation(
      subsystem: 'Battery safety',
      meaning:
          'The battery controller reported over-temperature linked to a cell vent event, which can indicate a damaged cell.',
      nextStep:
          'Stop riding, switch off, move the scooter away from combustible material, do not charge it, and have the battery inspected.',
      severity: FaultSeverity.stopSafely,
    );
  }
  if (_has(text, ['cell failure', 'parallel cell'])) {
    return const FaultExplanation(
      subsystem: 'Battery cells',
      meaning:
          'The BMS reported a cell group failure or a broken connection between parallel cells.',
      nextStep:
          'Avoid hard riding and do not charge unattended. Save a report and have the battery pack inspected.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['sensor']) && _has(text, ['failure', 'disconnect', 'fail']) ||
      _has(text, ['current sensor', 'sensor short', 'sensor open'])) {
    return const FaultExplanation(
      subsystem: 'Sensor or wiring',
      meaning:
          'A sensor (or its wiring) reported a failure, disconnection, short or open circuit, so its reading cannot be trusted.',
      nextStep:
          'Check the related connector and wiring. Compare the live reading with nearby sensors before replacing any part.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['voltage out of range']) ||
      RegExp(r'temperature\d* out of range').hasMatch(text)) {
    return const FaultExplanation(
      subsystem: 'Battery limits',
      meaning:
          'A cell voltage or pack temperature reading is outside the range the BMS accepts. This is a measured value, not necessarily a sensor failure.',
      nextStep:
          'Check cell voltages and temperatures in Battery. If they look normal the sensor path may be at fault; if not, avoid hard riding and charging until inspected.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['short circuit', 'short_circuit', 'thermal runaway']) ||
      _word(text, ['fire'])) {
    return const FaultExplanation(
      subsystem: 'Electrical safety',
      meaning:
          'A controller reported a possible short-circuit or severe thermal protection condition.',
      nextStep:
          'Stop safely, switch off, keep the scooter away from combustible material, and seek qualified service. Do not charge it.',
      severity: FaultSeverity.stopSafely,
    );
  }
  if (_has(text, [
    'brake fail',
    'brake error',
    'throttle stuck',
    'throttle fail',
    'throttle wiper',
    'unintended torque',
  ])) {
    return const FaultExplanation(
      subsystem: 'Rider control',
      meaning:
          'A braking or throttle control signal is implausible or unavailable.',
      nextStep:
          'Do not continue riding. Switch off and inspect the control, wiring and related sensor before use.',
      severity: FaultSeverity.stopSafely,
    );
  }
  if (_has(text, ['brake pad wear'])) {
    return const FaultExplanation(
      subsystem: 'Brakes',
      meaning:
          'The scooter reports that a front or rear brake-pad wear threshold has been reached.',
      nextStep:
          'Inspect pad thickness and the wear-sensor wiring before continued riding. Replace worn pads as a matched service item.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, [
    'overtemperature',
    'over temperature',
    'overtemp',
    'high temp',
    'pdu temperature',
  ])) {
    return const FaultExplanation(
      subsystem: 'Thermal protection',
      meaning:
          'A battery, motor, controller or charger temperature exceeded its expected range, so power may be limited.',
      nextStep:
          'Stop in a safe place and let the scooter cool. Do not charge until temperatures normalize; inspect it if the warning returns.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['undertemperature', 'under temperature', 'low temp'])) {
    return const FaultExplanation(
      subsystem: 'Thermal protection',
      meaning:
          'A component is colder than its normal operating range, which can limit charging, power or regeneration.',
      nextStep:
          'Let the scooter warm naturally and retry. Avoid fast charging or hard acceleration until the warning clears.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['overvoltage', 'over voltage', 'overvolt'])) {
    return const FaultExplanation(
      subsystem: 'Voltage protection',
      meaning:
          'A cell, pack or DC bus voltage exceeded the controller’s expected limit.',
      nextStep:
          'Stop hard acceleration or charging. Save a report and inspect pack voltage and cell spread if the condition persists.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, [
    'undervoltage',
    'under voltage',
    'undervolt',
    'low voltage',
  ])) {
    return const FaultExplanation(
      subsystem: 'Voltage protection',
      meaning:
          'A cell, the battery pack or a low-voltage supply fell below its expected range.',
      nextStep:
          'Charge normally if the pack is simply low. If the code returns, compare individual cells and inspect the affected supply.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['overcurrent', 'over current', 'current limit'])) {
    return const FaultExplanation(
      subsystem: 'Current protection',
      meaning:
          'Current demand or measured current exceeded the controller’s protection threshold.',
      nextStep:
          'Reduce load and let the scooter rest. If it repeats during normal riding, inspect the battery, motor and power wiring.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['contactor', 'precharge', 'pre charge'])) {
    return const FaultExplanation(
      subsystem: 'Battery power switching',
      meaning:
          'The high-voltage contactor or pre-charge sequence did not reach the state the controller expected.',
      nextStep:
          'Switch off and retry once. If it returns, do not repeatedly cycle power; have the battery switching circuit inspected.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['mosfet', 'afe ', 'analog front end'])) {
    return const FaultExplanation(
      subsystem: 'Battery electronics',
      meaning:
          'The BMS reported an abnormal battery switching or cell-monitoring electronics state.',
      nextStep:
          'Do not attempt repeated resets. Save a report and arrange battery-electronics inspection if the fault remains.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, [
    'charger',
    'charging',
    'mains',
    'ac voltage',
    'ac_v',
    'fast charge',
  ])) {
    return const FaultExplanation(
      subsystem: 'Charging',
      meaning:
          'The scooter or charger detected an input, handshake, temperature or charging-current problem.',
      nextStep:
          'Unplug safely, inspect the outlet and connector, then retry once. Use another known-good outlet; seek service if it repeats.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['motor stall', 'resolver', 'hall sensor', 'encoder']) ||
      _word(text, ['stall', 'stalling', 'hall'])) {
    return const FaultExplanation(
      subsystem: 'Motor drive',
      meaning:
          'The motor did not rotate as expected or its position feedback was implausible.',
      nextStep:
          'Stop safely and check that the wheel turns freely. Do not keep applying throttle if the fault remains.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, [
        'communication',
        'comm ',
        'bus signal',
        'timeout',
        'lost message',
        'disconnect',
        'mismatch',
      ]) ||
      _word(text, ['can']) ||
      code.toUpperCase().startsWith('U')) {
    return const FaultExplanation(
      subsystem: 'Controller communication',
      meaning:
          'One controller stopped receiving a message or received data inconsistent with another controller.',
      nextStep:
          'Save a report and power-cycle only when parked. If it returns, inspect connectors, power supplies and the CAN wiring.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, [
    'drive protection',
    'drive abnormal',
    'overload',
    'over speed',
    'overspeed',
    'parameter tuning',
  ])) {
    final tuning = text.contains('parameter tuning');
    final speed = _has(text, ['over speed', 'overspeed']);
    return FaultExplanation(
      subsystem: 'Motor controller',
      meaning: tuning
          ? 'The motor controller could not finish learning the motor’s electrical parameters (auto-tune), so drive may be limited or disabled.'
          : speed
          ? 'The motor spun faster than the controller allows and its over-speed protection acted.'
          : 'The motor controller protected the drive after an overload, abnormal drive condition or protection trip.',
      nextStep: tuning
          ? 'Switch off and retry once when parked. If it returns, have the motor and its position-sensor wiring checked before any recalibration.'
          : 'Stop safely and let the scooter rest. If it returns during normal riding, have the motor, controller and wiring inspected.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['sensor', 'signal implausible', 'out of range'])) {
    return const FaultExplanation(
      subsystem: 'Sensor or wiring',
      meaning:
          'A sensor value is missing, implausible or outside the range its controller expects.',
      nextStep:
          'Check related connectors and wiring. Compare the live reading with nearby sensors before replacing any part.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, [
    'eeprom',
    'flash memory',
    'internal memory',
    'software fault',
  ])) {
    return const FaultExplanation(
      subsystem: 'Controller software or memory',
      meaning:
          'A controller detected invalid software state, calibration data or non-volatile memory content.',
      nextStep:
          'Save a report and restart only when parked. Do not flash firmware solely from this message; verify software version and service procedure first.',
      severity: FaultSeverity.attention,
    );
  }
  if (_word(text, ['short', 'open']) ||
      _has(text, [
        'open circuit',
        ' circuit open',
        'connection failed',
        'disconnection failed',
      ])) {
    return const FaultExplanation(
      subsystem: 'Electrical circuit or wiring',
      meaning:
          'A controller measured an open circuit, short circuit or switching connection that did not match its command.',
      nextStep:
          'Inspect the named load, connector, fuse and wiring. Do not replace the controller until the circuit has been measured.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['fault reported by', 'failure reported by'])) {
    return const FaultExplanation(
      subsystem: 'Cross-controller report',
      meaning:
          'One controller is relaying a fault reported by another module; it is not the root-cause code by itself.',
      nextStep:
          'Read stored faults from every controller and diagnose the originating module’s code first.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['cell deviation', 'imbalance', 'unbalance', 'balancing'])) {
    return const FaultExplanation(
      subsystem: 'Battery cell balance',
      meaning:
          'One or more cell groups differ more than expected from the rest of the pack.',
      nextStep:
          'Complete a normal full charge so the BMS can balance cells, then compare the spread again. Inspect the pack if the gap persists.',
      severity: FaultSeverity.attention,
    );
  }
  if (_has(text, ['regen'])) {
    return const FaultExplanation(
      subsystem: 'Regenerative braking',
      meaning:
          'Regenerative braking is limited or unavailable, often because the battery is full, cold, hot or under protection.',
      nextStep:
          'Use the mechanical brakes normally. Recheck after state of charge and temperature move into their normal range.',
      severity: FaultSeverity.information,
    );
  }
  if (_has(text, ['reset', 'acknowledge', ' ack ', 'clear command'])) {
    return const FaultExplanation(
      subsystem: 'Controller status',
      meaning:
          'This looks like a reset or acknowledgement status rather than proof of a component failure.',
      nextStep:
          'Check whether a stored DTC is also present before treating this as a fault.',
      severity: FaultSeverity.information,
    );
  }
  if (_has(text, ['warning', ' warn', 'limit'])) {
    return const FaultExplanation(
      subsystem: 'Protection warning',
      meaning:
          'A controller is approaching or applying a protection limit. It may clear when operating conditions normalize.',
      nextStep:
          'Ride gently, watch for power limitation, and save a report if the warning remains or returns.',
      severity: FaultSeverity.attention,
    );
  }

  return FaultExplanation(
    subsystem: _controllerName(source),
    meaning:
        'The controller reported a condition named “${description.trim().isEmpty ? code : description.trim()}”. The available catalog does not define the failed part or root cause.',
    nextStep:
        'Save a diagnostic report and note when it occurred. If a red warning, unusual heat, smell, noise or reduced braking is present, stop riding and seek service.',
    severity: FaultSeverity.attention,
  );
}
