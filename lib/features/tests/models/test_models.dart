/// What kind of test it was. Prelims GS and CSAT have their own categories.
class TestCategory {
  static const prelimsGs = 'prelims_gs';
  static const csat = 'csat';
  static const sectional = 'sectional';
  static const mainsGs = 'mains_gs';
  static const essay = 'essay';
  static const optional = 'optional';
  static const other = 'other';

  static const all = [
    prelimsGs,
    csat,
    sectional,
    mainsGs,
    essay,
    optional,
    other,
  ];

  /// Objective tests: scored from correct / wrong counts with negative
  /// marking. The rest are marked by hand and the score is typed in.
  static bool isMcq(String c) => c == prelimsGs || c == csat || c == sectional;

  static String label(String c) {
    switch (c) {
      case prelimsGs:
        return 'Prelims GS';
      case csat:
        return 'CSAT';
      case sectional:
        return 'Sectional (MCQ)';
      case mainsGs:
        return 'Mains GS';
      case essay:
        return 'Essay';
      case optional:
        return 'Optional';
      default:
        return 'Other';
    }
  }

  static int defaultTotalQuestions(String c) {
    switch (c) {
      case prelimsGs:
        return 100;
      case csat:
        return 80;
      case sectional:
        return 25;
      default:
        return 0;
    }
  }

  static double defaultMaxMarks(String c) {
    switch (c) {
      case prelimsGs:
        return 200;
      case csat:
        return 200;
      case sectional:
        return 50;
      case mainsGs:
      case essay:
      case optional:
        return 250;
      default:
        return 100;
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

/// What the test dialog hands back. [score] is already worked out for
/// objective tests; null means "not taken / not marked yet".
class TestInput {
  const TestInput({
    required this.name,
    required this.series,
    required this.category,
    required this.date,
    required this.totalQuestions,
    required this.maxMarks,
    required this.correct,
    required this.wrong,
    required this.score,
    required this.timeMin,
    required this.analysisDone,
    required this.notes,
  });

  final String name;
  final String series;
  final String category;
  final DateTime date;
  final int totalQuestions;
  final double maxMarks;
  final int correct;
  final int wrong;
  final double? score;
  final int timeMin;
  final bool analysisDone;
  final String notes;
}

const Object _keep = Object();

class TestRecord {
  const TestRecord({
    required this.id,
    required this.name,
    this.series = '',
    required this.category,
    required this.date,
    this.totalQuestions = 0,
    required this.maxMarks,
    this.correct = 0,
    this.wrong = 0,
    this.score,
    this.timeMin = 0,
    this.analysisDone = false,
    this.notes = '',
    required this.createdAt,
  });

  final String id;
  final String name;

  /// Test series / provider, free text.
  final String series;
  final String category;

  /// "yyyy-MM-dd": the day the test is (or was) taken.
  final String date;

  /// Objective tests only; 0 otherwise.
  final int totalQuestions;
  final double maxMarks;
  final int correct;
  final int wrong;

  /// Null until the result is in.
  final double? score;
  final int timeMin;

  /// Whether the post-test analysis has been done.
  final bool analysisDone;
  final String notes;
  final String createdAt;

  TestRecord copyWith({
    String? name,
    String? series,
    String? category,
    String? date,
    int? totalQuestions,
    double? maxMarks,
    int? correct,
    int? wrong,
    Object? score = _keep,
    int? timeMin,
    bool? analysisDone,
    String? notes,
  }) =>
      TestRecord(
        id: id,
        name: name ?? this.name,
        series: series ?? this.series,
        category: category ?? this.category,
        date: date ?? this.date,
        totalQuestions: totalQuestions ?? this.totalQuestions,
        maxMarks: maxMarks ?? this.maxMarks,
        correct: correct ?? this.correct,
        wrong: wrong ?? this.wrong,
        score: identical(score, _keep) ? this.score : score as double?,
        timeMin: timeMin ?? this.timeMin,
        analysisDone: analysisDone ?? this.analysisDone,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'series': series,
        'category': category,
        'date': date,
        'totalQuestions': totalQuestions,
        'maxMarks': maxMarks,
        'correct': correct,
        'wrong': wrong,
        'score': score,
        'timeMin': timeMin,
        'analysisDone': analysisDone,
        'notes': notes,
        'createdAt': createdAt,
      };

  factory TestRecord.fromJson(Map<String, dynamic> j) {
    final category = TestCategory.normalize(j['category']);
    return TestRecord(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      series: (j['series'] ?? '').toString(),
      category: category,
      date: (j['date'] ?? '').toString(),
      totalQuestions: (j['totalQuestions'] as num?)?.toInt() ?? 0,
      maxMarks: (j['maxMarks'] as num?)?.toDouble() ??
          TestCategory.defaultMaxMarks(category),
      correct: (j['correct'] as num?)?.toInt() ?? 0,
      wrong: (j['wrong'] as num?)?.toInt() ?? 0,
      score: (j['score'] as num?)?.toDouble(),
      timeMin: (j['timeMin'] as num?)?.toInt() ?? 0,
      analysisDone: j['analysisDone'] == true,
      notes: (j['notes'] ?? '').toString(),
      createdAt: (j['createdAt'] ?? '').toString(),
    );
  }
}
