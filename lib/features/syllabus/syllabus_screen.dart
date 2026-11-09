import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import 'models/syllabus_models.dart';
import 'subject_dialog.dart';
import 'syllabus_controller.dart';

class SyllabusScreen extends ConsumerWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(syllabusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GS Syllabus')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final input = await showSubjectDialog(context);
          if (input == null) return;
          await ref
              .read(syllabusProvider.notifier)
              .addSubject(input.name, input.paper);
        },
        icon: const Icon(Icons.add),
        label: const Text('Subject'),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _OverallCard(stats: st.overall),
            const SizedBox(height: 12),
            if (!st.historyHandled) ...[
              const _HistoryBanner(),
              const SizedBox(height: 12),
            ],
            for (final paper in GsPaper.all) ..._paperSection(st, paper),
          ],
        ),
      ),
    );
  }

  List<Widget> _paperSection(SyllabusState st, String paper) {
    final subjects = st.subjectsOfPaper(paper);
    if (subjects.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 8),
        child: Text(
          GsPaper.title(paper),
          style: const TextStyle(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      for (final s in subjects)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SubjectCard(subject: s, stats: st.statsOf(s.id)),
        ),
    ];
  }
}

class _OverallCard extends StatelessWidget {
  final SubjectStats stats;
  const _OverallCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GS lecture completion',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            if (stats.total == 0)
              const Text(
                'No lectures added yet. Open a subject to add its lectures.',
              )
            else ...[
              Text(
                '${stats.percent}%',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ProgressBar(value: stats.fraction),
              const SizedBox(height: 8),
              Text(
                '${stats.completed} of ${stats.total} lectures completed'
                ' · ${stats.remaining} remaining',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryBanner extends StatelessWidget {
  const _HistoryBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Load your previous lecture counts?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'You can review and correct them first. Nothing is loaded '
              'unless you confirm.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () => context.go('/syllabus/setup'),
                child: const Text('Review & load'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final SubjectStats stats;
  const _SubjectCard({required this.subject, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/syllabus/${subject.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subject.name,
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
              const SizedBox(height: 8),
              Text(
                'Notes: ${trackStatusLabel(subject.notes)}'
                '  ·  PYQs: ${trackStatusLabel(subject.pyq)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
