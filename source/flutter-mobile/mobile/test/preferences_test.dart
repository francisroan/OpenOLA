import 'package:flutter_test/flutter_test.dart';
import 'package:openola/diagnostics/preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('workspace defaults to Owner and persists Technician', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    expect(prefs.workspaceMode, WorkspaceMode.owner);
    expect(await prefs.setWorkspaceMode(WorkspaceMode.technician), true);
    expect(prefs.workspaceMode, WorkspaceMode.technician);
    prefs.dispose();

    final restored = Preferences(await SharedPreferences.getInstance());
    expect(restored.workspaceMode, WorkspaceMode.technician);
    restored.dispose();
  });

  test('Service requires Developer Mode and falls back when locked', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Preferences(await SharedPreferences.getInstance());
    expect(await prefs.setWorkspaceMode(WorkspaceMode.service), false);
    expect(prefs.workspaceMode, WorkspaceMode.owner);
    await prefs.setDeveloperMode(true);
    expect(await prefs.setWorkspaceMode(WorkspaceMode.service), true);
    expect(prefs.workspaceMode, WorkspaceMode.service);
    await prefs.setDeveloperMode(false);
    expect(prefs.workspaceMode, WorkspaceMode.technician);
    prefs.dispose();
  });

  test('workspace tool policy separates read-only and service tools', () {
    expect(Tool.live.visibleIn(WorkspaceMode.technician), true);
    expect(Tool.headUnit.visibleIn(WorkspaceMode.technician), false);
    expect(Tool.headUnit.visibleIn(WorkspaceMode.service), true);
    expect(Tool.features.dev, false);
    expect(Tool.controls.dev, true);
  });
}
