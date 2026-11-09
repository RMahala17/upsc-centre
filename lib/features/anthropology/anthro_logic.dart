import 'dart:math' as math;

import '../../core/utils/dates.dart';
import '../syllabus/models/syllabus_models.dart';

// ---------------------------------------------------------------------------
// Chapter list parsing ("Name, 8" / "Name | 8" / "Name - 8" / one per line)
// ---------------------------------------------------------------------------

class ParsedChapter {
  const ParsedChapter(this.name, this.lectures);
  final String name;
  final int lectures;
}

final RegExp _bulletPrefix = RegExp(r'^\s*(?:[-*•]\s+|\d{1,3}[.)]\s+)');
final RegExp _countSuffix = RegExp(
  r'^(.+?)\s*(?:\||,|:|\t|\s-\s|\s–\s)\s*(\d{1,3})\s*(?:lectures?|lecs?)?\s*$',
  caseSensitive: false,
);

List<ParsedChapter> parseChapterList(String raw) {
  final out = <ParsedChapter>[];
  for (final line in raw.split(RegExp(r'\r?\n'))) {
    var t = line.trim();
    if (t.isEmpty) continue;
    t = t.replaceFirst(_bulletPrefix, '').trim();
    if (t.isEmpty) continue;

    var name = t;
    var count = 0;
    final m = _countSuffix.firstMatch(t);
    if (m != null) {
      final n = int.parse(m.group(2)!);
      if (n <= 200) {
        name = m.group(1)!.trim();
        count = n;
      }
    }
    if (name.isEmpty) continue;
    out.add(ParsedChapter(name, count));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Pace and estimated completion (based only on lectures that have a real
// completion date recorded in this app)
// ---------------------------------------------------------------------------

class PaceEstimate {
  const PaceEstimate({
    required this.lecturesPerDay,
    required this.windowDays,
    required this.completedInWindow,
    required this.enoughData,
    this.eta,
  });

  final double lecturesPerDay;
  final int windowDays;
  final int completedInWindow;

  /// False until there are at least [minDays] days of recorded data.
  final bool enoughData;
  final DateTime? eta;
}

/// Returns null when no lecture has a recorded completion date.
PaceEstimate? computePace({
  required List<Lecture> lectures,
  required DateTime now,
  required int remaining,
  int maxWindowDays = 14,
  int minDays = 3,
}) {
  final dated = <DateTime>[];
  for (final l in lectures) {
    if (!l.completed || l.completedAt == null) continue;
    final d = DateTime.tryParse(l.completedAt!);
    if (d != null) dated.add(d.toLocal());
  }
  if (dated.isEmpty) return null;

  final today = DateTime(now.year, now.month, now.day);
  dated.sort();
  final first = DateTime(dated.first.year, dated.first.month, dated.first.day);
  final windowStart = addDays(today, -(maxWindowDays - 1));
  final start = first.isAfter(windowStart) ? first : windowStart;
  final days = math.max(1, daysBetween(start, today) + 1);

  final inWindow = dated
      .where((d) => !DateTime(d.year, d.month, d.day).isBefore(start))
      .length;
  final pace = inWindow / days;
  final enough = days >= minDays;

  DateTime? eta;
  if (enough && pace > 0 && remaining > 0) {
    eta = addDays(today, (remaining / pace).ceil());
  }
  return PaceEstimate(
    lecturesPerDay: pace,
    windowDays: days,
    completedInWindow: inWindow,
    enoughData: enough,
    eta: eta,
  );
}

/// Finish date if the daily target were met every day from today.
DateTime? targetEta({
  required int remaining,
  required int dailyTarget,
  required DateTime now,
}) {
  if (remaining <= 0 || dailyTarget <= 0) return null;
  final today = DateTime(now.year, now.month, now.day);
  return addDays(today, (remaining / dailyTarget).ceil());
}
