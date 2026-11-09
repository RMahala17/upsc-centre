import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/streaks.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../timer/models/session_models.dart';
import '../timer/sessions_controller.dart';
import '../timer/start_timer_action.dart';
import 'ca_controller.dart';
import 'ca_dialog.dart';
import 'ca_logic.dart';
import 'models/ca_models.dart';

class CurrentAffairsScreen extends ConsumerStatefulWidget {
  const CurrentAffairsScreen({super.key});

  @override
  ConsumerState<CurrentAffairsScreen> createState() =>
      _CurrentAffairsScreenState();
}

class _CurrentAffairsScreenState extends ConsumerState<CurrentAffairsScreen> {
  String? _scope;
  String? _topic;
  String? _exam;
  bool _starredOnly = false;
  String _query = '';

  Future<void> _add(List<CaNote> all) async {
    final input = await showCaDialog(
      context,
      sourceSuggestions: sourceSuggestions(all),
    );
    if (input == null || !mounted) return;
    await ref.read(caProvider.notifier).add(input);
  }

  Future<void> _edit(CaNote n, List<CaNote> all) async {
    final input = await showCaDialog(
      context,
      existing: n,
      sourceSuggestions: sourceSuggestions(all),
    );
    if (input == null || !mounted) return;
    await ref.read(caProvider.notifier).edit(n.id, input);
  }

  Future<void> _delete(CaNote n) async {
    final ctrl = ref.read(caProvider.notifier);
    await ctrl.remove(n.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Note deleted',
      onUndo: () => ctrl.restore(n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(caProvider).notes;
    final today = dateOnly(DateTime.now());
    final due = dueNotes(all, today);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Current Affairs'),
          actions: [
            IconButton(
              tooltip: 'Start a current affairs timer',
              icon: const Icon(Icons.timer_outlined),
              onPressed: () => startTimerFor(
                context,
                ref,
                category: StudyCategory.currentAffairs,
                label: 'Current affairs',
              ),
            ),
          ],
          bottom: TabBar(
            tabs: [
              const Tab(text: 'Notes'),
              Tab(text: due.isEmpty ? 'Revise' : 'Revise (${due.length})'),
              const Tab(text: 'Overview'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _add(all),
          icon: const Icon(Icons.add),
          label: const Text('Note'),
        ),
        body: TabBarView(
          children: [
            _notesTab(all),
            PageBody(child: _reviseTab(all, due, today)),
            PageBody(child: _OverviewTab(all: all, today: today)),
          ],
        ),
      ),
    );
  }

  // ---------- Notes tab ----------

  Widget _filters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Search headlines, key points, sources',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _scope == null,
              onSelected: (_) => setState(() => _scope = null),
            ),
            for (final s in CaScope.all)
              ChoiceChip(
                label: Text(CaScope.label(s)),
                selected: _scope == s,
                onSelected: (_) =>
                    setState(() => _scope = _scope == s ? null : s),
              ),
            FilterChip(
              avatar: const Icon(Icons.star_outline, size: 18),
              label: const Text('Starred'),
              selected: _starredOnly,
              onSelected: (v) => setState(() => _starredOnly = v),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final e in CaExam.all)
              ChoiceChip(
                label: Text(CaExam.label(e)),
                selected: _exam == e,
                onSelected: (_) => setState(() => _exam = _exam == e ? null : e),
              ),
            DropdownButton<String?>(
              value: _topic,
              hint: const Text('Topic'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All topics'),
                ),
                for (final t in CaTopic.all)
                  DropdownMenuItem<String?>(
                    value: t,
                    child: Text(CaTopic.label(t)),
                  ),
              ],
              onChanged: (v) => setState(() => _topic = v),
            ),
          ],
        ),
      ],
    );
  }

  Widget _notesTab(List<CaNote> all) {
    final shown = filterNotes(
      all,
      scope: _scope,
      topic: _topic,
      exam: _exam,
      starredOnly: _starredOnly,
      query: _query,
    );

    // Flatten into date headers (String) and notes so a long list stays lazy.
    final rows = <Object>[];
    String? lastDay;
    for (final n in shown) {
      if (n.date != lastDay) {
        rows.add(n.date);
        lastDay = n.date;
      }
      rows.add(n);
    }

    final today = dateOnly(DateTime.now());

    return PageBody(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: rows.length + 2,
        itemBuilder: (context, i) {
          if (i == 0) return _filters();
          if (i == 1) {
            if (all.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'No notes yet. Tap "Note" to add today\'s headlines and key '
                  'points. Each note comes back for revision after 7, then '
                  '21, then 60 days.',
                  style: TextStyle(color: AppColors.muted),
                ),
              );
            }
            if (shown.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'No notes match these filters.',
                  style: TextStyle(color: AppColors.muted),
                ),
              );
            }
            return const SizedBox(height: 4);
          }
          final row = rows[i - 2];
          if (row is String) {
            return Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(
                DateFormat('EEE, d MMM y').format(parseDateKey(row)),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          }
          final n = row as CaNote;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CaTile(
              note: n,
              today: today,
              onEdit: () => _edit(n, all),
              onDelete: () => _delete(n),
            ),
          );
        },
      ),
    );
  }

  // ---------- Revise tab ----------

  Widget _reviseTab(List<CaNote> all, List<CaNote> due, DateTime today) {
    final ctrl = ref.read(caProvider.notifier);
    final upcoming = upcomingNotes(all, today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        Text(
          'Notes come back for revision ${kCaRevisionGaps[0]} days after their '
          'date, then ${kCaRevisionGaps[1]} and ${kCaRevisionGaps[2]} days '
          'after each revision.',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (due.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nothing due for revision right now.'),
            ),
          )
        else
          for (final n in due)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (n.summary.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          n.summary,
                          maxLines: 6,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _meta(n),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _revisionText(n, today),
                              style: const TextStyle(
                                color: kWarn,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => ctrl.markRevised(n.id),
                            icon: const Icon(Icons.check),
                            label: const Text('Revised'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Coming up in the next 7 days',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final n in upcoming)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    child: Text(
                      DateFormat('d MMM').format(nextRevisionDate(n)!),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

String _meta(CaNote n) {
  final exams = n.exams.map(CaExam.label).join(' + ');
  return [
    CaScope.label(n.scope),
    CaTopic.label(n.topic),
    if (n.source.isNotEmpty) n.source,
    exams,
  ].join(' · ');
}

String _revisionText(CaNote n, DateTime today) {
  final next = nextRevisionDate(n);
  if (next == null) return 'Revised ${n.revisions}× · all done';
  if (isDueForRevision(n, today)) {
    final d = caDaysOverdue(n, today);
    if (d == 0) return 'Revision due today';
    return 'Revision overdue by $d day${d == 1 ? '' : 's'}';
  }
  final base = n.revisions == 0 ? 'Not revised yet' : 'Revised ${n.revisions}×';
  return '$base · next ${DateFormat('d MMM').format(next)}';
}

class _CaTile extends ConsumerWidget {
  const _CaTile({
    required this.note,
    required this.today,
    required this.onEdit,
    required this.onDelete,
  });

  final CaNote note;
  final DateTime today;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(caProvider.notifier);
    final n = note;
    final due = isDueForRevision(n, today);
    final color = due
        ? kWarn
        : (isFullyRevised(n) ? AppColors.teal : AppColors.muted);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (n.summary.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        n.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _meta(n),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _revisionText(n, today),
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: n.starred ? 'Remove star' : 'Star',
                icon: Icon(
                  n.starred ? Icons.star : Icons.star_outline,
                  color: n.starred ? kWarn : AppColors.muted,
                ),
                onPressed: () => ctrl.toggleStar(n.id),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'revised':
                      ctrl.markRevised(n.id);
                    case 'reset':
                      ctrl.clearRevisions(n.id);
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  if (!isFullyRevised(n))
                    const PopupMenuItem(
                      value: 'revised',
                      child: Text('Mark revised'),
                    ),
                  if (n.revisions > 0)
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Reset revisions'),
                    ),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({required this.all, required this.today});

  final List<CaNote> all;
  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Add notes to see your current affairs coverage here.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    final sessions = ref.watch(sessionsProvider).sessions;
    final stats = summarizeCa(all, today);
    final days = caActiveDays(all, sessions);
    final streak = currentStreak(days, today);
    final longest = longestStreak(days);
    final perDay = notesPerDay(all, today, 14);
    final topics = countBy(all, (n) => n.topic);
    final scopes = countBy(all, (n) => n.scope);
    final months = notesPerMonth(all, today);
    final maxTopic = topics.isEmpty ? 1 : topics.first.count;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        SectionCard(
          title: 'At a glance',
          child: Column(
            children: [
              StatRow(
                tiles: [
                  StatTile(label: 'Notes', value: '${stats.total}'),
                  StatTile(label: 'Last 7 days', value: '${stats.last7Days}'),
                  StatTile(
                    label: 'Due to revise',
                    value: '${stats.due}',
                    color: stats.due > 0 ? kWarn : null,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              StatRow(
                tiles: [
                  StatTile(label: 'Starred', value: '${stats.starred}'),
                  StatTile(
                    label: 'Fully revised',
                    value: '${stats.fullyRevised}',
                  ),
                  StatTile(
                    label: 'Streak',
                    value: '${streak}d',
                    caption: 'best ${longest}d',
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Notes per day (last 14 days)',
          child: BarSeriesChart(
            points: [
              for (final d in perDay)
                BarPoint(
                  label: DateFormat('d').format(d.day),
                  value: d.count.toDouble(),
                  valueLabel: '${d.count}',
                  highlight: dateKey(d.day) == dateKey(today),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'By topic',
          child: Column(
            children: [
              for (final t in topics)
                BreakdownRow(
                  label: CaTopic.label(t.key),
                  value: '${t.count}',
                  fraction: t.count / maxTopic,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'By scope',
          child: Column(
            children: [
              for (final s in scopes)
                BreakdownRow(
                  label: CaScope.label(s.key),
                  value: '${s.count}',
                  fraction: s.count / stats.total,
                  color: AppColors.violet,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'By month',
          child: BarSeriesChart(
            points: [
              for (final m in months)
                BarPoint(
                  label: DateFormat('MMM')
                      .format(DateTime.parse('${m.key}-01')),
                  value: m.count.toDouble(),
                  valueLabel: '${m.count}',
                ),
            ],
          ),
        ),
      ],
    );
  }
}
