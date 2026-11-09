import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/revision/models/revision_models.dart';
import 'package:upsc_command_centre/features/revision/revision_logic.dart';

int _n = 0;
String _id() => 'i${_n++}';

RevisionCycle _cycle({
  String start = '2026-11-01',
  int length = 7,
  String? completed,
  String target = 'gs1_polity',
  int number = 1,
  List<RevisionItem> items = const [],
}) =>
    RevisionCycle(
      id: 'c${_n++}',
      targetType: RevisionTargetType.gs,
      targetId: target,
      targetName: 'Polity',
      number: number,
      startDate: start,
      lengthDays: length,
      completedDate: completed,
      items: items,
      createdAt: '',
    );

void main() {
  group('buildCycleItems', () {
    test('7-day plan: topics over days 1-5, PYQs day 6, self-test day 7', () {
      final topics = [for (var i = 1; i <= 10; i++) 'T$i'];
      final items = buildCycleItems(topics: topics, length: 7, newId: _id);
      final topicDays =
          items.where((i) => i.kind == ItemKind.topic).map((i) => i.day);
      expect(topicDays.toList(), [1, 1, 2, 2, 3, 3, 4, 4, 5, 5]);
      expect(items.firstWhere((i) => i.kind == ItemKind.pyq).day, 6);
      expect(items.firstWhere((i) => i.kind == ItemKind.selftest).day, 7);
      expect(items.length, 12);
    });

    test('few topics fill the earliest days', () {
      final items =
          buildCycleItems(topics: ['A', 'B', 'C'], length: 7, newId: _id);
      expect(
        items.where((i) => i.kind == ItemKind.topic).map((i) => i.day).toList(),
        [1, 2, 3],
      );
    });

    test('3-day plan has one content day', () {
      final items =
          buildCycleItems(topics: ['A', 'B'], length: 3, newId: _id);
      expect(
        items.where((i) => i.kind == ItemKind.topic).map((i) => i.day).toList(),
        [1, 1],
      );
      expect(items.firstWhere((i) => i.kind == ItemKind.pyq).day, 2);
      expect(items.firstWhere((i) => i.kind == ItemKind.selftest).day, 3);
    });

    test('no topics still gives PYQ and self-test items', () {
      final items = buildCycleItems(topics: [], length: 7, newId: _id);
      expect(items.length, 2);
    });
  });

  test('redistributeTopics keeps ticks and spreads evenly', () {
    final base = buildCycleItems(
      topics: ['A', 'B', 'C', 'D'],
      length: 7,
      newId: _id,
    );
    final scrambled = [
      for (final i in base) i.kind == ItemKind.topic ? i.copyWith(day: 1) : i,
    ];
    final ticked = [
      scrambled.first.toggled(DateTime(2026, 11, 1)),
      ...scrambled.skip(1),
    ];
    final out = redistributeTopics(ticked, 7);
    final topics = out.where((i) => i.kind == ItemKind.topic).toList();
    expect(topics.map((i) => i.day).toList(), [1, 2, 3, 4]);
    expect(topics.first.done, isTrue);
  });

  test('applyLength moves PYQ/self-test and clamps topics', () {
    final items = buildCycleItems(
      topics: [for (var i = 0; i < 10; i++) 'T$i'],
      length: 7,
      newId: _id,
    );
    final out = applyLength(items, 5);
    expect(out.firstWhere((i) => i.kind == ItemKind.pyq).day, 4);
    expect(out.firstWhere((i) => i.kind == ItemKind.selftest).day, 5);
    expect(
      out.where((i) => i.kind == ItemKind.topic).every((i) => i.day <= 3),
      isTrue,
    );
  });

  test('parseItemLines strips bullets and blanks', () {
    expect(
      parseItemLines('- Preamble\n\n2) Rights\n• Duties\n  \nSchedules'),
      ['Preamble', 'Rights', 'Duties', 'Schedules'],
    );
  });

  group('dates and status', () {
    final today = DateTime(2026, 11, 8);

    test('target date is start + length - 1', () {
      expect(cycleTarget(_cycle()), DateTime(2026, 11, 7));
    });

    test('overdue only when active and past target', () {
      final c = _cycle(); // due 7 Nov
      expect(isOverdue(c, today), isTrue);
      expect(daysOverdue(c, today), 1);
      expect(isOverdue(_cycle(completed: '2026-11-06'), today), isFalse);
      expect(isOverdue(_cycle(start: '2026-11-05'), today), isFalse);
    });

    test('currentDay and behindCount', () {
      final items = buildCycleItems(
        topics: ['A', 'B', 'C', 'D', 'E'],
        length: 7,
        newId: _id,
      );
      final c = _cycle(start: '2026-11-05', items: items); // day 4 on 8 Nov
      expect(currentDay(c, today), 4);
      expect(behindCount(c, today), 3); // days 1-3 untouched
      final c2 = c.copyWith(
        items: [items.first.toggled(DateTime(2026, 11, 5)), ...items.skip(1)],
      );
      expect(behindCount(c2, today), 2);
    });

    test('status derives from items and completion date', () {
      final items = buildCycleItems(topics: ['A'], length: 7, newId: _id);
      expect(statusOf(_cycle(items: items)), CycleStatus.notStarted);
      final ticked = [items.first.toggled(DateTime.now()), ...items.skip(1)];
      expect(statusOf(_cycle(items: ticked)), CycleStatus.inProgress);
      expect(
        statusOf(_cycle(items: ticked, completed: '2026-11-08')),
        CycleStatus.completed,
      );
    });

    test('summary and cycle counting', () {
      final cycles = [
        _cycle(), // overdue
        _cycle(start: '2026-11-06'), // due 12 Nov -> due soon
        _cycle(start: '2026-12-20'), // far away
        _cycle(completed: '2026-11-03', number: 2),
      ];
      final s = summarize(cycles, today);
      expect(s.active, 3);
      expect(s.overdue, 1);
      expect(s.dueSoon, 1);
      expect(s.completed, 1);
      expect(
        completedCycleCount(cycles, RevisionTargetType.gs, 'gs1_polity'),
        1,
      );
      expect(
        nextCycleNumber(cycles, RevisionTargetType.gs, 'gs1_polity'),
        3,
      );
      expect(nextCycleNumber(cycles, RevisionTargetType.gs, 'other'), 1);
    });
  });

  test('cycle survives a JSON round trip including items', () {
    final items = buildCycleItems(topics: ['A', 'B'], length: 7, newId: _id);
    final c = _cycle(items: items).copyWith(notes: 'n');
    final back = RevisionCycle.fromJson(c.toJson());
    expect(back.items.length, items.length);
    expect(back.notes, 'n');
    expect(back.startDate, '2026-11-01');
  });
}
