import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../syllabus/models/syllabus_models.dart';
import 'anthro_controller.dart';
import 'anthro_dialogs.dart';
import 'models/anthro_models.dart';

class AnthroChapterScreen extends ConsumerWidget {
  final String chapterId;
  const AnthroChapterScreen({super.key, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(anthroProvider);
    final chapter = st.chapterById(chapterId);

    if (chapter == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chapter')),
        body: const Center(child: Text('This chapter no longer exists.')),
      );
    }

    final ctrl = ref.read(anthroProvider.notifier);
    final lectures = st.lecturesOf(chapterId);
    final stats = st.statsOfChapter(chapterId);

    return Scaffold(
      appBar: AppBar(
        title: Text(chapter.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                final input =
                    await showChapterDialog(context, existing: chapter);
                if (input == null) return;
                await ctrl.updateChapter(
                  chapter.copyWith(name: input.name, paper: input.paper),
                );
              } else if (v == 'delete') {
                final ok = await confirmDialog(
                  context,
                  title: 'Delete chapter?',
                  message: 'Delete "${chapter.name}" and its '
                      '${lectures.length} lectures? This cannot be undone.',
                );
                if (!ok) return;
                await ctrl.deleteChapter(chapter.id);
                if (context.mounted) context.go('/optional');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit chapter')),
              PopupMenuItem(value: 'delete', child: Text('Delete chapter')),
            ],
          ),
        ],
      ),
      body: PageBody(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          itemCount: 2 + (lectures.isEmpty ? 1 : lectures.length),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _StatsCard(
                stats: stats,
                paperTitle: AnthroPaper.title(chapter.paper),
              );
            }
            if (i == 1) return _LecturesHeader(chapterId: chapterId);
            if (lectures.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No lectures yet. Use "Add" or "Add many" above.',
                  style: TextStyle(color: AppColors.muted),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _LectureTile(lecture: lectures[i - 2]),
            );
          },
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final SubjectStats stats;
  final String paperTitle;
  const _StatsCard({required this.stats, required this.paperTitle});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              paperTitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _stat('Total', '${stats.total}'),
                _stat('Completed', '${stats.completed}'),
                _stat('Remaining', '${stats.remaining}'),
                _stat('Done', '${stats.percent}%'),
              ],
            ),
            const SizedBox(height: 14),
            ProgressBar(value: stats.fraction),
          ],
        ),
      ),
    );
  }
}

class _LecturesHeader extends ConsumerWidget {
  final String chapterId;
  const _LecturesHeader({required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(anthroProvider.notifier);
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Lectures',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              final n = await promptInt(
                context,
                title: 'Add many lectures',
                label: 'How many lectures?',
              );
              if (n == null) return;
              await ctrl.addLectures(chapterId, n);
            },
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add many'),
          ),
          TextButton.icon(
            onPressed: () async {
              final t = await promptText(
                context,
                title: 'Add lecture',
                label: 'Lecture title',
                confirmLabel: 'Add',
              );
              if (t == null) return;
              await ctrl.addLecture(chapterId, t);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _LectureTile extends ConsumerWidget {
  final Lecture lecture;
  const _LectureTile({required this.lecture});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(anthroProvider.notifier);
    final doneAt = lecture.completedAt == null
        ? null
        : DateTime.tryParse(lecture.completedAt!);

    return Card(
      child: ListTile(
        onTap: () => ctrl.toggleLecture(lecture.id),
        leading: Checkbox(
          value: lecture.completed,
          onChanged: (_) => ctrl.toggleLecture(lecture.id),
        ),
        title: Text(
          lecture.title,
          style: lecture.completed
              ? const TextStyle(
                  color: AppColors.muted,
                  decoration: TextDecoration.lineThrough,
                )
              : null,
        ),
        subtitle: doneAt == null
            ? null
            : Text(
                'Completed ${DateFormat('d MMM yyyy').format(doneAt.toLocal())}',
                style: const TextStyle(fontSize: 12),
              ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'edit') {
              final t = await promptText(
                context,
                title: 'Edit lecture',
                label: 'Lecture title',
                initial: lecture.title,
              );
              if (t == null) return;
              await ctrl.editLecture(lecture.id, t);
            } else if (v == 'delete') {
              final ok = await confirmDialog(
                context,
                title: 'Delete lecture?',
                message: 'Delete "${lecture.title}"?',
              );
              if (!ok) return;
              await ctrl.deleteLecture(lecture.id);
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
