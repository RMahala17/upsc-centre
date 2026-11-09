import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/answers/models/answer_models.dart';
import 'package:upsc_command_centre/features/currentaffairs/models/ca_models.dart';
import 'package:upsc_command_centre/features/dashboard/dashboard_logic.dart';
import 'package:upsc_command_centre/features/planner/models/planner_models.dart';
import 'package:upsc_command_centre/features/revision/models/revision_models.dart';
import 'package:upsc_command_centre/features/tests/models/test_models.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';

int _n = 0;

RevisionCycle _cycle(
  String start, {
  int length = 7,
  String? completed,
  List<RevisionItem> items = const [],
}) =>
    RevisionCycle(
      id: 'c${_n++}',
      targetType: RevisionTargetType.gs,
      targetId: 'sub',
      targetName: 'Subject',
      number: 1,
      startDate: start,
      lengthDays: length,
      completedDate: completed,
      items: items,
      createdAt: '',
    );

RevisionItem _item(int day, {bool done = false}) => RevisionItem(
      id: 'i${_n++}',
      title: 'Item',
      day: day,
      order: _n,
      done: done,
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

TestRecord _test(String date, {double? score, bool analysis = false}) =>
    TestRecord(
      id: 'x${_n++}',
      name: 'T',
      category: TestCategory.prelimsGs,
      date: date,
      maxMarks: 200,
      score: score,
      analysisDone: analysis,
      createdAt: '',
    );

AnswerEntry _answer(String status) => AnswerEntry(
      id: 'a${_n++}',
      date: '2026-11-08',
      paper: 'gs1',
      question: 'Q',
      status: status,
      createdAt: '',
    );

CaNote _note(String date) =>
    CaNote(id: 'n${_n++}', date: date, title: 'T', createdAt: '');

void main() {
  final today = DateTime(2026, 11, 8);

  group('greeting and dates', () {
    test('greeting follows the hour', () {
      expect(greetingFor(6), 'Good morning');
      expect(greetingFor(12), 'Good afternoon');
      expect(greetingFor(16), 'Good afternoon');
      expect(greetingFor(17), 'Good evening');
      expect(greetingFor(23), 'Good evening');
    });

    test('isValidDateKey rejects impossible and malformed dates', () {
      expect(isValidDateKey('2026-02-28'), isTrue);
      expect(isValidDateKey('2026-02-31'), isFalse);
      expect(isValidDateKey('2026-2-3'), isFalse);
      expect(isValidDateKey('tomorrow'), isFalse);
      expect(isValidDateKey(''), isFalse);
    });
  });

  group('exam countdown', () {
    test('daysUntil counts whole calendar days', () {
      expect(daysUntil('2026-11-08', today), 0);
      expect(daysUntil('2026-11-09', today), 1);
      expect(daysUntil('2027-11-08', today), 365);
      expect(daysUntil('2026-11-01', today), -7);
    });

    test('daysUntil is null for missing or invalid dates', () {
      expect(daysUntil(null, today), isNull);
      expect(daysUntil('nonsense', today), isNull);
      expect(daysUntil('2026-02-31', today), isNull);
    });

    test('countdownText', () {
      expect(countdownText(30), '30 days');
      expect(countdownText(2), '2 days');
      expect(countdownText(1), 'Tomorrow');
      expect(countdownText(0), 'Today');
      expect(countdownText(-3), 'Passed');
    });
  });

  group('backup reminder', () {
    test('backupAgeDays', () {
      expect(backupAgeDays(null, today), isNull);
      expect(backupAgeDays(DateTime(2026, 11, 8, 6), today), 0);
      expect(backupAgeDays(DateTime(2026, 11, 1, 23), today), 7);
      // A clock moved backwards never gives a negative age.
      expect(backupAgeDays(DateTime(2026, 11, 20), today), 0);
    });

    test('reminder appears after a week, or when never backed up with data', () {
      expect(backupReminderDue(6, hasData: true), isFalse);
      expect(backupReminderDue(7, hasData: true), isTrue);
      expect(backupReminderDue(null, hasData: true), isTrue);
      expect(backupReminderDue(null, hasData: false), isFalse);
    });

    test('message wording', () {
      expect(backupReminderText(null), contains('not backed up'));
      expect(backupReminderText(1), contains('1 day ago'));
      expect(backupReminderText(9), contains('9 days ago'));
    });
  });

  group('revision today', () {
    test('counts today\'s items and items behind schedule', () {
      final onTrack = _cycle('2026-11-08', items: [
        _item(1, done: true),
        _item(1),
        _item(2),
      ]);
      final behind = _cycle('2026-11-07', items: [
        _item(1), // yesterday, not done
        _item(2, done: true), // today
      ]);
      final finished = _cycle('2026-11-01', completed: '2026-11-07', items: [
        _item(1),
      ]);
      final r = revisionToday([onTrack, behind, finished], today);
      expect(r.total, 3);
      expect(r.done, 2);
      expect(r.behind, 1);
    });
  });

  group('needs attention', () {
    test('everything fine means an empty list', () {
      final list = buildAttention(
        today: today,
        cycles: const [],
        tasks: [_task('2026-11-08')],
        tests: [_test('2026-11-20')],
        answers: const [],
        notes: [_note('2026-11-07')],
      );
      expect(list, isEmpty);
    });

    test('lists slipped work, most urgent first', () {
      final list = buildAttention(
        today: today,
        cycles: [_cycle('2026-10-01'), _cycle('2026-11-08')],
        tasks: [_task('2026-11-05'), _task('2026-11-06', done: true)],
        tests: [
          _test('2026-11-01'), // past, no result
          _test('2026-11-02', score: 90), // scored, analysis not done
          _test('2026-11-03', score: 90, analysis: true),
        ],
        answers: [
          _answer(AnswerStatus.written),
          _answer(AnswerStatus.needsRewrite),
          _answer(AnswerStatus.evaluated),
        ],
        notes: [_note('2026-11-01'), _note('2026-11-08')],
      );
      expect(list.map((a) => a.kind), [
        AttentionKind.revisionOverdue,
        AttentionKind.tasksCarried,
        AttentionKind.testResult,
        AttentionKind.caDue,
        AttentionKind.testAnalysis,
        AttentionKind.answerRewrite,
        AttentionKind.answerAwaiting,
      ]);
      expect(list.every((a) => a.count == 1), isTrue);
      expect(list.first.text, '1 revision cycle overdue');
      expect(list.first.route, '/revision');
      expect(list[1].route, '/planner');
      expect(list[3].route, '/notes');
    });

    test('plural wording', () {
      final list = buildAttention(
        today: today,
        cycles: const [],
        tasks: [_task('2026-11-01'), _task('2026-11-02')],
        tests: const [],
        answers: const [],
        notes: const [],
      );
      expect(list.single.text, '2 unfinished tasks from earlier days');
    });
  });
}
