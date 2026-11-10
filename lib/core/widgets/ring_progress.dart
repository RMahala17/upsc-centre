import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A circular progress ring with a violet-to-teal gradient. [center] is drawn
/// in the middle.
class RingProgress extends StatelessWidget {
  const RingProgress({
    super.key,
    required this.fraction,
    required this.center,
    this.size = 170,
    this.strokeWidth = 14,
  });

  final double fraction;
  final Widget center;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              fraction: fraction.clamp(0.0, 1.0).toDouble(),
              stroke: strokeWidth,
              track: Theme.of(context).dividerColor,
            ),
          ),
          center,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.fraction,
    required this.stroke,
    required this.track,
  });

  final double fraction;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - stroke) / 2;
    final centre = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: centre, radius: radius);

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (fraction <= 0) return;

    final shader = const SweepGradient(
      colors: [Color(0xFF8B5CF6), Color(0xFF14B8A6)],
      transform: GradientRotation(-math.pi / 2),
    ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.stroke != stroke || old.track != track;
}
