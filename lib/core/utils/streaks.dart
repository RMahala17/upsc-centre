import 'dates.dart';

final RegExp _dayKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Consecutive days in [days] ("yyyy-MM-dd" strings), counting back from
/// [today]. A day with nothing yet today does not break the streak: counting
/// then starts from yesterday.
int currentStreak(Set<String> days, DateTime today) {
  var cursor = dateOnly(today);
  if (!days.contains(dateKey(cursor))) {
    cursor = addDays(cursor, -1);
  }
  var streak = 0;
  while (days.contains(dateKey(cursor))) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

/// Longest run of consecutive days anywhere in [days]. Malformed entries are
/// ignored.
int longestStreak(Set<String> days) {
  final sorted = days.where(_dayKey.hasMatch).map(parseDateKey).toList()
    ..sort();
  if (sorted.isEmpty) return 0;
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final gap = daysBetween(sorted[i - 1], sorted[i]);
    if (gap == 1) {
      run++;
    } else if (gap > 1) {
      run = 1;
    }
    if (run > best) best = run;
  }
  return best;
}
