import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'glass_quality.dart';
import 'verify_slider.dart';

const accent = Color(0xff007aff);
const danger = Color(0xffff453a);
bool dark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;
Color ink(BuildContext c) =>
    dark(c) ? const Color(0xfff5f5f7) : const Color(0xff1d1d1f);
Color muted(BuildContext c) => dark(c)
    ? const Color(0xffebebf5).withValues(alpha: .68)
    : const Color(0xff3c3c43).withValues(alpha: .72);
Color fill(BuildContext c) =>
    const Color(0xff787880).withValues(alpha: dark(c) ? .24 : .12);
Color separator(BuildContext c) => dark(c)
    ? const Color(0xff545458).withValues(alpha: .55)
    : const Color(0xff3c3c43).withValues(alpha: .14);
bool reduced(BuildContext c) => MediaQuery.disableAnimationsOf(c);
Duration motion(BuildContext c) =>
    reduced(c) ? Duration.zero : const Duration(milliseconds: 240);

ThemeData glassTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final text = isDark ? const Color(0xfff5f5f7) : const Color(0xff1d1d1f);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: Colors.transparent,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: isDark ? const Color(0xff1e2028) : const Color(0xffeef1f7),
    ),
    dividerColor: isDark ? const Color(0xff3a3a42) : const Color(0xffd6d6dd),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: text,
        fontSize: 30,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontSize: 25,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -.8,
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -.5,
      ),
      titleMedium: TextStyle(
        color: text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -.2,
      ),
      bodyLarge: TextStyle(color: text, fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(color: text, fontSize: 13, height: 1.45),
      bodySmall: TextStyle(color: text, fontSize: 11, height: 1.45),
      labelLarge: TextStyle(
        color: text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: accent,
      selectionColor: Color(0x44007aff),
    ),
  );
}

/// Match the four static ambient glows of tool/glass/web/style.css.
class GlassWallpaper extends StatelessWidget {
  const GlassWallpaper({super.key});
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _Wallpaper(dark(context)), size: Size.infinite),
  );
}

class _Wallpaper extends CustomPainter {
  const _Wallpaper(this.isDark);
  final bool isDark;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = isDark ? const Color(0xff07080c) : const Color(0xffeef1f7),
    );
    void glow(Offset center, double radius, Color color, double opacity) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            stops: const [0, .25, 1],
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * .8),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final w = size.width;
    final h = size.height;
    glow(
      Offset(w * -.1, h * -.03),
      w * 1.25,
      isDark ? const Color(0xff123a7a) : const Color(0xffb7d4ff),
      .95,
    );
    glow(
      Offset(w * 1.1, h * .42),
      w * 1.05,
      isDark ? const Color(0xff0d4a3a) : const Color(0xffc9f2dc),
      .88,
    );
    glow(
      Offset(w * .18, h * 1.1),
      w * .90,
      isDark ? const Color(0xff5a2a1a) : const Color(0xffffd9c2),
      .68,
    );
    glow(
      Offset(w * .9, h * .98),
      w * .86,
      isDark ? const Color(0xff3a1f6a) : const Color(0xffe5d4ff),
      .68,
    );
  }

  @override
  bool shouldRepaint(_Wallpaper old) => old.isDark != isDark;
}

class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 22,
    this.chrome = false,
    this.grouped = true,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool chrome, grouped;
  @override
  Widget build(BuildContext context) {
    final isDark = dark(context);
    final highContrast = MediaQuery.highContrastOf(context);
    final sigma = highContrast ? 0.0 : GlassQualityScope.sigmaOf(context);
    final blurOff = sigma <= 0;
    final shape = BorderRadius.circular(radius);
    final color = isDark
        ? (chrome ? const Color(0xff242630) : const Color(0xff1e2028))
        : Colors.white;
    var opacity = highContrast
        ? .98
        : chrome
        ? (isDark ? .82 : .78)
        : (isDark ? .52 : .58);
    // With no backdrop blur, raise the fill so the card still reads as a solid
    // frosted surface instead of a see-through tint.
    if (blurOff && !highContrast) opacity = (opacity + .26).clamp(0.0, .96);
    final content = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        color: color.withValues(alpha: opacity),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? .10 : .75),
        ),
      ),
      child: _GlassAncestor(
        child: Padding(padding: padding, child: child),
      ),
    );
    final filter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
    return Container(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : const Color(0xff1e2846)).withValues(
              alpha: isDark ? .24 : .08,
            ),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          children: [
            // No blur (lite tier / high contrast): render the fill directly and
            // skip the expensive BackdropFilter sampling entirely.
            if (blurOff)
              content
            else if (grouped &&
                context.getInheritedWidgetOfExactType<_GlassAncestor>() == null)
              BackdropFilter.grouped(filter: filter, child: content)
            else
              BackdropFilter(filter: filter, child: content),
            Positioned(
              top: 1,
              left: radius * .7,
              right: radius * .7,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withValues(alpha: isDark ? .065 : .4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassAncestor extends InheritedWidget {
  const _GlassAncestor({required super.child});
  @override
  bool updateShouldNotify(_GlassAncestor old) => false;
}

class GlassButton extends StatefulWidget {
  const GlassButton(
    this.label, {
    super.key,
    this.onPressed,
    this.icon,
    this.primary = false,
    this.destructive = false,
    this.compact = false,
    this.disabledReason,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary, destructive, compact;
  final String? disabledReason;
  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) {
    final tap =
        widget.onPressed ??
        (widget.disabledReason == null
            ? null
            : () =>
                  showInfoGlass(context, widget.label, widget.disabledReason!));
    final color = widget.primary
        ? Colors.white
        : widget.destructive
        ? danger
        : widget.compact
        ? accent
        : ink(context);
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      child: AnimatedScale(
        scale: pressed && !reduced(context) ? .97 : 1,
        duration: motion(context),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: widget.onPressed == null ? .42 : 1,
          child: GestureDetector(
            onTap: tap,
            onTapDown: widget.onPressed == null
                ? null
                : (_) => setState(() => pressed = true),
            onTapCancel: () => setState(() => pressed = false),
            onTapUp: (_) => setState(() => pressed = false),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 12 : 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: widget.primary
                    ? null
                    : widget.destructive
                    ? danger.withValues(alpha: .12)
                    : fill(context),
                gradient: widget.primary
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xff168bff), accent],
                      )
                    : null,
                border: Border.all(
                  color: widget.primary
                      ? Colors.white.withValues(alpha: .09)
                      : Colors.white.withValues(
                          alpha: dark(context) ? .025 : .24,
                        ),
                ),
                boxShadow: widget.primary && widget.onPressed != null
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: .22),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: widget.compact
                    ? MainAxisSize.min
                    : MainAxisSize.max,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: color, size: 17),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showInfoGlass(
  BuildContext context,
  String title,
  String message,
) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .3),
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: Glass(
        grouped: false,
        chrome: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(CupertinoIcons.info_circle, color: accent, size: 30),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: TextStyle(
                color: muted(context),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            GlassButton('OK', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  );
}

class GlassField extends StatelessWidget {
  const GlassField({
    super.key,
    required this.controller,
    required this.label,
    this.keyboard,
    this.enabled = true,
    this.suffix,
    this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final bool enabled;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          color: muted(context),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 7),
      Container(
        decoration: BoxDecoration(
          color: fill(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: separator(context).withValues(alpha: .14)),
        ),
        child: TextField(
          controller: controller,
          enabled: enabled,
          onChanged: onChanged,
          keyboardType: keyboard,
          autocorrect: false,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 15,
            ),
            suffixIcon: suffix,
          ),
        ),
      ),
    ],
  );
}

class GlassToggle extends StatelessWidget {
  const GlassToggle(
    this.title,
    this.subtitle,
    this.value,
    this.onChanged, {
    super.key,
  });
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: muted(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          label: title,
          child: CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xff34c759),
          ),
        ),
      ],
    ),
  );
}

class Section extends StatelessWidget {
  const Section(this.title, {super.key, required this.children, this.icon});
  final String title;
  final List<Widget> children;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Glass(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: ink(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, this.subtitle, {super.key});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(color: muted(context), fontSize: 13, height: 1.4),
        ),
      ],
    ),
  );
}

Future<T?> glassSheet<T>(BuildContext context, Widget child) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .28),
      builder: (c) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              24,
              12,
              12 + MediaQuery.viewInsetsOf(c).bottom,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Glass(
                grouped: false,
                chrome: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(c).height * .8,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 18),
                          decoration: BoxDecoration(
                            color: muted(c).withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// Gate for *extremely* dangerous actions (e.g. firmware flashing): the user
/// must type the exact [word] (default "CONFIRM") before the action is enabled.
/// Returns true only when they type it and tap the destructive button.
Future<bool> confirmTyped(
  BuildContext context, {
  required String title,
  required String message,
  String word = 'CONFIRM',
  String action = 'Proceed',
}) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .45),
      builder: (_) => _TypedConfirm(title, message, word, action),
    ) ??
    false;

class _TypedConfirm extends StatefulWidget {
  const _TypedConfirm(this.title, this.message, this.word, this.action);
  final String title, message, word, action;
  @override
  State<_TypedConfirm> createState() => _TypedConfirmState();
}

class _TypedConfirmState extends State<_TypedConfirm> {
  final controller = TextEditingController();
  bool get ok => controller.text.trim() == widget.word;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    child: Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Glass(
          grouped: false,
          chrome: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: danger.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.exclamationmark_octagon_fill,
                      color: danger,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  widget.message,
                  style: TextStyle(
                    color: muted(context),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Type ${widget.word} to enable',
                  style: TextStyle(
                    color: muted(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                GlassField(
                  controller: controller,
                  label: '',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                GlassButton(
                  widget.action,
                  destructive: true,
                  onPressed: ok ? () => Navigator.pop(context, true) : null,
                ),
                const SizedBox(height: 8),
                GlassButton(
                  'Cancel',
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<bool> confirmGlass(
  BuildContext context,
  String title,
  String message,
) async =>
    await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .3),
      builder: (_) => _Confirmation(title, message),
    ) ??
    false;

class _Confirmation extends StatelessWidget {
  const _Confirmation(this.title, this.message);
  final String title, message;
  @override
  Widget build(BuildContext context) => BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
    child: Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Glass(
          grouped: false,
          chrome: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xffff9500).withValues(alpha: .15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      CupertinoIcons.exclamationmark_shield,
                      color: Color(0xffff9500),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: TextStyle(
                    color: muted(context),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 18),
                SlideToVerify(onVerified: () => Navigator.pop(context, true)),
                const SizedBox(height: 8),
                GlassButton(
                  'Cancel',
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * .28),
    child: Image.asset(
      'assets/images/scooter.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
      semanticLabel: 'OpenOLA scooter',
    ),
  );
}
