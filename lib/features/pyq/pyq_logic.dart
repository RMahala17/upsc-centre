import '../../core/utils/exam_papers.dart';
import 'models/pyq_models.dart';

const String untaggedTopic = 'Untagged';

/// Years accepted when adding questions.
int? parseYear(String raw, {required int maxYear}) {
  final n = int.tryParse(raw.trim());
  if (n == null || n < 1990 || n > maxYear) return null;
  return n;
}

/// Newest year first, then the order the questions were added in.
List<Pyq> filterPyqs(
  Iterable<Pyq> all, {
  String? exam,
  String? paper,
  int? year,
  String? topic,
  String? status,
  bool starredOnly = false,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final list = all.where((p) {
    if (exam != null && p.exam != exam) return false;
    if (paper != null && p.paper != paper) return false;
    if (year != null && p.year != year) return false;
    if (topic != null && _topicOf(p) != topic) return false;
    if (status != null && p.status != status) return false;
    if (starredOnly && !p.starred) return false;
    if (q.isNotEmpty &&
        !p.question.toLowerCase().contains(q) &&
        !p.topic.toLowerCase().contains(q) &&
        !p.note.toLowerCase().contains(q)) {
      return false;
    }
    return true;
  }).toList()
    ..sort((a, b) {
      final y = b.year.compareTo(a.year);
      if (y != 0) return y;
      final o = a.order.compareTo(b.order);
      return o != 0 ? o : a.createdAt.compareTo(b.createdAt);
    });
  return list;
}

String _topicOf(Pyq p) => p.topic.trim().isEmpty ? untaggedTopic : p.topic.trim();

/// Records one attempt. For Prelims pass [result] ("correct" / "wrong").
///
/// - a wrong answer always drops the question back to "attempted"
/// - a question already "mastered" stays mastered after a correct (or
///   unmarked) attempt
/// - Mains attempts carry no result
Pyq applyAttempt(Pyq p, DateTime now, {String? result}) {
  final keepMastered =
      p.status == PyqStatus.mastered && result != PyqResult.wrong;
  return p.copyWith(
    status: keepMastered ? PyqStatus.mastered : PyqStatus.attempted,
    lastResult: p.exam == PyqExam.prelims ? result : null,
    attempts: p.attempts + 1,
    lastAttemptAt: now.toIso8601String(),
  );
}

/// Marks a question mastered. A Prelims question keeps its last result.
Pyq markMastered(Pyq p) => p.copyWith(status: PyqStatus.mastered);

/// Back to "to do". The attempt count stays; the last result is cleared.
Pyq resetPyq(Pyq p) =>
    p.copyWith(status: PyqStatus.todo, lastResult: null);

class PyqStats {
  const PyqStats({
    required this.total,
    required this.todo,
    required this.attempted,
    required this.mastered,
    required this.correct,
    required this.wrong,
  });

  final int total;
  final int todo;
  final int attempted;
  final int mastered;

  /// Prelims questions whose latest attempt was right / wrong.
  final int correct;
  final int wrong;

  int get practised => attempted + mastered;
  double get practisedFraction => total == 0 ? 0 : practised / total;

  /// Share of marked Prelims questions answered correctly; null when none
  /// are marked.
  double? get accuracy =>
      (correct + wrong) == 0 ? null : correct / (correct + wrong);
}

PyqStats summarizePyqs(Iterable<Pyq> all) {
  var total = 0, todo = 0, attempted = 0, mastered = 0, correct = 0, wrong = 0;
  for (final p in all) {
    total++;
    switch (p.status) {
      case PyqStatus.attempted:
        attempted++;
      case PyqStatus.mastered:
        mastered++;
      default:
        todo++;
    }
    if (p.lastResult == PyqResult.correct) correct++;
    if (p.lastResult == PyqResult.wrong) wrong++;
  }
  return PyqStats(
    total: total,
    todo: todo,
    attempted: attempted,
    mastered: mastered,
    correct: correct,
    wrong: wrong,
  );
}

class YearCoverage {
  const YearCoverage({
    required this.year,
    required this.total,
    required this.practised,
    required this.mastered,
  });

  final int year;
  final int total;

  /// Attempted or mastered.
  final int practised;
  final int mastered;

  double get fraction => total == 0 ? 0 : practised / total;
}

/// One row per year that has questions, newest first.
List<YearCoverage> yearCoverage(Iterable<Pyq> all) {
  final total = <int, int>{};
  final practised = <int, int>{};
  final mastered = <int, int>{};
  for (final p in all) {
    total[p.year] = (total[p.year] ?? 0) + 1;
    if (p.status != PyqStatus.todo) {
      practised[p.year] = (practised[p.year] ?? 0) + 1;
    }
    if (p.status == PyqStatus.mastered) {
      mastered[p.year] = (mastered[p.year] ?? 0) + 1;
    }
  }
  final years = total.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final y in years)
      YearCoverage(
        year: y,
        total: total[y]!,
        practised: practised[y] ?? 0,
        mastered: mastered[y] ?? 0,
      ),
  ];
}

class TopicStat {
  const TopicStat({
    required this.topic,
    required this.total,
    required this.practised,
    required this.correct,
    required this.wrong,
  });

  final String topic;
  final int total;
  final int practised;
  final int correct;
  final int wrong;

  double? get accuracy =>
      (correct + wrong) == 0 ? null : correct / (correct + wrong);

  /// Enough marked Prelims answers, and under half right.
  bool get isWeak => (correct + wrong) >= 3 && (accuracy ?? 1) < 0.5;
}

/// Biggest topics first; ties by name.
List<TopicStat> topicStats(Iterable<Pyq> all) {
  final total = <String, int>{};
  final practised = <String, int>{};
  final correct = <String, int>{};
  final wrong = <String, int>{};
  for (final p in all) {
    final t = _topicOf(p);
    total[t] = (total[t] ?? 0) + 1;
    if (p.status != PyqStatus.todo) practised[t] = (practised[t] ?? 0) + 1;
    if (p.lastResult == PyqResult.correct) correct[t] = (correct[t] ?? 0) + 1;
    if (p.lastResult == PyqResult.wrong) wrong[t] = (wrong[t] ?? 0) + 1;
  }
  final out = [
    for (final t in total.keys)
      TopicStat(
        topic: t,
        total: total[t]!,
        practised: practised[t] ?? 0,
        correct: correct[t] ?? 0,
        wrong: wrong[t] ?? 0,
      ),
  ]..sort((a, b) {
      final c = b.total.compareTo(a.total);
      return c != 0 ? c : a.topic.compareTo(b.topic);
    });
  return out;
}

/// Topic names for quick picking: topics already used (most used first),
/// then [extra] names such as syllabus subjects. No duplicates.
List<String> topicSuggestions(
  Iterable<Pyq> all,
  Iterable<String> extra, {
  int max = 12,
}) {
  final counts = <String, int>{};
  for (final p in all) {
    final t = p.topic.trim();
    if (t.isEmpty) continue;
    counts[t] = (counts[t] ?? 0) + 1;
  }
  final used = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  final out = <String>[...used];
  for (final e in extra) {
    final t = e.trim();
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  return out.length > max ? out.sublist(0, max) : out;
}

/// Papers that belong to an exam stage.
List<String> papersFor(String exam) =>
    exam == PyqExam.prelims ? ExamPaper.prelims : ExamPaper.mains;
