import '../../core/utils/dates.dart';
import '../timer/models/session_models.dart';
import 'models/ca_models.dart';

/// Spaced revision of current affairs. The first revision is due this many
/// days after the note's date; each later one is due this many days after the
/// PREVIOUS revision. Revising late therefore pushes the next one back
/// instead of nagging again straight away.
const List<int> kCaRevisionGaps = [7, 21, 60];

DateTime noteDay(CaNote n) => parseDateKey(n.date);

/// When the next revision is due, or null once every revision is done.
DateTime? nextRevisionDate(CaNote n) {
  if (n.revisions >= kCaRevisionGaps.length) return null;
  final gap = kCaRevisionGaps[n.revisions];
  if (n.revisions == 0) return addDays(noteDay(n), gap);
  final last =
      n.lastRevisedAt == null ? null : DateTime.tryParse(n.lastRevisedAt!);
  final anchor = last == null ? noteDay(n) : dateOnly(last.toLocal());
  return addDays(anchor, gap);
}

bool isDueForRevision(CaNote n, DateTime today) {
  final next = nextRevisionDate(n);
  return next != null && !dateOnly(today).isBefore(next);
}

/// Days past the due date (0 = due today). Zero when not due.
int caDaysOverdue(CaNote n, DateTime today) {
  final next = nextRevisionDate(n);
  if (next == null) return 0;
  final d = daysBetween(next, dateOnly(today));
  return d < 0 ? 0 : d;
}

bool isFullyRevised(CaNote n) => n.revisions >= kCaRevisionGaps.length;

/// Records one revision.
CaNote applyRevision(CaNote n, DateTime now) {
  if (isFullyRevised(n)) return n;
  return n.copyWith(
    revisions: n.revisions + 1,
    lastRevisedAt: now.toIso8601String(),
  );
}

CaNote resetRevisions(CaNote n) => n.copyWith(revisions: 0, lastRevisedAt: null);

/// Notes due now, most overdue first (then newest note first).
List<CaNote> dueNotes(Iterable<CaNote> all, DateTime today) {
  final list = all.where((n) => isDueForRevision(n, today)).toList()
    ..sort((a, b) {
      final c = caDaysOverdue(b, today).compareTo(caDaysOverdue(a, today));
      return c != 0 ? c : b.date.compareTo(a.date);
    });
  return list;
}

/// Notes whose next revision falls within the next [days] days (not today).
/// Soonest first.
List<CaNote> upcomingNotes(Iterable<CaNote> all, DateTime today,
    {int days = 7}) {
  final t = dateOnly(today);
  final limit = addDays(t, days);
  final list = <CaNote>[];
  for (final n in all) {
    final next = nextRevisionDate(n);
    if (next == null) continue;
    if (next.isAfter(t) && !next.isAfter(limit)) list.add(n);
  }
  list.sort((a, b) => nextRevisionDate(a)!.compareTo(nextRevisionDate(b)!));
  return list;
}

/// Newest day first, then newest entry first within a day.
List<CaNote> filterNotes(
  Iterable<CaNote> all, {
  String? scope,
  String? topic,
  String? exam,
  bool starredOnly = false,
  String query = '',
}) {
  final q = query.trim().toLowerCase();
  final list = all.where((n) {
    if (scope != null && n.scope != scope) return false;
    if (topic != null && n.topic != topic) return false;
    if (exam != null && !n.exams.contains(exam)) return false;
    if (starredOnly && !n.starred) return false;
    if (q.isNotEmpty &&
        !n.title.toLowerCase().contains(q) &&
        !n.summary.toLowerCase().contains(q) &&
        !n.source.toLowerCase().contains(q)) {
      return false;
    }
    return true;
  }).toList()
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
  return list;
}

class CaStats {
  const CaStats({
    required this.total,
    required this.last7Days,
    required this.starred,
    required this.due,
    required this.fullyRevised,
  });

  final int total;

  /// Notes dated in the 7 days up to and including today.
  final int last7Days;
  final int starred;

  /// Notes due for revision right now.
  final int due;
  final int fullyRevised;
}

CaStats summarizeCa(Iterable<CaNote> all, DateTime today) {
  final from = dateKey(addDays(dateOnly(today), -6));
  final to = dateKey(dateOnly(today));
  var total = 0, last7 = 0, starred = 0, due = 0, full = 0;
  for (final n in all) {
    total++;
    if (n.date.compareTo(from) >= 0 && n.date.compareTo(to) <= 0) last7++;
    if (n.starred) starred++;
    if (isDueForRevision(n, today)) due++;
    if (isFullyRevised(n)) full++;
  }
  return CaStats(
    total: total,
    last7Days: last7,
    starred: starred,
    due: due,
    fullyRevised: full,
  );
}

class KeyCount {
  const KeyCount(this.key, this.count);
  final String key;
  final int count;
}

/// Counts per group, biggest first (ties by key).
List<KeyCount> countBy(Iterable<CaNote> all, String Function(CaNote) keyOf) {
  final counts = <String, int>{};
  for (final n in all) {
    final k = keyOf(n);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final out = [for (final e in counts.entries) KeyCount(e.key, e.value)]
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return out;
}

class DayCount {
  const DayCount(this.day, this.count);
  final DateTime day;
  final int count;
}

/// Notes per day for the [n] days ending on [today], oldest first.
List<DayCount> notesPerDay(Iterable<CaNote> all, DateTime today, int n) {
  final byDate = <String, int>{};
  for (final note in all) {
    byDate[note.date] = (byDate[note.date] ?? 0) + 1;
  }
  final t = dateOnly(today);
  return [
    for (var i = n - 1; i >= 0; i--)
      DayCount(addDays(t, -i), byDate[dateKey(addDays(t, -i))] ?? 0),
  ];
}

/// Notes per calendar month for the last [months] months, oldest first.
/// Keys look like "2026-11".
List<KeyCount> notesPerMonth(Iterable<CaNote> all, DateTime today,
    {int months = 6}) {
  final counts = <String, int>{};
  for (final n in all) {
    if (n.date.length < 7) continue;
    final k = n.date.substring(0, 7);
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final out = <KeyCount>[];
  for (var i = months - 1; i >= 0; i--) {
    final d = DateTime(today.year, today.month - i, 1);
    final k = '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}';
    out.add(KeyCount(k, counts[k] ?? 0));
  }
  return out;
}

/// Days on which current affairs was worked on: a note was written, or a
/// current-affairs study session was logged.
Set<String> caActiveDays(
  Iterable<CaNote> notes,
  Iterable<StudySession> sessions,
) {
  final days = <String>{};
  for (final n in notes) {
    if (n.date.isNotEmpty) days.add(n.date);
  }
  for (final s in sessions) {
    if (s.category == StudyCategory.currentAffairs &&
        s.durationSec > 0 &&
        s.date.isNotEmpty) {
      days.add(s.date);
    }
  }
  return days;
}

/// Sources already used (most used first), then common defaults. No
/// duplicates.
List<String> sourceSuggestions(Iterable<CaNote> all, {int max = 8}) {
  final counts = <String, int>{};
  for (final n in all) {
    final s = n.source.trim();
    if (s.isEmpty) continue;
    counts[s] = (counts[s] ?? 0) + 1;
  }
  final used = counts.keys.toList()
    ..sort((a, b) {
      final c = counts[b]!.compareTo(counts[a]!);
      return c != 0 ? c : a.compareTo(b);
    });
  final out = <String>[...used];
  for (final d in const ['The Hindu', 'Indian Express', 'PIB', 'Yojana']) {
    if (!out.contains(d)) out.add(d);
  }
  return out.length > max ? out.sublist(0, max) : out;
}
