import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/analytics/analytics_logic.dart';
import 'package:upsc_command_centre/features/planner/models/planner_models.dart';
import 'package:upsc_command_centre/features/syllabus/models/syllabus_models.dart';
import 'package:upsc_command_centre/features/tests/models/test_models.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';

int _n = 0;

StudySession _s(String date, int sec, {String category = StudyCategory.gs}) =>
    StudySession(
      id: 's${_n++}',
      date: date,
      startedAt: '${date}T09:00:00',
      durationSec: sec,
      category: category,
      createdAt: '',
    );

PlannerTask _task(String date, {bool done = false}) => PlannerTask(
      id: 't${_n++}',
      date: date,
      title: 'Task',
      category: StudyCategory.gs,
      done: done,
      order: 1,
      createdAt: '',
    );

Subject _subject(String id, String paper, {String? name}) => Subject(
      id: id,
      name: name ?? id,
      paper: paper,
      order: 1,
      createdAt: '',
    );

Lecture _lecture(String subjectId, {bool done = false}) => Lecture(
      id: 'l${_n++}',
      subjectId: subjectId,
      title: 'L',
      order: 1,
      completed: done,
      createdAt: '',
    );

TestRecord _test(
  String date, {
  double? score,
  double max = 200,
  String category = TestCategory.prelimsGs,
}) =>
    TestRecord(
      id: 'x${_n++}',
      name: 'Test $date',
      category: category,
      date: date,
      maxMarks: max,
      score: score,
      createdAt: '2026-11-08T10:00:0${_n % 10}',
    );

void main() {
  // Sunday 8 November 2026.
  final today = DateTime(2026, 11, 8);

  group('date window', () {
    test('fixed ranges end today and include it', () {
      final w = windowFor(AnalyticsRange.week, today, const []);
      expect(w.start, DateTime(2026, 11, 2));
      expect(w.end, today);
      expect(w.days, 7);
      expect(windowFor(AnalyticsRange.month, today, const []).days, 30);
      expect(windowFor(AnalyticsRange.quarter, today, const []).days, 90);
    });

    test('all time starts at the first session', () {
      final w = windowFor(
        AnalyticsRange.all,
        today,
        [_s('2026-10-20', 60), _s('2026-10-25', 60)],
      );
      expect(w.start, DateTime(2026, 10, 20));
      expect(w.days, 20);
    });

    test('all time with no sessions is just today', () {
      final w = windowFor(AnalyticsRange.all, today, const []);
      expect(w.days, 1);
      expect(w.start, today);
    });

    test('containsKey is inclusive at both ends', () {
      final w = windowFor(AnalyticsRange.week, today, const []);
      expect(w.containsKey('2026-11-02'), isTrue);
      expect(w.containsKey('2026-11-08'), isTrue);
      expect(w.containsKey('2026-11-01'), isFalse);
      expect(w.containsKey('2026-11-09'), isFalse);
    });
  });

  group('study summary', () {
    test('totals only what is inside the window', () {
      final w = windowFor(AnalyticsRange.week, today, const []);
      final sum = summarizeStudy([
        _s('2026-11-08', 3600),
        _s('2026-11-08', 1800, category: StudyCategory.anthro),
        _s('2026-11-03', 7200),
        _s('2026-10-30', 9999), // outside
      ], w);
      expect(sum.totalSec, 12600);
      expect(sum.activeDays, 2);
      expect(sum.windowDays, 7);
      expect(sum.avgPerDaySec, 1800);
      expect(sum.avgPerActiveDaySec, 6300);
      expect(sum.bestDay!.sec, 7200);
      expect(sum.byCategory[StudyCategory.gs], 10800);
      expect(sum.byCategory[StudyCategory.anthro], 1800);
    });

    test('an empty window is all zeros', () {
      final w = windowFor(AnalyticsRange.week, today, const []);
      final sum = summarizeStudy(const [], w);
      expect(sum.totalSec, 0);
      expect(sum.avgPerDaySec, 0);
      expect(sum.avgPerActiveDaySec, 0);
      expect(sum.bestDay, isNull);
    });

    test('categoriesBySize drops empty ones and sorts', () {
      final list = categoriesBySize({'a': 10, 'b': 30, 'c': 0, 'd': 30});
      expect(list.map((e) => e.key), ['b', 'd', 'a']);
    });

    test('studyDays needs the minimum time in a day', () {
      final days = studyDays([
        _s('2026-11-08', 1000),
        _s('2026-11-08', 900), // 1900 >= 1800
        _s('2026-11-07', 1799),
      ]);
      expect(days, {'2026-11-08'});
      expect(studyDays([_s('2026-11-07', 60)], minSec: 60), {'2026-11-07'});
    });
  });

  group('chart buckets', () {
    test('up to 31 days gives one bar per day', () {
      final w = windowFor(AnalyticsRange.month, today, const []);
      final b = studyBuckets([_s('2026-11-08', 600), _s('2026-10-10', 300)], w);
      expect(b.length, 30);
      expect(b.every((x) => x.isDay), isTrue);
      expect(b.last.sec, 600);
      expect(b.first.start, DateTime(2026, 10, 10));
      expect(b.first.sec, 300);
    });

    test('longer windows give weekly bars ending on the last day', () {
      final w = windowFor(AnalyticsRange.quarter, today, const []);
      final b = studyBuckets([
        _s('2026-11-08', 600),
        _s('2026-11-02', 400), // same final week (11-02..11-08)
        _s('2026-11-01', 200), // week before
      ], w);
      expect(b.length, 13);
      expect(b.last.end, today);
      expect(b.last.start, DateTime(2026, 11, 2));
      expect(b.last.sec, 1000);
      expect(b[b.length - 2].sec, 200);
      // The oldest bar is clipped to the window start.
      expect(b.first.start, w.start);
    });

    test('the number of weekly bars is capped', () {
      final w = DateWindow(DateTime(2024, 1, 1), today);
      final b = studyBuckets(const [], w);
      expect(b.length, kMaxChartBuckets);
      expect(b.last.end, today);
    });

    test('weekday averages divide by how often the weekday occurs', () {
      // Mon 26 Oct .. Sun 8 Nov: every weekday occurs twice.
      final w = DateWindow(DateTime(2026, 10, 26), today);
      final avg = weekdayAverages([_s('2026-11-02', 3600)], w); // a Monday
      expect(avg.length, 7);
      expect(avg[0], 1800);
      expect(avg.sublist(1).every((v) => v == 0), isTrue);
    });
  });

  group('planner follow-through', () {
    test('counts done tasks and fully cleared days in the window', () {
      final w = windowFor(AnalyticsRange.week, today, const []);
      final p = summarizePlan([
        _task('2026-11-08', done: true),
        _task('2026-11-08', done: true),
        _task('2026-11-07', done: true),
        _task('2026-11-07'),
        _task('2026-10-01'), // outside
      ], w);
      expect(p.total, 4);
      expect(p.done, 3);
      expect(p.daysPlanned, 2);
      expect(p.daysCleared, 1);
      expect(p.fraction, closeTo(0.75, 1e-9));
    });

    test('no tasks means zero, not NaN', () {
      final p = summarizePlan(const [], windowFor(AnalyticsRange.week, today, const []));
      expect(p.total, 0);
      expect(p.fraction, 0);
    });
  });

  group('syllabus progress', () {
    final subjects = [
      _subject('a', 'GS1', name: 'Alpha'),
      _subject('b', 'GS1', name: 'Beta'),
      _subject('c', 'GS2', name: 'Gamma'),
      _subject('d', 'GS3', name: 'Delta'),
    ];
    final lectures = [
      _lecture('a', done: true),
      _lecture('a', done: true),
      _lecture('a'),
      _lecture('b'),
      _lecture('b'),
      _lecture('c', done: true),
      _lecture('ghost', done: true), // deleted subject: ignored
    ];

    test('paperProgress sums lectures per paper in paper order', () {
      final p = paperProgress(subjects, lectures);
      expect(p.map((e) => e.paper), ['GS1', 'GS2', 'GS3']);
      expect(p[0].subjects, 2);
      expect(p[0].total, 5);
      expect(p[0].done, 2);
      expect(p[0].percent, 40);
      expect(p[1].percent, 100);
      expect(p[2].total, 0);
      expect(p[2].fraction, 0);
    });

    test('leastProgress skips finished and empty subjects', () {
      final l = leastProgress(subjects, lectures);
      expect(l.map((e) => e.subject.id), ['b', 'a']);
      expect(leastProgress(subjects, lectures, max: 1).length, 1);
    });

    test('subjectsWithoutLectures counts only subjects with none', () {
      expect(subjectsWithoutLectures(subjects, lectures), 1); // d
    });

    test('countTrack splits by status', () {
      final tracked = [
        _subject('a', 'GS1').copyWith(notes: TrackStatus.done),
        _subject('b', 'GS1').copyWith(notes: TrackStatus.inProgress),
        _subject('c', 'GS1'),
      ];
      final c = countTrack(tracked, (s) => s.notes);
      expect(c.done, 1);
      expect(c.inProgress, 1);
      expect(c.notStarted, 1);
      expect(c.total, 3);
    });
  });

  group('tests', () {
    test('testTrend keeps scored tests, oldest first, newest N', () {
      final t = testTrend([
        _test('2026-11-03', score: 100),
        _test('2026-11-01', score: 80),
        _test('2026-11-05'), // no score
        _test('2026-11-07', score: 120),
      ], max: 2);
      expect(t.map((p) => p.date), ['2026-11-03', '2026-11-07']);
      expect(t.first.percent, closeTo(50, 1e-9));
      expect(t.last.percent, closeTo(60, 1e-9));
    });

    test('trendRange is at least 0 to 100 and widens for outliers', () {
      var r = trendRange(const []);
      expect(r.min, 0);
      expect(r.max, 100);
      r = trendRange(const [-15, 50]);
      expect(r.min, -20);
      expect(r.max, 100);
      r = trendRange(const [105]);
      expect(r.max, 110);
    });

    test('testCategoryAverages groups scored tests by category', () {
      final rows = testCategoryAverages([
        _test('2026-11-01', score: 100),
        _test('2026-11-02', score: 140),
        _test('2026-11-03', score: 40, max: 50, category: TestCategory.sectional),
        _test('2026-11-04', category: TestCategory.csat), // unscored
      ]);
      expect(rows.map((r) => r.category),
          [TestCategory.prelimsGs, TestCategory.sectional]);
      expect(rows[0].count, 2);
      expect(rows[0].avgPercent, closeTo(60, 1e-9));
      expect(rows[0].bestPercent, closeTo(70, 1e-9));
      expect(rows[1].avgPercent, closeTo(80, 1e-9));
    });
  });
}
