import 'package:intl/intl.dart';

import '../../core/storage/db.dart';

/// Collections shown to the user, in display order. (`settings` holds app
/// preferences, not records, so it is left out.)
const List<String> kRecordCollections = [
  Collections.subjects,
  Collections.lectures,
  Collections.anthroChapters,
  Collections.anthroLectures,
  Collections.revisionCycles,
  Collections.tasks,
  Collections.sessions,
  Collections.answers,
  Collections.pyqs,
  Collections.tests,
  Collections.notes,
];

String collectionLabel(String c) {
  switch (c) {
    case Collections.subjects:
      return 'GS subjects';
    case Collections.lectures:
      return 'GS lectures';
    case Collections.anthroChapters:
      return 'Anthropology chapters';
    case Collections.anthroLectures:
      return 'Anthropology lectures';
    case Collections.revisionCycles:
      return 'Revision cycles';
    case Collections.tasks:
      return 'Planner tasks';
    case Collections.sessions:
      return 'Study sessions';
    case Collections.answers:
      return 'Answers';
    case Collections.pyqs:
      return 'PYQs';
    case Collections.tests:
      return 'Tests';
    case Collections.notes:
      return 'Current affairs notes';
    default:
      return c;
  }
}

/// What is inside a backup file (or what is stored on this device).
class BackupSummary {
  const BackupSummary({
    required this.counts,
    this.schemaVersion,
    this.exportedAt,
  });

  /// Collection id -> number of records. Only [kRecordCollections].
  final Map<String, int> counts;
  final int? schemaVersion;
  final DateTime? exportedAt;

  int get total => counts.values.fold(0, (a, b) => a + b);

  /// Non-empty rows as (label, count), in display order.
  List<(String, int)> get rows => [
        for (final c in kRecordCollections)
          if ((counts[c] ?? 0) > 0) (collectionLabel(c), counts[c]!),
      ];
}

/// [data] must already have passed `BackupService.validate`.
BackupSummary summarizeBackup(Map<String, dynamic> data) {
  final cols = data['collections'];
  final counts = <String, int>{};
  for (final c in kRecordCollections) {
    final records = cols is Map ? cols[c] : null;
    counts[c] = records is Map ? records.length : 0;
  }
  final version = data['schemaVersion'];
  return BackupSummary(
    counts: counts,
    schemaVersion: version is int ? version : null,
    exportedAt: DateTime.tryParse(data['exportedAt']?.toString() ?? '')
        ?.toLocal(),
  );
}

String backupFileName(DateTime now) =>
    'upsc-command-centre-backup-${DateFormat('yyyy-MM-dd-HHmm').format(now)}.json';

/// "today", "yesterday", "5 days ago".
String ageText(int days) {
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  return '$days days ago';
}
