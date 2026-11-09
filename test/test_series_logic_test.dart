import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/tests/models/test_models.dart';
import 'package:upsc_command_centre/features/tests/test_logic.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';

int _n = 0;

TestRecord _t(
  String date, {
  String category = TestCategory.prelimsGs,
  int total = 100,
  double max = 200,
  int correct = 0,
  int wrong = 0,
  double? score,
  bool analysisDone = false,
}) =>
    TestRecord(
      id: 't${_n++}',
      name: 'Test',
      category: category,
      date: date,
      totalQuestions: total,
      maxMarks: max,
      correct: correct,
      wrong: wrong,
      score: score,
      analysisDone: analysisDone,
      createdAt: '',
    );

void main() {
  group('objective scoring', () {
    test('Prelims GS: +2 per right answer, one third of that off per wrong', () {
      final s = mcqScore(correct: 60, wrong: 30, total: 100, maxMarks: 200);
      expect(s, closeTo(100, 1e-9)); // 120 - 20
    });

    test('CSAT: 2.5 marks a question', () {
      final s = mcqScore(correct: 50, wrong: 12, total: 80, maxMarks: 200);
      expect(s, closeTo(115, 1e-9)); // 125 - 10
    });

    test('skipped questions score nothing', () {
      final s = mcqScore(correct: 10, wrong: 0, total: 100, maxMarks: 200);
      expect(s, closeTo(20, 1e-9));
    });

    test('too many wrong answers give a negative score', () {
      final s = mcqScore(correct: 0, wrong: 3, total: 100, maxMarks: 200);
      expect(s, closeTo(-2, 1e-9));
    });

    test('a test with no questions scores zero instead of dividing by zero', () {
      expect(mcqScore(correct: 1, wrong: 1, total: 0, maxMarks: 100), 0);
      expect(negativeLost(wrong: 5, total: 0, maxMarks: 100), 0);
    });

    test('marks lost to negatives', () {
      expect(negativeLost(wrong: 30, total: 100, maxMarks: 200), closeTo(20, 1e-9));
    });

    test('count validation', () {
      expect(validateMcqCounts(total: 100, correct: 60, wrong: 40), isNull);
      expect(validateMcqCounts(total: 100, correct: 60, wrong: 41), isNotNull);
      expect(validateMcqCounts(total: 0, correct: 0, wrong: 0), isNotNull);
    });
  });

  group('percent and phase', () {
    test('percentOf needs a score and positive max marks', () {
      expect(percentOf(_t('2026-11-08', score: 100)), closeTo(50, 1e-9));
      expect(percentOf(_t('2026-11-08')), isNull);
      expect(percentOf(_t('2026-11-08', max: 0, score: 5)), isNull);
    });

    test('percent can be negative', () {
      expect(percentOf(_t('2026-11-08', score: -2)), closeTo(-1, 1e-9));
    });

    test('phase: done, upcoming or result pending', () {
      const today = '2026-11-08';
      expect(phaseOf(_t('2026-11-01', score: 90), today), TestPhase.done);
      expect(phaseOf(_t('2026-11-08'), today), TestPhase.upcoming);
      expect(phaseOf(_t('2026-11-20'), today), TestPhase.upcoming);
      expect(phaseOf(_t('2026-11-07'), today), TestPhase.pending);
    });
  });

  group('filterTests', () {
    test('newest first and by category', () {
      final a = _t('2026-10-01');
      final b = _t('2026-10-20', category: TestCategory.essay);
      final c = _t('2026-10-10', category: TestCategory.csat);
      expect(filterTests([a, b, c]).map((t) => t.id).toList(),
          [b.id, c.id, a.id]);
      expect(filterTests([a, b, c], category: TestCategory.csat)
          .map((t) => t.id)
          .toList(), [c.id]);
    });
  });

  group('summarizeTests', () {
    final t2Score = mcqScore(correct: 70, wrong: 20, total: 100, maxMarks: 200);
    final all = [
      _t('2026-10-01',
          correct: 60, wrong: 30, score: 100, analysisDone: true),
      _t('2026-10-15', correct: 70, wrong: 20, score: t2Score),
      _t('2026-10-20',
          category: TestCategory.essay, total: 0, max: 250, score: 125),
      _t('2026-11-20'), // upcoming: not counted
    ];

    test('counts only tests with a result', () {
      final s = summarizeTests(all);
      expect(s.taken, 3);
      final p2 = t2Score / 200 * 100;
      expect(s.avgPercent, closeTo((50 + p2 + 50) / 3, 1e-9));
      expect(s.bestPercent, closeTo(p2, 1e-9));
      expect(s.lastPercent, closeTo(50, 1e-9)); // the essay, latest by date
    });

    test('accuracy and negatives only come from objective tests', () {
      final s = summarizeTests(all);
      expect(s.accuracy, closeTo(130 / 180, 1e-9));
      expect(s.negativeLost, closeTo(20 + 20 * 2 / 3, 1e-9));
    });

    test('analysis pending counts taken tests only', () {
      expect(summarizeTests(all).analysisPending, 2);
    });

    test('recent percentages are oldest first and capped', () {
      final s = summarizeTests(all, recent: 2);
      expect(s.recentPercents.length, 2);
      expect(s.recentPercents.last, closeTo(50, 1e-9));
      expect(s.recentPercents.first, closeTo(t2Score / 200 * 100, 1e-9));
    });

    test('nothing taken gives empty stats, not fake zeros', () {
      final s = summarizeTests([_t('2026-11-20')]);
      expect(s.taken, 0);
      expect(s.avgPercent, isNull);
      expect(s.bestPercent, isNull);
      expect(s.accuracy, isNull);
      expect(s.recentPercents, isEmpty);
    });
  });

  group('categories', () {
    test('which are objective', () {
      expect(TestCategory.isMcq(TestCategory.prelimsGs), isTrue);
      expect(TestCategory.isMcq(TestCategory.csat), isTrue);
      expect(TestCategory.isMcq(TestCategory.sectional), isTrue);
      expect(TestCategory.isMcq(TestCategory.mainsGs), isFalse);
      expect(TestCategory.isMcq(TestCategory.essay), isFalse);
    });

    test('Prelims defaults', () {
      expect(TestCategory.defaultTotalQuestions(TestCategory.prelimsGs), 100);
      expect(TestCategory.defaultMaxMarks(TestCategory.prelimsGs), 200);
      expect(TestCategory.defaultTotalQuestions(TestCategory.csat), 80);
      expect(TestCategory.defaultMaxMarks(TestCategory.csat), 200);
    });

    test('timer category: Prelims and CSAT use the prelims category', () {
      expect(studyCategoryFor(TestCategory.prelimsGs), StudyCategory.prelims);
      expect(studyCategoryFor(TestCategory.csat), StudyCategory.prelims);
      expect(studyCategoryFor(TestCategory.mainsGs), StudyCategory.test);
    });
  });

  group('TestRecord', () {
    test('survives a JSON round trip', () {
      final t = _t('2026-10-01',
          correct: 60, wrong: 30, score: 100, analysisDone: true);
      expect(TestRecord.fromJson(t.toJson()).toJson(), t.toJson());
    });

    test('copyWith can clear a score', () {
      final t = _t('2026-10-01', score: 100);
      expect(t.copyWith(score: null).score, isNull);
      expect(t.copyWith(notes: 'x').score, 100);
    });

    test('unknown category becomes other, missing max uses a default', () {
      final t = TestRecord.fromJson({'id': 'x', 'category': 'nonsense'});
      expect(t.category, TestCategory.other);
      expect(t.maxMarks, 100);
      final csat = TestRecord.fromJson({'id': 'y', 'category': 'csat'});
      expect(csat.maxMarks, 200);
    });
  });
}
