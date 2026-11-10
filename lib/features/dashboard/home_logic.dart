import '../../core/utils/dates.dart';
import '../planner/models/planner_models.dart';
import '../revision/models/revision_models.dart';
import '../timer/models/session_models.dart';
import '../timer/timer_logic.dart';
import 'dashboard_logic.dart';

/// Share of all lectures (GS + Anthropology) that are done, 0 to 100.
int overallPercent({
  required int gsDone,
  required int gsTotal,
  required int anDone,
  required int anTotal,
}) {
  final total = gsTotal + anTotal;
  if (total <= 0) return 0;
  return ((gsDone + anDone) * 100 / total).round().clamp(0, 100).toInt();
}

/// Revision items ticked off plus PYQs practised, out of everything added.
class RevisionPyqProgress {
  const RevisionPyqProgress({
    required this.revisionDone,
    required this.revisionTotal,
    required this.pyqDone,
    required this.pyqTotal,
  });

  final int revisionDone;
  final int revisionTotal;
  final int pyqDone;
  final int pyqTotal;

  int get done => revisionDone + pyqDone;
  int get total => revisionTotal + pyqTotal;
  double get fraction => total == 0 ? 0 : done / total;
  int get percent => (fraction * 100).round();
}

RevisionPyqProgress revisionPyqProgress(
  List<RevisionCycle> cycles, {
  required int pyqPractised,
  required int pyqTotal,
}) {
  var total = 0;
  var done = 0;
  for (final c in cycles) {
    total += c.items.length;
    done += c.items.where((i) => i.done).length;
  }
  return RevisionPyqProgress(
    revisionDone: done,
    revisionTotal: total,
    pyqDone: pyqPractised,
    pyqTotal: pyqTotal,
  );
}

String? _yearFor(String prefix, Map<String, String> dates, DateTime today) {
  final upcoming = <DateTime>[];
  final past = <DateTime>[];
  for (final e in dates.entries) {
    if (!e.key.startsWith(prefix) || !isValidDateKey(e.value)) continue;
    final d = parseDateKey(e.value);
    if (d.isBefore(today)) {
      past.add(d);
    } else {
      upcoming.add(d);
    }
  }
  if (upcoming.isNotEmpty) {
    upcoming.sort();
    return '${upcoming.first.year}';
  }
  if (past.isNotEmpty) {
    past.sort();
    return '${past.last.year}';
  }
  return null;
}

/// Small label for the header, e.g. "UPSC 2027", from the exam dates the
/// student entered. Falls back to "UPSC · UPPCS" when none are set.
String examBadge(Map<String, String> examDates, DateTime today) {
  final upsc = _yearFor('upsc_', examDates, today);
  if (upsc != null) return 'UPSC $upsc';
  final uppcs = _yearFor('uppcs_', examDates, today);
  if (uppcs != null) return 'UPPCS $uppcs';
  return 'UPSC · UPPCS';
}

/// First task of today that is not done yet, in planner order.
PlannerTask? nextTarget(List<PlannerTask> tasks, String todayKey) {
  final open = tasks.where((t) => t.date == todayKey && !t.done).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return open.isEmpty ? null : open.first;
}

class WeekDayHours {
  const WeekDayHours({
    required this.label,
    required this.day,
    required this.sec,
    required this.isToday,
    required this.isFuture,
  });

  final String label;
  final DateTime day;
  final int sec;
  final bool isToday;
  final bool isFuture;
}

const List<String> _weekLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// Study time for each day of the current week, Monday to Sunday.
List<WeekDayHours> weekHours(Iterable<StudySession> sessions, DateTime today) {
  final t = dateOnly(today);
  final monday = DateTime(t.year, t.month, t.day - (t.weekday - 1));
  final todayKey = dateKey(t);
  return [
    for (var i = 0; i < 7; i++)
      () {
        final day = DateTime(monday.year, monday.month, monday.day + i);
        final key = dateKey(day);
        final future = day.isAfter(t);
        return WeekDayHours(
          label: _weekLabels[i],
          day: day,
          sec: future ? 0 : totalSecOnDate(sessions, key),
          isToday: key == todayKey,
          isFuture: future,
        );
      }(),
  ];
}
