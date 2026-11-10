import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../design/glass_quality.dart';
import '../design/haptics.dart';

enum WorkspaceMode {
  owner('Owner', 'Simple health, battery and everyday controls'),
  technician('Technician', 'Read-only diagnostics and vehicle data'),
  service('Service', 'Active tests, ECU tools and head-unit access');

  const WorkspaceMode(this.label, this.description);
  final String label;
  final String description;
}

enum Tool {
  status('Vehicle status', 'Monitoring'),
  recorder('Recorder', 'Monitoring'),
  components('Components', 'ECU information'),
  firmware('Firmware', 'ECU information'),
  software('Software', 'ECU information'),
  live('Live signals', 'Monitoring'),
  charging('Charging', 'Monitoring'),
  controls('Vehicle controls', 'Vehicle controls'),
  features('Vehicle features', 'Vehicle controls'),
  componentTests('Component tests', 'Vehicle controls'),
  actuators('Actuator tests', 'Service & recovery'),
  recovery('Fault clearing & ECU restart', 'Service & recovery'),
  headUnit('Head-unit console', 'Service & recovery'),
  parameters('Parameters', 'Calibration & engineering'),
  performance('Performance limits', 'Calibration & engineering'),
  engineering('Engineering tools', 'Calibration & engineering');

  const Tool(this.label, this.group);
  final String label, group;

  /// Developer (advanced / potentially dangerous) windows. These are hidden
  /// until the user explicitly enters Developer Mode (warning + slide-to-verify)
  /// and are then surfaced in the Tools sidebar. Everything else is a basic,
  /// high-level troubleshooting window that is always available.
  bool get dev =>
      this == Tool.controls ||
      this == Tool.actuators ||
      this == Tool.recovery ||
      this == Tool.headUnit ||
      this == Tool.parameters ||
      this == Tool.performance ||
      this == Tool.engineering;

  /// Basic windows are always reachable without Developer Mode.
  bool get basic => !dev;

  bool visibleIn(WorkspaceMode workspace) => switch (workspace) {
    WorkspaceMode.owner => false,
    WorkspaceMode.technician => const {
      Tool.status,
      Tool.recorder,
      Tool.components,
      Tool.firmware,
      Tool.software,
      Tool.live,
      Tool.charging,
    }.contains(this),
    WorkspaceMode.service => true,
  };
}

class Preferences extends ChangeNotifier {
  Preferences(this.store) {
    theme = ThemeMode.values.firstWhere(
      (m) => m.name == store.getString('theme'),
      orElse: () => ThemeMode.system,
    );
    reduceMotion = store.getBool('reduceMotion') ?? false;
    developerMode = store.getBool('developerMode') ?? false;
    workspaceMode = WorkspaceMode.values.firstWhere(
      (mode) => mode.name == store.getString('workspaceMode'),
      // Existing Developer Mode users are migrated to Service so an app update
      // does not appear to remove their established tool access. Fresh installs
      // still start in the safe Owner workspace.
      orElse: () => developerMode ? WorkspaceMode.service : WorkspaceMode.owner,
    );
    if (workspaceMode == WorkspaceMode.service && !developerMode) {
      workspaceMode = WorkspaceMode.technician;
    }
    haptics = store.getBool('haptics') ?? true;
    AppHaptics.enabled = haptics;
    tutorialSeen = store.getBool('tutorialSeen') ?? false;
    disclaimerAccepted = store.getBool('disclaimerAccepted') ?? false;
    quality = GlassQuality(
      auto: store.getBool('glassAuto') ?? true,
      manual: GlassTier.values.firstWhere(
        (t) => t.name == store.getString('glassTier'),
        orElse: () => GlassTier.high,
      ),
    );
    quality.addListener(_saveQuality);
  }
  final SharedPreferences store;
  ThemeMode theme = ThemeMode.system;
  bool reduceMotion = false;
  bool developerMode = false;
  late WorkspaceMode workspaceMode;
  bool haptics = true;
  bool tutorialSeen = false;
  bool disclaimerAccepted = false;
  late final GlassQuality quality;

  void _saveQuality() {
    store.setBool('glassAuto', quality.auto);
    store.setString('glassTier', quality.manual.name);
  }

  Future<void> appearance(ThemeMode value) async {
    theme = value;
    notifyListeners();
    await store.setString('theme', value.name);
  }

  Future<void> motion(bool value) async {
    reduceMotion = value;
    notifyListeners();
    await store.setBool('reduceMotion', value);
  }

  Future<void> setHaptics(bool value) async {
    haptics = value;
    AppHaptics.enabled = value;
    notifyListeners();
    await store.setBool('haptics', value);
    if (value) AppHaptics.success(); // noticeable confirmation buzz
  }

  /// Enters or leaves Developer Mode. Entering should only be called after the
  /// warning + slide-to-verify gate in the UI.
  Future<void> setDeveloperMode(bool value) async {
    developerMode = value;
    if (value) {
      workspaceMode = WorkspaceMode.service;
      await store.setString('workspaceMode', workspaceMode.name);
    } else if (workspaceMode == WorkspaceMode.service) {
      workspaceMode = WorkspaceMode.technician;
      await store.setString('workspaceMode', workspaceMode.name);
    }
    notifyListeners();
    await store.setBool('developerMode', value);
  }

  Future<bool> setWorkspaceMode(WorkspaceMode value) async {
    if (value == WorkspaceMode.service && !developerMode) return false;
    workspaceMode = value;
    notifyListeners();
    await store.setString('workspaceMode', value.name);
    return true;
  }

  /// Records that the user accepted the first-boot experimental/liability
  /// disclaimer. Shown once before anything else.
  Future<void> setDisclaimerAccepted(bool value) async {
    disclaimerAccepted = value;
    notifyListeners();
    await store.setBool('disclaimerAccepted', value);
  }

  /// Marks the first-run tutorial as seen (or resets it when [value] is false).
  Future<void> setTutorialSeen(bool value) async {
    tutorialSeen = value;
    notifyListeners();
    await store.setBool('tutorialSeen', value);
  }

  @override
  void dispose() {
    quality.removeListener(_saveQuality);
    quality.dispose();
    super.dispose();
  }

  /// A window is available when it is basic, or when Developer Mode is active.
  bool has(Tool tool) => tool.basic || developerMode;
}
