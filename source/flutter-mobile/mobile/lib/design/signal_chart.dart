import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass.dart';

/// A single physical scale per chart; unlike mixed-unit overlays, axes stay meaningful.
class SignalChart extends StatelessWidget {
  const SignalChart(
    this.points, {
    super.key,
    this.unit = '',
    this.color = accent,
  });
  final List<(double, double)> points;
  final String unit;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const SizedBox(
        height: 190,
        child: Center(child: Text('Waiting for fresh samples')),
      );
    }
    final min = points.map((p) => p.$2).reduce(math.min),
        max = points.map((p) => p.$2).reduce(math.max);
    return Semantics(
      label:
          'Trend, ${points.length} points. Minimum ${min.toStringAsFixed(2)}, maximum ${max.toStringAsFixed(2)} $unit.',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${max.toStringAsFixed(2)} $unit',
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
              Text(
                'Latest ${points.last.$2.toStringAsFixed(2)} $unit',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 190,
            width: double.infinity,
            child: CustomPaint(
              painter: _Chart(points, color, separator(context), min, max),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${points.first.$1.toStringAsFixed(0)} s',
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
              Text(
                '${min.toStringAsFixed(2)} $unit · minimum',
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
              Text(
                '${points.last.$1.toStringAsFixed(0)} s',
                style: TextStyle(color: muted(context), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chart extends CustomPainter {
  _Chart(this.points, this.color, this.grid, this.min, this.max);
  final List<(double, double)> points;
  final Color color, grid;
  final double min, max;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = grid.withValues(alpha: .3)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      canvas.drawLine(
        Offset(0, i * size.height / 3),
        Offset(size.width, i * size.height / 3),
        p,
      );
    }
    final spread = max - min,
        padding = spread == 0 ? math.max(min.abs() * .01, 1.0) : spread * .12;
    final lo = min - padding, range = max + padding - lo;
    final first = points.first.$1,
        timeRange = math.max(1.0, points.last.$1 - first);
    Offset pos((double, double) point) => Offset(
      (point.$1 - first) / timeRange * size.width,
      size.height - (point.$2 - lo) / range * size.height,
    );
    final path = Path();
    Offset? previous;
    for (final point in points) {
      final current = pos(point);
      // Missing telemetry creates a visible break rather than an invented plateau.
      if (previous == null || point.$1 - previous.dx > 3.1) {
        path.moveTo(current.dx, current.dy);
      } else {
        path.lineTo(current.dx, current.dy);
      }
      previous = Offset(point.$1, point.$2);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(pos(points.last), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _Chart old) =>
      old.points != points || old.color != color || old.grid != grid;
}
