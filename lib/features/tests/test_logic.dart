import '../timer/models/session_models.dart';
import 'models/test_models.dart';

/// Marks for an objective test with one-third negative marking: each right
/// answer earns `maxMarks / total`, each wrong answer costs a third of that.
/// Unanswered questions score nothing. A test with no questions scores 0.
double mcqScore({
  required int correct,
  required int wrong,
  required int total,
  required double maxMarks,
}) {
  if (total <= 0) return 0;
  final per = maxMarks / total;
  return correct * per - wrong * per / 3;
}

/// Marks lost to wrong answers (a positive number).
double negativeLost({
  required int wrong,
  required int total,
  required double maxMarks,
}) {
  if (total <= 0) return 0;
  return wrong * (maxMarks / total) / 3;
}

/// Score as a percentage of the maximum, or null when there is no result.
/// Can be negative for an objective test with many wrong answers.
double? percentOf(TestRecord t) {
  final s = t.score;
  if (s == null || t.maxMarks <= 0) return null;
  return s / t.maxMarks * 100;
}

/// Timer category to use when starting the stopwatch for a test.
String studyCategoryFor(String testCategory) =>
    (testCategory == TestCategory.prelimsGs || testCategory == TestCategory.csat)
        ? StudyCategory.prelims
        : StudyCategory.test;

enum TestPhase {
  /// No result yet and the test day has not passed.
  upcoming,

  /// The test day has passed but the result is not entered.
  pending,

  /// Result entered.
  done,
}

/// [todayKey] is "yyyy-MM-dd".
TestPhase phaseOf(TestRecord t, String todayKey) {
  if (t.score != null) return TestPhase.done;
  return t.date.compareTo(todayKey) >= 0 ? TestPhase.upcoming : TestPhase.pending;
}

/// Newest first. Optionally limited to one category.
List<TestRecord> filterTests(Iterable<TestRecord> all, {String? category}) {
  final list = all.where((t) => category == null || t.category == category).toList()
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
  return list;
}

class TestStats {
  const TestStats({
    required this.taken,
    required this.avgPercent,
    required this.bestPercent,
    required this.lastPercent,
    required this.accuracy,
    required this.negativeLost,
    required this.analysisPending,
    required this.recentPercents,
  });

  /// Tests with a result.
  final int taken;
  final double? avgPercent;
  final double? bestPercent;

  /// The most recent test by date.
  final double? lastPercent;

  /// Correct / (correct + wrong) over objective tests; null if none.
  final double? accuracy;

  /// Total marks lost to wrong answers over objective tests.
  final double negativeLost;

  /// Taken tests whose analysis is not done yet.
  final int analysisPending;

  /// Percentages of the latest tests, oldest first (for a small trend).
  final List<double> recentPercents;
}

TestStats summarizeTests(Iterable<TestRecord> all, {int recent = 10}) {
  final taken = all.where((t) => t.score != null).toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });

  var sum = 0.0;
  double? best;
  var correct = 0;
  var wrong = 0;
  var lost = 0.0;
  var pending = 0;
  final percents = <double>[];

  for (final t in taken) {
    final p = percentOf(t);
    if (p != null) {
      percents.add(p);
      sum += p;
      if (best == null || p > best) best = p;
    }
    if (!t.analysisDone) pending++;
    if (TestCategory.isMcq(t.category)) {
      correct += t.correct;
      wrong += t.wrong;
      lost += negativeLost(
        wrong: t.wrong,
        total: t.totalQuestions,
        maxMarks: t.maxMarks,
      );
    }
  }

  final start = percents.length > recent ? percents.length - recent : 0;
  return TestStats(
    taken: taken.length,
    avgPercent: percents.isEmpty ? null : sum / percents.length,
    bestPercent: best,
    lastPercent: percents.isEmpty ? null : percents.last,
    accuracy: (correct + wrong) == 0 ? null : correct / (correct + wrong),
    negativeLost: lost,
    analysisPending: pending,
    recentPercents: percents.sublist(start),
  );
}

/// Why an objective test's counts cannot be right, or null if they are fine.
String? validateMcqCounts({
  required int total,
  required int correct,
  required int wrong,
}) {
  if (total <= 0) return 'Total questions must be at least 1.';
  if (correct + wrong > total) {
    return 'Correct + wrong ($correct + $wrong) is more than the $total '
        'questions.';
  }
  return null;
}
