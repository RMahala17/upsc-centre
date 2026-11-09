import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/durations.dart';
import '../../core/utils/exam_papers.dart';
import '../../core/utils/parsing.dart';
import '../../core/utils/streaks.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/progress_bar.dart';
import '../../core/widgets/section_card.dart';
import '../answers/answer_controller.dart';
import '../answers/answer_logic.dart';
import '../answers/models/answer_models.dart';
import '../anthropology/anthro_controller.dart';
import '../anthropology/models/anthro_models.dart';
import '../currentaffairs/ca_controller.dart';
import '../currentaffairs/ca_logic.dart';
import '../currentaffairs/models/ca_models.dart';
import '../planner/planner_controller.dart';
import '../pyq/pyq_controller.dart';
import '../pyq/models/pyq_models.dart';
import '../pyq/pyq_logic.dart';
import '../revision/models/revision_models.dart';
import '../revision/revision_controller.dart';
import '../revision/revision_logic.dart' as rev;
import '../revision/revision_targets.dart';
import '../syllabus/models/syllabus_models.dart';
import '../syllabus/syllabus_controller.dart';
import '../tests/models/test_models.dart';
import '../tests/test_controller.dart';
import '../tests/test_logic.dart';
import '../timer/category_ui.dart';
import '../timer/models/session_models.dart';
import '../timer/sessions_controller.dart';
import 'analytics_logic.dart';

String _pct(double v) => '${v.round()}%';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsRange _range = AnalyticsRange.month;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Study'),
              Tab(text: 'Progress'),
              Tab(text: 'Practice'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            PageBody(child: _studyTab()),
            const PageBody(child: _ProgressTab()),
            const PageBody(child: _PracticeTab()),
          ],
        ),
      ),
    );
  }

  // ---------- Study tab ----------

  Widget _studyTab() {
    final sessions = ref.watch(sessionsProvider).sessions;
    final tasks = ref.watch(plannerProvider).tasks;
    final today = dateOnly(DateTime.now());

    final w = windowFor(_range, today, sessions);
    final s = summarizeStudy(sessions, w);
    final buckets = studyBuckets(sessions, w);
    final weekly = w.days > 31;
    final days = studyDays(sessions);
    final plan = summarizePlan(tasks, w);
    final weekdays = weekdayAverages(sessions, w);
    final cats = categoriesBySize(s.byCategory);

    final n = buckets.length;
    final labelEvery = n <= 8 ? 1 : (n <= 16 ? 2 : (n / 6).ceil());

    var bestWeekday = -1;
    var bestAvg = 0;
    for (var i = 0; i < weekdays.length; i++) {
      if (weekdays[i] > bestAvg) {
        bestAvg = weekdays[i];
        bestWeekday = i;
      }
    }
    const weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in AnalyticsRange.values)
              ChoiceChip(
                label: Text(rangeLabel(r)),
                selected: _range == r,
                onSelected: (_) => setState(() => _range = r),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${DateFormat('d MMM').format(w.start)} – '
          '${DateFormat('d MMM y').format(w.end)}',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (sessions.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No study sessions yet. Time you track with the study timer '
                'shows up here.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          )
        else ...[
          SectionCard(
            title: 'Study time',
            child: Column(
              children: [
                StatRow(
                  tiles: [
                    StatTile(label: 'Total', value: formatHm(s.totalSec)),
                    StatTile(
                      label: 'Per day',
                      value: formatHm(s.avgPerDaySec),
                    ),
                    StatTile(
                      label: 'Days studied',
                      value: '${s.activeDays}/${w.days}',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                StatRow(
                  tiles: [
                    StatTile(
                      label: 'Best day',
                      value: s.bestDay == null ? '–' : formatHm(s.bestDay!.sec),
                      caption: s.bestDay == null
                          ? null
                          : DateFormat('d MMM').format(s.bestDay!.day),
                    ),
                    StatTile(
                      label: 'Streak',
                      value: '${currentStreak(days, dateOnly(DateTime.now()))}d',
                      caption: '${formatHm(kStreakMinSec)}+ a day',
                    ),
                    StatTile(
                      label: 'Best streak',
                      value: '${longestStreak(days)}d',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: weekly ? 'Study time by week' : 'Study time by day',
            child: BarSeriesChart(
              points: [
                for (final b in buckets)
                  BarPoint(
                    label: weekly
                        ? DateFormat('d MMM').format(b.start)
                        : (w.days <= 7
                            ? DateFormat('E').format(b.start)
                            : DateFormat('d').format(b.start)),
                    value: b.sec.toDouble(),
                    valueLabel: formatHm(b.sec),
                    highlight: !weekly && dateKey(b.start) == dateKey(today),
                  ),
              ],
              showValues: n <= 7,
              labelEvery: labelEvery,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Where the time went',
            child: Column(
              children: [
                if (cats.isEmpty)
                  const Text(
                    'No time logged in this period.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                for (final c in cats)
                  BreakdownRow(
                    label: StudyCategory.label(c.key),
                    value:
                        '${formatHm(c.value)} · ${_pct(c.value / s.totalSec * 100)}',
                    fraction: c.value / s.totalSec,
                    color: categoryColor(c.key),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: 'Average by weekday',
            child: BarSeriesChart(
              points: [
                for (var i = 0; i < 7; i++)
                  BarPoint(
                    label: weekdayNames[i],
                    value: weekdays[i].toDouble(),
                    valueLabel: formatHm(weekdays[i]),
                    highlight: i == bestWeekday,
                  ),
              ],
              showValues: false,
            ),
          ),
          if (bestWeekday >= 0)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'You study most on ${weekdayNames[bestWeekday]}s '
                '(${formatHm(bestAvg)} on average).',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          title: 'Planner follow-through',
          onTap: () => context.go('/planner'),
          child: plan.total == 0
              ? const Text(
                  'No tasks planned in this period.',
                  style: TextStyle(color: AppColors.muted),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan.done} of ${plan.total} tasks done · '
                      '${_pct(plan.fraction * 100)}',
                    ),
                    const SizedBox(height: 8),
                    ProgressBar(value: plan.fraction),
                    const SizedBox(height: 8),
                    Text(
                      '${plan.daysCleared} of ${plan.daysPlanned} planned '
                      'days fully cleared.',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Progress tab
// ---------------------------------------------------------------------------

class _ProgressTab extends ConsumerWidget {
  const _ProgressTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = dateOnly(now);
    final gs = ref.watch(syllabusProvider);
    final an = ref.watch(anthroProvider);
    final cycles = ref.watch(revisionProvider).cycles;
    final targets = ref.watch(revisionTargetsProvider);
    final notes = ref.watch(caProvider).notes;
    final sessions = ref.watch(sessionsProvider).sessions;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _gsCard(context, gs),
        const SizedBox(height: 12),
        _anthroCard(context, an, now),
        const SizedBox(height: 12),
        _revisionCard(context, cycles, targets, today),
        const SizedBox(height: 12),
        _caCard(context, notes, sessions, today),
      ],
    );
  }

  Widget _trackLine(String label, TrackCounts c) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$label: ${c.done} done · ${c.inProgress} in progress · '
          '${c.notStarted} not started',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      );

  Widget _gsCard(BuildContext context, SyllabusState gs) {
    final overall = gs.overall;
    final papers = paperProgress(gs.subjects, gs.lectures);
    final least = leastProgress(gs.subjects, gs.lectures);
    final empty = subjectsWithoutLectures(gs.subjects, gs.lectures);

    return SectionCard(
      title: 'GS syllabus',
      onTap: () => context.go('/syllabus'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overall.total == 0)
            const Text(
              'No lectures entered yet. Add them in the syllabus tracker.',
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            BreakdownRow(
              label: 'All GS lectures',
              value:
                  '${overall.completed} of ${overall.total} · ${overall.percent}%',
              fraction: overall.fraction,
              color: AppColors.violet,
            ),
            for (final p in papers)
              BreakdownRow(
                label: GsPaper.title(p.paper),
                value: p.total == 0
                    ? 'none entered'
                    : '${p.done} of ${p.total} · ${p.percent}%',
                fraction: p.fraction,
                caption: '${p.subjects} subjects',
              ),
          ],
          if (gs.subjects.isNotEmpty) ...[
            const SizedBox(height: 4),
            _trackLine('Notes', countTrack(gs.subjects, (s) => s.notes)),
            _trackLine('PYQs', countTrack(gs.subjects, (s) => s.pyq)),
          ],
          if (empty > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '$empty subject${empty == 1 ? '' : 's'} have no lectures '
                'entered yet.',
                style: const TextStyle(color: kWarn, fontSize: 12),
              ),
            ),
          if (least.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Least progress so far',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final l in least)
              BreakdownRow(
                label: l.subject.name,
                value: '${l.done} of ${l.total}',
                fraction: l.fraction,
                color: AppColors.violet,
              ),
          ],
        ],
      ),
    );
  }

  Widget _anthroCard(BuildContext context, AnthroState an, DateTime now) {
    final pace = an.pace(now);
    final target = an.targetFinish(now);

    return SectionCard(
      title: 'Anthropology',
      onTap: () => context.go('/optional'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BreakdownRow(
            label: 'Planned lectures',
            value: '${an.completed} of ${an.denominator} · ${an.percent}%',
            fraction: an.fraction,
          ),
          for (final p in AnthroPaper.all)
            Builder(builder: (context) {
              final st = an.statsOfPaper(p);
              return BreakdownRow(
                label: 'Paper ${AnthroPaper.title(p)}',
                value: st.total == 0
                    ? 'none entered'
                    : '${st.completed} of ${st.total} · ${st.percent}%',
                fraction: st.fraction,
              );
            }),
          if (pace == null)
            const Text(
              'Tick off lectures to see your pace.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            )
          else ...[
            Text(
              'Pace: ${pace.lecturesPerDay.toStringAsFixed(1)} lectures a day '
              'over the last ${pace.windowDays} day'
              '${pace.windowDays == 1 ? '' : 's'}.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (pace.enoughData && pace.eta != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'At this pace you finish on '
                  '${DateFormat('d MMM y').format(pace.eta!)}.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
          ],
          if (target != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'At your target of ${an.dailyTarget} a day you finish on '
                '${DateFormat('d MMM y').format(target)}.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _revisionCard(
    BuildContext context,
    List<RevisionCycle> cycles,
    List<RevisionTarget> targets,
    DateTime today,
  ) {
    final summary = rev.summarize(cycles, today);
    final cover = revisionCoverage(cycles, targets);

    return SectionCard(
      title: 'Revision',
      onTap: () => context.go('/revision'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cycles.isEmpty)
            const Text(
              'No revision cycles yet.',
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            StatRow(
              tiles: [
                StatTile(label: 'Active', value: '${summary.active}'),
                StatTile(
                  label: 'Overdue',
                  value: '${summary.overdue}',
                  color: summary.overdue > 0 ? kWarn : null,
                ),
                StatTile(label: 'Completed', value: '${summary.completed}'),
              ],
            ),
            const SizedBox(height: 16),
          ],
          BreakdownRow(
            label: 'Revision coverage',
            value: '${cover.complete} of ${cover.eligible}',
            fraction: cover.eligible == 0 ? 0 : cover.complete / cover.eligible,
            caption: cover.eligible == 0
                ? 'Finish all lectures of a subject to start revising it.'
                : '${cover.started} of ${cover.eligible} completed subjects '
                    'started · goal is ${rev.kRequiredCycles} cycles each',
          ),
        ],
      ),
    );
  }

  Widget _caCard(
    BuildContext context,
    List<CaNote> notes,
    List<StudySession> sessions,
    DateTime today,
  ) {
    final stats = summarizeCa(notes, today);
    final days = caActiveDays(notes, sessions);

    return SectionCard(
      title: 'Current affairs',
      onTap: () => context.go('/notes'),
      child: notes.isEmpty
          ? const Text(
              'No current affairs notes yet.',
              style: TextStyle(color: AppColors.muted),
            )
          : StatRow(
              tiles: [
                StatTile(label: 'Notes', value: '${stats.total}'),
                StatTile(label: 'Last 7 days', value: '${stats.last7Days}'),
                StatTile(
                  label: 'Due to revise',
                  value: '${stats.due}',
                  color: stats.due > 0 ? kWarn : null,
                ),
                StatTile(
                  label: 'Streak',
                  value: '${currentStreak(days, today)}d',
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Practice tab
// ---------------------------------------------------------------------------

class _PracticeTab extends ConsumerWidget {
  const _PracticeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dateOnly(DateTime.now());
    final tests = ref.watch(testProvider).tests;
    final pyqs = ref.watch(pyqProvider).pyqs;
    final answers = ref.watch(answerProvider).answers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        _testsCard(context, tests),
        const SizedBox(height: 12),
        _pyqCard(context, pyqs),
        const SizedBox(height: 12),
        _answersCard(context, answers, today),
      ],
    );
  }

  Widget _testsCard(BuildContext context, List<TestRecord> tests) {
    final stats = summarizeTests(tests);
    final trend = testTrend(tests);
    final cats = testCategoryAverages(tests);
    final range = trendRange(trend.map((t) => t.percent));

    return SectionCard(
      title: 'Tests',
      onTap: () => context.go('/tests'),
      child: stats.taken == 0
          ? const Text(
              'No scored tests yet. Enter results in Test Series.',
              style: TextStyle(color: AppColors.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(
                  tiles: [
                    StatTile(label: 'Taken', value: '${stats.taken}'),
                    StatTile(
                      label: 'Average',
                      value: stats.avgPercent == null
                          ? '–'
                          : _pct(stats.avgPercent!),
                    ),
                    StatTile(
                      label: 'Best',
                      value: stats.bestPercent == null
                          ? '–'
                          : _pct(stats.bestPercent!),
                    ),
                    StatTile(
                      label: 'Latest',
                      value: stats.lastPercent == null
                          ? '–'
                          : _pct(stats.lastPercent!),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LineTrendChart(
                  values: [for (final t in trend) t.percent],
                  minY: range.min,
                  maxY: range.max,
                ),
                const SizedBox(height: 4),
                if (trend.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('d MMM')
                            .format(parseDateKey(trend.first.date)),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'last ${trend.length} scored test'
                        '${trend.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        DateFormat('d MMM')
                            .format(parseDateKey(trend.last.date)),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                for (final c in cats)
                  BreakdownRow(
                    label: TestCategory.label(c.category),
                    value:
                        'avg ${_pct(c.avgPercent)} · best ${_pct(c.bestPercent)}',
                    fraction: (c.avgPercent / 100).clamp(0.0, 1.0).toDouble(),
                    caption: '${c.count} test${c.count == 1 ? '' : 's'}',
                  ),
                if (stats.accuracy != null)
                  Text(
                    'MCQ accuracy ${_pct(stats.accuracy! * 100)} · '
                    '${formatNumber(stats.negativeLost)} marks lost to '
                    'negative marking.',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                if (stats.analysisPending > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${stats.analysisPending} test'
                      '${stats.analysisPending == 1 ? '' : 's'} still need '
                      'analysis.',
                      style: const TextStyle(color: kWarn, fontSize: 12),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _pyqCard(BuildContext context, List<Pyq> pyqs) {
    final stats = summarizePyqs(pyqs);
    final weak = topicStats(pyqs).where((t) => t.isWeak).take(5).toList();

    return SectionCard(
      title: 'PYQs',
      onTap: () => context.go('/pyq'),
      child: stats.total == 0
          ? const Text(
              'No PYQs added yet.',
              style: TextStyle(color: AppColors.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(
                  tiles: [
                    StatTile(label: 'Questions', value: '${stats.total}'),
                    StatTile(
                      label: 'Practised',
                      value: _pct(stats.practisedFraction * 100),
                    ),
                    StatTile(label: 'Mastered', value: '${stats.mastered}'),
                    StatTile(
                      label: 'Prelims accuracy',
                      value: stats.accuracy == null
                          ? '–'
                          : _pct(stats.accuracy! * 100),
                    ),
                  ],
                ),
                if (weak.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Weak topics (under 50% right)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  for (final t in weak)
                    BreakdownRow(
                      label: t.topic,
                      value: _pct((t.accuracy ?? 0) * 100),
                      fraction: t.accuracy ?? 0,
                      color: AppColors.danger,
                      caption: '${t.correct} right, ${t.wrong} wrong',
                    ),
                ],
              ],
            ),
    );
  }

  Widget _answersCard(
    BuildContext context,
    List<AnswerEntry> answers,
    DateTime today,
  ) {
    final stats = summarizeAnswers(answers, today);
    final papers = paperBreakdown(answers);

    return SectionCard(
      title: 'Answer writing',
      onTap: () => context.go('/answers'),
      child: stats.total == 0
          ? const Text(
              'No answers written yet.',
              style: TextStyle(color: AppColors.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatRow(
                  tiles: [
                    StatTile(label: 'Answers', value: '${stats.total}'),
                    StatTile(label: 'Last 7 days', value: '${stats.last7Days}'),
                    StatTile(
                      label: 'Average score',
                      value: stats.avgPercent == null
                          ? '–'
                          : _pct(stats.avgPercent!),
                    ),
                    StatTile(label: 'Streak', value: '${stats.streak}d'),
                  ],
                ),
                const SizedBox(height: 16),
                for (final p in papers)
                  BreakdownRow(
                    label: ExamPaper.label(p.paper),
                    value: '${p.count} answer${p.count == 1 ? '' : 's'}',
                    fraction: p.avgPercent == null
                        ? 0
                        : (p.avgPercent! / 100).clamp(0.0, 1.0).toDouble(),
                    color: AppColors.violet,
                    caption: p.avgPercent == null
                        ? 'Not evaluated yet'
                        : 'Average ${_pct(p.avgPercent!)}',
                  ),
                if (stats.awaitingEvaluation > 0 || stats.needsRewrite > 0)
                  Text(
                    [
                      if (stats.awaitingEvaluation > 0)
                        '${stats.awaitingEvaluation} waiting to be evaluated',
                      if (stats.needsRewrite > 0)
                        '${stats.needsRewrite} to rewrite',
                    ].join(' · '),
                    style: const TextStyle(color: kWarn, fontSize: 12),
                  ),
              ],
            ),
    );
  }
}
