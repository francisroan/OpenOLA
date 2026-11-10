import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/catalog.dart';
import 'diagnostics/preferences.dart';
import 'diagnostics/controller.dart';
import 'bluetooth/ble_controller.dart';
import 'design/glass.dart';
import 'design/glass_quality.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait — the diagnostic UI is designed vertically and should not
  // rotate with the phone (users reported it following auto-rotate).
  // Portrait-up only: requesting both portrait directions makes Flutter ask
  // Android for USER_PORTRAIT, which hands orientation to the system's
  // auto-rotate machinery and can make OEM skins (ColorOS) show auto-rotate as
  // on. A single fixed orientation does not involve the rotation setting.
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  runApp(const _Startup());
  try {
    final store = await SharedPreferences.getInstance();
    final catalog = await Catalog.load();
    final prefs = Preferences(store);
    runApp(OpenOla(prefs: prefs, diagnostics: Diagnostics(catalog, prefs)));
  } catch (error) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: glassTheme(Brightness.light),
        darkTheme: glassTheme(Brightness.dark),
        home: Scaffold(
          body: Stack(
            children: [
              const Positioned.fill(child: GlassWallpaper()),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Glass(
                    child: SelectableText(
                      'OpenOLA could not load its local data.\n$error',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Startup extends StatelessWidget {
  const _Startup();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: glassTheme(Brightness.light),
    darkTheme: glassTheme(Brightness.dark),
    home: const Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: GlassWallpaper()),
          Center(
            child: Glass(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppMark(size: 76),
                  SizedBox(height: 20),
                  Text('OpenOLA'),
                  SizedBox(height: 12),
                  CircularProgressIndicator.adaptive(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class OpenOla extends StatelessWidget {
  const OpenOla({
    super.key,
    required this.prefs,
    required this.diagnostics,
    this.ble,
  });
  final Preferences prefs;
  final Diagnostics diagnostics;
  final ScooterBle? ble;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: prefs,
    builder: (_, _) => MaterialApp(
      title: 'OpenOLA',
      debugShowCheckedModeBanner: false,
      theme: glassTheme(Brightness.light),
      darkTheme: glassTheme(Brightness.dark),
      themeMode: prefs.theme,
      builder: (context, child) => GlassQualityScope(
        quality: prefs.quality,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations:
                prefs.reduceMotion || MediaQuery.disableAnimationsOf(context),
          ),
          child: child!,
        ),
      ),
      home: AppShell(d: diagnostics, prefs: prefs, ble: ble),
    ),
  );
}
