import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/durations.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../anthropology/anthro_controller.dart';
import '../revision/models/revision_models.dart';
import '../revision/revision_controller.dart';
import '../revision/revision_logic.dart';
import '../revision/revision_targets.dart';
import '../syllabus/syllabus_controller.dart';
import '../timer/models/session_models.dart';
import '../timer/sessions_controller.dart';
import '../timer/timer_controller.dart';
import '../timer/timer_logic.dart';
import 'models/planner_models.dart';
import 'planner_controller.dart';
import 'planner_logic.dart';
import 'task_dialog.dart';

const Color _warn = Color(0xFFD97706);

class PlannerScreen extends ConsumerStatefulWidget {
  const PlannerScreen({super.key});

  @override
  ConsumerState<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends ConsumerState<PlannerScreen> {
  late DateTime _day = dateOnly(DateTime.now());

  bool get _isToday => daysBetween(_day, dateOnly(DateTime.now())) == 0;

  void _shift(int n) => setState(() => _day = addDays(_day, n));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _day = dateOnly(picked));
  }

  // ---------- actions ----------

  Future<void> _addTasks() async {
    final input = await showTaskDialog(context);
    if (input == null || !mounted) return;
    await ref.read(plannerProvider.notifier).add(
          date: _day,
          titles: input.titles,
          category: input.category,
          plannedMin: input.plannedMin,
        );
  }

  Future<void> _editTask(PlannerTask t) async {
    final input = await showTaskDialog(context, existing: t);
    if (input == null || !mounted) return;
    await ref.read(plannerProvider.notifier).edit(
          t.id,
          title: input.titles.first,
          category: input.category,
          plannedMin: input.plannedMin,
        );
  }

  Future<void> _deleteTask(PlannerTask t) async {
    final ctrl = ref.read(plannerProvider.notifier);
    await ctrl.remove(t.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Task deleted',
      onUndo: () => ctrl.restore(t),
    );
  }

  Future<void> _carryOver() async {
    final n = await ref.read(plannerProvider.notifier).carryOver(_day);
    if (!mounted || n == 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Moved $n task${n == 1 ? '' : 's'} to today')),
    );
  }

  Future<void> _startTimer(PlannerTask t) async {
    final ok = await ref.read(timerProvider.notifier).start(
          category: t.category,
          label: t.title,
          taskId: t.id,
        );
    if (!mounted) return;
    if (ok) {
      context.go('/timer');
    } else {
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
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(plannerProvider).tasks;
    final sessions = ref.watch(sessionsProvider).sessions;
    final rev = ref.watch(revisionProvider);
    final targets = ref.watch(revisionTargetsProvider);
    final anthro = ref.watch(anthroProvider);
    final gs = ref.watch(syllabusProvider);

    final key = dateKey(_day);
    final tasks = tasksOnDate(all, key);
    final summary = summarizeDay(tasks);
    final studiedSec = totalSecOnDate(sessions, key);
    final carry = _isToday ? unfinishedBefore(all, key) : <PlannerTask>[];

    final revEntries = <(RevisionCycle, List<RevisionItem>)>[];
    var behind = 0;
    for (final c in rev.cycles) {
      final items = todaysItems(c, _day);
      if (items.isNotEmpty) revEntries.add((c, items));
      if (_isToday) behind += behindCount(c, _day);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Planner')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTasks,
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _DateBar(
              day: _day,
              isToday: _isToday,
              onPrev: () => _shift(-1),
              onNext: () => _shift(1),
              onPick: _pickDay,
              onToday: () => setState(() => _day = dateOnly(DateTime.now())),
            ),
            const SizedBox(height: 8),
            _SummaryCard(summary: summary, studiedSec: studiedSec),
            if (carry.isNotEmpty) ...[
              const SizedBox(height: 12),
              _CarryCard(count: carry.length, onCarry: _carryOver),
            ],
            if (revEntries.isNotEmpty || behind > 0) ...[
              const SizedBox(height: 12),
              _RevisionCard(
                entries: revEntries,
                targets: targets,
                behind: behind,
              ),
            ],
            const SizedBox(height: 12),
            _TargetsCard(
              anthroDone: anthro.completedOn(_day),
              anthroTarget: anthro.dailyTarget,
              gsDone: lecturesCompletedOn(gs.lectures, _day),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                'Tasks',
                style: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Nothing planned for this day. Tap "Task" to plan it. '
                  'You can paste several tasks at once, one per line.',
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              for (final t in tasks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TaskTile(
                    task: t,
                    spentSec: secOnTask(sessions, t.id),
                    onToggle: () =>
                        ref.read(plannerProvider.notifier).toggle(t.id),
                    onStart: () => _startTimer(t),
                    onEdit: () => _editTask(t),
                    onMoveNext: () => ref
                        .read(plannerProvider.notifier)
                        .moveToDate(t.id, addDays(_day, 1)),
                    onDelete: () => _deleteTask(t),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _DateBar extends StatelessWidget {
  const _DateBar({
    required this.day,
    required this.isToday,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
    required this.onToday,
  });

  final DateTime day;
  final bool isToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final label =
        '${isToday ? 'Today · ' : ''}${DateFormat('EEE, d MMM yyyy').format(day)}';
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous day',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrev,
        ),
        Expanded(
          child: TextButton(
            onPressed: onPick,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(
          tooltip: 'Next day',
          icon: const Icon(Icons.chevron_right),
          onPressed: onNext,
        ),
        if (!isToday) TextButton(onPressed: onToday, child: const Text('Today')),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, required this.studiedSec});

  final DayPlanSummary summary;
  final int studiedSec;

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
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
        child: Column(
          children: [
            Row(
              children: [
                _stat('Tasks done', '${summary.done}/${summary.total}'),
                _stat('Studied', formatHm(studiedSec)),
                _stat(
                  'Planned',
                  summary.plannedMin > 0 ? formatMinutes(summary.plannedMin) : '–',
                ),
              ],
            ),
            if (summary.total > 0) ...[
              const SizedBox(height: 12),
              ProgressBar(value: summary.fraction),
            ],
          ],
        ),
      ),
    );
  }
}

class _CarryCard extends StatelessWidget {
  const _CarryCard({required this.count, required this.onCarry});

  final int count;
  final VoidCallback onCarry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.history, color: _warn),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$count unfinished task${count == 1 ? '' : 's'} from earlier days',
              ),
            ),
            FilledButton.tonal(
              onPressed: onCarry,
              child: const Text('Carry over'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisionCard extends ConsumerWidget {
  const _RevisionCard({
    required this.entries,
    required this.targets,
    required this.behind,
  });

  final List<(RevisionCycle, List<RevisionItem>)> entries;
  final List<RevisionTarget> targets;
  final int behind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(revisionProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Revision for this day',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            for (final (c, items) in entries) ...[
              InkWell(
                onTap: () => context.go('/revision/${c.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Text(
                    '${cycleTargetName(c, targets)} · Cycle ${c.number}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              for (final i in items)
                ListTile(
                  dense: true,
                  leading: Checkbox(
                    value: i.done,
                    onChanged: (_) => ctrl.toggleItem(c.id, i.id),
                  ),
                  title: Text(
                    i.title,
                    style: i.done
                        ? const TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.muted,
                          )
                        : null,
                  ),
                ),
            ],
            if (behind > 0)
              InkWell(
                onTap: () => context.go('/revision'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '$behind earlier revision item${behind == 1 ? '' : 's'} '
                    'still pending',
                    style: const TextStyle(color: _warn),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({
    required this.anthroDone,
    required this.anthroTarget,
    required this.gsDone,
  });

  final int anthroDone;
  final int anthroTarget;
  final int gsDone;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Lectures completed',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(child: Text('Anthropology')),
                Text(
                  anthroTarget > 0
                      ? '$anthroDone / $anthroTarget'
                      : '$anthroDone (no daily target)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (anthroTarget > 0) ...[
              const SizedBox(height: 6),
              ProgressBar(value: anthroDone / anthroTarget),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('GS')),
                Text(
                  '$gsDone',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.spentSec,
    required this.onToggle,
    required this.onStart,
    required this.onEdit,
    required this.onMoveNext,
    required this.onDelete,
  });

  final PlannerTask task;
  final int spentSec;
  final VoidCallback onToggle;
  final VoidCallback onStart;
  final VoidCallback onEdit;
  final VoidCallback onMoveNext;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = task;
    final parts = <String>[
      StudyCategory.label(t.category),
      if (t.plannedMin > 0) '${formatMinutes(t.plannedMin)} planned',
      if (spentSec > 0) '${formatHm(spentSec)} studied',
      if (t.carryCount > 0) 'carried over ×${t.carryCount}',
    ];
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 4),
        leading: Checkbox(value: t.done, onChanged: (_) => onToggle()),
        title: Text(
          t.title,
          style: t.done
              ? const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: AppColors.muted,
                )
              : null,
        ),
        subtitle: Text(
          parts.join(' · '),
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!t.done)
              IconButton(
                tooltip: 'Start timer',
                icon: const Icon(Icons.play_circle_outline),
                onPressed: onStart,
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    onEdit();
                  case 'next':
                    onMoveNext();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'next', child: Text('Move to next day')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
