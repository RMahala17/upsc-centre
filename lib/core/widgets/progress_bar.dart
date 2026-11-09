import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const ProgressBar({
    super.key,
    required this.value,
    this.color = AppColors.teal,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0).toDouble(),
        minHeight: height,
        backgroundColor: Theme.of(context).dividerColor,
        color: color,
      ),
    );
  }
}
