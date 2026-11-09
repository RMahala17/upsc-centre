import 'dart:math' as math;

import '../../core/utils/dates.dart';
import '../planner/models/planner_models.dart';
import '../revision/models/revision_models.dart';
import '../revision/revision_logic.dart'
    show completedCycleCount, hasActiveCycle, kRequiredCycles;
import '../revision/revision_targets.dart';
import '../syllabus/models/syllabus_models.dart';
import '../tests/models/test_models.dart';
import '../tests/test_logic.dart';
import '../timer/models/session_models.dart';
import '../timer/timer_logic.dart';

// ---------------------------------------------------------------------------
// Date window
// ---------------------------------------------------------------------------

enum AnalyticsRange { week, month, quarter, all }

String rangeLabel(AnalyticsRange r) {
  switch (r) {
    case AnalyticsRange.week:
      return '7 days';
    case AnalyticsRange.month:
      return '30 days';
    case AnalyticsRange.quarter:
      return '90 days';
    case AnalyticsRange.all:
      return 'All time';
  }
}

/// Inclusive span of calendar days.
class DateWindow {
  const DateWindow(this.start, this.end);

  final DateTime start;
  final DateTime end;

  int get days => daysBetween(start, end) + 1;
  String get startKey => dateKey(start);
  String get endKey => dateKey(end);

  /// [key] is "yyyy-MM-dd"; those strings sort in calendar order.
  bool containsKey(String key) =>
      key.compareTo(startKey) >= 0 && key.compareTo(endKey) <= 0;
}

/// "All time" starts on the first day that has a session.
DateWindow windowFor(
  AnalyticsRange r,
  DateTime today,
  Iterable<StudySession> sessions,
) {
  final end = dateOnly(today);
  switch (r) {
    case AnalyticsRange.week:
      return DateWindow(addDays(end, -6), end);
    case AnalyticsRange.month:
      return DateWindow(addDays(end, -29), end);
    case AnalyticsRange.quarter:
      return DateWindow(addDays(end, -89), end);
    case AnalyticsRange.all:
      String? first;
      for (final s in sessions) {
        if (s.date.isEmpty) continue;
        if (first == null || s.date.compareTo(first) < 0) first = s.date;
      }
      if (first == null) return DateWindow(end, end);
      final start = parseDateKey(first);
      return DateWindow(start.isAfter(end) ? end : start, end);
  }
}

// ---------------------------------------------------------------------------
// Study time
// ---------------------------------------------------------------------------

/// A day counts towards the study streak once this much time is logged.
const int kStreakMinSec = 30 * 60;

/// Days with at least [minSec] of study logged.
Set<String> studyDays(
  Iterable<StudySession> sessions, {
  int minSec = kStreakMinSec,
}) {
  final byDate = <String, int>{};
  for (final s in sessions) {
    if (s.date.isEmpty) continue;
    byDate[s.date] = (byDate[s.date] ?? 0) + s.durationSec;
  }
  return {
    for (final e in byDate.entries)
      if (e.value >= minSec) e.key,
  };
}

class StudySummary {
  const StudySummary({
    required this.totalSec,
    required this.activeDays,
    required this.windowDays,
    required this.bestDay,
    required this.byCategory,
  });

  final int totalSec;

  /// Days in the window with any study time.
  final int activeDays;
  final int windowDays;
  final DayTotal? bestDay;
  final Map<String, int> byCategory;

  int get avgPerDaySec => windowDays <= 0 ? 0 : totalSec ~/ windowDays;
  int get avgPerActiveDaySec => activeDays == 0 ? 0 : totalSec ~/ activeDays;
}

StudySummary summarizeStudy(Iterable<StudySession> sessions, DateWindow w) {
  final byDate = <String, int>{};
  final byCat = <String, int>{};
  var total = 0;
  for (final s in sessions) {
    if (!w.containsKey(s.date)) continue;
    byDate[s.date] = (byDate[s.date] ?? 0) + s.durationSec;
    byCat[s.category] = (byCat[s.category] ?? 0) + s.durationSec;
    total += s.durationSec;
  }
  var active = 0;
  DayTotal? best;
  for (final e in byDate.entries) {
    if (e.value <= 0) continue;
    active++;
    if (best == null ||
        e.value > best.sec ||
        (e.value == best.sec && e.key.compareTo(dateKey(best.day)) > 0)) {
      best = DayTotal(parseDateKey(e.key), e.value);
    }
  }
  return StudySummary(
    totalSec: total,
    activeDays: active,
    windowDays: w.days,
    bestDay: best,
    byCategory: byCat,
  );
}

/// Categories with time, biggest first.
List<MapEntry<String, int>> categoriesBySize(Map<String, int> byCategory) {
  final list = byCategory.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return list;
}

class StudyBucket {
  const StudyBucket(this.start, this.end, this.sec);

  final DateTime start;
  final DateTime end;
  final int sec;

  bool get isDay => daysBetween(start, end) == 0;
}

const int kMaxChartBuckets = 26;

/// Daily bars for windows up to 31 days, otherwise weekly bars counted back
/// from the window's last day (at most [maxBuckets] of them, oldest first).
List<StudyBucket> studyBuckets(
  Iterable<StudySession> sessions,
  DateWindow w, {
  int maxBuckets = kMaxChartBuckets,
}) {
  final byDate = <String, int>{};
  for (final s in sessions) {
    if (w.containsKey(s.date)) {
      byDate[s.date] = (byDate[s.date] ?? 0) + s.durationSec;
    }
  }

  if (w.days <= 31) {
    return [
      for (var i = 0; i < w.days; i++)
        StudyBucket(
          addDays(w.start, i),
          addDays(w.start, i),
          byDate[dateKey(addDays(w.start, i))] ?? 0,
        ),
    ];
  }

  int sumRange(DateTime a, DateTime b) {
    var t = 0;
    for (var d = a; !d.isAfter(b); d = addDays(d, 1)) {
      t += byDate[dateKey(d)] ?? 0;
    }
    return t;
  }

  final n = math.min((w.days / 7).ceil(), maxBuckets);
  final out = <StudyBucket>[];
  for (var i = n - 1; i >= 0; i--) {
    final end = addDays(w.end, -7 * i);
    var start = addDays(end, -6);
    if (start.isBefore(w.start)) start = w.start;
    out.add(StudyBucket(start, end, sumRange(start, end)));
  }
  return out;
}

/// Average study seconds per weekday over the window. Index 0 is Monday,
/// 6 is Sunday. A weekday that never occurs in the window averages 0.
List<int> weekdayAverages(Iterable<StudySession> sessions, DateWindow w) {
  final byDate = <String, int>{};
  for (final s in sessions) {
    if (w.containsKey(s.date)) {
      byDate[s.date] = (byDate[s.date] ?? 0) + s.durationSec;
    }
  }
  final totals = List<int>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  for (var d = w.start; !d.isAfter(w.end); d = addDays(d, 1)) {
    final i = d.weekday - 1;
    counts[i]++;
    totals[i] += byDate[dateKey(d)] ?? 0;
  }
  return [
    for (var i = 0; i < 7; i++) counts[i] == 0 ? 0 : totals[i] ~/ counts[i],
  ];
}

// ---------------------------------------------------------------------------
// Planner follow-through
// ---------------------------------------------------------------------------

class PlanSummary {
  const PlanSummary({
    required this.total,
    required this.done,
    required this.daysPlanned,
    required this.daysCleared,
  });

  final int total;
  final int done;

  /// Days in the window that had at least one task.
  final int daysPlanned;

  /// Days where every task was ticked.
  final int daysCleared;

  double get fraction => total == 0 ? 0 : done / total;
}

PlanSummary summarizePlan(Iterable<PlannerTask> tasks, DateWindow w) {
  final total = <String, int>{};
  final done = <String, int>{};
  for (final t in tasks) {
    if (!w.containsKey(t.date)) continue;
    total[t.date] = (total[t.date] ?? 0) + 1;
    if (t.done) done[t.date] = (done[t.date] ?? 0) + 1;
  }
  var all = 0, ticked = 0, cleared = 0;
  for (final e in total.entries) {
    all += e.value;
    final d = done[e.key] ?? 0;
    ticked += d;
    if (d == e.value) cleared++;
  }
  return PlanSummary(
    total: all,
    done: ticked,
    daysPlanned: total.length,
    daysCleared: cleared,
  );
}

// ---------------------------------------------------------------------------
// Syllabus progress
// ---------------------------------------------------------------------------

class PaperProgress {
  const PaperProgress({
    required this.paper,
    required this.subjects,
    required this.total,
    required this.done,
  });

  final String paper;
  final int subjects;
  final int total;
  final int done;

  double get fraction => total == 0 ? 0 : done / total;
  int get percent => (fraction * 100).round();
}

/// One row per GS paper that has subjects, in paper order. Lectures of
/// deleted subjects are ignored.
List<PaperProgress> paperProgress(
  Iterable<Subject> subjects,
  Iterable<Lecture> lectures,
) {
  final paperOf = <String, String>{};
  final subjectCount = <String, int>{};
  for (final s in subjects) {
    paperOf[s.id] = s.paper;
    subjectCount[s.paper] = (subjectCount[s.paper] ?? 0) + 1;
  }
  final total = <String, int>{};
  final done = <String, int>{};
  for (final l in lectures) {
    final p = paperOf[l.subjectId];
    if (p == null) continue;
    total[p] = (total[p] ?? 0) + 1;
    if (l.completed) done[p] = (done[p] ?? 0) + 1;
  }
  final papers = [
    ...GsPaper.all,
    ...subjectCount.keys.where((p) => !GsPaper.all.contains(p)),
  ];
  return [
    for (final p in papers)
      if ((subjectCount[p] ?? 0) > 0)
        PaperProgress(
          paper: p,
          subjects: subjectCount[p]!,
          total: total[p] ?? 0,
          done: done[p] ?? 0,
        ),
  ];
}

class TrackCounts {
  const TrackCounts({
    required this.done,
    required this.inProgress,
    required this.notStarted,
  });

  final int done;
  final int inProgress;
  final int notStarted;

  int get total => done + inProgress + notStarted;
}

/// How many subjects are done / in progress / not started for one tracker
/// (pass `(s) => s.notes` or `(s) => s.pyq`).
TrackCounts countTrack(
  Iterable<Subject> subjects,
  TrackStatus Function(Subject) pick,
) {
  var done = 0, progress = 0, none = 0;
  for (final s in subjects) {
    switch (pick(s)) {
      case TrackStatus.done:
        done++;
      case TrackStatus.inProgress:
        progress++;
      case TrackStatus.notStarted:
        none++;
    }
  }
  return TrackCounts(done: done, inProgress: progress, notStarted: none);
}

class SubjectProgress {
  const SubjectProgress({
    required this.subject,
    required this.total,
    required this.done,
  });

  final Subject subject;
  final int total;
  final int done;

  double get fraction => total == 0 ? 0 : done / total;
}

/// Subjects that have lectures but are not finished, least complete first.
List<SubjectProgress> leastProgress(
  Iterable<Subject> subjects,
  Iterable<Lecture> lectures, {
  int max = 5,
}) {
  final total = <String, int>{};
  final done = <String, int>{};
  for (final l in lectures) {
    total[l.subjectId] = (total[l.subjectId] ?? 0) + 1;
    if (l.completed) done[l.subjectId] = (done[l.subjectId] ?? 0) + 1;
  }
  final list = <SubjectProgress>[];
  for (final s in subjects) {
    final t = total[s.id] ?? 0;
    final d = done[s.id] ?? 0;
    if (t == 0 || d >= t) continue;
    list.add(SubjectProgress(subject: s, total: t, done: d));
  }
  list.sort((a, b) {
    final c = a.fraction.compareTo(b.fraction);
    if (c != 0) return c;
    final t = b.total.compareTo(a.total);
    return t != 0 ? t : a.subject.name.compareTo(b.subject.name);
  });
  return list.length > max ? list.sublist(0, max) : list;
}

/// Subjects that have no lectures entered at all.
int subjectsWithoutLectures(
  Iterable<Subject> subjects,
  Iterable<Lecture> lectures,
) {
  final withLectures = {for (final l in lectures) l.subjectId};
  return subjects.where((s) => !withLectures.contains(s.id)).length;
}

// ---------------------------------------------------------------------------
// Revision coverage
// ---------------------------------------------------------------------------

class RevisionCoverage {
  const RevisionCoverage({
    required this.eligible,
    required this.complete,
    required this.started,
  });

  /// Subjects / papers whose lectures are all completed, so revision applies.
  final int eligible;

  /// Of those, how many have [kRequiredCycles] completed cycles.
  final int complete;

  /// Of those, how many have at least one completed or active cycle.
  final int started;
}

RevisionCoverage revisionCoverage(
  List<RevisionCycle> cycles,
  Iterable<RevisionTarget> targets,
) {
  var eligible = 0, complete = 0, started = 0;
  for (final t in targets) {
    if (!t.fullyCompleted) continue;
    eligible++;
    final doneCycles = completedCycleCount(cycles, t.type, t.id);
    if (doneCycles >= kRequiredCycles) complete++;
    if (doneCycles > 0 || hasActiveCycle(cycles, t.type, t.id)) started++;
  }
  return RevisionCoverage(
    eligible: eligible,
    complete: complete,
    started: started,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

class TrendPoint {
  const TrendPoint({
    required this.date,
    required this.percent,
    required this.name,
  });

  /// "yyyy-MM-dd"
  final String date;
  final double percent;
  final String name;
}

/// Scored tests, oldest first, limited to the latest [max].
List<TrendPoint> testTrend(Iterable<TestRecord> tests, {int max = 12}) {
  final taken = tests.where((t) => percentOf(t) != null).toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });
  final points = [
    for (final t in taken)
      TrendPoint(date: t.date, percent: percentOf(t)!, name: t.name),
  ];
  return points.length > max ? points.sublist(points.length - max) : points;
}

class CategoryAverage {
  const CategoryAverage({
    required this.category,
    required this.count,
    required this.avgPercent,
    required this.bestPercent,
  });

  final String category;
  final int count;
  final double avgPercent;
  final double bestPercent;
}

/// One row per test category that has at least one scored test, in the
/// app's category order.
List<CategoryAverage> testCategoryAverages(Iterable<TestRecord> tests) {
  final out = <CategoryAverage>[];
  for (final c in TestCategory.all) {
    var count = 0;
    var sum = 0.0;
    double? best;
    for (final t in tests) {
      if (t.category != c) continue;
      final p = percentOf(t);
      if (p == null) continue;
      count++;
      sum += p;
      if (best == null || p > best) best = p;
    }
    if (count > 0) {
      out.add(CategoryAverage(
        category: c,
        count: count,
        avgPercent: sum / count,
        bestPercent: best!,
      ));
    }
  }
  return out;
}

/// Axis range for a percentage trend: at least 0..100, wider if a score
/// falls outside it (negative marking can push a score below zero).
({double min, double max}) trendRange(Iterable<double> values) {
  var lo = 0.0, hi = 100.0;
  for (final v in values) {
    if (v < lo) lo = v;
    if (v > hi) hi = v;
  }
  return (min: (lo / 10).floorToDouble() * 10, max: (hi / 10).ceilToDouble() * 10);
}
