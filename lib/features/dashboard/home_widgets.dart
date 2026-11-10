import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/durations.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/ring_progress.dart';
import '../../core/widgets/section_card.dart';
import '../planner/models/planner_models.dart';
import '../planner/planner_controller.dart';
import '../planner/planner_logic.dart';
import '../timer/category_ui.dart';
import '../timer/models/session_models.dart';
import '../timer/start_timer_action.dart';
import 'home_logic.dart';

const Color _kTealBright = Color(0xFF14B8A6);

/// App-bar title: logo badge, app name, exam label and today's date.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, required this.badge, required this.dateText});

  final String badge;
  final String dateText;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.violet, _kTealBright],
            ),
          ),
          child: const Text(
            'UPSC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'UPSC Command Centre',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                '$badge · $dateText',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Big ring with the overall progress and the GS / Anthropology split.
class OverviewCard extends StatelessWidget {
  const OverviewCard({
    super.key,
    required this.percent,
    required this.gsPercent,
    required this.anthroPercent,
    required this.onTap,
  });

  final int percent;
  final int gsPercent;
  final int anthroPercent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'PREP OVERVIEW',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              RingProgress(
                fraction: percent / 100,
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'GS & Anthro',
                      style: TextStyle(color: AppColors.muted, fontSize: 12),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Legend(
                    color: AppColors.violet,
                    label: 'GS',
                    value: '$gsPercent%',
                  ),
                  _Legend(
                    color: _kTealBright,
                    label: 'Anthro',
                    value: '$anthroPercent%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label ',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Compact card: title, big percent, one short caption and a thin bar.
class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.percent,
    required this.caption,
    required this.fraction,
    required this.color,
    required this.onTap,
  });

  final String title;
  final int percent;
  final String caption;
  final double fraction;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  caption,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 8),
              ProgressBar(value: fraction, color: color, height: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// The first unfinished task of today with a Start button.
class NextTargetCard extends ConsumerWidget {
  const NextTargetCard({super.key, required this.todayKey});

  final String todayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(plannerProvider).tasks;
    final next = nextTarget(all, todayKey);
    final todayCount = tasksOnDate(all, todayKey).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flag_outlined, size: 18, color: AppColors.violet),
                SizedBox(width: 8),
                Text(
                  'MY NEXT TARGET',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (next != null)
              ..._withTask(context, ref, next)
            else if (todayCount == 0) ...[
              const Text(
                'Nothing planned for today yet.',
                style: TextStyle(color: AppColors.muted),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/planner'),
                  child: const Text('Plan your day'),
                ),
              ),
            ] else
              const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppColors.teal),
                  SizedBox(width: 8),
                  Expanded(child: Text("All of today's tasks are done.")),
                ],
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _withTask(BuildContext context, WidgetRef ref, PlannerTask t) {
    return [
      Text(
        t.title,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      Text(
        [
          StudyCategory.label(t.category),
          if (t.plannedMin > 0) formatMinutes(t.plannedMin),
        ].join(' · '),
        style: TextStyle(color: categoryColor(t.category), fontSize: 13),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => startTimerFor(
                context,
                ref,
                category: t.category,
                label: t.title,
                taskId: t.id,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start now'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.outlined(
            tooltip: 'Mark done',
            icon: const Icon(Icons.check),
            onPressed: () => ref.read(plannerProvider.notifier).toggle(t.id),
          ),
        ],
      ),
    ];
  }
}

/// Monday to Sunday study time as horizontal bars, today highlighted.
class WeekHoursCard extends StatelessWidget {
  const WeekHoursCard({
    super.key,
    required this.days,
    required this.goalMin,
    required this.onTap,
  });

  final List<WeekDayHours> days;
  final int goalMin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final goalSec = math.max(goalMin * 60, 1);
    final scale = days.fold<int>(goalSec, (m, d) => math.max(m, d.sec));
    final weekSec = days.fold<int>(0, (a, d) => a + d.sec);
    final track = Theme.of(context).dividerColor;

    return SectionCard(
      title: 'Weekly study hours',
      trailing: Text(
        formatHm(weekSec),
        style: const TextStyle(color: AppColors.muted),
      ),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final d in days)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      d.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: d.isToday ? FontWeight.w800 : null,
                        color: d.isToday ? AppColors.teal : AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        children: [
                          Container(height: 12, color: track),
                          FractionallySizedBox(
                            widthFactor: (d.sec / scale).clamp(0.0, 1.0),
                            child: Container(
                              height: 12,
                              color: d.isToday
                                  ? AppColors.teal
                                  : AppColors.violet,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      d.sec > 0 ? formatHm(d.sec) : '-',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Text(
            'Bars are scaled to your daily goal of ${formatMinutes(goalMin)}.',
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
