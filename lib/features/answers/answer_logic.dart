import '../../core/utils/dates.dart';
import '../../core/utils/exam_papers.dart';
import '../../core/utils/parsing.dart';
import 'models/answer_models.dart';

/// A starting point for the word limit. The user can always change it.
int suggestedWordLimit(String paper, int marks) {
  if (paper == ExamPaper.essay) return 1200;
  return marks <= 10 ? 150 : 250;
}

/// Score as a percentage of the marks, or null when not evaluated.
double? scorePercent(AnswerEntry a) {
  final s = a.score;
  if (s == null || a.marks <= 0) return null;
  return s / a.marks * 100;
}

/// Which status an answer should have after the user saves it.
String deriveAnswerStatus({
  required String? current,
  required double? score,
  required bool needsRewrite,
}) {
  if (needsRewrite) return AnswerStatus.needsRewrite;
  if (current == AnswerStatus.rewritten) return AnswerStatus.rewritten;
  return score != null ? AnswerStatus.evaluated : AnswerStatus.written;
}

/// Parses a typed score. Blank is fine (not evaluated yet) and gives
/// `ok: true, value: null`. Anything that is not a number from 0 to [marks]
/// gives `ok: false`.
({bool ok, double? value}) parseScore(String raw, {required int marks}) {
  if (raw.trim().isEmpty) return (ok: true, value: null);
  final v = parseDecimal(raw);
  if (v == null || v < 0 || v > marks) return (ok: false, value: null);
  return (ok: true, value: v);
}

/// Newest first. Optionally limited to one paper and / or one status.
List<AnswerEntry> filterAnswers(
  Iterable<AnswerEntry> all, {
  String? paper,
  String? status,
}) {
  final list = all
      .where((a) =>
          (paper == null || a.paper == paper) &&
          (status == null || a.status == status))
      .toList()
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
  return list;
}

/// Consecutive days with at least one answer, counting back from [today].
/// A day with no answer yet today does not break the streak: counting then
/// starts from yesterday.
int writingStreak(Iterable<AnswerEntry> all, DateTime today) {
  final days = all.map((a) => a.date).toSet();
  var cursor = dateOnly(today);
  if (!days.contains(dateKey(cursor))) {
    cursor = addDays(cursor, -1);
  }
  var streak = 0;
  while (days.contains(dateKey(cursor))) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

class AnswerStats {
  const AnswerStats({
    required this.total,
    required this.last7Days,
    required this.evaluated,
    required this.awaitingEvaluation,
    required this.needsRewrite,
    required this.avgPercent,
    required this.streak,
  });

  final int total;

  /// Answers written in the 7 days up to and including today.
  final int last7Days;

  /// Answers that have a score.
  final int evaluated;

  /// Written but no score yet (and not flagged for rewrite).
  final int awaitingEvaluation;
  final int needsRewrite;

  /// Average of the per-answer percentages; null when nothing is scored.
  final double? avgPercent;
  final int streak;
}

AnswerStats summarizeAnswers(Iterable<AnswerEntry> all, DateTime today) {
  final from = dateKey(addDays(dateOnly(today), -6));
  final to = dateKey(dateOnly(today));
  var last7 = 0;
  var evaluated = 0;
  var awaiting = 0;
  var rewrite = 0;
  var pctSum = 0.0;
  var pctCount = 0;
  var total = 0;
  for (final a in all) {
    total++;
    if (a.date.compareTo(from) >= 0 && a.date.compareTo(to) <= 0) last7++;
    if (a.status == AnswerStatus.written) awaiting++;
    if (a.status == AnswerStatus.needsRewrite) rewrite++;
    final p = scorePercent(a);
    if (p != null) {
      evaluated++;
      pctSum += p;
      pctCount++;
    }
  }
  return AnswerStats(
    total: total,
    last7Days: last7,
    evaluated: evaluated,
    awaitingEvaluation: awaiting,
    needsRewrite: rewrite,
    avgPercent: pctCount == 0 ? null : pctSum / pctCount,
    streak: writingStreak(all, today),
  );
}

class PaperStat {
  const PaperStat({
    required this.paper,
    required this.count,
    required this.avgPercent,
  });

  final String paper;
  final int count;
  final double? avgPercent;
}

/// One row per paper that has at least one answer, in paper order.
List<PaperStat> paperBreakdown(Iterable<AnswerEntry> all) {
  final out = <PaperStat>[];
  for (final p in ExamPaper.mains) {
    var count = 0;
    var sum = 0.0;
    var scored = 0;
    for (final a in all) {
      if (a.paper != p) continue;
      count++;
      final pct = scorePercent(a);
      if (pct != null) {
        sum += pct;
        scored++;
      }
    }
    if (count > 0) {
      out.add(PaperStat(
        paper: p,
        count: count,
        avgPercent: scored == 0 ? null : sum / scored,
      ));
    }
  }
  return out;
}
