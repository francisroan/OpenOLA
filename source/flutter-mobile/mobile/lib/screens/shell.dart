import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../bluetooth/ble_controller.dart';
import '../diagnostics/controller.dart';
import '../diagnostics/preferences.dart';
import '../design/glass.dart';
import '../design/haptics.dart';
import '../design/dashboard.dart';
import 'core.dart';
import 'advanced.dart';
import 'live_signals.dart';
import 'battery_page.dart';
import 'tutorial.dart';
import 'workspace_pages.dart';

IconData toolIcon(Tool t) => switch (t) {
  Tool.status => CupertinoIcons.gauge,
  Tool.software => CupertinoIcons.square_arrow_down,
  Tool.recorder => CupertinoIcons.recordingtape,
  Tool.components => CupertinoIcons.square_stack_3d_up,
  Tool.firmware => CupertinoIcons.square_stack_3d_up,
  Tool.live => CupertinoIcons.waveform,
  Tool.charging => CupertinoIcons.bolt,
  Tool.controls => CupertinoIcons.cursor_rays,
  Tool.features => CupertinoIcons.car_detailed,
  Tool.componentTests => CupertinoIcons.lightbulb_fill,
  Tool.actuators => CupertinoIcons.wrench,
  Tool.recovery => CupertinoIcons.arrow_clockwise,
  Tool.headUnit => CupertinoIcons.chevron_left_slash_chevron_right,
  Tool.parameters => CupertinoIcons.slider_horizontal_3,
  Tool.performance => CupertinoIcons.speedometer,
  Tool.engineering => CupertinoIcons.gear_alt,
};
Color toolColor(Tool t) => switch (t) {
  Tool.charging => orange,
  Tool.controls || Tool.features => purple,
  Tool.componentTests => orange,
  Tool.actuators || Tool.recovery || Tool.headUnit => teal,
  Tool.performance => const Color(0xffff453a),
  Tool.parameters || Tool.engineering => const Color(0xff5856d6),
  _ => accent,
};

/// Warning + slide-to-verify gate for turning Developer Mode on. Returns true
/// only when the user slides to confirm. Shared by the sidebar and Settings so
/// the gate reads identically everywhere.
Future<bool> enterDeveloperMode(BuildContext context, Preferences prefs) async {
  final ok = await confirmGlass(
    context,
    'Enter Developer Mode',
    'This reveals advanced tools that can write calibration values, drive '
        'actuators, restart ECUs and control the scooter over Bluetooth. Only '
        'use them on a parked scooter with the charger disconnected. Slide to '
        'confirm you understand the risk.',
  );
  if (ok) {
    AppHaptics.warning();
    await prefs.setDeveloperMode(true);
  }
  return ok;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.d, required this.prefs, this.ble});
  final Diagnostics d;
  final Preferences prefs;
  final ScooterBle? ble;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final scaffold = GlobalKey<ScaffoldState>();
  bool drawerOpen = false;
  bool settingsOpen = false;
  int tab = 0;
  Tool? tool;
  bool faultsOpen = false;
  bool reportsOpen = false;
  final reportState = ReportState();
  final controller = ScrollController();
  // Anchors the guided tour spotlights onto live chrome.
  final tourKeys = {
    'tools': GlobalKey(),
    'tabs': GlobalKey(),
    'search': GlobalKey(),
    'settings': GlobalKey(),
  };

  // Basic, high-level troubleshooting destinations.
  static const labels = ['Home', 'Battery', 'Diagnose', 'Controls'];
  static const icons = [
    CupertinoIcons.house,
    CupertinoIcons.battery_100,
    CupertinoIcons.waveform_path_ecg,
    CupertinoIcons.cursor_rays,
  ];

  bool _wasConnected = false;
  bool _reconnecting = false;
  bool _showingOnboarding = false;

  /// Shows a popup when the live link drops, and auto-recovers a *wedged* link.
  /// The disconnect popup only fires on a genuine connected→disconnected
  /// transition in the foreground (the gRPC link, not vehicle sleep). The
  /// auto-reconnect handles the head-unit lockup where commands stop responding
  /// — the known fix is a session reconnect, so the app does it rather than
  /// leaving the user to disconnect by hand.
  void _onConnectionChange() {
    final d = widget.d;
    final nowConnected = d.connected;
    if (_wasConnected && !nowConnected && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          tab = 0;
          tool = null;
          settingsOpen = false;
          faultsOpen = false;
          reportsOpen = false;
          drawerOpen = false;
        });
      });
    }
    if (!_wasConnected && nowConnected && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runOnboarding());
    }
    if (_wasConnected && !nowConnected && mounted && d.foreground) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Disconnected from the scooter — reconnect from this screen.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
      });
    }
    _wasConnected = nowConnected;
    if (d.connectionStuck &&
        !d.busy &&
        !_reconnecting &&
        mounted &&
        d.foreground) {
      _reconnecting = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          _reconnecting = false;
          return;
        }
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Link was stuck — reconnecting…'),
              duration: Duration(seconds: 4),
            ),
          );
        try {
          await d.reconnect();
        } finally {
          _reconnecting = false;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wasConnected = widget.d.connected;
    widget.d.addListener(_onConnectionChange);
    // The disclaimer belongs before connection. The navigation tour waits
    // until a live/demo workspace exists, so every highlighted target is real.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runOnboarding());
  }

  Future<void> _runOnboarding() async {
    if (!mounted || _showingOnboarding) return;
    _showingOnboarding = true;
    try {
      if (!widget.prefs.disclaimerAccepted) {
        await showDisclaimer(context);
        await widget.prefs.setDisclaimerAccepted(true);
        if (!mounted) return;
      }
      if (widget.d.connected && !widget.prefs.tutorialSeen) {
        await showTour(context, anchors: tourKeys, onTab: _tourTab);
        await widget.prefs.setTutorialSeen(true);
      }
    } finally {
      _showingOnboarding = false;
    }
  }

  /// Switches the host screen while the guided tour runs so the UI a step
  /// describes is visible behind the spotlight.
  void _tourTab(int t) {
    if (!mounted) return;
    setState(() {
      tab = t;
      settingsOpen = false;
      tool = null;
      faultsOpen = false;
      reportsOpen = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.d.foreground =
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached;
    if (state == AppLifecycleState.paused && widget.d.session.active) {
      widget.d.stopSession(
        reason: 'Session saved because OpenOLA left the foreground.',
      );
    }
    if (state == AppLifecycleState.resumed && widget.d.connected) {
      widget.d.emit();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.d.removeListener(_onConnectionChange);
    controller.dispose();
    super.dispose();
  }

  void navigate(int value) {
    AppHaptics.selection();
    setState(() {
      tab = value;
      tool = null;
      settingsOpen = false;
      faultsOpen = false;
      reportsOpen = false;
    });
    if (controller.hasClients) controller.jumpTo(0);
  }

  void openTool(Tool value) {
    if (!widget.prefs.has(value)) {
      // Locked developer window — offer the gate instead of opening it.
      enterDeveloperMode(context, widget.prefs);
      return;
    }
    AppHaptics.selection();
    setState(() {
      tool = value;
      settingsOpen = false;
      faultsOpen = false;
      reportsOpen = false;
    });
    if (controller.hasClients) controller.jumpTo(0);
  }

  void openReports() {
    AppHaptics.selection();
    setState(() {
      reportsOpen = true;
      settingsOpen = false;
      faultsOpen = false;
      tool = null;
    });
    if (controller.hasClients) controller.jumpTo(0);
  }

  void openSettings() {
    AppHaptics.selection();
    setState(() {
      settingsOpen = true;
      tool = null;
      faultsOpen = false;
      reportsOpen = false;
    });
    if (controller.hasClients) controller.jumpTo(0);
  }

  Future<void> openSearch() => glassSheet<void>(
    context,
    PageStack([
      const Heading('Search', 'Find a vehicle signal or parameter.'),
      UniversalSearch(d: widget.d),
    ]),
  );

  Future<void> appearance() async {
    final mode = await glassSheet<ThemeMode>(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Heading('Appearance', 'Choose the look that feels right.'),
          const SizedBox(height: 18),
          for (final m in ThemeMode.values)
            WorkspaceRow(
              switch (m) {
                ThemeMode.system => 'System',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              switch (m) {
                ThemeMode.system => 'Follow your device',
                ThemeMode.light => 'Bright, translucent glass',
                ThemeMode.dark => 'Deep, ambient glass',
              },
              switch (m) {
                ThemeMode.system => CupertinoIcons.circle_lefthalf_fill,
                ThemeMode.light => CupertinoIcons.sun_max,
                ThemeMode.dark => CupertinoIcons.moon,
              },
              m == ThemeMode.dark
                  ? purple
                  : m == ThemeMode.light
                  ? orange
                  : accent,
              trailing: m == widget.prefs.theme
                  ? const Icon(
                      CupertinoIcons.checkmark,
                      color: accent,
                      size: 18,
                    )
                  : const SizedBox(width: 18),
              onTap: () => Navigator.pop(context, m),
            ),
        ],
      ),
    );
    if (mode != null) await widget.prefs.appearance(mode);
  }

  void menuAction(VoidCallback action) {
    scaffold.currentState?.closeDrawer();
    action();
  }

  Future<void> mode() async {
    final d = widget.d;
    if (d.busy) return;
    if (!widget.prefs.developerMode) {
      d.message = 'Unlock the Service workspace before changing vehicle mode.';
      d.emit();
      return;
    }
    if (d.mode == 'SERVICE') {
      await d.serviceMode(false);
    } else if (await confirmGlass(
      context,
      'Enter Service mode?',
      'Confirm the scooter is parked and the charger is disconnected. This changes vehicle mode for diagnostic tests.',
    )) {
      await d.serviceMode(true);
    }
  }

  Future<void> connection() => glassSheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Heading(
          widget.d.demo ? 'Demo scooter' : 'Scooter connection',
          widget.d.demo
              ? 'Simulated readings. Nothing is sent to a scooter.'
              : widget.d.freshness,
        ),
        const SizedBox(height: 18),
        WorkspaceRow(
          'Vehicle mode',
          widget.d.mode,
          CupertinoIcons.car_detailed,
          accent,
        ),
        WorkspaceRow('Firmware', widget.d.firmware, CupertinoIcons.gear, teal),
        const SizedBox(height: 12),
        if (widget.prefs.developerMode)
          GlassButton(
            widget.d.mode == 'SERVICE' ? 'Leave Service mode' : 'Enter Service',
            icon: CupertinoIcons.wrench,
            onPressed: widget.d.busy
                ? null
                : () {
                    Navigator.pop(context);
                    mode();
                  },
          )
        else
          Text(
            'Vehicle mode changes are available only from the unlocked Service workspace.',
            style: TextStyle(color: muted(context), fontSize: 12),
          ),
        const SizedBox(height: 18),
        GlassButton(
          widget.d.demo ? 'End demo' : 'Disconnect',
          onPressed: widget.d.busy
              ? null
              : () {
                  Navigator.pop(context);
                  widget.d.disconnect();
                },
        ),
      ],
    ),
  );

  String _currentTitle() => settingsOpen
      ? 'Settings'
      : faultsOpen
      ? 'Fault scan'
      : reportsOpen
      ? 'Reports'
      : tool != null
      ? tool!.label
      : labels[tab];

  Widget _toolbar(bool wide) {
    final d = widget.d;
    final compact =
        !wide &&
        MediaQuery.sizeOf(context).width < 400 &&
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Glass(
      chrome: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          if (!wide) ...[
            Tooltip(
              message: 'Open tools menu',
              child: compact
                  ? IconButton(
                      key: tourKeys['tools'],
                      onPressed: () {
                        AppHaptics.light();
                        scaffold.currentState?.openDrawer();
                      },
                      icon: const Icon(CupertinoIcons.sidebar_left, size: 20),
                    )
                  : TextButton.icon(
                      key: tourKeys['tools'],
                      onPressed: () {
                        AppHaptics.light();
                        scaffold.currentState?.openDrawer();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: ink(context),
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(CupertinoIcons.sidebar_left, size: 20),
                      label: const Text(
                        'Tools',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 2),
            if (!compact) ...[
              const AppMark(size: 24),
              const SizedBox(width: 6),
            ],
          ] else
            const SizedBox(width: 8),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                wide ? _currentTitle() : 'OpenOLA',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
            ),
          ),
          if (widget.prefs.developerMode && !compact) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Developer Mode is on',
              child: StatusChip(
                'Dev',
                color: danger,
                icon: CupertinoIcons.wrench,
                onTap: openSettings,
              ),
            ),
          ],
          if (d.connected) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Connection and Service mode',
              child: StatusChip(
                d.demo ? 'Demo' : 'Connected',
                color: d.demo ? purple : green,
                icon: d.demo ? CupertinoIcons.play_circle : CupertinoIcons.link,
                onTap: connection,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Tooltip(
            key: tourKeys['search'],
            message: 'Search vehicle data',
            child: IconButton(
              key: const ValueKey('global-search'),
              onPressed: openSearch,
              icon: const Icon(CupertinoIcons.search, size: 20),
            ),
          ),
          Tooltip(
            key: const ValueKey('open-settings'),
            message: 'Settings',
            child: IconButton(
              key: tourKeys['settings'],
              onPressed: openSettings,
              icon: Icon(
                CupertinoIcons.slider_horizontal_3,
                color: settingsOpen ? accent : ink(context),
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabItem(int i, {required bool rail}) {
    final selected = tab == i && tool == null && !settingsOpen;
    return Semantics(
      selected: selected,
      button: true,
      label: labels[i],
      child: GestureDetector(
        key: ValueKey('nav-${labels[i]}'),
        onTap: () => navigate(i),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: motion(context),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 48),
          padding: EdgeInsets.symmetric(
            vertical: rail ? 12 : 10,
            horizontal: rail ? 12 : 4,
          ),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(rail ? 12 : 16),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .22),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: rail
              ? Row(
                  children: [
                    Icon(
                      icons[i],
                      color: selected ? Colors.white : accent,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          color: selected ? Colors.white : ink(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icons[i],
                      color: selected ? Colors.white : muted(context),
                      size: 21,
                    ),
                    const SizedBox(height: 5),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        style: TextStyle(
                          color: selected ? Colors.white : muted(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _bottomNav() => RepaintBoundary(
    child: Glass(
      key: tourKeys['tabs'],
      chrome: true,
      radius: 22,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(child: _tabItem(i, rail: false)),
          ],
        ],
      ),
    ),
  );

  Widget _toolRow(Tool t) => Semantics(
    selected: tool == t,
    child: Container(
      decoration: BoxDecoration(
        color: tool == t ? fill(context) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: WorkspaceRow(
        t.label,
        '',
        toolIcon(t),
        toolColor(t),
        onTap: () => menuAction(() => openTool(t)),
      ),
    ),
  );

  Widget _groupLabel(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 18, 0, 6),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        color: muted(context),
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: .8,
      ),
    ),
  );

  Future<void> _selectWorkspace(WorkspaceMode workspace) async {
    if (workspace == WorkspaceMode.service && !widget.prefs.developerMode) {
      final unlocked = await enterDeveloperMode(context, widget.prefs);
      if (!unlocked || !mounted) return;
    }
    await widget.prefs.setWorkspaceMode(workspace);
    if (!mounted) return;
    setState(() {
      tool = null;
      settingsOpen = false;
      faultsOpen = false;
      reportsOpen = false;
    });
  }

  Widget _workspaceRow(WorkspaceMode workspace) => WorkspaceRow(
    workspace.label,
    workspace.description,
    switch (workspace) {
      WorkspaceMode.owner => CupertinoIcons.person,
      WorkspaceMode.technician => CupertinoIcons.waveform_path_ecg,
      WorkspaceMode.service => CupertinoIcons.wrench,
    },
    workspace == WorkspaceMode.service ? danger : accent,
    trailing: widget.prefs.workspaceMode == workspace
        ? const Icon(CupertinoIcons.checkmark_circle_fill, color: accent)
        : workspace == WorkspaceMode.service && !widget.prefs.developerMode
        ? Icon(CupertinoIcons.lock, color: muted(context), size: 16)
        : null,
    onTap: () => menuAction(() => _selectWorkspace(workspace)),
  );

  /// Workspace-aware drawer: bottom destinations stay stable while this list
  /// reveals only the specialist windows relevant to the selected audience.
  List<Widget> _windows() {
    final workspace = widget.prefs.workspaceMode;
    final tools = Tool.values
        .where((t) => t.visibleIn(workspace))
        .where(
          (t) =>
              t != Tool.features &&
              t != Tool.controls &&
              t != Tool.recovery,
        )
        .toList();
    final groups = tools.map((t) => t.group).toSet();
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'Workspace',
          style: TextStyle(
            color: ink(context),
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: -.5,
          ),
        ),
      ),
      const SizedBox(height: 8),
      for (final workspace in WorkspaceMode.values) _workspaceRow(workspace),
      if (tools.isNotEmpty) ...[
        const SizedBox(height: 12),
        Divider(color: separator(context)),
      ],
      for (final group in groups) ...[
        _groupLabel(group),
        for (final t in tools.where((t) => t.group == group)) _toolRow(t),
      ],
      const SizedBox(height: 12),
      Divider(color: separator(context)),
      WorkspaceRow(
        'Reports',
        'Snapshots and session activity',
        CupertinoIcons.doc_text,
        purple,
        onTap: () => menuAction(openReports),
      ),
      WorkspaceRow(
        'Appearance',
        '',
        CupertinoIcons.circle_lefthalf_fill,
        purple,
        onTap: () => menuAction(appearance),
      ),
      WorkspaceRow(
        'Settings',
        '',
        CupertinoIcons.slider_horizontal_3,
        accent,
        onTap: () => menuAction(openSettings),
      ),
      if (widget.d.connected)
        WorkspaceRow(
          'Connection',
          widget.d.mode == 'SERVICE' ? 'Service mode' : '',
          CupertinoIcons.link,
          green,
          onTap: () => menuAction(connection),
        ),
    ];
  }

  Widget _sidebar({required bool rail, bool drawer = false}) => Glass(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const AppMark(),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'OpenOLA',
                style: TextStyle(
                  color: ink(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (drawer)
              IconButton(
                tooltip: 'Close tools',
                onPressed: () => scaffold.currentState?.closeDrawer(),
                icon: Icon(
                  CupertinoIcons.xmark,
                  color: muted(context),
                  size: 17,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              if (rail && !drawer) ...[
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _tabItem(i, rail: true),
                  ),
                const SizedBox(height: 14),
              ],
              ..._windows(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _page() {
    final d = widget.d;
    if (settingsOpen) {
      return SettingsPage(
        d: d,
        prefs: widget.prefs,
        onShowTutorial: () {
          setState(() => settingsOpen = false);
          showTour(context, anchors: tourKeys, onTab: _tourTab);
        },
        onEnterDeveloper: () => enterDeveloperMode(context, widget.prefs),
        onWorkspaceSelected: _selectWorkspace,
      );
    }
    if (faultsOpen) return FaultsPage(d: d);
    if (reportsOpen) return ReportsPage(d: d, state: reportState);
    if (tool != null) return AdvancedPage(tool: tool!, d: d);
    return switch (tab) {
      0 => d.connected ? HomePage(d: d, navigate: navigate) : ConnectPage(d: d),
      1 => BatteryPage(d: d),
      2 => FaultsPage(d: d),
      _ => OwnerControlsPage(d: d, openTool: openTool),
    };
  }

  /// Leaving the app mid-transfer can leave a half-written file on the scooter,
  /// so ask first (and offer to cancel or jump to the transfer).
  Future<void> _confirmLeaveDuringTransfer() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Transfer in progress'),
        content: const Text(
          'An APK is being sent to or pulled from the scooter. Leaving the app '
          'now can interrupt it and leave a partial file on the head unit.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'stay'),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel transfer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'leave'),
            child: const Text('Leave anyway', style: TextStyle(color: danger)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'cancel') {
      widget.d.cancelOperation();
    } else if (choice == 'leave') {
      await SystemNavigator.pop();
    }
  }

  Widget _connectionGate() => Scaffold(
    resizeToAvoidBottomInset: true,
    body: Stack(
      children: [
        const Positioned.fill(child: GlassWallpaper()),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: ListView(
                key: const ValueKey('connection-gate-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                children: [ConnectPage(d: widget.d)],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([widget.d, widget.prefs]),
    builder: (context, _) {
      final d = widget.d;
      if (!d.connected) return _connectionGate();
      final wide = MediaQuery.sizeOf(context).width >= 760;
      final liveWorkspace = tool == Tool.live && d.connected && !settingsOpen;
      return PopScope(
        canPop:
            !d.transferActive &&
            ((tool == null && !settingsOpen && !faultsOpen && !reportsOpen) ||
                drawerOpen),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop || drawerOpen) return;
          if (d.transferActive) {
            _confirmLeaveDuringTransfer();
            return;
          }
          if (tool != null || settingsOpen || faultsOpen || reportsOpen) {
            navigate(tab);
          }
        },
        child: Scaffold(
          key: scaffold,
          resizeToAvoidBottomInset: true,
          drawerScrimColor: Colors.black.withValues(alpha: .25),
          onDrawerChanged: (open) => setState(() => drawerOpen = open),
          drawer: wide
              ? null
              : Drawer(
                  width: MediaQuery.sizeOf(context).width * .86 > 320
                      ? 320
                      : MediaQuery.sizeOf(context).width * .86,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                      child: _sidebar(rail: true, drawer: true),
                    ),
                  ),
                ),
          body: Stack(
            children: [
              const Positioned.fill(child: GlassWallpaper()),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(wide ? 16 : 14),
                  child: BackdropGroup(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (wide) ...[
                          SizedBox(width: 240, child: _sidebar(rail: true)),
                          const SizedBox(width: 18),
                        ],
                        Expanded(
                          child: Column(
                            children: [
                              _toolbar(wide),
                              const SizedBox(height: 18),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1100,
                                    ),
                                    child: RepaintBoundary(
                                      child: liveWorkspace
                                          ? CustomScrollView(
                                              key: const ValueKey(
                                                'workspace-scroll',
                                              ),
                                              controller: controller,
                                              slivers: [
                                                LiveSignalsSlivers(d: d),
                                              ],
                                            )
                                          : ListView(
                                              key: const ValueKey(
                                                'workspace-scroll',
                                              ),
                                              controller: controller,
                                              padding: const EdgeInsets.only(
                                                bottom: 18,
                                              ),
                                              children: [
                                                AnimatedSwitcher(
                                                  // Snappier than the default so
                                                  // opening a tool feels instant.
                                                  duration: reduced(context)
                                                      ? Duration.zero
                                                      : const Duration(
                                                          milliseconds: 130,
                                                        ),
                                                  switchInCurve:
                                                      Curves.easeOutCubic,
                                                  child: BackdropGroup(
                                                    key: ValueKey(
                                                      settingsOpen
                                                          ? 'settings'
                                                          : tool?.name ?? tab,
                                                    ),
                                                    child: _page(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                              if (d.enteredServiceMode && !d.demo) ...[
                                const SizedBox(height: 10),
                                Glass(
                                  chrome: true,
                                  radius: 16,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    4,
                                    4,
                                    4,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.wrench_fill,
                                        size: 16,
                                        color: orange,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Service mode is on — the scooter’s own buttons may be limited.',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                        ),
                                      ),
                                      TextButton(
                                        key: const ValueKey(
                                          'leave-service-mode',
                                        ),
                                        onPressed: d.busy
                                            ? null
                                            : () => d.serviceMode(false),
                                        child: const Text('Return to Customer'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (d.busy || d.message.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Glass(
                                  chrome: true,
                                  radius: 16,
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    8,
                                    4,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      if (d.busy) ...[
                                        CupertinoActivityIndicator(
                                          animating: !reduced(context),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      Expanded(
                                        child: InkWell(
                                          key: const ValueKey(
                                            'operation-strip',
                                          ),
                                          onTap: d.transferActive
                                              ? () => openTool(Tool.headUnit)
                                              : null,
                                          child: Text(
                                            d.transferActive
                                                ? d.transferSummary
                                                : d.busy
                                                ? 'Operation in progress…'
                                                : d.message,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      if (d.busy)
                                        TextButton(
                                          key: const ValueKey(
                                            'cancel-operation',
                                          ),
                                          onPressed: d.cancelOperation,
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(color: danger),
                                          ),
                                        ),
                                      if (!d.busy)
                                        IconButton(
                                          tooltip: 'Dismiss message',
                                          onPressed: () {
                                            d.message = '';
                                            d.emit();
                                          },
                                          icon: const Icon(
                                            CupertinoIcons.xmark,
                                            size: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                              if (!wide &&
                                  MediaQuery.viewInsetsOf(context).bottom ==
                                      0) ...[
                                const SizedBox(height: 12),
                                _bottomNav(),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
