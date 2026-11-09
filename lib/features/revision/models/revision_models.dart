import '../../syllabus/models/syllabus_models.dart';

enum RevisionTargetType { gs, anthro }

RevisionTargetType parseTargetType(Object? v) {
  for (final t in RevisionTargetType.values) {
    if (t.name == v) return t;
  }
  return RevisionTargetType.gs;
}

enum ItemKind { topic, pyq, selftest }

ItemKind parseItemKind(Object? v) {
  for (final k in ItemKind.values) {
    if (k.name == v) return k;
  }
  return ItemKind.topic;
}

enum CycleStatus { notStarted, inProgress, completed }

String cycleStatusLabel(CycleStatus s) {
  switch (s) {
    case CycleStatus.notStarted:
      return 'Not started';
    case CycleStatus.inProgress:
      return 'In progress';
    case CycleStatus.completed:
      return 'Completed';
  }
}

class RevisionItem {
  const RevisionItem({
    required this.id,
    required this.title,
    required this.day,
    required this.order,
    this.kind = ItemKind.topic,
    this.done = false,
    this.doneAt,
  });

  final String id;
  final String title;

  /// Plan day, 1-based (Day 1 = cycle start date).
  final int day;
  final int order;
  final ItemKind kind;
  final bool done;
  final String? doneAt;

  RevisionItem copyWith({String? title, int? day, int? order}) => RevisionItem(
        id: id,
        title: title ?? this.title,
        day: day ?? this.day,
        order: order ?? this.order,
        kind: kind,
        done: done,
        doneAt: doneAt,
      );

  RevisionItem toggled(DateTime now) => RevisionItem(
        id: id,
        title: title,
        day: day,
        order: order,
        kind: kind,
        done: !done,
        doneAt: done ? null : now.toIso8601String(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'day': day,
        'order': order,
        'kind': kind.name,
        'done': done,
        'doneAt': doneAt,
      };

  factory RevisionItem.fromJson(Map<String, dynamic> j) => RevisionItem(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        day: (j['day'] as num?)?.toInt() ?? 1,
        order: (j['order'] as num?)?.toInt() ?? 0,
        kind: parseItemKind(j['kind']),
        done: j['done'] == true,
        doneAt: j['doneAt']?.toString(),
      );
}

/// One revision pass over a GS subject or an Anthropology paper.
/// Completely independent of lecture completion.
class RevisionCycle {
  const RevisionCycle({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.number,
    required this.startDate,
    required this.lengthDays,
    this.completedDate,
    this.notes = '',
    this.pyqStatus = TrackStatus.notStarted,
    this.items = const [],
    required this.createdAt,
  });

  final String id;
  final RevisionTargetType targetType;
  final String targetId;

  /// Name when the cycle was created (used if the subject is later deleted).
  final String targetName;
  final int number;

  /// "yyyy-MM-dd"
  final String startDate;
  final int lengthDays;

  /// "yyyy-MM-dd", set only when the cycle is marked complete.
  final String? completedDate;
  final String notes;
  final TrackStatus pyqStatus;
  final List<RevisionItem> items;
  final String createdAt;

  RevisionCycle copyWith({
    String? startDate,
    int? lengthDays,
    String? completedDate,
    bool clearCompleted = false,
    String? notes,
    TrackStatus? pyqStatus,
    List<RevisionItem>? items,
  }) {
    return RevisionCycle(
      id: id,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      number: number,
      startDate: startDate ?? this.startDate,
      lengthDays: lengthDays ?? this.lengthDays,
      completedDate: clearCompleted ? null : (completedDate ?? this.completedDate),
      notes: notes ?? this.notes,
      pyqStatus: pyqStatus ?? this.pyqStatus,
      items: items ?? this.items,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'targetType': targetType.name,
        'targetId': targetId,
        'targetName': targetName,
        'number': number,
        'startDate': startDate,
        'lengthDays': lengthDays,
        'completedDate': completedDate,
        'notes': notes,
        'pyqStatus': pyqStatus.name,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt,
      };

  factory RevisionCycle.fromJson(Map<String, dynamic> j) {
    final rawItems = j['items'];
    final items = <RevisionItem>[];
    if (rawItems is List) {
      for (final m in rawItems) {
        if (m is Map) {
          items.add(RevisionItem.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }
    return RevisionCycle(
      id: (j['id'] ?? '').toString(),
      targetType: parseTargetType(j['targetType']),
      targetId: (j['targetId'] ?? '').toString(),
      targetName: (j['targetName'] ?? '').toString(),
      number: (j['number'] as num?)?.toInt() ?? 1,
      startDate: (j['startDate'] ?? '').toString(),
      lengthDays: (j['lengthDays'] as num?)?.toInt() ?? 7,
      completedDate: j['completedDate']?.toString(),
      notes: (j['notes'] ?? '').toString(),
      pyqStatus: parseTrackStatus(j['pyqStatus']),
      items: items,
      createdAt: (j['createdAt'] ?? '').toString(),
    );
  }
}
