/// What a block of study time was spent on. Prelims and CSAT practice have
/// their own category so they do not get lumped into "Test series".
class StudyCategory {
  static const gs = 'gs';
  static const anthro = 'anthro';
  static const revision = 'revision';
  static const pyq = 'pyq';
  static const answers = 'answers';
  static const test = 'test';
  static const prelims = 'prelims';
  static const currentAffairs = 'current_affairs';
  static const other = 'other';

  static const all = [
    gs,
    anthro,
    revision,
    pyq,
    answers,
    test,
    prelims,
    currentAffairs,
    other,
  ];

  static String label(String c) {
    switch (c) {
      case gs:
        return 'GS';
      case anthro:
        return 'Anthropology';
      case revision:
        return 'Revision';
      case pyq:
        return 'PYQ';
      case answers:
        return 'Answer writing';
      case test:
        return 'Test series';
      case prelims:
        return 'Prelims / CSAT';
      case currentAffairs:
        return 'Current affairs';
      default:
        return 'Other';
    }
  }

  /// Unknown values (e.g. from a future version) fall back to "other".
  static String normalize(Object? v) {
    for (final c in all) {
      if (c == v) return c;
    }
    return other;
  }
}

/// One finished block of study time.
///
/// [date] is the local calendar day the block STARTED on ("yyyy-MM-dd").
/// A session that runs past midnight is counted entirely on its start day.
class StudySession {
  const StudySession({
    required this.id,
    required this.date,
    required this.startedAt,
    required this.durationSec,
    required this.category,
    this.label = '',
    this.taskId,
    this.note = '',
    this.manual = false,
    required this.createdAt,
  });

  final String id;
  final String date;

  /// ISO time the session started (used only for ordering).
  final String startedAt;

  /// Active study time in seconds (paused time is NOT included).
  final int durationSec;
  final String category;
  final String label;

  /// Planner task this time was spent on, if any.
  final String? taskId;
  final String note;

  /// True when typed in by hand rather than recorded by the stopwatch.
  final bool manual;
  final String createdAt;

  StudySession copyWith({
    String? date,
    String? startedAt,
    int? durationSec,
    String? category,
    String? label,
    String? note,
  }) =>
      StudySession(
        id: id,
        date: date ?? this.date,
        startedAt: startedAt ?? this.startedAt,
        durationSec: durationSec ?? this.durationSec,
        category: category ?? this.category,
        label: label ?? this.label,
        taskId: taskId,
        note: note ?? this.note,
        manual: manual,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'startedAt': startedAt,
        'durationSec': durationSec,
        'category': category,
        'label': label,
        'taskId': taskId,
        'note': note,
        'manual': manual,
        'createdAt': createdAt,
      };

  factory StudySession.fromJson(Map<String, dynamic> j) => StudySession(
        id: (j['id'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        startedAt: (j['startedAt'] ?? '').toString(),
        durationSec: (j['durationSec'] as num?)?.toInt() ?? 0,
        category: StudyCategory.normalize(j['category']),
        label: (j['label'] ?? '').toString(),
        taskId: j['taskId']?.toString(),
        note: (j['note'] ?? '').toString(),
        manual: j['manual'] == true,
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}
