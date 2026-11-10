import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/platform/platform_services.dart';
import '../../core/storage/backup_meta.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/durations.dart';
import '../../core/utils/streaks.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/install_guide.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/theme_mode_button.dart';
import '../analytics/analytics_logic.dart';
import '../answers/answer_controller.dart';
import '../anthropology/anthro_controller.dart';
import '../currentaffairs/ca_controller.dart';
import '../planner/planner_controller.dart';
import '../planner/planner_logic.dart';
import '../pyq/pyq_controller.dart';
import '../pyq/pyq_logic.dart';
import '../revision/revision_controller.dart';
import '../revision/revision_logic.dart' as rev;
import '../syllabus/syllabus_controller.dart';
import '../tests/test_controller.dart';
import '../timer/category_ui.dart';
import '../timer/models/session_models.dart';
import '../timer/sessions_controller.dart';
import '../timer/timer_logic.dart';
import 'dashboard_dialogs.dart';
import 'dashboard_logic.dart';
import 'dashboard_prefs.dart';
import 'home_logic.dart';
import 'home_widgets.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _editSettings(
    BuildContext context,
    WidgetRef ref,
    DashboardPrefsState prefs,
  ) async {
    final result = await showDashboardSettingsDialog(context, current: prefs);
    if (result == null) return;
    await ref.read(dashboardPrefsProvider.notifier).save(
          dailyGoalMin: result.dailyGoalMin,
          examDates: result.examDates,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final todayKey = dateKey(today);

    final sessions = ref.watch(sessionsProvider).sessions;
    final tasks = ref.watch(plannerProvider).tasks;
    final gs = ref.watch(syllabusProvider);
    final an = ref.watch(anthroProvider);
    final cycles = ref.watch(revisionProvider).cycles;
    final pyqs = ref.watch(pyqProvider).pyqs;
    final answers = ref.watch(answerProvider).answers;
    final tests = ref.watch(testProvider).tests;
    final notes = ref.watch(caProvider).notes;
    final prefs = ref.watch(dashboardPrefsProvider);

    final hasData = sessions.isNotEmpty ||
        tasks.isNotEmpty ||
        pyqs.isNotEmpty ||
        answers.isNotEmpty ||
        tests.isNotEmpty ||
        notes.isNotEmpty ||
        cycles.isNotEmpty ||
        gs.overall.completed > 0 ||
        an.completed > 0;

    final ageDays = backupAgeDays(BackupMeta.lastBackupAt(), today);
    final attention = buildAttention(
      today: today,
      cycles: cycles,
      tasks: tasks,
      tests: tests,
      answers: answers,
      notes: notes,
    );

    final pyqStats = summarizePyqs(pyqs);
    final revPyq = revisionPyqProgress(
      cycles,
      pyqPractised: pyqStats.practised,
      pyqTotal: pyqStats.total,
    );
    final overall = overallPercent(
      gsDone: gs.overall.completed,
      gsTotal: gs.overall.total,
      anDone: an.completed,
      anTotal: an.denominator,
    );

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: BrandTitle(
          badge: examBadge(prefs.examDates, today),
          dateText: DateFormat('EEE, d MMM').format(today),
        ),
        actions: [
          if (canShowInstallHelp())
            IconButton(
              tooltip: 'Install app',
              icon: const Icon(Icons.install_mobile_outlined),
              onPressed: () => installOrGuide(context),
            ),
          const ThemeModeButton(),
          IconButton(
            tooltip: 'Daily goal and exam dates',
            icon: const Icon(Icons.tune),
            onPressed: () => _editSettings(context, ref, prefs),
          ),
        ],
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            if (backupReminderDue(ageDays, hasData: hasData)) ...[
              _BackupBanner(text: backupReminderText(ageDays)),
              const SizedBox(height: 12),
            ],
            OverviewCard(
              percent: overall,
              gsPercent: gs.overall.percent,
              anthroPercent: an.percent,
              onTap: () => context.go('/analytics'),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SummaryCard(
                    title: 'GS syllabus',
                    percent: gs.overall.percent,
                    caption: gs.overall.total == 0
                        ? 'Not set up'
                        : '${gs.overall.completed}/${gs.overall.total}',
                    fraction: gs.overall.fraction,
                    color: AppColors.violet,
                    onTap: () => context.go('/syllabus'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SummaryCard(
                    title: 'Anthropology',
                    percent: an.percent,
                    caption: an.denominator == 0
                        ? 'Not set up'
                        : '${an.completed}/${an.denominator}',
                    fraction: an.fraction,
                    color: AppColors.teal,
                    onTap: () => context.go('/optional'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SummaryCard(
                    title: 'Revision & PYQ',
                    percent: revPyq.percent,
                    caption: revPyq.total == 0
                        ? 'Nothing yet'
                        : '${revPyq.done}/${revPyq.total}',
                    fraction: revPyq.fraction,
                    color: AppColors.violet,
                    onTap: () => context.go('/revision'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            NextTargetCard(todayKey: todayKey),
            const SizedBox(height: 12),
            _CountdownCard(
              prefs: prefs,
              today: today,
              onSet: () => _editSettings(context, ref, prefs),
            ),
            const SizedBox(height: 12),
            _TodayCard(
              todaySec: totalSecOnDate(sessions, todayKey),
              sessionsToday: sessionsOnDate(sessions, todayKey).length,
              goalMin: prefs.dailyGoalMin,
              streak: currentStreak(studyDays(sessions), today),
              lecturesToday:
                  lecturesCompletedOn(gs.lectures, today) + an.completedOn(today),
            ),
            const SizedBox(height: 12),
            WeekHoursCard(
              days: weekHours(sessions, today),
              goalMin: prefs.dailyGoalMin,
              onTap: () => context.go('/analytics'),
            ),
            const SizedBox(height: 12),
            _PlanCard(todayKey: todayKey),
            const SizedBox(height: 12),
            _RevisionCard(today: today),
            const SizedBox(height: 12),
            if (attention.isNotEmpty)
              SectionCard(
                title: 'Needs attention',
                child: Column(
                  children: [
                    for (final a in attention)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_attentionIcon(a.kind), color: kWarn),
                        title: Text(a.text),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go(a.route),
                      ),
                  ],
                ),
              )
            else if (hasData)
              const SectionCard(
                title: 'Needs attention',
                child: Text(
                  'You are all caught up.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            const SizedBox(height: 12),
            const _QuickLinks(),
          ],
        ),
      ),
    );
  }
}

IconData _attentionIcon(AttentionKind k) {
  switch (k) {
    case AttentionKind.revisionOverdue:
      return Icons.replay_outlined;
    case AttentionKind.tasksCarried:
      return Icons.event_busy_outlined;
    case AttentionKind.testResult:
    case AttentionKind.testAnalysis:
      return Icons.fact_check_outlined;
    case AttentionKind.caDue:
      return Icons.newspaper_outlined;
    case AttentionKind.answerRewrite:
    case AttentionKind.answerAwaiting:
      return Icons.edit_note_outlined;
  }
}

class _BackupBanner extends StatelessWidget {
  const _BackupBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: kWarn),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/backup'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.backup_outlined, color: kWarn),
              const SizedBox(width: 12),
              Expanded(child: Text(text)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.prefs,
    required this.today,
    required this.onSet,
  });

  final DashboardPrefsState prefs;
  final DateTime today;
  final VoidCallback onSet;

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String key, int days})>[];
    for (final m in kExamMilestones) {
      final d = daysUntil(prefs.examDates[m.key], today);
      if (d != null) rows.add((label: m.label, key: m.key, days: d));
    }

    if (rows.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('Set your exam dates'),
          subtitle: const Text('UPSC and UPPCS countdowns appear here.'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onSet,
        ),
      );
    }

    // Upcoming first (soonest first), then dates that have passed.
    rows.sort((a, b) {
      final ap = a.days < 0, bp = b.days < 0;
      if (ap != bp) return ap ? 1 : -1;
      return a.days.compareTo(b.days);
    });

    return SectionCard(
      title: 'Countdown',
      onTap: onSet,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final r in rows)
            SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.label,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    countdownText(r.days),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: r.days < 0 ? AppColors.muted : AppColors.teal,
                    ),
                  ),
                  Text(
                    DateFormat('d MMM y')
                        .format(parseDateKey(prefs.examDates[r.key]!)),
                    style: const TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.todaySec,
    required this.sessionsToday,
    required this.goalMin,
    required this.streak,
    required this.lecturesToday,
  });

  final int todaySec;
  final int sessionsToday;
  final int goalMin;
  final int streak;
  final int lecturesToday;

  @override
  Widget build(BuildContext context) {
    final goalSec = goalMin * 60;
    final fraction = goalSec <= 0 ? 0.0 : todaySec / goalSec;
    final reached = todaySec >= goalSec;

    return SectionCard(
      title: 'Today',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatHm(todaySec),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: reached ? AppColors.teal : null,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'of ${formatMinutes(goalMin)} goal',
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(
            value: fraction,
            color: reached ? AppColors.teal : AppColors.violet,
          ),
          const SizedBox(height: 16),
          StatRow(
            tiles: [
              StatTile(
                label: 'Study streak',
                value: '${streak}d',
                caption: '${formatHm(kStreakMinSec)}+ a day',
              ),
              StatTile(label: 'Sessions', value: '$sessionsToday'),
              StatTile(label: 'Lectures done', value: '$lecturesToday'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/timer'),
              icon: const Icon(Icons.timer_outlined),
              label: const Text('Open study timer'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  const _PlanCard({required this.todayKey});

  final String todayKey;

  static const int _maxShown = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = tasksOnDate(ref.watch(plannerProvider).tasks, todayKey);
    final summary = summarizeDay(tasks);
    final ctrl = ref.read(plannerProvider.notifier);
    final shown = tasks.length > _maxShown ? tasks.sublist(0, _maxShown) : tasks;

    return SectionCard(
      title: "Today's plan",
      trailing: tasks.isEmpty
          ? null
          : Text(
              '${summary.done} of ${summary.total} done',
              style: const TextStyle(color: AppColors.muted),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tasks.isEmpty)
            const Text(
              'Nothing planned for today yet.',
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            ProgressBar(value: summary.fraction),
            const SizedBox(height: 4),
            for (final t in shown)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: t.done,
                onChanged: (_) => ctrl.toggle(t.id),
                title: Text(
                  t.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    decoration: t.done ? TextDecoration.lineThrough : null,
                    color: t.done ? AppColors.muted : null,
                  ),
                ),
                subtitle: Text(
                  [
                    StudyCategory.label(t.category),
                    if (t.plannedMin > 0) formatMinutes(t.plannedMin),
                  ].join(' · '),
                  style: TextStyle(
                    color: categoryColor(t.category),
                    fontSize: 12,
                  ),
                ),
              ),
            if (tasks.length > _maxShown)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+ ${tasks.length - _maxShown} more in the planner',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/planner'),
              child: Text(tasks.isEmpty ? 'Plan your day' : 'Open planner'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionCard extends ConsumerWidget {
  const _RevisionCard({required this.today});

  final DateTime today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycles = ref.watch(revisionProvider).cycles;
    final summary = rev.summarize(cycles, today);
    final todayItems = revisionToday(cycles, today);

    if (cycles.isEmpty) {
      return SectionCard(
        title: 'Revision',
        onTap: () => context.go('/revision'),
        child: const Text(
          'No revision cycles yet. Start one once a subject is complete.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    }

    return SectionCard(
      title: 'Revision',
      onTap: () => context.go('/revision'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatRow(
            tiles: [
              StatTile(label: 'Active', value: '${summary.active}'),
              StatTile(
                label: 'Overdue',
                value: '${summary.overdue}',
                color: summary.overdue > 0 ? kWarn : null,
              ),
              StatTile(label: 'Due in 7 days', value: '${summary.dueSoon}'),
            ],
          ),
          if (todayItems.total > 0 || todayItems.behind > 0) ...[
            const SizedBox(height: 12),
            Text(
              [
                if (todayItems.total > 0)
                  "Today's items: ${todayItems.done} of ${todayItems.total} done",
                if (todayItems.behind > 0)
                  '${todayItems.behind} behind schedule',
              ].join(' · '),
              style: TextStyle(
                color: todayItems.behind > 0 ? kWarn : AppColors.muted,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  static const _links = [
    ('/notes', 'Current affairs', Icons.newspaper_outlined),
    ('/answers', 'Answer writing', Icons.edit_note_outlined),
    ('/pyq', 'PYQs', Icons.quiz_outlined),
    ('/tests', 'Tests', Icons.fact_check_outlined),
    ('/optional', 'Anthropology', Icons.psychology_outlined),
    ('/analytics', 'Analytics', Icons.insights_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (path, label, icon) in _links)
          ActionChip(
            avatar: Icon(icon, size: 18),
            label: Text(label),
            onPressed: () => context.go(path),
          ),
      ],
    );
  }
}
