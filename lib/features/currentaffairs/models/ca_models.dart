/// Where a current-affairs item happened. "State" is Uttar Pradesh for UPPCS;
/// change [CaScope.stateName] to retarget another state PCS.
class CaScope {
  static const national = 'national';
  static const international = 'international';
  static const state = 'state';
  static const all = [national, international, state];

  static const stateName = 'Uttar Pradesh';

  static String label(String s) {
    switch (s) {
      case international:
        return 'International';
      case state:
        return stateName;
      default:
        return 'National';
    }
  }

  static String normalize(Object? v) {
    for (final s in all) {
      if (s == v) return s;
    }
    return national;
  }
}

class CaTopic {
  static const polity = 'polity';
  static const economy = 'economy';
  static const ir = 'ir';
  static const environment = 'environment';
  static const scitech = 'scitech';
  static const society = 'society';
  static const history = 'history';
  static const geography = 'geography';
  static const security = 'security';
  static const schemes = 'schemes';
  static const ethics = 'ethics';
  static const other = 'other';

  static const all = [
    polity,
    economy,
    ir,
    environment,
    scitech,
    society,
    history,
    geography,
    security,
    schemes,
    ethics,
    other,
  ];

  static String label(String t) {
    switch (t) {
      case polity:
        return 'Polity & Governance';
      case economy:
        return 'Economy';
      case ir:
        return 'International Relations';
      case environment:
        return 'Environment & Ecology';
      case scitech:
        return 'Science & Tech';
      case society:
        return 'Society & Social Justice';
      case history:
        return 'History, Art & Culture';
      case geography:
        return 'Geography';
      case security:
        return 'Internal Security';
      case schemes:
        return 'Schemes, Reports & Indices';
      case ethics:
        return 'Ethics';
      default:
        return 'Other';
    }
  }

  /// Unknown values (e.g. from a future version) fall back to "other".
  static String normalize(Object? v) {
    for (final t in all) {
      if (t == v) return t;
    }
    return other;
  }
}

/// Which exam an item is useful for.
class CaExam {
  static const upsc = 'upsc';
  static const uppcs = 'uppcs';
  static const all = [upsc, uppcs];

  static String label(String e) => e == uppcs ? 'UPPCS' : 'UPSC';

  /// Sensible starting choice: state news matters mainly for the state PCS,
  /// everything else for both.
  static List<String> defaultsFor(String scope) =>
      scope == CaScope.state ? [uppcs] : [upsc, uppcs];

  /// Keeps known values only, in a fixed order. Empty or malformed input
  /// means "both", so an item never ends up tagged for nothing.
  static List<String> normalizeList(Object? v) {
    final found = <String>{};
    if (v is List) {
      for (final e in v) {
        if (e == upsc || e == uppcs) found.add(e as String);
      }
    }
    if (found.isEmpty) return List<String>.of(all);
    return [for (final e in all) if (found.contains(e)) e];
  }
}

/// What the note dialog hands back.
class CaInput {
  const CaInput({
    required this.date,
    required this.title,
    required this.summary,
    required this.source,
    required this.scope,
    required this.topic,
    required this.exams,
  });

  final DateTime date;
  final String title;
  final String summary;
  final String source;
  final String scope;
  final String topic;
  final List<String> exams;
}

const Object _keep = Object();

/// One current-affairs note.
class CaNote {
  const CaNote({
    required this.id,
    required this.date,
    required this.title,
    this.summary = '',
    this.source = '',
    this.scope = CaScope.national,
    this.topic = CaTopic.other,
    this.exams = const [CaExam.upsc, CaExam.uppcs],
    this.starred = false,
    this.revisions = 0,
    this.lastRevisedAt,
    required this.createdAt,
  });

  final String id;

  /// "yyyy-MM-dd": the day the news is from.
  final String date;
  final String title;
  final String summary;
  final String source;
  final String scope;
  final String topic;
  final List<String> exams;
  final bool starred;

  /// How many scheduled revisions have been done.
  final int revisions;
  final String? lastRevisedAt;
  final String createdAt;

  CaNote copyWith({
    String? date,
    String? title,
    String? summary,
    String? source,
    String? scope,
    String? topic,
    List<String>? exams,
    bool? starred,
    int? revisions,
    Object? lastRevisedAt = _keep,
  }) =>
      CaNote(
        id: id,
        date: date ?? this.date,
        title: title ?? this.title,
        summary: summary ?? this.summary,
        source: source ?? this.source,
        scope: scope ?? this.scope,
        topic: topic ?? this.topic,
        exams: exams ?? this.exams,
        starred: starred ?? this.starred,
        revisions: revisions ?? this.revisions,
        lastRevisedAt: identical(lastRevisedAt, _keep)
            ? this.lastRevisedAt
            : lastRevisedAt as String?,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'summary': summary,
        'source': source,
        'scope': scope,
        'topic': topic,
        'exams': exams,
        'starred': starred,
        'revisions': revisions,
        'lastRevisedAt': lastRevisedAt,
        'createdAt': createdAt,
      };

  factory CaNote.fromJson(Map<String, dynamic> j) => CaNote(
        id: (j['id'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        source: (j['source'] ?? '').toString(),
        scope: CaScope.normalize(j['scope']),
        topic: CaTopic.normalize(j['topic']),
        exams: CaExam.normalizeList(j['exams']),
        starred: j['starred'] == true,
        revisions: (j['revisions'] as num?)?.toInt() ?? 0,
        lastRevisedAt: j['lastRevisedAt']?.toString(),
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}
