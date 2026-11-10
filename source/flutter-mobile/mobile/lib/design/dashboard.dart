import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'glass.dart';

const green = Color(0xff34c759);
const orange = Color(0xffff9500);
const purple = Color(0xffaf52de);
const teal = Color(0xff30b0c7);

/// The compact colored icon tiles used throughout the desktop GUI.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, this.color, {super.key, this.size = 36});
  final IconData icon;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, .30)!, color],
      ),
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: .15),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * .52),
  );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color, this.icon, this.onTap});
  final String label;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final tone = color ?? muted(context);
    return Semantics(
      button: onTap != null,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: onTap == null ? 28 : 44),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color == null ? fill(context) : tone.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: tone),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  style: TextStyle(
                    color: tone,
                    fontSize: 11,
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
}

class BatteryRing extends StatelessWidget {
  const BatteryRing(this.value, {super.key, this.size = 144});
  final double? value;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: value == null
        ? 'Battery charge unavailable'
        : 'Battery charge ${value!.round()} percent',
    child: SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: ((value ?? 0) / 100).clamp(0, 1)),
              duration: reduced(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (_, amount, _) =>
                  CustomPaint(painter: _Ring(amount, fill(context))),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: value == null ? '—' : value!.toStringAsFixed(0),
                          style: TextStyle(
                            color: ink(context),
                            fontSize: 39,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1.8,
                          ),
                        ),
                        TextSpan(
                          text: '%',
                          style: TextStyle(
                            color: muted(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Battery',
                  style: TextStyle(
                    color: muted(context),
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Ring extends CustomPainter {
  const _Ring(this.value, this.track);
  final double value;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(7);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(rect, paint..color = track);
    if (value <= 0) return;
    paint.shader = const SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: math.pi * 1.5,
      colors: [green, teal, green],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(rect);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5)
        ..color = green.withValues(alpha: .20),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint
        ..maskFilter = null
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_Ring old) => value != old.value || track != old.track;
}

class MetricValue extends StatelessWidget {
  const MetricValue(
    this.label,
    this.value, {
    super.key,
    this.unit = '',
    this.compact = false,
  });
  final String label, value, unit;
  final bool compact;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: TextStyle(
          color: muted(context),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 3),
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: value,
              style: TextStyle(
                color: ink(context),
                fontSize: compact ? 20 : 25,
                fontWeight: FontWeight.w700,
                letterSpacing: -.7,
              ),
            ),
            if (unit.isNotEmpty)
              TextSpan(
                text: ' $unit',
                style: TextStyle(
                  color: muted(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class WorkspaceTile extends StatelessWidget {
  const WorkspaceTile(
    this.title,
    this.subtitle,
    this.icon,
    this.color, {
    super.key,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Glass(
        padding: const EdgeInsets.all(14),
        radius: 18,
        child: Row(
          children: [
            IconTile(icon, color, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ink(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: muted(context),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class WorkspaceRow extends StatelessWidget {
  const WorkspaceRow(
    this.title,
    this.subtitle,
    this.icon,
    this.color, {
    super.key,
    this.onTap,
    this.trailing,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      // Make the whole row tappable, not just the icon/text/chevron pixels.
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            IconTile(icon, color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: ink(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: muted(context),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ] else if (onTap != null)
              Icon(
                CupertinoIcons.chevron_right,
                color: muted(context),
                size: 14,
              ),
          ],
        ),
      ),
    ),
  );
}
