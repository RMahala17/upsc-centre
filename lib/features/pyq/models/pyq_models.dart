import '../../../core/utils/exam_papers.dart';

class PyqExam {
  static const prelims = 'prelims';
  static const mains = 'mains';
  static const all = [prelims, mains];

  static String label(String e) => e == prelims ? 'Prelims' : 'Mains';

  static String normalize(Object? v) => v == prelims ? prelims : mains;
}

class PyqStatus {
  static const todo = 'todo';
  static const attempted = 'attempted';
  static const mastered = 'mastered';
  static const all = [todo, attempted, mastered];

  static String label(String s) {
    switch (s) {
      case attempted:
        return 'Attempted';
      case mastered:
        return 'Mastered';
      default:
        return 'To do';
    }
  }

  static String normalize(Object? v) {
    for (final s in all) {
      if (s == v) return s;
    }
    return todo;
  }
}

/// Outcome of a Prelims attempt. Mains questions have no right / wrong.
class PyqResult {
  static const correct = 'correct';
  static const wrong = 'wrong';

  static String? normalize(Object? v) =>
      (v == correct || v == wrong) ? v as String : null;
}

/// What the PYQ dialog hands back.
class PyqInput {
  const PyqInput({
    required this.exam,
    required this.paper,
    required this.year,
    required this.topic,
    required this.marks,
    required this.questions,
    required this.note,
  });

  final String exam;
  final String paper;
  final int year;
  final String topic;

  /// Mains marks; 0 for Prelims or "not set".
  final int marks;

  /// One entry when editing; one per line when adding.
  final List<String> questions;
  final String note;
}

const Object _keep = Object();

class Pyq {
  const Pyq({
    required this.id,
    required this.exam,
    required this.year,
    required this.paper,
    required this.question,
    this.topic = '',
    this.marks = 0,
    this.status = PyqStatus.todo,
    this.lastResult,
    this.attempts = 0,
    this.lastAttemptAt,
    this.starred = false,
    this.note = '',
    required this.order,
    required this.createdAt,
  });

  final String id;
  final String exam;
  final int year;
  final String paper;
  final String question;
  final String topic;
  final int marks;
  final String status;

  /// "correct" / "wrong" for the latest Prelims attempt, else null.
  final String? lastResult;
  final int attempts;
  final String? lastAttemptAt;

  /// Flagged to come back to.
  final bool starred;
  final String note;

  /// Position inside its exam + year, so pasted lists keep their order.
  final int order;
  final String createdAt;

  Pyq copyWith({
    String? exam,
    int? year,
    String? paper,
    String? question,
    String? topic,
    int? marks,
    String? status,
    Object? lastResult = _keep,
    int? attempts,
    Object? lastAttemptAt = _keep,
    bool? starred,
    String? note,
    int? order,
  }) =>
      Pyq(
        id: id,
        exam: exam ?? this.exam,
        year: year ?? this.year,
        paper: paper ?? this.paper,
        question: question ?? this.question,
        topic: topic ?? this.topic,
        marks: marks ?? this.marks,
        status: status ?? this.status,
        lastResult:
            identical(lastResult, _keep) ? this.lastResult : lastResult as String?,
        attempts: attempts ?? this.attempts,
        lastAttemptAt: identical(lastAttemptAt, _keep)
            ? this.lastAttemptAt
            : lastAttemptAt as String?,
        starred: starred ?? this.starred,
        note: note ?? this.note,
        order: order ?? this.order,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'exam': exam,
        'year': year,
        'paper': paper,
        'question': question,
        'topic': topic,
        'marks': marks,
        'status': status,
        'lastResult': lastResult,
        'attempts': attempts,
        'lastAttemptAt': lastAttemptAt,
        'starred': starred,
        'note': note,
        'order': order,
        'createdAt': createdAt,
      };

  factory Pyq.fromJson(Map<String, dynamic> j) {
    final exam = PyqExam.normalize(j['exam']);
    return Pyq(
      id: (j['id'] ?? '').toString(),
      exam: exam,
      year: (j['year'] as num?)?.toInt() ?? 0,
      paper: ExamPaper.normalize(
        j['paper'],
        fallback: exam == PyqExam.prelims ? ExamPaper.prelimsGs : ExamPaper.gs1,
      ),
      question: (j['question'] ?? '').toString(),
      topic: (j['topic'] ?? '').toString(),
      marks: (j['marks'] as num?)?.toInt() ?? 0,
      status: PyqStatus.normalize(j['status']),
      lastResult: PyqResult.normalize(j['lastResult']),
      attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      lastAttemptAt: j['lastAttemptAt']?.toString(),
      starred: j['starred'] == true,
      note: (j['note'] ?? '').toString(),
      order: (j['order'] as num?)?.toInt() ?? 0,
      createdAt: (j['createdAt'] ?? '').toString(),
    );
  }
}
