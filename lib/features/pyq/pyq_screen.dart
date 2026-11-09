import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/exam_papers.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../syllabus/syllabus_controller.dart';
import 'models/pyq_models.dart';
import 'pyq_controller.dart';
import 'pyq_dialogs.dart';
import 'pyq_logic.dart';

const Color _warn = Color(0xFFD97706);

class PyqScreen extends ConsumerStatefulWidget {
  const PyqScreen({super.key});

  @override
  ConsumerState<PyqScreen> createState() => _PyqScreenState();
}

class _PyqScreenState extends ConsumerState<PyqScreen> {
  String? _exam;
  String? _status;
  int? _year;
  bool _starredOnly = false;
  String _query = '';

  int _defaultYear(List<Pyq> all) {
    if (all.isEmpty) return DateTime.now().year;
    return all.map((p) => p.year).reduce((a, b) => a > b ? a : b);
  }

  List<String> _suggestions(List<Pyq> all) {
    final subjects = ref.read(syllabusProvider).subjects.map((s) => s.name);
    return topicSuggestions(all, subjects);
  }

  Future<void> _add(List<Pyq> all) async {
    final input = await showPyqDialog(
      context,
      defaultYear: _defaultYear(all),
      suggestions: _suggestions(all),
    );
    if (input == null || !mounted) return;
    final n = await ref.read(pyqProvider.notifier).add(input);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $n question${n == 1 ? '' : 's'}')),
    );
  }

  Future<void> _edit(Pyq p, List<Pyq> all) async {
    final input = await showPyqDialog(
      context,
      existing: p,
      defaultYear: p.year,
      suggestions: _suggestions(all),
    );
    if (input == null || !mounted) return;
    await ref.read(pyqProvider.notifier).edit(p.id, input);
  }

  Future<void> _delete(Pyq p) async {
    final ctrl = ref.read(pyqProvider.notifier);
    await ctrl.remove(p.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Question deleted',
      onUndo: () => ctrl.restore(p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(pyqProvider).pyqs;
    final years = yearCoverage(all).map((y) => y.year).toList();
    // A filter year can disappear (last question deleted): ignore it then.
    final year = years.contains(_year) ? _year : null;
    final shown = filterPyqs(
      all,
      exam: _exam,
      year: year,
      status: _status,
      starredOnly: _starredOnly,
      query: _query,
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('PYQ Manager'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Questions'), Tab(text: 'Overview')],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _add(all),
          icon: const Icon(Icons.add),
          label: const Text('Questions'),
        ),
        body: TabBarView(
          children: [
            PageBody(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                children: [
                  TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search questions, topics, notes',
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
                        selected: _exam == null,
                        onSelected: (_) => setState(() => _exam = null),
                      ),
                      for (final e in PyqExam.all)
                        ChoiceChip(
                          label: Text(PyqExam.label(e)),
                          selected: _exam == e,
                          onSelected: (_) =>
                              setState(() => _exam = _exam == e ? null : e),
                        ),
                      FilterChip(
                        avatar: const Icon(Icons.star_outline, size: 18),
                        label: const Text('Starred'),
                        selected: _starredOnly,
                        onSelected: (v) => setState(() => _starredOnly = v),
                      ),
                      if (years.isNotEmpty)
                        DropdownButton<int?>(
                          value: year,
                          hint: const Text('Year'),
                          underline: const SizedBox.shrink(),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All years'),
                            ),
                            for (final y in years)
                              DropdownMenuItem<int?>(
                                value: y,
                                child: Text('$y'),
                              ),
                          ],
                          onChanged: (v) => setState(() => _year = v),
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
                      for (final s in PyqStatus.all)
                        ChoiceChip(
                          label: Text(PyqStatus.label(s)),
                          selected: _status == s,
                          onSelected: (_) => setState(
                            () => _status = _status == s ? null : s,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (all.isEmpty)
                    const Text(
                      'No questions yet. Tap "Questions" to add some. You can '
                      'paste a whole year at once, one question per line.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else if (shown.isEmpty)
                    const Text(
                      'No questions match these filters.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    for (final p in shown)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PyqTile(
                          pyq: p,
                          onEdit: () => _edit(p, all),
                          onDelete: () => _delete(p),
                        ),
                      ),
                ],
              ),
            ),
            PageBody(child: _OverviewTab(all: all)),
          ],
        ),
      ),
    );
  }
}

class _PyqTile extends ConsumerWidget {
  const _PyqTile({
    required this.pyq,
    required this.onEdit,
    required this.onDelete,
  });

  final Pyq pyq;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _statusColor {
    if (pyq.lastResult == PyqResult.wrong) return AppColors.danger;
    switch (pyq.status) {
      case PyqStatus.mastered:
        return AppColors.teal;
      case PyqStatus.attempted:
        return _warn;
      default:
        return AppColors.muted;
    }
  }

  String get _statusText {
    final base = PyqStatus.label(pyq.status);
    if (pyq.lastResult == PyqResult.correct) return '$base · last: correct';
    if (pyq.lastResult == PyqResult.wrong) return '$base · last: wrong';
    return base;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(pyqProvider.notifier);
    final p = pyq;
    final isPrelims = p.exam == PyqExam.prelims;
    final parts = <String>[
      '${p.year}',
      ExamPaper.label(p.paper),
      if (p.marks > 0) '${p.marks} marks',
      if (p.topic.isNotEmpty) p.topic,
      if (p.attempts > 0) '${p.attempts} attempt${p.attempts == 1 ? '' : 's'}',
    ];

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
                      p.question,
                      maxLines: 4,
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
                      _statusText,
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (p.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        p.note,
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
              IconButton(
                tooltip: p.starred ? 'Remove star' : 'Star',
                icon: Icon(
                  p.starred ? Icons.star : Icons.star_outline,
                  color: p.starred ? _warn : AppColors.muted,
                ),
                onPressed: () => ctrl.toggleStar(p.id),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'correct':
                      ctrl.attempt(p.id, result: PyqResult.correct);
                    case 'wrong':
                      ctrl.attempt(p.id, result: PyqResult.wrong);
                    case 'attempted':
                      ctrl.attempt(p.id);
                    case 'mastered':
                      ctrl.master(p.id);
                    case 'reset':
                      ctrl.reset(p.id);
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  if (isPrelims) ...const [
                    PopupMenuItem(
                      value: 'correct',
                      child: Text('Attempted: got it right'),
                    ),
                    PopupMenuItem(
                      value: 'wrong',
                      child: Text('Attempted: got it wrong'),
                    ),
                  ] else
                    const PopupMenuItem(
                      value: 'attempted',
                      child: Text('Mark attempted'),
                    ),
                  if (p.status != PyqStatus.mastered)
                    const PopupMenuItem(
                      value: 'mastered',
                      child: Text('Mark mastered'),
                    ),
                  if (p.status != PyqStatus.todo)
                    const PopupMenuItem(
                      value: 'reset',
                      child: Text('Reset to to do'),
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

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.all});

  final List<Pyq> all;

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
    if (all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Add questions to see year and topic coverage here.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }
    final stats = summarizePyqs(all);
    final years = yearCoverage(all);
    final topics = topicStats(all);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    _stat('Questions', '${stats.total}'),
                    _stat('Practised', '${stats.practised}'),
                    _stat('Mastered', '${stats.mastered}'),
                    _stat(
                      'Prelims accuracy',
                      stats.accuracy == null
                          ? '–'
                          : '${(stats.accuracy! * 100).round()}%',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ProgressBar(value: stats.practisedFraction),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            'By year',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final y in years)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${y.year}')),
                    Text(
                      '${y.practised}/${y.total} practised · '
                      '${y.mastered} mastered',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ProgressBar(value: y.fraction, height: 6),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            'By topic',
            style: TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final t in topics)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        t.topic,
                        style: t.isWeak ? const TextStyle(color: _warn) : null,
                      ),
                    ),
                    Text(
                      [
                        '${t.practised}/${t.total} practised',
                        if (t.accuracy != null)
                          '${(t.accuracy! * 100).round()}% right',
                      ].join(' · '),
                      style: TextStyle(
                        color: t.isWeak ? _warn : AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ProgressBar(
                  value: t.total == 0 ? 0 : t.practised / t.total,
                  height: 6,
                  color: t.isWeak ? _warn : AppColors.teal,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
