import 'dart:math' as math;

import '../../core/utils/dates.dart';
import 'models/session_models.dart';

/// A timer left running longer than this triggers a "did you forget to stop
/// it?" warning.
const int kLongTimerSec = 8 * 3600;

/// Longest single session accepted when saving or typing one in.
const int kMaxSessionMinutes = 24 * 60;

/// The stopwatch, stored as TIMESTAMPS, never as a ticking counter.
///
/// elapsed = [accumulatedMs] (all earlier running segments)
///         + (now - [segmentStartMs]) while running.
///
/// Because nothing is counted in memory, killing the app, locking the phone
/// or reloading the browser tab loses no time.
class ActiveTimer {
  const ActiveTimer({
    required this.sessionStartMs,
    this.accumulatedMs = 0,
    this.segmentStartMs,
    this.category = StudyCategory.gs,
    this.label = '',
    this.taskId,
  });

  factory ActiveTimer.start(
    int nowMs, {
    String category = StudyCategory.gs,
    String label = '',
    String? taskId,
  }) =>
      ActiveTimer(
        sessionStartMs: nowMs,
        segmentStartMs: nowMs,
        category: category,
        label: label,
        taskId: taskId,
      );

  /// When the very first segment began (decides the session's date).
  final int sessionStartMs;

  /// Running time banked from earlier segments (before each pause).
  final int accumulatedMs;

  /// Start of the current running segment; null while paused.
  final int? segmentStartMs;
  final String category;
  final String label;
  final String? taskId;

  bool get running => segmentStartMs != null;

  /// Never negative, even if the device clock is moved backwards.
  int elapsedMs(int nowMs) {
    final seg = segmentStartMs == null ? 0 : math.max(0, nowMs - segmentStartMs!);
    return accumulatedMs + seg;
  }

  int elapsedSec(int nowMs) => elapsedMs(nowMs) ~/ 1000;

  ActiveTimer paused(int nowMs) {
    if (!running) return this;
    return ActiveTimer(
      sessionStartMs: sessionStartMs,
      accumulatedMs: elapsedMs(nowMs),
      segmentStartMs: null,
      category: category,
      label: label,
      taskId: taskId,
    );
  }

  ActiveTimer resumed(int nowMs) {
    if (running) return this;
    return ActiveTimer(
      sessionStartMs: sessionStartMs,
      accumulatedMs: accumulatedMs,
      segmentStartMs: nowMs,
      category: category,
      label: label,
      taskId: taskId,
    );
  }

  ActiveTimer withMeta({String? category, String? label}) => ActiveTimer(
        sessionStartMs: sessionStartMs,
        accumulatedMs: accumulatedMs,
        segmentStartMs: segmentStartMs,
        category: category ?? this.category,
        label: label ?? this.label,
        taskId: taskId,
      );

  Map<String, dynamic> toJson() => {
        'sessionStartMs': sessionStartMs,
        'accumulatedMs': accumulatedMs,
        'segmentStartMs': segmentStartMs,
        'category': category,
        'label': label,
        'taskId': taskId,
      };

  /// Returns null for missing or malformed data instead of throwing.
  static ActiveTimer? tryParse(Map<String, dynamic>? j) {
    if (j == null) return null;
    final start = j['sessionStartMs'];
    if (start is! num) return null;
    final seg = j['segmentStartMs'];
    return ActiveTimer(
      sessionStartMs: start.toInt(),
      accumulatedMs: (j['accumulatedMs'] as num?)?.toInt() ?? 0,
      segmentStartMs: seg is num ? seg.toInt() : null,
      // Missing -> GS (the default); present but unknown -> other.
      category: j['category'] == null
          ? StudyCategory.gs
          : StudyCategory.normalize(j['category']),
      label: (j['label'] ?? '').toString(),
      taskId: j['taskId']?.toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// Session aggregation
// ---------------------------------------------------------------------------

class DayTotal {
  const DayTotal(this.day, this.sec);
  final DateTime day;
  final int sec;
}

int totalSecOnDate(Iterable<StudySession> sessions, String key) {
  var total = 0;
  for (final s in sessions) {
    if (s.date == key) total += s.durationSec;
  }
  return total;
}

/// Sessions of one day, most recent first.
List<StudySession> sessionsOnDate(Iterable<StudySession> sessions, String key) {
  final list = sessions.where((s) => s.date == key).toList()
    ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  return list;
}

/// Daily totals for the [n] days ending on [today], oldest first.
List<DayTotal> lastNDays(Iterable<StudySession> sessions, DateTime today, int n) {
  final byDate = <String, int>{};
  for (final s in sessions) {
    byDate[s.date] = (byDate[s.date] ?? 0) + s.durationSec;
  }
  final t = dateOnly(today);
  final out = <DayTotal>[];
  for (var i = n - 1; i >= 0; i--) {
    final d = addDays(t, -i);
    out.add(DayTotal(d, byDate[dateKey(d)] ?? 0));
  }
  return out;
}

Map<String, int> secByCategory(Iterable<StudySession> sessions) {
  final out = <String, int>{};
  for (final s in sessions) {
    out[s.category] = (out[s.category] ?? 0) + s.durationSec;
  }
  return out;
}

/// Total time recorded against one planner task.
int secOnTask(Iterable<StudySession> sessions, String taskId) {
  var total = 0;
  for (final s in sessions) {
    if (s.taskId == taskId) total += s.durationSec;
  }
  return total;
}
