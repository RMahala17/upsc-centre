enum TrackStatus { notStarted, inProgress, done }

String trackStatusLabel(TrackStatus s) {
  switch (s) {
    case TrackStatus.notStarted:
      return 'Not started';
    case TrackStatus.inProgress:
      return 'In progress';
    case TrackStatus.done:
      return 'Done';
  }
}

TrackStatus parseTrackStatus(Object? v) {
  for (final s in TrackStatus.values) {
    if (s.name == v) return s;
  }
  return TrackStatus.notStarted;
}

class GsPaper {
  static const all = ['GS1', 'GS2', 'GS3', 'GS4'];

  static String title(String paper) {
    switch (paper) {
      case 'GS1':
        return 'GS Paper 1';
      case 'GS2':
        return 'GS Paper 2';
      case 'GS3':
        return 'GS Paper 3';
      case 'GS4':
        return 'GS Paper 4';
      default:
        return paper;
    }
  }
}

class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.paper,
    required this.order,
    this.notes = TrackStatus.notStarted,
    this.pyq = TrackStatus.notStarted,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String paper;
  final int order;
  final TrackStatus notes;
  final TrackStatus pyq;
  final String createdAt;

  Subject copyWith({
    String? name,
    String? paper,
    int? order,
    TrackStatus? notes,
    TrackStatus? pyq,
  }) {
    return Subject(
      id: id,
      name: name ?? this.name,
      paper: paper ?? this.paper,
      order: order ?? this.order,
      notes: notes ?? this.notes,
      pyq: pyq ?? this.pyq,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'paper': paper,
        'order': order,
        'notes': notes.name,
        'pyq': pyq.name,
        'createdAt': createdAt,
      };

  factory Subject.fromJson(Map<String, dynamic> j) => Subject(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        paper: (j['paper'] ?? 'GS1').toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
        notes: parseTrackStatus(j['notes']),
        pyq: parseTrackStatus(j['pyq']),
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}

class Lecture {
  const Lecture({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.order,
    this.completed = false,
    this.completedAt,
    required this.createdAt,
  });

  final String id;
  final String subjectId;
  final String title;
  final int order;
  final bool completed;

  /// ISO time when ticked in this app. Null for lectures loaded as
  /// "already completed" from older counts (the real date is unknown).
  final String? completedAt;
  final String createdAt;

  Lecture copyWith({String? title}) => Lecture(
        id: id,
        subjectId: subjectId,
        title: title ?? this.title,
        order: order,
        completed: completed,
        completedAt: completedAt,
        createdAt: createdAt,
      );

  Lecture toggled(DateTime now) => Lecture(
        id: id,
        subjectId: subjectId,
        title: title,
        order: order,
        completed: !completed,
        completedAt: completed ? null : now.toIso8601String(),
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'title': title,
        'order': order,
        'completed': completed,
        'completedAt': completedAt,
        'createdAt': createdAt,
      };

  factory Lecture.fromJson(Map<String, dynamic> j) => Lecture(
        id: (j['id'] ?? '').toString(),
        subjectId: (j['subjectId'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
        completed: j['completed'] == true,
        completedAt: j['completedAt']?.toString(),
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}

class SubjectStats {
  const SubjectStats(this.total, this.completed);

  final int total;
  final int completed;

  int get remaining => total - completed;
  double get fraction => total == 0 ? 0 : completed / total;
  int get percent => (fraction * 100).round();
}
