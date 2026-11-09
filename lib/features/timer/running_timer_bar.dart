import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/durations.dart';
import '../../core/widgets/tick_builder.dart';
import 'category_ui.dart';
import 'models/session_models.dart';
import 'timer_controller.dart';

/// Thin bar shown above every screen while a timer is running or paused, so
/// it is never forgotten. Hidden on the timer screen itself.
class RunningTimerBar extends ConsumerWidget {
  const RunningTimerBar({super.key, required this.location});

  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(timerProvider);
    if (t == null || location.startsWith('/timer')) {
      return const SizedBox.shrink();
    }
    final ctrl = ref.read(timerProvider.notifier);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      child: InkWell(
        onTap: () => context.go('/timer'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 20, color: categoryColor(t.category)),
              const SizedBox(width: 10),
              TickBuilder(
                active: t.running,
                builder: (context, nowMs) => Text(
                  formatClock(t.elapsedSec(nowMs)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  t.label.isEmpty ? StudyCategory.label(t.category) : t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              if (!t.running)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'Paused',
                    style: TextStyle(color: Color(0xFFD97706), fontSize: 12),
                  ),
                ),
              IconButton(
                tooltip: t.running ? 'Pause' : 'Resume',
                icon: Icon(t.running ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (t.running) {
                    ctrl.pause();
                  } else {
                    ctrl.resume();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
