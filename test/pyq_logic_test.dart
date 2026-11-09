import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/core/utils/exam_papers.dart';
import 'package:upsc_command_centre/features/pyq/models/pyq_models.dart';
import 'package:upsc_command_centre/features/pyq/pyq_logic.dart';

int _n = 0;

Pyq _p({
  String exam = PyqExam.prelims,
  int year = 2023,
  int order = 1,
  String topic = '',
  String status = PyqStatus.todo,
  String? result,
  String question = 'Q',
  bool starred = false,
}) =>
    Pyq(
      id: 'p${_n++}',
      exam: exam,
      year: year,
      paper: exam == PyqExam.prelims ? ExamPaper.prelimsGs : ExamPaper.gs1,
      question: question,
      topic: topic,
      status: status,
      lastResult: result,
      starred: starred,
      order: order,
      createdAt: '',
    );

void main() {
  final now = DateTime(2026, 11, 8, 9);

  group('parseYear', () {
    test('accepts a sensible year', () {
      expect(parseYear('2023', maxYear: 2027), 2023);
      expect(parseYear(' 2027 ', maxYear: 2027), 2027);
    });

    test('rejects junk and out-of-range years', () {
      expect(parseYear('1989', maxYear: 2027), isNull);
      expect(parseYear('2028', maxYear: 2027), isNull);
      expect(parseYear('abc', maxYear: 2027), isNull);
      expect(parseYear('', maxYear: 2027), isNull);
    });
  });

  group('filterPyqs', () {
    final a = _p(year: 2022, order: 1, question: 'Panchayati Raj');
    final b = _p(year: 2023, order: 2, topic: 'Polity', starred: true);
    final c = _p(year: 2023, order: 1, topic: 'Economy', status: PyqStatus.mastered);
    final d = _p(exam: PyqExam.mains, year: 2023, order: 3);
    final all = [a, b, c, d];

    test('newest year first, then insertion order', () {
      expect(filterPyqs(all).map((p) => p.id).toList(),
          [c.id, b.id, d.id, a.id]);
    });

    test('filters by exam, year, topic, status and star', () {
      expect(filterPyqs(all, exam: PyqExam.mains).map((p) => p.id), [d.id]);
      expect(filterPyqs(all, year: 2022).map((p) => p.id), [a.id]);
      expect(filterPyqs(all, topic: 'Polity').map((p) => p.id), [b.id]);
      expect(
          filterPyqs(all, status: PyqStatus.mastered).map((p) => p.id), [c.id]);
      expect(filterPyqs(all, starredOnly: true).map((p) => p.id), [b.id]);
    });

    test('untagged questions can be filtered by the Untagged label', () {
      expect(filterPyqs(all, topic: untaggedTopic).map((p) => p.id).toSet(),
          {a.id, d.id});
    });

    test('search looks in question, topic and note, ignoring case', () {
      expect(filterPyqs(all, query: 'panchayati').map((p) => p.id), [a.id]);
      expect(filterPyqs(all, query: 'ECONOMY').map((p) => p.id), [c.id]);
      expect(filterPyqs(all, query: 'zzz'), isEmpty);
    });
  });

  group('applyAttempt', () {
    test('a right Prelims answer marks the question attempted', () {
      final r = applyAttempt(_p(), now, result: PyqResult.correct);
      expect(r.status, PyqStatus.attempted);
      expect(r.lastResult, PyqResult.correct);
      expect(r.attempts, 1);
      expect(r.lastAttemptAt, isNotNull);
    });

    test('a wrong answer drops a mastered question back to attempted', () {
      final r = applyAttempt(
        _p(status: PyqStatus.mastered, result: PyqResult.correct),
        now,
        result: PyqResult.wrong,
      );
      expect(r.status, PyqStatus.attempted);
      expect(r.lastResult, PyqResult.wrong);
    });

    test('a right answer keeps a mastered question mastered', () {
      final r = applyAttempt(
        _p(status: PyqStatus.mastered),
        now,
        result: PyqResult.correct,
      );
      expect(r.status, PyqStatus.mastered);
      expect(r.attempts, 1);
    });

    test('Mains attempts never store a right / wrong result', () {
      final r = applyAttempt(
        _p(exam: PyqExam.mains),
        now,
        result: PyqResult.correct,
      );
      expect(r.status, PyqStatus.attempted);
      expect(r.lastResult, isNull);
    });

    test('attempts accumulate', () {
      var p = _p();
      p = applyAttempt(p, now, result: PyqResult.wrong);
      p = applyAttempt(p, now, result: PyqResult.correct);
      expect(p.attempts, 2);
    });
  });

  group('mastered and reset', () {
    test('markMastered keeps the last result', () {
      final r = markMastered(_p(status: PyqStatus.attempted, result: PyqResult.correct));
      expect(r.status, PyqStatus.mastered);
      expect(r.lastResult, PyqResult.correct);
    });

    test('reset goes back to to-do, clears the result, keeps attempts', () {
      final p = applyAttempt(_p(), now, result: PyqResult.wrong);
      final r = resetPyq(p);
      expect(r.status, PyqStatus.todo);
      expect(r.lastResult, isNull);
      expect(r.attempts, 1);
    });
  });

  group('stats', () {
    final all = [
      _p(topic: 'Polity', status: PyqStatus.attempted, result: PyqResult.correct),
      _p(topic: 'Polity', status: PyqStatus.attempted, result: PyqResult.wrong),
      _p(topic: 'Polity', status: PyqStatus.attempted, result: PyqResult.wrong),
      _p(topic: 'Polity', status: PyqStatus.mastered, result: PyqResult.correct),
      _p(topic: 'Economy', status: PyqStatus.attempted, result: PyqResult.wrong),
      _p(topic: 'Economy', status: PyqStatus.attempted, result: PyqResult.wrong),
      _p(topic: 'Economy', status: PyqStatus.attempted, result: PyqResult.wrong),
      _p(year: 2022),
    ];

    test('summary', () {
      final s = summarizePyqs(all);
      expect(s.total, 8);
      expect(s.todo, 1);
      expect(s.attempted, 6);
      expect(s.mastered, 1);
      expect(s.practised, 7);
      expect(s.correct, 2);
      expect(s.wrong, 5);
      expect(s.accuracy, closeTo(2 / 7, 1e-9));
    });

    test('no marked answers means no accuracy', () {
      expect(summarizePyqs([_p()]).accuracy, isNull);
      expect(summarizePyqs(const []).practisedFraction, 0);
    });

    test('topics are ordered by size and untagged ones are grouped', () {
      final t = topicStats(all);
      expect(t.map((x) => x.topic).toList(), ['Polity', 'Economy', untaggedTopic]);
      expect(t[0].total, 4);
      expect(t[0].practised, 4);
      expect(t[2].practised, 0);
    });

    test('weak topics need 3+ marked answers and under 50% right', () {
      final t = topicStats(all);
      expect(t[0].isWeak, isFalse); // Polity: 2 of 4 right
      expect(t[1].isWeak, isTrue); // Economy: 0 of 3 right
      expect(t[2].isWeak, isFalse); // Untagged: nothing marked
    });

    test('year coverage, newest first', () {
      final y = yearCoverage([
        _p(year: 2023, status: PyqStatus.attempted),
        _p(year: 2023),
        _p(year: 2022, status: PyqStatus.mastered),
      ]);
      expect(y.map((e) => e.year).toList(), [2023, 2022]);
      expect(y[0].total, 2);
      expect(y[0].practised, 1);
      expect(y[0].mastered, 0);
      expect(y[0].fraction, 0.5);
      expect(y[1].mastered, 1);
    });
  });

  group('topicSuggestions', () {
    final all = [
      _p(topic: 'Polity'),
      _p(topic: 'Polity'),
      _p(topic: 'Economy'),
      _p(),
    ];

    test('used topics first, then extras, no duplicates', () {
      expect(
        topicSuggestions(all, ['Geography', 'Polity', '  ']),
        ['Polity', 'Economy', 'Geography'],
      );
    });

    test('respects the maximum', () {
      expect(topicSuggestions(all, ['Geography'], max: 2), ['Polity', 'Economy']);
    });
  });

  group('Pyq', () {
    test('survives a JSON round trip', () {
      final p = applyAttempt(_p(topic: 'Polity', starred: true), now,
          result: PyqResult.correct);
      expect(Pyq.fromJson(p.toJson()).toJson(), p.toJson());
    });

    test('unknown stored values fall back safely', () {
      final p = Pyq.fromJson({
        'id': 'x',
        'exam': 'weird',
        'paper': 'zzz',
        'status': '??',
        'lastResult': 'maybe',
      });
      expect(p.exam, PyqExam.mains);
      expect(p.paper, ExamPaper.gs1);
      expect(p.status, PyqStatus.todo);
      expect(p.lastResult, isNull);
    });

    test('papersFor matches the exam stage', () {
      expect(papersFor(PyqExam.prelims), ExamPaper.prelims);
      expect(papersFor(PyqExam.mains), ExamPaper.mains);
    });
  });
}
