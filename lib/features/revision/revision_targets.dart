import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../anthropology/anthro_controller.dart';
import '../anthropology/models/anthro_models.dart';
import '../syllabus/syllabus_controller.dart';
import 'models/revision_models.dart';

/// Something that can be revised: a GS subject or an Anthropology paper.
class RevisionTarget {
  const RevisionTarget({
    required this.type,
    required this.id,
    required this.name,
    required this.allTopics,
    required this.completedTopics,
    required this.fullyCompleted,
  });

  final RevisionTargetType type;
  final String id;
  final String name;

  /// Checklist seeds: lecture titles (GS) or chapter names (Anthropology).
  final List<String> allTopics;
  final List<String> completedTopics;

  /// True when every lecture of this subject/paper is completed.
  final bool fullyCompleted;

  String get key => '${type.name}:$id';
}

final revisionTargetsProvider = Provider<List<RevisionTarget>>((ref) {
  final gs = ref.watch(syllabusProvider);
  final an = ref.watch(anthroProvider);
  final out = <RevisionTarget>[];

  for (final s in gs.subjects) {
    final lectures = gs.lecturesOf(s.id);
    final stats = gs.statsOf(s.id);
    out.add(RevisionTarget(
      type: RevisionTargetType.gs,
      id: s.id,
      name: s.name,
      allTopics: lectures.map((l) => l.title).toList(),
      completedTopics:
          lectures.where((l) => l.completed).map((l) => l.title).toList(),
      fullyCompleted: stats.total > 0 && stats.completed == stats.total,
    ));
  }

  for (final p in AnthroPaper.all) {
    final chapters = an.chaptersOfPaper(p);
    final stats = an.statsOfPaper(p);
    out.add(RevisionTarget(
      type: RevisionTargetType.anthro,
      id: p,
      name: 'Anthropology ${AnthroPaper.title(p)}',
      allTopics: chapters.map((c) => c.name).toList(),
      completedTopics: chapters.where((c) {
        final s = an.statsOfChapter(c.id);
        return s.total > 0 && s.completed == s.total;
      }).map((c) => c.name).toList(),
      fullyCompleted: stats.total > 0 && stats.completed == stats.total,
    ));
  }
  return out;
});

/// Current name of the cycle's subject, falling back to the saved name.
String cycleTargetName(RevisionCycle c, List<RevisionTarget> targets) {
  for (final t in targets) {
    if (t.type == c.targetType && t.id == c.targetId) return t.name;
  }
  return c.targetName;
}
