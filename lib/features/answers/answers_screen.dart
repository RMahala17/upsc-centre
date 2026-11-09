import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/exam_papers.dart';
import '../../core/utils/parsing.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../timer/models/session_models.dart';
import '../timer/start_timer_action.dart';
import 'answer_controller.dart';
import 'answer_dialog.dart';
import 'answer_logic.dart';
import 'models/answer_models.dart';

const Color _warn = Color(0xFFD97706);

class AnswersScreen extends ConsumerStatefulWidget {
  const AnswersScreen({super.key});

  @override
  ConsumerState<AnswersScreen> createState() => _AnswersScreenState();
}

class _AnswersScreenState extends ConsumerState<AnswersScreen> {
  String? _paper;
  String? _status;

  Future<void> _add() async {
    final input = await showAnswerDialog(context);
    if (input == null || !mounted) return;
    await ref.read(answerProvider.notifier).add(input);
  }

  Future<void> _edit(AnswerEntry a) async {
    final input = await showAnswerDialog(context, existing: a);
    if (input == null || !mounted) return;
    await ref.read(answerProvider.notifier).edit(a.id, input);
  }

  Future<void> _delete(AnswerEntry a) async {
    final ctrl = ref.read(answerProvider.notifier);
    await ctrl.remove(a.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Answer deleted',
      onUndo: () => ctrl.restore(a),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(answerProvider).answers;
    final today = dateOnly(DateTime.now());
    final stats = summarizeAnswers(all, today);
    final breakdown = paperBreakdown(all);
    final shown = filterAnswers(all, paper: _paper, status: _status);

    return Scaffold(
      appBar: AppBar(title: const Text('Answer Writing')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Answer'),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _StatsCard(stats: stats, breakdown: breakdown),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All papers'),
                  selected: _paper == null,
                  onSelected: (_) => setState(() => _paper = null),
                ),
                for (final p in ExamPaper.mains)
                  ChoiceChip(
                    label: Text(ExamPaper.label(p)),
                    selected: _paper == p,
                    onSelected: (_) =>
                        setState(() => _paper = _paper == p ? null : p),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Any status'),
                  selected: _status == null,
                  onSelected: (_) => setState(() => _status = null),
                ),
                for (final s in AnswerStatus.all)
                  ChoiceChip(
                    label: Text(AnswerStatus.label(s)),
                    selected: _status == s,
                    onSelected: (_) =>
                        setState(() => _status = _status == s ? null : s),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (all.isEmpty)
              const Text(
                'No answers logged yet. Tap "Answer" after you write one: '
                'add the question, the marks and, once evaluated, the score '
                'and what to improve.',
                style: TextStyle(color: AppColors.muted),
              )
            else if (shown.isEmpty)
              const Text(
                'No answers match these filters.',
                style: TextStyle(color: AppColors.muted),
              )
            else
              for (final a in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _AnswerTile(
                    answer: a,
                    onEdit: () => _edit(a),
                    onTimer: () => startTimerFor(
                      context,
                      ref,
                      category: StudyCategory.answers,
                      label: a.question,
                    ),
                    onRewritten: () =>
                        ref.read(answerProvider.notifier).markRewritten(a.id),
                    onDelete: () => _delete(a),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.stats, required this.breakdown});

  final AnswerStats stats;
  final List<PaperStat> breakdown;

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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _stat('Last 7 days', '${stats.last7Days}'),
                _stat('Day streak', '${stats.streak}'),
                _stat(
                  'Avg score',
                  stats.avgPercent == null
                      ? '–'
                      : '${stats.avgPercent!.round()}%',
                ),
                _stat('Total', '${stats.total}'),
              ],
            ),
            if (stats.awaitingEvaluation > 0 || stats.needsRewrite > 0) ...[
              const SizedBox(height: 12),
              Text(
                [
                  if (stats.awaitingEvaluation > 0)
                    '${stats.awaitingEvaluation} awaiting evaluation',
                  if (stats.needsRewrite > 0)
                    '${stats.needsRewrite} to rewrite',
                ].join(' · '),
                style: const TextStyle(color: _warn),
              ),
            ],
            if (breakdown.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                'By paper',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 8),
              for (final b in breakdown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(ExamPaper.label(b.paper))),
                          Text(
                            b.avgPercent == null
                                ? '${b.count} written'
                                : '${b.count} written · '
                                    '${b.avgPercent!.round()}% avg',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (b.avgPercent != null) ...[
                        const SizedBox(height: 4),
                        ProgressBar(value: b.avgPercent! / 100, height: 6),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({
    required this.answer,
    required this.onEdit,
    required this.onTimer,
    required this.onRewritten,
    required this.onDelete,
  });

  final AnswerEntry answer;
  final VoidCallback onEdit;
  final VoidCallback onTimer;
  final VoidCallback onRewritten;
  final VoidCallback onDelete;

  IconData get _icon {
    switch (answer.status) {
      case AnswerStatus.evaluated:
        return Icons.check_circle_outline;
      case AnswerStatus.needsRewrite:
        return Icons.refresh;
      case AnswerStatus.rewritten:
        return Icons.task_alt;
      default:
        return Icons.edit_note_outlined;
    }
  }

  Color get _iconColor {
    switch (answer.status) {
      case AnswerStatus.evaluated:
      case AnswerStatus.rewritten:
        return AppColors.teal;
      case AnswerStatus.needsRewrite:
        return _warn;
      default:
        return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = answer;
    final date = DateFormat('d MMM').format(parseDateKey(a.date));
    final parts = <String>[
      ExamPaper.label(a.paper),
      '${a.marks} marks',
      if (a.wordLimit > 0) '${a.wordLimit} words',
      if (a.minutes > 0) '${a.minutes} min',
      date,
      if (a.topic.isNotEmpty) a.topic,
    ];
    final scoreText = a.score == null
        ? AnswerStatus.label(a.status)
        : '${formatNumber(a.score!)}/${a.marks}';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(_icon, color: _iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.question,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
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
                        color: _iconColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (a.feedback.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        a.feedback,
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
                    case 'rewritten':
                      onRewritten();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                    value: 'timer',
                    child: Text('Start timer'),
                  ),
                  if (a.status == AnswerStatus.needsRewrite)
                    const PopupMenuItem(
                      value: 'rewritten',
                      child: Text('Mark as rewritten'),
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
