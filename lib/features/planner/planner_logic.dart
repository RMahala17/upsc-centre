import '../syllabus/models/syllabus_models.dart';
import 'models/planner_models.dart';

/// Tasks planned for one day ("yyyy-MM-dd"), in the order they were added.
List<PlannerTask> tasksOnDate(Iterable<PlannerTask> all, String key) {
  final list = all.where((t) => t.date == key).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return list;
}

/// Unfinished tasks planned for any day BEFORE [key], oldest first.
/// ("yyyy-MM-dd" strings sort in calendar order.)
List<PlannerTask> unfinishedBefore(Iterable<PlannerTask> all, String key) {
  final list = all.where((t) => !t.done && t.date.compareTo(key) < 0).toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
  return list;
}

class DayPlanSummary {
  const DayPlanSummary({
    required this.total,
    required this.done,
    required this.plannedMin,
  });

  final int total;
  final int done;

  /// Sum of planned minutes over ALL of the day's tasks (0 if none set).
  final int plannedMin;

  double get fraction => total == 0 ? 0 : done / total;
}

DayPlanSummary summarizeDay(List<PlannerTask> tasks) {
  var done = 0;
  var planned = 0;
  for (final t in tasks) {
    if (t.done) done++;
    planned += t.plannedMin;
  }
  return DayPlanSummary(total: tasks.length, done: done, plannedMin: planned);
}

/// How many lectures were ticked off on the given local calendar day.
/// Lectures with no recorded completion time are never counted.
int lecturesCompletedOn(Iterable<Lecture> lectures, DateTime day) {
  var n = 0;
  for (final l in lectures) {
    if (!l.completed || l.completedAt == null) continue;
    final d = DateTime.tryParse(l.completedAt!)?.toLocal();
    if (d == null) continue;
    if (d.year == day.year && d.month == day.month && d.day == day.day) n++;
  }
  return n;
}

/// Parses planned minutes typed by the user. Blank means "not set" (0).
/// Returns null when the text is not a valid whole number of minutes.
int? parsePlannedMinutes(String raw, {int max = 24 * 60}) {
  final t = raw.trim();
  if (t.isEmpty) return 0;
  final n = int.tryParse(t);
  if (n == null || n < 0 || n > max) return null;
  return n;
}
