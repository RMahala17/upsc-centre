import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/dashboard/home_logic.dart';
import 'package:upsc_command_centre/features/planner/models/planner_models.dart';
import 'package:upsc_command_centre/features/revision/models/revision_models.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';

PlannerTask _task(String id, String date, int order, {bool done = false}) =>
    PlannerTask(
      id: id,
      date: date,
      title: 'Task $id',
      category: StudyCategory.gs,
      order: order,
      done: done,
      createdAt: '2026-11-01T00:00:00',
    );

StudySession _session(String date, int sec) => StudySession(
      id: 's$date$sec',
      date: date,
      startedAt: '${date}T08:00:00',
      durationSec: sec,
      category: StudyCategory.gs,
      createdAt: '${date}T09:00:00',
    );

void main() {
  group('overallPercent', () {
    test('combines GS and Anthropology lectures', () {
      expect(
        overallPercent(gsDone: 40, gsTotal: 100, anDone: 10, anTotal: 100),
        25,
      );
    });

    test('is 0 when nothing is entered', () {
      expect(overallPercent(gsDone: 0, gsTotal: 0, anDone: 0, anTotal: 0), 0);
    });

    test('is 100 when everything is done', () {
      expect(overallPercent(gsDone: 3, gsTotal: 3, anDone: 0, anTotal: 0), 100);
    });
  });

  group('revisionPyqProgress', () {
    test('adds revision items and practised PYQs', () {
      final cycle = RevisionCycle(
        id: 'c1',
        targetType: RevisionTargetType.gs,
        targetId: 'g1',
        targetName: 'Polity',
        number: 1,
        startDate: '2026-11-01',
        lengthDays: 7,
        createdAt: '2026-11-01T00:00:00',
        items: const [
          RevisionItem(id: 'a', title: 'A', day: 1, order: 0, done: true),
          RevisionItem(id: 'b', title: 'B', day: 1, order: 1),
          RevisionItem(id: 'c', title: 'C', day: 2, order: 2),
        ],
      );
      final p = revisionPyqProgress([cycle], pyqPractised: 2, pyqTotal: 4);
      expect(p.done, 3);
      expect(p.total, 7);
      expect(p.percent, 43);
    });

    test('is empty with no data', () {
      final p = revisionPyqProgress(const [], pyqPractised: 0, pyqTotal: 0);
      expect(p.total, 0);
      expect(p.percent, 0);
      expect(p.fraction, 0);
    });
  });

  group('examBadge', () {
    final today = DateTime(2026, 11, 10);

    test('uses the year of the next UPSC date', () {
      expect(
        examBadge(
          {'upsc_prelims': '2027-05-24', 'upsc_mains': '2027-09-18'},
          today,
        ),
        'UPSC 2027',
      );
    });

    test('prefers an upcoming date over one already passed', () {
      expect(
        examBadge(
          {'upsc_prelims': '2026-05-24', 'upsc_mains': '2027-09-18'},
          today,
        ),
        'UPSC 2027',
      );
    });

    test('falls back to the last passed date', () {
      expect(examBadge({'upsc_prelims': '2026-05-24'}, today), 'UPSC 2026');
    });

    test('uses UPPCS when only UPPCS dates are set', () {
      expect(examBadge({'uppcs_prelims': '2027-03-01'}, today), 'UPPCS 2027');
    });

    test('ignores invalid dates and falls back', () {
      expect(examBadge({'upsc_prelims': '2027-02-31'}, today), 'UPSC · UPPCS');
      expect(examBadge(const {}, today), 'UPSC · UPPCS');
    });
  });

  group('nextTarget', () {
    test('picks the first unfinished task of today in order', () {
      final tasks = [
        _task('t1', '2026-11-10', 2),
        _task('t2', '2026-11-10', 1),
        _task('t3', '2026-11-10', 0, done: true),
        _task('t4', '2026-11-11', 0),
      ];
      expect(nextTarget(tasks, '2026-11-10')!.id, 't2');
    });

    test('is null when everything is done or nothing is planned', () {
      expect(
        nextTarget([_task('t1', '2026-11-10', 0, done: true)], '2026-11-10'),
        isNull,
      );
      expect(nextTarget(const [], '2026-11-10'), isNull);
    });
  });

  group('weekHours', () {
    test('runs Monday to Sunday and marks today and the future', () {
      final days = weekHours(
        [
          _session('2026-11-08', 999), // previous Sunday: not in this week
          _session('2026-11-09', 3600),
          _session('2026-11-10', 1800),
          _session('2026-11-10', 600),
        ],
        DateTime(2026, 11, 10, 15, 30),
      );
      expect(days.map((d) => d.label).toList(),
          ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']);
      expect(days[0].day, DateTime(2026, 11, 9));
      expect(days[0].sec, 3600);
      expect(days[1].sec, 2400);
      expect(days[1].isToday, isTrue);
      expect(days[0].isToday, isFalse);
      expect(days[2].isFuture, isTrue);
      expect(days[6].sec, 0);
    });

    test('works across a month boundary', () {
      final days = weekHours(const [], DateTime(2026, 12, 1));
      expect(days.first.day, DateTime(2026, 11, 30));
      expect(days.last.day, DateTime(2026, 12, 6));
    });

    test('on a Sunday the whole week is past or today', () {
      final days = weekHours(const [], DateTime(2026, 11, 15));
      expect(days.first.day, DateTime(2026, 11, 9));
      expect(days.last.isToday, isTrue);
      expect(days.any((d) => d.isFuture), isFalse);
    });
  });
}
