import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../syllabus/models/syllabus_models.dart';
import 'models/revision_models.dart';
import 'revision_controller.dart';
import 'revision_dialogs.dart';
import 'revision_logic.dart';
import 'revision_screen.dart';
import 'revision_targets.dart';

String _fmt(DateTime d) => DateFormat('d MMM yyyy').format(d);

class _Entry {
  final int? day;
  final RevisionItem? item;
  const _Entry.header(this.day) : item = null;
  const _Entry.item(this.item) : day = null;
}

class CycleDetailScreen extends ConsumerWidget {
  final String cycleId;
  const CycleDetailScreen({super.key, required this.cycleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(revisionProvider);
    final targets = ref.watch(revisionTargetsProvider);
    final cycle = st.cycleById(cycleId);

    if (cycle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Revision cycle')),
        body: const Center(child: Text('This cycle no longer exists.')),
      );
    }

    final ctrl = ref.read(revisionProvider.notifier);
    final today = dateOnly(DateTime.now());
    final name = cycleTargetName(cycle, targets);

    final byDay = <int, List<RevisionItem>>{};
    for (final i in cycle.items) {
      byDay.putIfAbsent(i.day, () => []).add(i);
    }
    final days = byDay.keys.toList()..sort();
    final entries = <_Entry>[];
    for (final d in days) {
      entries.add(_Entry.header(d));
      final list = byDay[d]!..sort((a, b) => a.order.compareTo(b.order));
      for (final i in list) {
        entries.add(_Entry.item(i));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('$name · Cycle ${cycle.number}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'schedule') {
                final r = await showScheduleDialog(
                  context,
                  start: cycleStart(cycle),
                  length: cycle.lengthDays,
                );
                if (r == null) return;
                await ctrl.updateSchedule(cycle.id, r.$1, r.$2);
              } else if (v == 'spread') {
                final ok = await confirmDialog(
                  context,
                  title: 'Spread topics evenly?',
                  message: 'Topic items will be re-assigned evenly across the '
                      'plan days. Your ticks are kept.',
                  confirmLabel: 'Spread',
                );
                if (ok) await ctrl.redistribute(cycle.id);
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete cycle?',
                  message: 'Delete this revision cycle and its checklist? '
                      'This cannot be undone.',
                );
                if (!ok) return;
                await ctrl.deleteCycle(cycle.id);
                if (context.mounted) context.go('/revision');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'schedule', child: Text('Edit schedule')),
              PopupMenuItem(value: 'spread', child: Text('Spread topics evenly')),
              PopupMenuItem(value: 'delete', child: Text('Delete cycle')),
            ],
          ),
        ],
      ),
      body: PageBody(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: 3 + (entries.isEmpty ? 1 : entries.length),
          itemBuilder: (context, i) {
            if (i == 0) return _OverviewCard(cycle: cycle, today: today);
            if (i == 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _ActionsCard(cycle: cycle),
              );
            }
            if (i == 2) return _ChecklistHeader(cycle: cycle, today: today);
            if (entries.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'The checklist is empty. Use "Add" or "Paste".',
                  style: TextStyle(color: AppColors.muted),
                ),
              );
            }
            final e = entries[i - 3];
            if (e.item != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ItemTile(cycle: cycle, item: e.item!),
              );
            }
            final day = e.day!;
            final list = byDay[day]!;
            final done = list.where((x) => x.done).length;
            final date = addDays(cycleStart(cycle), day - 1);
            final isToday = date == today;
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Day $day · ${DateFormat('EEE, d MMM').format(date)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isToday)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: StatusChip(label: 'Today', color: AppColors.teal),
                    ),
                  Text(
                    '$done/${list.length}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final RevisionCycle cycle;
  final DateTime today;
  const _OverviewCard({required this.cycle, required this.today});

  Widget _col(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip(label: chipLabel, color: chipColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dueText(cycle, today),
                    style: TextStyle(
                      color: overdue ? AppColors.danger : AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _col('Start', _fmt(cycleStart(cycle))),
                _col('Target', _fmt(cycleTarget(cycle))),
                _col(
                  'Completed',
                  cycle.completedDate == null
                      ? '—'
                      : _fmt(parseDateKey(cycle.completedDate!)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ProgressBar(value: total == 0 ? 0 : done / total),
            const SizedBox(height: 8),
            Text(
              '$done of $total items done',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
    );
  }
}

class _ActionsCard extends ConsumerWidget {
  final RevisionCycle cycle;
  const _ActionsCard({required this.cycle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(revisionProvider.notifier);
    final pending = cycle.items.where((i) => !i.done).length;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: isActive(cycle)
                  ? FilledButton(
                      onPressed: () async {
                        if (pending > 0) {
                          final ok = await confirmDialog(
                            context,
                            title: 'Mark cycle complete?',
                            message: '$pending item${pending == 1 ? ' is' : 's are'} '
                                'not ticked. Mark the cycle complete anyway?',
                            confirmLabel: 'Mark complete',
                          );
                          if (!ok) return;
                        }
                        await ctrl.completeCycle(cycle.id, DateTime.now());
                      },
                      child: const Text('Mark cycle complete'),
                    )
                  : OutlinedButton(
                      onPressed: () => ctrl.reopenCycle(cycle.id),
                      child: const Text('Reopen cycle'),
                    ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('PYQ practice'),
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<TrackStatus>(
                value: cycle.pyqStatus,
                items: [
                  for (final s in TrackStatus.values)
                    DropdownMenuItem(value: s, child: Text(trackStatusLabel(s))),
                ],
                onChanged: (v) {
                  if (v != null) ctrl.setPyqStatus(cycle.id, v);
                },
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Notes'),
            subtitle: Text(
              cycle.notes.isEmpty ? 'No notes yet' : cycle.notes,
              style: const TextStyle(color: AppColors.muted),
            ),
            trailing: const Icon(Icons.edit_outlined, size: 20),
            onTap: () async {
              final t = await showNotesDialog(context, initial: cycle.notes);
              if (t == null) return;
              await ctrl.setNotes(cycle.id, t);
            },
          ),
        ],
      ),
    );
  }
}

class _ChecklistHeader extends ConsumerWidget {
  final RevisionCycle cycle;
  final DateTime today;
  const _ChecklistHeader({required this.cycle, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(revisionProvider.notifier);
    final startDay = currentDay(cycle, today).clamp(1, cycle.lengthDays);

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Checklist',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final r = await showPasteItemsDialog(
                context,
                length: cycle.lengthDays,
                initialDay: startDay,
              );
              if (r == null) return;
              await ctrl.addItems(cycle.id, r.$1, r.$2);
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Paste'),
          ),
          TextButton.icon(
            onPressed: () async {
              final r = await showItemDialog(
                context,
                length: cycle.lengthDays,
                initialDay: startDay,
                dialogTitle: 'Add item',
              );
              if (r == null) return;
              await ctrl.addItems(cycle.id, [r.$1], r.$2);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final RevisionCycle cycle;
  final RevisionItem item;
  const _ItemTile({required this.cycle, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(revisionProvider.notifier);
    final doneAt =
        item.doneAt == null ? null : DateTime.tryParse(item.doneAt!)?.toLocal();

    return Card(
      child: ListTile(
        onTap: () => ctrl.toggleItem(cycle.id, item.id),
        leading: Checkbox(
          value: item.done,
          onChanged: (_) => ctrl.toggleItem(cycle.id, item.id),
        ),
        title: Text(
          item.title,
          style: item.done
              ? const TextStyle(
                  color: AppColors.muted,
                  decoration: TextDecoration.lineThrough,
                )
              : null,
        ),
        subtitle: doneAt == null
            ? null
            : Text(
                'Done ${_fmt(doneAt)}',
                style: const TextStyle(fontSize: 12),
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              final r = await showItemDialog(
                context,
                length: cycle.lengthDays,
                initialTitle: item.title,
                initialDay: item.day,
                dialogTitle: 'Edit item',
              );
              if (r == null) return;
              await ctrl.editItem(cycle.id, item.id, title: r.$1, day: r.$2);
            } else if (v == 'delete') {
              final ok = await confirmDialog(
                context,
                title: 'Delete item?',
                message: 'Delete "${item.title}"?',
              );
              if (!ok) return;
              await ctrl.deleteItem(cycle.id, item.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
