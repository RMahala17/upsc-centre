import 'dart:math' as math;

import '../../core/utils/dates.dart';
import 'models/revision_models.dart';

const int kMinCycleDays = 3;
const int kMaxCycleDays = 30;
const int kDefaultCycleDays = 7;
const int kRequiredCycles = 2;

/// Days used for topic portions. The last two days are always
/// "PYQs and important topics" and "Full revision and self-test".
int contentDays(int length) => math.max(1, length - 2);

const String kPyqTitle = 'PYQs and important topics';
const String kSelfTestTitle = 'Full revision and self-test';

/// Spreads [topics] evenly over the content days (earlier days get the
/// extra ones), then adds the PYQ and self-test items.
List<RevisionItem> buildCycleItems({
  required List<String> topics,
  required int length,
  required String Function() newId,
}) {
  final c = contentDays(length);
  final n = topics.length;
  final base = n ~/ c;
  final extra = n % c;
  final items = <RevisionItem>[];
  var idx = 0;
  var order = 1;
  for (var d = 1; d <= c; d++) {
    final count = base + (d <= extra ? 1 : 0);
    for (var k = 0; k < count; k++) {
      items.add(RevisionItem(
        id: newId(),
        title: topics[idx],
        day: d,
        order: order++,
      ));
      idx++;
    }
  }
  items.add(RevisionItem(
    id: newId(),
    title: kPyqTitle,
    day: length - 1,
    order: order++,
    kind: ItemKind.pyq,
  ));
  items.add(RevisionItem(
    id: newId(),
    title: kSelfTestTitle,
    day: length,
    order: order++,
    kind: ItemKind.selftest,
  ));
  return items;
}

/// Re-spreads topic items evenly over the content days, keeping their order
/// and ticks. PYQ / self-test items are left alone.
List<RevisionItem> redistributeTopics(List<RevisionItem> items, int length) {
  final topics = items.where((i) => i.kind == ItemKind.topic).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  final c = contentDays(length);
  final n = topics.length;
  final base = n ~/ c;
  final extra = n % c;
  final newDay = <String, int>{};
  var idx = 0;
  for (var d = 1; d <= c; d++) {
    final count = base + (d <= extra ? 1 : 0);
    for (var k = 0; k < count; k++) {
      newDay[topics[idx].id] = d;
      idx++;
    }
  }
  return [
    for (final i in items)
      i.kind == ItemKind.topic ? i.copyWith(day: newDay[i.id] ?? i.day) : i,
  ];
}

/// Adjusts item days after the cycle length changes.
List<RevisionItem> applyLength(List<RevisionItem> items, int length) {
  final c = contentDays(length);
  return [
    for (final i in items)
      switch (i.kind) {
        ItemKind.pyq => i.copyWith(day: length - 1),
        ItemKind.selftest => i.copyWith(day: length),
        ItemKind.topic => i.copyWith(day: math.min(i.day, c)),
      },
  ];
}

final RegExp _itemBullet = RegExp(r'^\s*(?:[-*•]\s+|\d{1,3}[.)]\s+)');

/// One item per line; strips simple bullets/numbering; skips blanks.
List<String> parseItemLines(String raw) {
  final out = <String>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    final t = line.replaceFirst(_itemBullet, '').trim();
    if (t.isNotEmpty) out.add(t);
  }
  return out;
}

// ---------------------------------------------------------------------------
// Dates and status
// ---------------------------------------------------------------------------

DateTime cycleStart(RevisionCycle c) => parseDateKey(c.startDate);
DateTime cycleTarget(RevisionCycle c) =>
    addDays(cycleStart(c), c.lengthDays - 1);
DateTime itemDate(RevisionCycle c, RevisionItem i) =>
    addDays(cycleStart(c), i.day - 1);

bool isActive(RevisionCycle c) => c.completedDate == null;

CycleStatus statusOf(RevisionCycle c) {
  if (c.completedDate != null) return CycleStatus.completed;
  return c.items.any((i) => i.done)
      ? CycleStatus.inProgress
      : CycleStatus.notStarted;
}

bool isOverdue(RevisionCycle c, DateTime today) =>
    isActive(c) && dateOnly(today).isAfter(cycleTarget(c));

int daysOverdue(RevisionCycle c, DateTime today) =>
    daysBetween(cycleTarget(c), dateOnly(today));

int daysUntilDue(RevisionCycle c, DateTime today) =>
    daysBetween(dateOnly(today), cycleTarget(c));

/// 1-based day of the plan that [today] falls on (<= 0 means not started yet).
int currentDay(RevisionCycle c, DateTime today) =>
    daysBetween(cycleStart(c), dateOnly(today)) + 1;

/// Unticked items planned for an earlier day than today.
int behindCount(RevisionCycle c, DateTime today) {
  if (!isActive(c)) return 0;
  final cd = currentDay(c, today);
  return c.items.where((i) => !i.done && i.day < cd).length;
}

/// All items planned for today (ticked or not), for active cycles only.
List<RevisionItem> todaysItems(RevisionCycle c, DateTime today) {
  if (!isActive(c)) return const [];
  final cd = currentDay(c, today);
  final list = c.items.where((i) => i.day == cd).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return list;
}

class RevisionSummary {
  const RevisionSummary({
    required this.active,
    required this.overdue,
    required this.dueSoon,
    required this.completed,
  });
  final int active;
  final int overdue;

  /// Active, not overdue, due within the next 7 days (including today).
  final int dueSoon;
  final int completed;
}

RevisionSummary summarize(List<RevisionCycle> cycles, DateTime today) {
  var active = 0, overdue = 0, soon = 0, done = 0;
  for (final c in cycles) {
    if (!isActive(c)) {
      done++;
      continue;
    }
    active++;
    if (isOverdue(c, today)) {
      overdue++;
    } else if (daysUntilDue(c, today) <= 7) {
      soon++;
    }
  }
  return RevisionSummary(
    active: active,
    overdue: overdue,
    dueSoon: soon,
    completed: done,
  );
}

int completedCycleCount(
  List<RevisionCycle> cycles,
  RevisionTargetType type,
  String targetId,
) =>
    cycles
        .where((c) =>
            c.targetType == type && c.targetId == targetId && !isActive(c))
        .length;

bool hasActiveCycle(
  List<RevisionCycle> cycles,
  RevisionTargetType type,
  String targetId,
) =>
    cycles.any((c) =>
        c.targetType == type && c.targetId == targetId && isActive(c));

int nextCycleNumber(
  List<RevisionCycle> cycles,
  RevisionTargetType type,
  String targetId,
) {
  var maxN = 0;
  for (final c in cycles) {
    if (c.targetType == type && c.targetId == targetId) {
      maxN = math.max(maxN, c.number);
    }
  }
  return maxN + 1;
}
