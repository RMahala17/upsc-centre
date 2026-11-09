import '../../timer/models/session_models.dart';

/// One item on a day's plan.
class PlannerTask {
  const PlannerTask({
    required this.id,
    required this.date,
    required this.title,
    required this.category,
    this.plannedMin = 0,
    this.done = false,
    this.doneAt,
    required this.order,
    this.carryCount = 0,
    required this.createdAt,
  });

  final String id;

  /// "yyyy-MM-dd"
  final String date;
  final String title;
  final String category;

  /// Planned study minutes; 0 means "not set".
  final int plannedMin;
  final bool done;
  final String? doneAt;
  final int order;

  /// How many times this task was carried over to a later day.
  final int carryCount;
  final String createdAt;

  PlannerTask copyWith({
    String? date,
    String? title,
    String? category,
    int? plannedMin,
    int? order,
    int? carryCount,
  }) =>
      PlannerTask(
        id: id,
        date: date ?? this.date,
        title: title ?? this.title,
        category: category ?? this.category,
        plannedMin: plannedMin ?? this.plannedMin,
        done: done,
        doneAt: doneAt,
        order: order ?? this.order,
        carryCount: carryCount ?? this.carryCount,
        createdAt: createdAt,
      );

  PlannerTask toggled(DateTime now) => PlannerTask(
        id: id,
        date: date,
        title: title,
        category: category,
        plannedMin: plannedMin,
        done: !done,
        doneAt: done ? null : now.toIso8601String(),
        order: order,
        carryCount: carryCount,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'category': category,
        'plannedMin': plannedMin,
        'done': done,
        'doneAt': doneAt,
        'order': order,
        'carryCount': carryCount,
        'createdAt': createdAt,
      };

  factory PlannerTask.fromJson(Map<String, dynamic> j) => PlannerTask(
        id: (j['id'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        category: StudyCategory.normalize(j['category']),
        plannedMin: (j['plannedMin'] as num?)?.toInt() ?? 0,
        done: j['done'] == true,
        doneAt: j['doneAt']?.toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
        carryCount: (j['carryCount'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}
