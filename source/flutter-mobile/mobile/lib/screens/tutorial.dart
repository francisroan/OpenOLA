import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../design/glass.dart';
import '../design/haptics.dart';

/// One step of the first-run tour. [anchor] names a UI target (a key in the
/// anchors map passed to [showTour]); when present the overlay spotlights that
/// element and places the caption beside it, otherwise the caption is centered.
class TourStep {
  const TourStep(
    this.icon,
    this.color,
    this.title,
    this.body, {
    this.anchor,
    this.tab,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  /// Named UI target to spotlight (a key in the anchors map), or null to
  /// centre the caption.
  final String? anchor;

  /// Bottom-bar tab to switch to for this step, so the screen being described
  /// is visible behind the spotlight. Null leaves the current screen.
  final int? tab;
}

const tourSteps = <TourStep>[
  TourStep(
    CupertinoIcons.sparkles,
    accent,
    'Welcome to OpenOLA',
    'A local diagnostics app for your scooter — no account, no cloud. Until a '
        'scooter or Demo is connected only the connection screen is available; '
        'everything below unlocks once you are in. Here is a quick tour.',
    tab: 0,
  ),
  TourStep(
    CupertinoIcons.house,
    Color(0xff34c759),
    'Home',
    'Charge, range, battery health and scooter health at a glance, plus the '
        'odometer, which fills in automatically from the scooter. To connect '
        'again later, choose Scooter Wi-Fi, Phone hotspot or Shared Wi-Fi on the '
        'connect screen — each shows its three steps — or explore with Demo.',
    anchor: 'tabs',
    tab: 0,
  ),
  TourStep(
    CupertinoIcons.battery_100,
    Color(0xff30d158),
    'Battery',
    'State of health, cycles and pack temperature, then every cell group with '
        'its charge %, voltage, internal resistance (IR) and available Wh. Tap '
        'a cell for detail. It reads passively, so it does not disturb charging.',
    anchor: 'tabs',
    tab: 1,
  ),
  TourStep(
    CupertinoIcons.waveform_path_ecg,
    Color(0xff32ade6),
    'Diagnose: faults',
    'Scan the battery, motor and vehicle controllers for stored faults. Tap the '
        '(i) beside any code or live flag for a plain-language, offline '
        'explanation and safe next steps. Browse every known code any time under '
        'Settings ▸ Browse offline fault guide.',
    anchor: 'tabs',
    tab: 2,
  ),
  TourStep(
    CupertinoIcons.cursor_rays,
    Color(0xffff9f0a),
    'Controls',
    'Everyday controls: Sport and Hyper access (needs Park, the charger '
        'unplugged and a typed confirmation) and vehicle features. Riding mode '
        'itself is still changed with the handlebar button.',
    anchor: 'tabs',
    tab: 3,
  ),
  TourStep(
    CupertinoIcons.sidebar_left,
    accent,
    'Tools and workspaces',
    'Tap Tools to pick a workspace — Owner (simple), Technician (live signals, '
        'charging, recorder, reports) or Service (developer tools). Reports and '
        'saved snapshots for a service visit are in this menu too.',
    anchor: 'tools',
  ),
  TourStep(
    CupertinoIcons.wrench,
    Color(0xffff453a),
    'Service and Developer Mode',
    'Riskier tools stay locked until you slide to enter Developer Mode: '
        'actuator tests, ECU tools and the Head-unit console — terminal, app '
        'launcher, APK / split-APK (.apks) installer with progress, and pulling '
        'an installed app’s APK to a folder on your phone. Use them only on a '
        'parked scooter you own.',
    anchor: 'tools',
  ),
  TourStep(
    CupertinoIcons.search,
    accent,
    'Search vehicle data',
    'Tap the magnifying glass at the top right to search signals and parameters '
        'from any screen. Results show what the scooter currently reports and '
        'which values are unavailable.',
    anchor: 'search',
  ),
  TourStep(
    CupertinoIcons.slider_horizontal_3,
    Color(0xff5856d6),
    'Settings & this tour',
    'Appearance, haptics, workspace and the offline fault guide live here. This '
        'tour won’t pop up again — replay it any time from Settings ▸ Show '
        'tutorial.',
    anchor: 'settings',
  ),
];

/// Shows the guided tour. [anchors] maps a step's `anchor` to the live widget's
/// GlobalKey so the overlay can spotlight it. Resolves when finished or skipped.
Future<void> showTour(
  BuildContext context, {
  Map<String, GlobalKey> anchors = const {},
  void Function(int tab)? onTab,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Tutorial',
  barrierColor: Colors.transparent,
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (_, _, _) => _Tour(anchors: anchors, onTab: onTab),
  transitionBuilder: (_, anim, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);

class _Tour extends StatefulWidget {
  const _Tour({required this.anchors, this.onTab});
  final Map<String, GlobalKey> anchors;
  final void Function(int tab)? onTab;
  @override
  State<_Tour> createState() => _TourState();
}

class _TourState extends State<_Tour> {
  int index = 0;

  @override
  void initState() {
    super.initState();
    // Apply the first step's screen once the overlay is up, then rebuild so the
    // spotlight measures the now-visible target.
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyTab());
  }

  /// Switches the host screen to the current step's tab, if it names one, so
  /// the described UI is visible behind the spotlight.
  void _applyTab() {
    final t = tourSteps[index].tab;
    if (t != null) widget.onTab?.call(t);
    if (mounted) setState(() {});
  }

  Rect? _anchorRect(String? id) {
    if (id == null) return null;
    final ctx = widget.anchors[id]?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  void _next() {
    if (index >= tourSteps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    AppHaptics.selection();
    setState(() => index++);
    _applyTab();
  }

  void _back() {
    if (index == 0) return;
    AppHaptics.selection();
    setState(() => index--);
    _applyTab();
  }

  @override
  Widget build(BuildContext context) {
    final step = tourSteps[index];
    final screen = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final rawRect = _anchorRect(step.anchor);
    // Inflate a touch so the highlight breathes around the target.
    final rect = rawRect?.inflate(8);
    // Place the caption on whichever side of the target has more room.
    final below = rect == null || rect.bottom < screen.height * .5;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Dimmed scrim with a rounded hole over the target.
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _Spotlight(rect))),
          ),
          // Caption card.
          Positioned(
            left: 16,
            right: 16,
            top: rect != null && below ? rect.bottom + 14 : null,
            bottom: rect != null && !below
                ? screen.height - rect.top + 14
                : (rect == null ? null : null),
            child: rect == null
                ? Padding(
                    padding: EdgeInsets.only(
                      top: screen.height * .28,
                      bottom: pad.bottom,
                    ),
                    child: Align(child: _card(step)),
                  )
                : Align(child: _card(step)),
          ),
        ],
      ),
    );
  }

  Widget _card(TourStep step) {
    final last = index == tourSteps.length - 1;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Glass(
        grouped: false,
        chrome: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: step.color.withValues(alpha: .15),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(step.icon, color: step.color, size: 22),
                ),
                const Spacer(),
                Text(
                  '${index + 1} / ${tourSteps.length}',
                  style: TextStyle(
                    color: muted(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(step.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              step.body,
              style: TextStyle(
                color: muted(context),
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < tourSteps.length; i++)
                  AnimatedContainer(
                    duration: motion(context),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == index
                          ? accent
                          : muted(context).withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: index > 0
                      ? GlassButton('Back', onPressed: _back)
                      : GlassButton(
                          'Skip',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    last ? 'Get started' : 'Next',
                    primary: true,
                    onPressed: _next,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a dark scrim with a rounded-rectangle hole punched over [hole].
class _Spotlight extends CustomPainter {
  const _Spotlight(this.hole);
  final Rect? hole;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final scrim = Paint()..color = Colors.black.withValues(alpha: .62);
    if (hole == null) {
      canvas.drawRect(full, scrim);
      return;
    }
    final rr = RRect.fromRectAndRadius(hole!, const Radius.circular(18));
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(full),
      Path()..addRRect(rr),
    );
    canvas.drawPath(path, scrim);
    // Accent ring around the spotlight.
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: .9),
    );
  }

  @override
  bool shouldRepaint(_Spotlight old) => old.hole != hole;
}

/// Blocking first-boot experimental / liability disclaimer. Must be accepted
/// before the app can be used; shown once (see `prefs.disclaimerAccepted`).
Future<void> showDisclaimer(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Disclaimer',
  barrierColor: Colors.black.withValues(alpha: .78),
  transitionDuration: const Duration(milliseconds: 240),
  pageBuilder: (_, _, _) => const _Disclaimer(),
  transitionBuilder: (_, anim, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xffff453a);
    return PopScope(
      canPop: false, // cannot be dismissed with the system back gesture
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Glass(
                grouped: false,
                chrome: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: danger.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: danger,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Experimental — please read',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OpenOLA is experimental, community reverse-engineering '
                              'software. It talks directly to your scooter\'s '
                              'controllers and can read — and, in advanced modes, '
                              'change — low-level settings.',
                              style: TextStyle(
                                color: muted(context),
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _bullet(
                              context,
                              'Use it entirely at your own risk, on a scooter you own.',
                            ),
                            _bullet(
                              context,
                              'It may be inaccurate, incomplete or wrong for your '
                              'model and firmware.',
                            ),
                            _bullet(
                              context,
                              'Advanced writes (parameters, performance limits, '
                              'actuators, firmware) can damage or brick components, '
                              'and can be unsafe if the scooter is not parked.',
                            ),
                            _bullet(
                              context,
                              'Modifying your vehicle may void your warranty and may '
                              'be illegal to use on public roads in your area.',
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'The authors provide NO warranty and accept NO '
                              'responsibility for any damage, injury, loss, legal '
                              'consequence, or warranty/registration issue arising from '
                              'its use. By continuing you accept these terms and take '
                              'full responsibility.',
                              style: TextStyle(
                                color: muted(context),
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    GlassButton(
                      'I understand & accept',
                      primary: true,
                      icon: CupertinoIcons.checkmark_shield,
                      onPressed: () {
                        AppHaptics.success();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 10),
          child: Icon(
            CupertinoIcons.circle_fill,
            size: 6,
            color: muted(context),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: muted(context), height: 1.45),
          ),
        ),
      ],
    ),
  );
}
