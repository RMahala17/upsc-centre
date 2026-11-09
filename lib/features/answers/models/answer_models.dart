import '../../../core/utils/exam_papers.dart';

class AnswerStatus {
  static const written = 'written';
  static const evaluated = 'evaluated';
  static const needsRewrite = 'needs_rewrite';
  static const rewritten = 'rewritten';

  static const all = [written, evaluated, needsRewrite, rewritten];

  static String label(String s) {
    switch (s) {
      case evaluated:
        return 'Evaluated';
      case needsRewrite:
        return 'Needs rewrite';
      case rewritten:
        return 'Rewritten';
      default:
        return 'Not evaluated';
    }
  }

  static String normalize(Object? v) {
    for (final s in all) {
      if (s == v) return s;
    }
    return written;
  }
}

/// What the answer dialog hands back. The controller turns it into an
/// [AnswerEntry].
class AnswerInput {
  const AnswerInput({
    required this.date,
    required this.paper,
    required this.question,
    required this.topic,
    required this.marks,
    required this.wordLimit,
    required this.minutes,
    required this.score,
    required this.feedback,
    required this.needsRewrite,
  });

  final DateTime date;
  final String paper;
  final String question;
  final String topic;
  final int marks;

  /// 0 means "no limit".
  final int wordLimit;

  /// Minutes spent writing; 0 means "not recorded".
  final int minutes;

  /// Null means "not evaluated yet".
  final double? score;
  final String feedback;
  final bool needsRewrite;
}

const Object _keep = Object();

/// One practice answer.
class AnswerEntry {
  const AnswerEntry({
    required this.id,
    required this.date,
    required this.paper,
    required this.question,
    this.topic = '',
    this.marks = 10,
    this.wordLimit = 150,
    this.minutes = 0,
    this.score,
    this.feedback = '',
    this.status = AnswerStatus.written,
    required this.createdAt,
  });

  final String id;

  /// "yyyy-MM-dd" the answer was written on.
  final String date;
  final String paper;
  final String question;
  final String topic;
  final int marks;
  final int wordLimit;
  final int minutes;
  final double? score;
  final String feedback;
  final String status;
  final String createdAt;

  AnswerEntry copyWith({
    String? date,
    String? paper,
    String? question,
    String? topic,
    int? marks,
    int? wordLimit,
    int? minutes,
    Object? score = _keep,
    String? feedback,
    String? status,
  }) =>
      AnswerEntry(
        id: id,
        date: date ?? this.date,
        paper: paper ?? this.paper,
        question: question ?? this.question,
        topic: topic ?? this.topic,
        marks: marks ?? this.marks,
        wordLimit: wordLimit ?? this.wordLimit,
        minutes: minutes ?? this.minutes,
        score: identical(score, _keep) ? this.score : score as double?,
        feedback: feedback ?? this.feedback,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'paper': paper,
        'question': question,
        'topic': topic,
        'marks': marks,
        'wordLimit': wordLimit,
        'minutes': minutes,
        'score': score,
        'feedback': feedback,
        'status': status,
        'createdAt': createdAt,
      };

  factory AnswerEntry.fromJson(Map<String, dynamic> j) => AnswerEntry(
        id: (j['id'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        paper: ExamPaper.normalize(j['paper'], fallback: ExamPaper.gs1),
        question: (j['question'] ?? '').toString(),
        topic: (j['topic'] ?? '').toString(),
        marks: (j['marks'] as num?)?.toInt() ?? 10,
        wordLimit: (j['wordLimit'] as num?)?.toInt() ?? 0,
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        score: (j['score'] as num?)?.toDouble(),
        feedback: (j['feedback'] ?? '').toString(),
        status: AnswerStatus.normalize(j['status']),
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}
