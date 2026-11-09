import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/core/utils/dates.dart';
import 'package:upsc_command_centre/core/utils/durations.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';
import 'package:upsc_command_centre/features/timer/timer_logic.dart';

int _n = 0;

StudySession _s(
  String date,
  int sec, {
  String category = StudyCategory.gs,
  String? taskId,
  String? start,
}) =>
    StudySession(
      id: 's${_n++}',
      date: date,
      startedAt: start ?? '${date}T10:00:00.000',
      durationSec: sec,
      category: category,
      taskId: taskId,
      createdAt: '',
    );

void main() {
  group('ActiveTimer', () {
    test('counts elapsed time from the start timestamp', () {
      final t = ActiveTimer.start(1000);
      expect(t.running, isTrue);
      expect(t.elapsedMs(6000), 5000);
      expect(t.elapsedSec(6000), 5);
    });

    test('pause freezes the clock', () {
      final p = ActiveTimer.start(1000).paused(6000);
      expect(p.running, isFalse);
      expect(p.elapsedMs(6000), 5000);
      expect(p.elapsedMs(999999), 5000);
    });

    test('resume continues from the banked time', () {
      final r = ActiveTimer.start(1000).paused(6000).resumed(10000);
      expect(r.running, isTrue);
      expect(r.elapsedMs(13000), 8000); // 5s before pause + 3s after
    });

    test('pausing a paused timer, or resuming a running one, changes nothing',
        () {
      final running = ActiveTimer.start(0);
      final paused = running.paused(1000);
      expect(identical(paused.paused(5000), paused), isTrue);
      expect(identical(running.resumed(5000), running), isTrue);
    });

    test('survives being killed: saved JSON restores the same elapsed time',
        () {
      final running = ActiveTimer.start(
        1000,
        category: StudyCategory.anthro,
        label: 'Kinship',
        taskId: 'task-1',
      );
      final restored = ActiveTimer.tryParse(running.toJson())!;
      expect(restored.running, isTrue);
      expect(restored.elapsedMs(50000), running.elapsedMs(50000));
      expect(restored.category, StudyCategory.anthro);
      expect(restored.label, 'Kinship');
      expect(restored.taskId, 'task-1');

      final paused = running.paused(9000);
      final restoredPaused = ActiveTimer.tryParse(paused.toJson())!;
      expect(restoredPaused.running, isFalse);
      expect(restoredPaused.elapsedMs(123456), 8000);
    });

    test('a clock moved backwards never gives negative time', () {
      expect(ActiveTimer.start(10000).elapsedMs(5000), 0);
    });

    test('malformed stored data is ignored instead of crashing', () {
      expect(ActiveTimer.tryParse(null), isNull);
      expect(ActiveTimer.tryParse({'accumulatedMs': 5}), isNull);
      expect(ActiveTimer.tryParse({'sessionStartMs': 'x'}), isNull);
      final minimal = ActiveTimer.tryParse({'sessionStartMs': 7})!;
      expect(minimal.running, isFalse);
      expect(minimal.accumulatedMs, 0);
      expect(minimal.category, StudyCategory.gs);
    });

    test('unknown category falls back to other', () {
      final t = ActiveTimer.tryParse(
        {'sessionStartMs': 1, 'category': 'from_the_future'},
      )!;
      expect(t.category, StudyCategory.other);
    });

    test('changing label or category keeps the timing', () {
      final t = ActiveTimer.start(1000).paused(4000);
      final m = t.withMeta(category: StudyCategory.revision, label: 'Polity');
      expect(m.elapsedMs(0), 3000);
      expect(m.running, isFalse);
      expect(m.category, StudyCategory.revision);
      expect(m.label, 'Polity');
    });
  });

  group('session aggregation', () {
    test('totalSecOnDate adds only that day', () {
      final list = [
        _s('2026-11-08', 600),
        _s('2026-11-08', 900),
        _s('2026-11-07', 3000),
      ];
      expect(totalSecOnDate(list, '2026-11-08'), 1500);
      expect(totalSecOnDate(list, '2026-11-01'), 0);
    });

    test('lastNDays is oldest first, ends today, fills empty days with 0', () {
      final today = DateTime(2026, 11, 8);
      final days = lastNDays(
        [_s('2026-11-08', 60), _s('2026-11-05', 120)],
        today,
        7,
      );
      expect(days.length, 7);
      expect(dateKey(days.first.day), '2026-11-02');
      expect(dateKey(days.last.day), '2026-11-08');
      expect(days.last.sec, 60);
      expect(days[3].sec, 120); // Nov 5
      expect(days[0].sec, 0);
    });

    test('lastNDays crosses a month boundary correctly', () {
      final days = lastNDays(const [], DateTime(2026, 11, 2), 7);
      expect(dateKey(days.first.day), '2026-10-27');
    });

    test('sessionsOnDate returns most recent first', () {
      final a = _s('2026-11-08', 60, start: '2026-11-08T08:00:00.000');
      final b = _s('2026-11-08', 60, start: '2026-11-08T15:00:00.000');
      final c = _s('2026-11-07', 60);
      final out = sessionsOnDate([a, c, b], '2026-11-08');
      expect(out.map((s) => s.id).toList(), [b.id, a.id]);
    });

    test('secByCategory and secOnTask', () {
      final list = [
        _s('2026-11-08', 100, category: StudyCategory.gs, taskId: 't1'),
        _s('2026-11-08', 200, category: StudyCategory.gs),
        _s('2026-11-08', 50, category: StudyCategory.anthro, taskId: 't1'),
      ];
      final by = secByCategory(list);
      expect(by[StudyCategory.gs], 300);
      expect(by[StudyCategory.anthro], 50);
      expect(secOnTask(list, 't1'), 150);
      expect(secOnTask(list, 'nope'), 0);
    });

    test('session survives a JSON round trip', () {
      final s = _s('2026-11-08', 1800, taskId: 'abc');
      final back = StudySession.fromJson(s.toJson());
      expect(back.date, '2026-11-08');
      expect(back.durationSec, 1800);
      expect(back.taskId, 'abc');
      expect(back.manual, isFalse);
      expect(StudySession.fromJson(_s('2026-11-08', 5).toJson()).taskId, isNull);
    });
  });

  group('duration formatting', () {
    test('formatClock', () {
      expect(formatClock(0), '0:00:00');
      expect(formatClock(309), '0:05:09');
      expect(formatClock(5400), '1:30:00');
      expect(formatClock(-5), '0:00:00');
    });

    test('formatHm', () {
      expect(formatHm(0), '0m');
      expect(formatHm(59), '<1m');
      expect(formatHm(125), '2m');
      expect(formatHm(3600), '1h');
      expect(formatHm(5400), '1h 30m');
    });
  });
}
