class AnthroPaper {
  static const paper1 = 'ANT1';
  static const paper2 = 'ANT2';
  static const all = [paper1, paper2];

  static String title(String paper) {
    switch (paper) {
      case paper1:
        return 'Paper I';
      case paper2:
        return 'Paper II';
      default:
        return paper;
    }
  }
}

/// A chapter of the Anthropology optional. Its lectures are stored as
/// `Lecture` records (subjectId = chapter id) in the anthro_lectures collection.
class Chapter {
  const Chapter({
    required this.id,
    required this.paper,
    required this.name,
    required this.order,
    required this.createdAt,
  });

  final String id;
  final String paper;
  final String name;
  final int order;
  final String createdAt;

  Chapter copyWith({String? name, String? paper}) => Chapter(
        id: id,
        paper: paper ?? this.paper,
        name: name ?? this.name,
        order: order,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'paper': paper,
        'name': name,
        'order': order,
        'createdAt': createdAt,
      };

  factory Chapter.fromJson(Map<String, dynamic> j) => Chapter(
        id: (j['id'] ?? '').toString(),
        paper: (j['paper'] ?? AnthroPaper.paper1).toString(),
        name: (j['name'] ?? '').toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
        createdAt: (j['createdAt'] ?? '').toString(),
      );
}
