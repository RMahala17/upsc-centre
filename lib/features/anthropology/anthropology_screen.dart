import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../syllabus/models/syllabus_models.dart';
import 'anthro_controller.dart';
import 'anthro_dialogs.dart';
import 'models/anthro_models.dart';

String _fmtDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

class AnthropologyScreen extends ConsumerWidget {
  const AnthropologyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(anthroProvider);
    final ctrl = ref.read(anthroProvider.notifier);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anthropology Optional'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Targets',
            onPressed: () async {
              final r = await showAnthroSettingsDialog(
                context,
                target: st.dailyTarget,
                planned: st.plannedTotal,
              );
              if (r == null) return;
              await ctrl.saveSettings(target: r.$1, planned: r.$2);
            },
          ),
        ],
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _OverallCard(st: st),
            const SizedBox(height: 12),
            _TodayCard(st: st, now: now),
            const SizedBox(height: 12),
            _PaceCard(st: st, now: now),
            for (final paper in AnthroPaper.all)
              ..._paperSection(context, st, ctrl, paper),
          ],
        ),
      ),
    );
  }

  List<Widget> _paperSection(
    BuildContext context,
    AnthroState st,
    AnthroController ctrl,
    String paper,
  ) {
    final stats = st.statsOfPaper(paper);
    final chapters = st.chaptersOfPaper(paper);
    final title = AnthroPaper.title(paper);

    return [
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    stats.total == 0
                        ? 'No lectures entered'
                        : '${stats.completed}/${stats.total} · ${stats.percent}%',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(value: stats.fraction),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final input =
                          await showChapterDialog(context, paper: paper);
                      if (input == null) return;
                      await ctrl.addChapter(
                          input.paper, input.name, input.lectureCount);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add chapter'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final items = await showPasteChaptersDialog(
                        context,
                        paperTitle: title,
                      );
                      if (items == null) return;
                      final (c, l) = await ctrl.addChaptersBulk(paper, items);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added $c chapters with $l lectures.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Paste list'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      if (chapters.isEmpty)
        const Padding(
          padding: EdgeInsets.all(8),
          child: Text(
            'No chapters yet. Add one, or paste your chapter list.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      for (final c in chapters)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChapterCard(chapter: c, stats: st.statsOfChapter(c.id)),
        ),
    ];
  }
}

class _OverallCard extends StatelessWidget {
  final AnthroState st;
  const _OverallCard({required this.st});

  @override
  Widget build(BuildContext context) {
    final String? note;
    if (st.unentered > 0) {
      note = '${st.entered} of ${st.plannedTotal} lectures are entered into '
          'chapters. Progress is measured against ${st.plannedTotal}.';
    } else if (st.entered > st.plannedTotal) {
      note = 'Chapters hold more lectures than the planned total '
          '(${st.plannedTotal}). Progress uses ${st.entered}.';
    } else {
      note = null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overall completion',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text(
              '${st.percent}%',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ProgressBar(value: st.fraction),
            const SizedBox(height: 8),
            Text(
              '${st.completed} of ${st.denominator} lectures completed'
              ' · ${st.remaining} remaining',
              style: const TextStyle(color: AppColors.muted),
            ),
            if (note != null) ...[
              const SizedBox(height: 8),
              Text(
                note,
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final AnthroState st;
  final DateTime now;
  const _TodayCard({required this.st, required this.now});

  @override
  Widget build(BuildContext context) {
    final done = st.completedOn(now);
    final target = st.dailyTarget;
    final reached = done >= target;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Today's lectures",
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
                Text(
                  '$done / $target',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ProgressBar(
              value: target == 0 ? 0 : done / target,
              color: AppColors.violet,
            ),
            const SizedBox(height: 8),
            Text(
              reached ? 'Daily target reached.' : '${target - done} to go today.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaceCard extends StatelessWidget {
  final AnthroState st;
  final DateTime now;
  const _PaceCard({required this.st, required this.now});

  Widget _line(String label, String value, {String? note}) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (note != null)
            Text(
              note,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      const Text(
        'Estimated completion',
        style: TextStyle(color: AppColors.muted),
      ),
    ];

    if (st.remaining <= 0) {
      children.add(const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('All planned lectures are completed.'),
      ));
    } else {
      final pace = st.pace(now);
      if (pace == null) {
        children.add(_line(
          'At your actual pace',
          'Not enough data yet',
          note: 'Tick lectures as you finish them; pace is measured from '
              'their completion dates.',
        ));
      } else if (!pace.enoughData) {
        children.add(_line(
          'At your actual pace',
          'Not enough data yet',
          note: 'Needs at least 3 days of recorded lectures '
              '(so far ${pace.completedInWindow} in ${pace.windowDays} '
              'day${pace.windowDays == 1 ? '' : 's'}).',
        ));
      } else if (pace.eta == null) {
        children.add(_line(
          'At your actual pace',
          'No lectures completed recently',
          note: 'Measured over the last ${pace.windowDays} days.',
        ));
      } else {
        children.add(_line(
          'At your actual pace (${pace.lecturesPerDay.toStringAsFixed(1)} per day)',
          _fmtDate(pace.eta!),
          note: 'Based on ${pace.completedInWindow} lectures in the last '
              '${pace.windowDays} days.',
        ));
      }

      final planDate = st.targetFinish(now);
      if (planDate != null) {
        children.add(_line(
          'If you meet your target (${st.dailyTarget} per day)',
          _fmtDate(planDate),
        ));
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  final SubjectStats stats;
  const _ChapterCard({required this.chapter, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/optional/chapter/${chapter.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      chapter.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    stats.total == 0
                        ? 'No lectures'
                        : '${stats.completed}/${stats.total}',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ProgressBar(value: stats.fraction),
            ],
          ),
        ),
      ),
    );
  }
}
