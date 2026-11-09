import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/core/utils/exam_papers.dart';
import 'package:upsc_command_centre/core/utils/parsing.dart';
import 'package:upsc_command_centre/features/answers/answer_logic.dart';
import 'package:upsc_command_centre/features/answers/models/answer_models.dart';

int _n = 0;

AnswerEntry _a(
  String date, {
  String paper = ExamPaper.gs1,
  int marks = 10,
  double? score,
  String status = AnswerStatus.written,
}) =>
    AnswerEntry(
      id: 'a${_n++}',
      date: date,
      paper: paper,
      question: 'Q',
      marks: marks,
      score: score,
      status: status,
      createdAt: '2026-11-08T10:00:0${_n % 10}',
    );

void main() {
  final today = DateTime(2026, 11, 8);

  group('word limit and score', () {
    test('suggested word limits', () {
      expect(suggestedWordLimit(ExamPaper.essay, 125), 1200);
      expect(suggestedWordLimit(ExamPaper.gs2, 10), 150);
      expect(suggestedWordLimit(ExamPaper.gs2, 15), 250);
      expect(suggestedWordLimit(ExamPaper.gs4, 20), 250);
    });

    test('scorePercent is null until evaluated', () {
      expect(scorePercent(_a('2026-11-08')), isNull);
      expect(scorePercent(_a('2026-11-08', score: 7.5)), closeTo(75, 1e-9));
    });

    test('parseScore accepts blank, decimals and comma decimals', () {
      expect(parseScore('', marks: 10).ok, isTrue);
      expect(parseScore('  ', marks: 10).value, isNull);
      expect(parseScore('7,5', marks: 10).value, 7.5);
      expect(parseScore('10', marks: 10).ok, isTrue);
    });

    test('parseScore rejects out of range and junk', () {
      expect(parseScore('11', marks: 10).ok, isFalse);
      expect(parseScore('-1', marks: 10).ok, isFalse);
      expect(parseScore('abc', marks: 10).ok, isFalse);
    });
  });

  group('status', () {
    test('score marks an answer evaluated, no score leaves it written', () {
      expect(
        deriveAnswerStatus(current: null, score: 6, needsRewrite: false),
        AnswerStatus.evaluated,
      );
      expect(
        deriveAnswerStatus(current: null, score: null, needsRewrite: false),
        AnswerStatus.written,
      );
    });

    test('needs rewrite wins, rewritten sticks until flagged again', () {
      expect(
        deriveAnswerStatus(current: null, score: 6, needsRewrite: true),
        AnswerStatus.needsRewrite,
      );
      expect(
        deriveAnswerStatus(
          current: AnswerStatus.rewritten,
          score: 6,
          needsRewrite: false,
        ),
        AnswerStatus.rewritten,
      );
      expect(
        deriveAnswerStatus(
          current: AnswerStatus.rewritten,
          score: 6,
          needsRewrite: true,
        ),
        AnswerStatus.needsRewrite,
      );
    });

    test('unflagging needs-rewrite falls back to the score state', () {
      expect(
        deriveAnswerStatus(
          current: AnswerStatus.needsRewrite,
          score: null,
          needsRewrite: false,
        ),
        AnswerStatus.written,
      );
    });
  });

  group('filter and streak', () {
    test('newest first, then by paper and status', () {
      final old = _a('2026-11-01', paper: ExamPaper.gs2);
      final mid = _a('2026-11-05', status: AnswerStatus.evaluated, score: 5);
      final recent = _a('2026-11-08', paper: ExamPaper.gs2);
      final all = [old, recent, mid];
      expect(filterAnswers(all).map((a) => a.id).toList(),
          [recent.id, mid.id, old.id]);
      expect(filterAnswers(all, paper: ExamPaper.gs2).map((a) => a.id).toList(),
          [recent.id, old.id]);
      expect(
        filterAnswers(all, status: AnswerStatus.evaluated)
            .map((a) => a.id)
            .toList(),
        [mid.id],
      );
    });

    test('streak counts consecutive days ending today', () {
      final list = [_a('2026-11-08'), _a('2026-11-07'), _a('2026-11-06')];
      expect(writingStreak(list, today), 3);
    });

    test('nothing written yet today does not break the streak', () {
      final list = [_a('2026-11-07'), _a('2026-11-06')];
      expect(writingStreak(list, today), 2);
    });

    test('a gap ends the streak and no answers means zero', () {
      final list = [_a('2026-11-08'), _a('2026-11-06')];
      expect(writingStreak(list, today), 1);
      expect(writingStreak(const [], today), 0);
      expect(writingStreak([_a('2026-11-01')], today), 0);
    });
  });

  group('stats', () {
    final all = [
      _a('2026-11-08', score: 8, status: AnswerStatus.evaluated),
      _a('2026-11-07',
          paper: ExamPaper.gs2,
          marks: 15,
          score: 7.5,
          status: AnswerStatus.evaluated),
      _a('2026-11-06'),
      _a('2026-11-05', score: 4, status: AnswerStatus.needsRewrite),
      _a('2026-11-01', paper: ExamPaper.gs3),
    ];

    test('summary counts', () {
      final s = summarizeAnswers(all, today);
      expect(s.total, 5);
      expect(s.last7Days, 4); // 1 Nov is outside the 7 days up to 8 Nov
      expect(s.evaluated, 3);
      expect(s.awaitingEvaluation, 2);
      expect(s.needsRewrite, 1);
      expect(s.avgPercent, closeTo((80 + 50 + 40) / 3, 1e-9));
      expect(s.streak, 4);
    });

    test('empty list has no average', () {
      final s = summarizeAnswers(const [], today);
      expect(s.total, 0);
      expect(s.avgPercent, isNull);
    });

    test('paper breakdown skips papers with no answers', () {
      final b = paperBreakdown(all);
      expect(b.map((p) => p.paper).toList(),
          [ExamPaper.gs1, ExamPaper.gs2, ExamPaper.gs3]);
      expect(b[0].count, 3);
      expect(b[0].avgPercent, closeTo(60, 1e-9));
      expect(b[1].avgPercent, closeTo(50, 1e-9));
      expect(b[2].avgPercent, isNull);
    });
  });

  group('AnswerEntry', () {
    test('survives a JSON round trip', () {
      final a = _a('2026-11-08', score: 6.5, status: AnswerStatus.evaluated);
      final back = AnswerEntry.fromJson(a.toJson());
      expect(back.toJson(), a.toJson());
    });

    test('copyWith can clear a score', () {
      final a = _a('2026-11-08', score: 6.5);
      expect(a.copyWith(score: null).score, isNull);
      expect(a.copyWith(feedback: 'x').score, 6.5);
    });

    test('unknown values fall back safely', () {
      final a = AnswerEntry.fromJson({
        'id': 'x',
        'paper': 'nonsense',
        'status': 'nonsense',
      });
      expect(a.paper, ExamPaper.gs1);
      expect(a.status, AnswerStatus.written);
      expect(a.score, isNull);
    });
  });

  group('number helpers', () {
    test('formatNumber trims zeros', () {
      expect(formatNumber(120), '120');
      expect(formatNumber(120.5), '120.5');
      expect(formatNumber(120.666), '120.67');
      expect(formatNumber(-0.001), '0');
    });
  });
}
