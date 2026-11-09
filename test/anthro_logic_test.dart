import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/anthropology/anthro_controller.dart';
import 'package:upsc_command_centre/features/anthropology/anthro_logic.dart';
import 'package:upsc_command_centre/features/anthropology/models/anthro_models.dart';
import 'package:upsc_command_centre/features/syllabus/models/syllabus_models.dart';

Lecture _done(String id, DateTime at, {String chapter = 'c1'}) => Lecture(
      id: id,
      subjectId: chapter,
      title: 'L$id',
      order: 1,
      completed: true,
      completedAt: at.toIso8601String(),
      createdAt: '2026-01-01T00:00:00.000',
    );

void main() {
  group('parseChapterList', () {
    test('parses names with and without counts', () {
      final r = parseChapterList(
        'Human Evolution, 8\n'
        '- Genetics | 6\n'
        '3) Culture\n'
        'Pre-historic Cultures - 4\n'
        '\n'
        'Long, name here, 10 lectures\n',
      );
      expect(r.map((e) => e.name).toList(), [
        'Human Evolution',
        'Genetics',
        'Culture',
        'Pre-historic Cultures',
        'Long, name here',
      ]);
      expect(r.map((e) => e.lectures).toList(), [8, 6, 0, 4, 10]);
    });

    test('empty input gives no chapters', () {
      expect(parseChapterList('  \n \n'), isEmpty);
    });
  });

  group('computePace', () {
    final now = DateTime(2026, 11, 20, 12);

    test('returns null when nothing has a recorded date', () {
      final undated = Lecture(
        id: 'u',
        subjectId: 'c1',
        title: 'x',
        order: 1,
        completed: true,
        createdAt: '',
      );
      expect(computePace(lectures: [undated], now: now, remaining: 10), isNull);
    });

    test('computes pace and ETA from real completions', () {
      final ls = [
        _done('1', DateTime(2026, 11, 16, 9)),
        _done('2', DateTime(2026, 11, 17, 9)),
        _done('3', DateTime(2026, 11, 18, 9)),
        _done('4', DateTime(2026, 11, 18, 15)),
        _done('5', DateTime(2026, 11, 20, 9)),
      ];
      final p = computePace(lectures: ls, now: now, remaining: 10)!;
      expect(p.windowDays, 5);
      expect(p.completedInWindow, 5);
      expect(p.lecturesPerDay, 1.0);
      expect(p.enoughData, isTrue);
      expect(p.eta, DateTime(2026, 11, 30));
    });

    test('does not estimate with under 3 days of data', () {
      final ls = [
        _done('1', DateTime(2026, 11, 19, 9)),
        _done('2', DateTime(2026, 11, 20, 9)),
      ];
      final p = computePace(lectures: ls, now: now, remaining: 10)!;
      expect(p.enoughData, isFalse);
      expect(p.eta, isNull);
    });
  });

  test('targetEta rounds up whole days', () {
    final eta = targetEta(
      remaining: 5,
      dailyTarget: 2,
      now: DateTime(2026, 11, 8, 20),
    );
    expect(eta, DateTime(2026, 11, 11));
    expect(targetEta(remaining: 0, dailyTarget: 2, now: DateTime.now()), isNull);
  });

  test('overall progress is measured against the planned total', () {
    final state = AnthroState(
      chapters: const [
        Chapter(
            id: 'c1',
            paper: AnthroPaper.paper1,
            name: 'A',
            order: 1,
            createdAt: ''),
      ],
      lectures: [
        _done('1', DateTime(2026, 11, 1)),
        _done('2', DateTime(2026, 11, 2)),
        Lecture(
            id: '3',
            subjectId: 'c1',
            title: 'L3',
            order: 3,
            createdAt: ''),
      ],
      dailyTarget: 2,
      plannedTotal: 176,
    );
    expect(state.entered, 3);
    expect(state.completed, 2);
    expect(state.denominator, 176);
    expect(state.remaining, 174);
    expect(state.unentered, 173);
  });
}
