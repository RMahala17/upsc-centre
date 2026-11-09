import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'progress_bar.dart';

/// Amber used for "needs attention" text across screens.
const Color kWarn = Color(0xFFD97706);

/// One number with a label under it. Put several in a [StatRow].
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.color,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        if (caption != null)
          Text(
            caption!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
      ],
    );
  }
}

/// Equal-width row of [StatTile]s.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.tiles});

  final List<StatTile> tiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final t in tiles) Expanded(child: t)],
    );
  }
}

/// A label, a value on the right and a thin bar underneath.
class BreakdownRow extends StatelessWidget {
  const BreakdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.color = AppColors.teal,
    this.caption,
  });

  final String label;
  final String value;
  final double fraction;
  final Color color;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ProgressBar(value: fraction, color: color, height: 6),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class BarPoint {
  const BarPoint({
    required this.label,
    required this.value,
    this.valueLabel = '',
    this.highlight = false,
  });

  final String label;
  final double value;

  /// Small text above the bar (hidden when there are many bars).
  final String valueLabel;

  /// Drawn in the highlight colour (for example, today).
  final bool highlight;
}

/// Plain-widget bar chart (no chart package, so no API surprises).
class BarSeriesChart extends StatelessWidget {
  const BarSeriesChart({
    super.key,
    required this.points,
    this.color = AppColors.violet,
    this.highlightColor = AppColors.teal,
    this.height = 112,
    this.showValues = true,
    this.labelEvery = 1,
  });

  final List<BarPoint> points;
  final Color color;
  final Color highlightColor;
  final double height;
  final bool showValues;

  /// Show only every n-th label under the bars (1 = all).
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    var maxV = 0.0;
    for (final p in points) {
      maxV = math.max(maxV, p.value);
    }
    final barMax = math.max(20.0, height - 44);
    final slim = points.length > 14;
    final step = labelEvery < 1 ? 1 : labelEvery;

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < points.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    showValues && points[i].value > 0
                        ? points[i].valueLabel
                        : '',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: maxV <= 0
                        ? 3.0
                        : math.max(3.0, barMax * points[i].value / maxV),
                    margin: EdgeInsets.symmetric(horizontal: slim ? 1.5 : 6),
                    decoration: BoxDecoration(
                      color: points[i].highlight ? highlightColor : color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i % step == 0 ? points[i].label : '',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Simple line chart for percentages over time. Guide lines are drawn at
/// [guides] (for example 0, 50, 100).
class LineTrendChart extends StatelessWidget {
  const LineTrendChart({
    super.key,
    required this.values,
    this.minY = 0,
    this.maxY = 100,
    this.color = AppColors.teal,
    this.height = 120,
    this.guides = const [0, 50, 100],
  });

  final List<double> values;
  final double minY;
  final double maxY;
  final Color color;
  final double height;
  final List<double> guides;

  static const double _left = 34;
  static const double _pad = 8;

  double _yFor(double v) {
    final range = (maxY - minY) <= 0 ? 1.0 : maxY - minY;
    final inner = height - _pad * 2;
    return _pad + inner * (1 - (v - minY) / range);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _LinePainter(
                values: values,
                minY: minY,
                maxY: maxY,
                color: color,
                guides: guides,
                gridColor: Theme.of(context).dividerColor,
                left: _left,
                pad: _pad,
              ),
            ),
          ),
          for (final g in guides)
            if (g >= minY && g <= maxY)
              Positioned(
                left: 0,
                top: _yFor(g) - 7,
                child: Text(
                  '${g.round()}%',
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.values,
    required this.minY,
    required this.maxY,
    required this.color,
    required this.guides,
    required this.gridColor,
    required this.left,
    required this.pad,
  });

  final List<double> values;
  final double minY;
  final double maxY;
  final Color color;
  final List<double> guides;
  final Color gridColor;
  final double left;
  final double pad;

  @override
  void paint(Canvas canvas, Size size) {
    final range = (maxY - minY) <= 0 ? 1.0 : maxY - minY;
    final innerW = size.width - left - pad;
    final innerH = size.height - pad * 2;

    double yOf(double v) {
      final clamped = v < minY ? minY : (v > maxY ? maxY : v);
      return pad + innerH * (1 - (clamped - minY) / range);
    }

    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final g in guides) {
      if (g < minY || g > maxY) continue;
      final y = yOf(g);
      canvas.drawLine(Offset(left, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;

    Offset point(int i) {
      final x = values.length == 1
          ? left + innerW / 2
          : left + innerW * i / (values.length - 1);
      return Offset(x, yOf(values[i]));
    }

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final p = point(i);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    final dot = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(point(i), 3.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => true;
}
