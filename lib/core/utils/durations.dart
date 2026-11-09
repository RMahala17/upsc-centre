String _two(int n) => n.toString().padLeft(2, '0');

/// Stopwatch style, e.g. 0:05:09 or 1:30:00.
String formatClock(int totalSec) {
  final s = totalSec < 0 ? 0 : totalSec;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = s % 60;
  return '$h:${_two(m)}:${_two(sec)}';
}

/// Short summary style, e.g. "2h 15m", "45m", "<1m".
String formatHm(int totalSec) {
  final s = totalSec < 0 ? 0 : totalSec;
  if (s == 0) return '0m';
  if (s < 60) return '<1m';
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  if (h == 0) return '${m}m';
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Minutes as "1h 30m" / "45m" (used for planned time on tasks).
String formatMinutes(int minutes) => formatHm(minutes * 60);
