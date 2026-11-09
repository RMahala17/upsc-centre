import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/parsing.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../timer/start_timer_action.dart';
import 'models/test_models.dart';
import 'test_controller.dart';
import 'test_dialog.dart';
import 'test_logic.dart';

const Color _warn = Color(0xFFD97706);

class TestsScreen extends ConsumerStatefulWidget {
  const TestsScreen({super.key});

  @override
  ConsumerState<TestsScreen> createState() => _TestsScreenState();
}

class _TestsScreenState extends ConsumerState<TestsScreen> {
  String? _category;

  Future<void> _add() async {
    final input = await showTestDialog(context);
    if (input == null || !mounted) return;
    await ref.read(testProvider.notifier).add(input);
  }

  Future<void> _edit(TestRecord t) async {
    final input = await showTestDialog(context, existing: t);
    if (input == null || !mounted) return;
    await ref.read(testProvider.notifier).edit(t.id, input);
  }

  Future<void> _delete(TestRecord t) async {
    final ctrl = ref.read(testProvider.notifier);
    await ctrl.remove(t.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Test deleted',
      onUndo: () => ctrl.restore(t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(testProvider).tests;
    final todayKey = dateKey(dateOnly(DateTime.now()));
    final shown = filterTests(all, category: _category);
    final stats = summarizeTests(shown);

    return Scaffold(
      appBar: AppBar(title: const Text('Test Series')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Test'),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                for (final c in TestCategory.all)
                  ChoiceChip(
                    label: Text(TestCategory.label(c)),
                    selected: _category == c,
                    onSelected: (_) =>
                        setState(() => _category = _category == c ? null : c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _StatsCard(stats: stats),
            const SizedBox(height: 16),
            if (all.isEmpty)
              const Text(
                'No tests yet. Tap "Test" to log one. Prelims GS and CSAT '
                'tests are scored from your correct and wrong counts with '
                'negative marking worked out for you.',
                style: TextStyle(color: AppColors.muted),
              )
            else if (shown.isEmpty)
              const Text(
                'No tests in this category.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              for (final t in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TestTile(
                    test: t,
                    phase: phaseOf(t, todayKey),
                    onEdit: () => _edit(t),
                    onTimer: () => startTimerFor(
                      context,
                      ref,
                      category: studyCategoryFor(t.category),
                      label: t.name,
                    ),
                    onToggleAnalysis: () =>
                        ref.read(testProvider.notifier).toggleAnalysis(t.id),
                    onDelete: () => _delete(t),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats});

  final TestStats stats;

  static String _pct(double? v) => v == null ? '–' : '${v.round()}%';

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
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final extra = <String>[
      if (stats.accuracy != null)
        'Accuracy ${(stats.accuracy! * 100).round()}% of answered',
      if (stats.negativeLost > 0)
        '−${formatNumber(stats.negativeLost)} marks lost to wrong answers',
      if (stats.analysisPending > 0)
        '${stats.analysisPending} analysis pending',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _stat('Taken', '${stats.taken}'),
                _stat('Average', _pct(stats.avgPercent)),
                _stat('Best', _pct(stats.bestPercent)),
                _stat('Latest', _pct(stats.lastPercent)),
              ],
            ),
            if (stats.recentPercents.length >= 2) ...[
              const SizedBox(height: 14),
              Text(
                'Last ${stats.recentPercents.length} tests (% of max marks)',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 6),
              _TrendBars(percents: stats.recentPercents),
            ],
            if (extra.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final line in extra)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      color: line.endsWith('analysis pending')
                          ? _warn
                          : AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A tiny bar trend, oldest on the left. Heights are % of max marks, never
/// below a thin sliver so a very low score is still visible.
class _TrendBars extends StatelessWidget {
  const _TrendBars({required this.percents});

  final List<double> percents;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final p in percents)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: (p / 100).clamp(0.04, 1.0).toDouble(),
                    widthFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.violet,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TestTile extends StatelessWidget {
  const _TestTile({
    required this.test,
    required this.phase,
    required this.onEdit,
    required this.onTimer,
    required this.onToggleAnalysis,
    required this.onDelete,
  });

  final TestRecord test;
  final TestPhase phase;
  final VoidCallback onEdit;
  final VoidCallback onTimer;
  final VoidCallback onToggleAnalysis;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = test;
    final date = DateFormat('d MMM yyyy').format(parseDateKey(t.date));
    final parts = <String>[
      TestCategory.label(t.category),
      if (t.series.isNotEmpty) t.series,
      date,
      if (t.timeMin > 0) '${t.timeMin} min',
    ];

    final String scoreText;
    Color scoreColor = AppColors.teal;
    switch (phase) {
      case TestPhase.done:
        final pct = percentOf(t);
        scoreText = '${formatNumber(t.score!)} / ${formatNumber(t.maxMarks)}'
            '${pct == null ? '' : '  ·  ${pct.round()}%'}';
      case TestPhase.upcoming:
        scoreText = 'Upcoming';
        scoreColor = AppColors.muted;
      case TestPhase.pending:
        scoreText = 'Add result';
        scoreColor = _warn;
    }

    String? mcqLine;
    if (phase == TestPhase.done && TestCategory.isMcq(t.category)) {
      final skipped = t.totalQuestions - t.correct - t.wrong;
      final lost = negativeLost(
        wrong: t.wrong,
        total: t.totalQuestions,
        maxMarks: t.maxMarks,
      );
      mcqLine = 'Right ${t.correct} · Wrong ${t.wrong} · '
          'Skipped ${skipped < 0 ? 0 : skipped} · '
          '−${formatNumber(lost)} from negatives';
    }

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
                      t.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      parts.join(' · '),
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scoreText,
                      style: TextStyle(
                        color: scoreColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (mcqLine != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        mcqLine,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (phase == TestPhase.done) ...[
                      const SizedBox(height: 2),
                      Text(
                        t.analysisDone ? 'Analysis done' : 'Analysis pending',
                        style: TextStyle(
                          color: t.analysisDone ? AppColors.muted : _warn,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (t.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        t.notes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                    case 'timer':
                      onTimer();
                    case 'analysis':
                      onToggleAnalysis();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text(
                      phase == TestPhase.done ? 'Edit' : 'Enter result / edit',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'timer',
                    child: Text('Start timer'),
                  ),
                  if (phase == TestPhase.done)
                    PopupMenuItem(
                      value: 'analysis',
                      child: Text(
                        t.analysisDone
                            ? 'Mark analysis not done'
                            : 'Mark analysis done',
                      ),
                    ),
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
