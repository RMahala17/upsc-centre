import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import 'models/revision_models.dart';
import 'revision_controller.dart';
import 'revision_dialogs.dart';
import 'revision_logic.dart';
import 'revision_targets.dart';

const Color kWarn = Color(0xFFD97706);

String _fmt(DateTime d) => DateFormat('d MMM yyyy').format(d);

String dueText(RevisionCycle c, DateTime today) {
  if (!isActive(c)) {
    return 'Completed ${_fmt(parseDateKey(c.completedDate!))}';
  }
  final due = _fmt(cycleTarget(c));
  if (isOverdue(c, today)) {
    final n = daysOverdue(c, today);
    return 'Overdue by $n day${n == 1 ? '' : 's'} (was due $due)';
  }
  final until = daysUntilDue(c, today);
  if (currentDay(c, today) <= 0) {
    final s = -currentDay(c, today) + 1;
    return 'Starts in $s day${s == 1 ? '' : 's'} · due $due';
  }
  if (until == 0) return 'Due today';
  return 'Due in $until day${until == 1 ? '' : 's'} ($due)';
}

class RevisionScreen extends ConsumerWidget {
  const RevisionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(revisionProvider);
    final targets = ref.watch(revisionTargetsProvider);
    final ctrl = ref.read(revisionProvider.notifier);
    final today = dateOnly(DateTime.now());

    final summary = summarize(st.cycles, today);
    final active = st.cycles.where(isActive).toList()
      ..sort((a, b) => cycleTarget(a).compareTo(cycleTarget(b)));
    final overdue = active.where((c) => isOverdue(c, today)).toList();
    final upcoming = active.where((c) => !isOverdue(c, today)).toList();
    final completed = st.cycles.where((c) => !isActive(c)).toList()
      ..sort((a, b) => b.completedDate!.compareTo(a.completedDate!));

    final ready = <RevisionTarget>[
      for (final t in targets)
        if (t.fullyCompleted &&
            completedCycleCount(st.cycles, t.type, t.id) < kRequiredCycles &&
            !hasActiveCycle(st.cycles, t.type, t.id))
          t,
    ];

    Future<void> startCycle(RevisionTarget? initial) async {
      final input = await showNewCycleDialog(
        context,
        targets: targets,
        initial: initial,
      );
      if (input == null) return;
      final id = await ctrl.createCycle(
        type: input.target.type,
        targetId: input.target.id,
        targetName: input.target.name,
        start: input.start,
        length: input.length,
        topics: input.topics,
      );
      if (context.mounted) context.go('/revision/$id');
    }

    Widget header(String text, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            text,
            style: TextStyle(
              color: color ?? AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    Widget cycleCard(RevisionCycle c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CycleCard(
            cycle: c,
            name: cycleTargetName(c, targets),
            today: today,
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Revision')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => startCycle(null),
        icon: const Icon(Icons.add),
        label: const Text('New cycle'),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _SummaryCard(summary: summary),
            if (active.isNotEmpty) ...[
              const SizedBox(height: 12),
              _TodayCard(
                cycles: active,
                targets: targets,
                today: today,
              ),
            ],
            if (overdue.isNotEmpty) ...[
              header('Overdue', color: AppColors.danger),
              for (final c in overdue) cycleCard(c),
            ],
            if (upcoming.isNotEmpty) ...[
              header('Active and upcoming'),
              for (final c in upcoming) cycleCard(c),
            ],
            if (ready.isNotEmpty) ...[
              header('Ready for revision'),
              for (final t in ready)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReadyCard(
                    target: t,
                    doneCycles: completedCycleCount(st.cycles, t.type, t.id),
                    nextNumber: nextCycleNumber(st.cycles, t.type, t.id),
                    onStart: () => startCycle(t),
                  ),
                ),
            ],
            if (completed.isNotEmpty) ...[
              header('Completed cycles'),
              for (final c in completed.take(15)) cycleCard(c),
            ],
            if (st.cycles.isEmpty && ready.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'No revision cycles yet. Tap "New cycle" to start one. '
                  'Subjects whose lectures are all completed will also '
                  'appear here as ready for revision.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final RevisionSummary summary;
  const _SummaryCard({required this.summary});

  Widget _stat(String label, int value, {Color? color}) => Expanded(
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
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
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _stat('Active', summary.active),
            _stat(
              'Overdue',
              summary.overdue,
              color: summary.overdue > 0 ? AppColors.danger : null,
            ),
            _stat('Due in 7 days', summary.dueSoon),
            _stat('Completed', summary.completed),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  final List<RevisionCycle> cycles;
  final List<RevisionTarget> targets;
  final DateTime today;
  const _TodayCard({
    required this.cycles,
    required this.targets,
    required this.today,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(revisionProvider.notifier);
    final entries = <(RevisionCycle, RevisionItem)>[];
    for (final c in cycles) {
      for (final i in todaysItems(c, today)) {
        entries.add((c, i));
      }
    }
    if (entries.isEmpty) return const SizedBox.shrink();
    final done = entries.where((e) => e.$2.done).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Today's revision",
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                  Text(
                    '$done / ${entries.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            for (final (c, i) in entries)
              ListTile(
                dense: true,
                onTap: () => context.go('/revision/${c.id}'),
                leading: Checkbox(
                  value: i.done,
                  onChanged: (_) => ctrl.toggleItem(c.id, i.id),
                ),
                title: Text(
                  i.title,
                  style: i.done
                      ? const TextStyle(
                          color: AppColors.muted,
                          decoration: TextDecoration.lineThrough,
                        )
                      : null,
                ),
                subtitle: Text(
                  '${cycleTargetName(c, targets)} · Cycle ${c.number}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final RevisionCycle cycle;
  final String name;
  final DateTime today;
  const _CycleCard({
    required this.cycle,
    required this.name,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final overdue = isOverdue(cycle, today);
    final status = statusOf(cycle);
    final total = cycle.items.length;
    final done = cycle.items.where((i) => i.done).length;
    final behind = behindCount(cycle, today);

    final chipLabel = overdue ? 'Overdue' : cycleStatusLabel(status);
    final chipColor = overdue
        ? AppColors.danger
        : status == CycleStatus.completed
            ? AppColors.teal
            : status == CycleStatus.inProgress
                ? AppColors.violet
                : AppColors.muted;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/revision/${cycle.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$name · Cycle ${cycle.number}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  StatusChip(label: chipLabel, color: chipColor),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(
                value: total == 0 ? 0 : done / total,
                color: AppColors.teal,
              ),
              const SizedBox(height: 8),
              Text(
                '$done of $total items · ${dueText(cycle, today)}',
                style: TextStyle(
                  color: overdue ? AppColors.danger : AppColors.muted,
                  fontSize: 12,
                ),
              ),
              if (behind > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '$behind item${behind == 1 ? '' : 's'} behind schedule',
                    style: const TextStyle(color: kWarn, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  final RevisionTarget target;
  final int doneCycles;
  final int nextNumber;
  final VoidCallback onStart;
  const _ReadyCard({
    required this.target,
    required this.doneCycles,
    required this.nextNumber,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              target.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'All lectures completed · $doneCycles of $kRequiredCycles '
              'revision cycles done',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: onStart,
                child: Text('Start cycle $nextNumber'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
