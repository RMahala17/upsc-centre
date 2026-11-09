import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/planner/models/planner_models.dart';
import 'package:upsc_command_centre/features/planner/planner_logic.dart';
import 'package:upsc_command_centre/features/syllabus/models/syllabus_models.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';

int _n = 0;

PlannerTask _t(
  String date, {
  int order = 1,
  bool done = false,
  int planned = 0,
  String title = 'Task',
}) =>
    PlannerTask(
      id: 't${_n++}',
      date: date,
      title: title,
      category: StudyCategory.gs,
      plannedMin: planned,
      done: done,
      order: order,
      createdAt: '',
    );

void main() {
  group('planner day lists', () {
    test('tasksOnDate filters by day and sorts by order', () {
      final a = _t('2026-11-08', order: 2);
      final b = _t('2026-11-08', order: 1);
      final c = _t('2026-11-09', order: 1);
      final out = tasksOnDate([a, b, c], '2026-11-08');
      expect(out.map((t) => t.id).toList(), [b.id, a.id]);
    });

    test('unfinishedBefore skips done tasks, today and the future', () {
      final old = _t('2026-11-05');
      final doneOld = _t('2026-11-06', done: true);
      final yesterday = _t('2026-11-07');
      final today = _t('2026-11-08');
      final future = _t('2026-11-09');
      final out = unfinishedBefore(
        [future, today, yesterday, doneOld, old],
        '2026-11-08',
      );
      expect(out.map((t) => t.id).toList(), [old.id, yesterday.id]);
    });

    test('summarizeDay counts done tasks and adds planned minutes', () {
      final s = summarizeDay([
        _t('2026-11-08', planned: 30, done: true),
        _t('2026-11-08'),
        _t('2026-11-08', planned: 45),
      ]);
      expect(s.total, 3);
      expect(s.done, 1);
      expect(s.plannedMin, 75);
      expect(s.fraction, closeTo(1 / 3, 1e-9));
    });

    test('an empty day has zero progress, not a fake value', () {
      final s = summarizeDay(const []);
      expect(s.total, 0);
      expect(s.fraction, 0);
    });
  });

  group('PlannerTask', () {
    test('toggling sets then clears doneAt', () {
      final t = _t('2026-11-08');
      final done = t.toggled(DateTime(2026, 11, 8, 10));
      expect(done.done, isTrue);
      expect(done.doneAt, isNotNull);
      final undone = done.toggled(DateTime(2026, 11, 8, 11));
      expect(undone.done, isFalse);
      expect(undone.doneAt, isNull);
    });

    test('survives a JSON round trip', () {
      final t = _t('2026-11-08', planned: 90, title: 'Kinship notes')
          .copyWith(carryCount: 2);
      final back = PlannerTask.fromJson(t.toJson());
      expect(back.title, 'Kinship notes');
      expect(back.plannedMin, 90);
      expect(back.carryCount, 2);
      expect(back.date, '2026-11-08');
    });

    test('missing and unknown fields get safe defaults', () {
      final t = PlannerTask.fromJson({'id': 'x', 'category': 'zzz'});
      expect(t.category, StudyCategory.other);
      expect(t.plannedMin, 0);
      expect(t.carryCount, 0);
      expect(t.done, isFalse);
    });
  });

  group('helpers', () {
    test('lecturesCompletedOn counts only lectures ticked that day', () {
      Lecture lec({required bool completed, String? at}) => Lecture(
            id: 'l${_n++}',
            subjectId: 's',
            title: 'L',
            order: 1,
            completed: completed,
            completedAt: at,
            createdAt: '',
          );
      final day = DateTime(2026, 11, 8);
      final list = [
        lec(completed: true, at: DateTime(2026, 11, 8, 10).toIso8601String()),
        lec(completed: true, at: DateTime(2026, 11, 7, 23).toIso8601String()),
        lec(completed: true), // historical: no date, never counted
        lec(completed: false, at: DateTime(2026, 11, 8, 9).toIso8601String()),
      ];
      expect(lecturesCompletedOn(list, day), 1);
    });

    test('parsePlannedMinutes', () {
      expect(parsePlannedMinutes(''), 0);
      expect(parsePlannedMinutes('  '), 0);
      expect(parsePlannedMinutes(' 45 '), 45);
      expect(parsePlannedMinutes('1440'), 1440);
      expect(parsePlannedMinutes('1441'), isNull);
      expect(parsePlannedMinutes('abc'), isNull);
      expect(parsePlannedMinutes('-5'), isNull);
    });
  });
}
