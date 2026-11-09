import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'timer_controller.dart';

/// Starts the stopwatch for [category] and opens the timer screen. If a timer
/// is already running nothing changes and a hint with an "Open" button shows.
Future<void> startTimerFor(
  BuildContext context,
  WidgetRef ref, {
  required String category,
  required String label,
  String? taskId,
}) async {
  final ok = await ref.read(timerProvider.notifier).start(
        category: category,
        label: label,
        taskId: taskId,
      );
  if (!context.mounted) return;
  if (ok) {
    context.go('/timer');
    return;
  }
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: const Text('A timer is already running. Save it first.'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () => context.go('/timer'),
      ),
    ),
  );
}
