import '../../core/utils/dates.dart';
import '../answers/models/answer_models.dart';
import '../currentaffairs/ca_logic.dart';
import '../currentaffairs/models/ca_models.dart';
import '../planner/models/planner_models.dart';
import '../planner/planner_logic.dart';
import '../revision/models/revision_models.dart';
import '../revision/revision_logic.dart' as rev;
import '../tests/models/test_models.dart';
import '../tests/test_logic.dart';

String greetingFor(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

final RegExp _dayKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// True for a real calendar day written as "yyyy-MM-dd" (2026-02-31 is not).
bool isValidDateKey(String s) {
  if (!_dayKey.hasMatch(s)) return false;
  final d = DateTime.tryParse(s);
  return d != null && dateKey(d) == s;
}

// ---------------------------------------------------------------------------
// Exam countdown
// ---------------------------------------------------------------------------

/// Whole days from [today] to the exam day. Negative once it has passed; null
/// when no valid date is set.
int? daysUntil(String? key, DateTime today) {
  if (key == null || !isValidDateKey(key)) return null;
  return daysBetween(dateOnly(today), parseDateKey(key));
}

String countdownText(int days) {
  if (days > 1) return '$days days';
  if (days == 1) return 'Tomorrow';
  if (days == 0) return 'Today';
  return 'Passed';
}

// ---------------------------------------------------------------------------
// Backup reminder
// ---------------------------------------------------------------------------

/// A backup older than this many days triggers the reminder.
const int kBackupStaleDays = 7;

/// Whole days since the last backup; null when there has never been one.
int? backupAgeDays(DateTime? last, DateTime today) {
  if (last == null) return null;
  final d = daysBetween(dateOnly(last), dateOnly(today));
  return d < 0 ? 0 : d;
}

/// "Never backed up" only matters once there is something to lose.
bool backupReminderDue(int? ageDays, {required bool hasData}) =>
    ageDays == null ? hasData : ageDays >= kBackupStaleDays;

String backupReminderText(int? ageDays) {
  if (ageDays == null) {
    return 'You have not backed up yet. If this browser\'s site data is '
        'cleared, everything here is lost.';
  }
  return 'Your last backup was ${_plural(ageDays, 'day')} ago. Export a fresh '
      'one so nothing is lost.';
}

// ---------------------------------------------------------------------------
// Revision today
// ---------------------------------------------------------------------------

class RevisionToday {
  const RevisionToday({
    required this.total,
    required this.done,
    required this.behind,
  });

  /// Items planned for today across active cycles.
  final int total;
  final int done;

  /// Unticked items planned for earlier days.
  final int behind;
}

RevisionToday revisionToday(List<RevisionCycle> cycles, DateTime today) {
  var total = 0, done = 0, behind = 0;
  for (final c in cycles) {
    if (!rev.isActive(c)) continue;
    for (final i in rev.todaysItems(c, today)) {
      total++;
      if (i.done) done++;
    }
    behind += rev.behindCount(c, today);
  }
  return RevisionToday(total: total, done: done, behind: behind);
}

// ---------------------------------------------------------------------------
// Needs attention
// ---------------------------------------------------------------------------

enum AttentionKind {
  revisionOverdue,
  tasksCarried,
  testResult,
  caDue,
  testAnalysis,
  answerRewrite,
  answerAwaiting,
}

class AttentionItem {
  const AttentionItem(this.kind, this.count, this.text, this.route);

  final AttentionKind kind;
  final int count;
  final String text;

  /// Where tapping the item goes.
  final String route;
}

/// Things that have slipped, most urgent first. Empty when all is well.
List<AttentionItem> buildAttention({
  required DateTime today,
  required List<RevisionCycle> cycles,
  required List<PlannerTask> tasks,
  required List<TestRecord> tests,
  required List<AnswerEntry> answers,
  required List<CaNote> notes,
}) {
  final out = <AttentionItem>[];
  final todayKey = dateKey(dateOnly(today));

  final overdue = cycles.where((c) => rev.isOverdue(c, today)).length;
  if (overdue > 0) {
    out.add(AttentionItem(
      AttentionKind.revisionOverdue,
      overdue,
      '${_plural(overdue, 'revision cycle')} overdue',
      '/revision',
    ));
  }

  final carried = unfinishedBefore(tasks, todayKey).length;
  if (carried > 0) {
    out.add(AttentionItem(
      AttentionKind.tasksCarried,
      carried,
      '${_plural(carried, 'unfinished task')} from earlier days',
      '/planner',
    ));
  }

  final noResult =
      tests.where((t) => phaseOf(t, todayKey) == TestPhase.pending).length;
  if (noResult > 0) {
    out.add(AttentionItem(
      AttentionKind.testResult,
      noResult,
      '${_plural(noResult, 'test')} past the date with no result entered',
      '/tests',
    ));
  }

  final caDue = notes.where((n) => isDueForRevision(n, today)).length;
  if (caDue > 0) {
    out.add(AttentionItem(
      AttentionKind.caDue,
      caDue,
      '${_plural(caDue, 'current affairs note')} due for revision',
      '/notes',
    ));
  }

  final analysis =
      tests.where((t) => t.score != null && !t.analysisDone).length;
  if (analysis > 0) {
    out.add(AttentionItem(
      AttentionKind.testAnalysis,
      analysis,
      '$analysis test${analysis == 1 ? '' : 's'} awaiting analysis',
      '/tests',
    ));
  }

  final rewrite =
      answers.where((a) => a.status == AnswerStatus.needsRewrite).length;
  if (rewrite > 0) {
    out.add(AttentionItem(
      AttentionKind.answerRewrite,
      rewrite,
      '${_plural(rewrite, 'answer')} marked for rewrite',
      '/answers',
    ));
  }

  final awaiting =
      answers.where((a) => a.status == AnswerStatus.written).length;
  if (awaiting > 0) {
    out.add(AttentionItem(
      AttentionKind.answerAwaiting,
      awaiting,
      '${_plural(awaiting, 'answer')} waiting to be evaluated',
      '/answers',
    ));
  }

  return out;
}
