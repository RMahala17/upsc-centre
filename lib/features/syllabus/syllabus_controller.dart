import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/storage/settings_store.dart';
import 'models/syllabus_models.dart';

class HistoricalLoad {
  const HistoricalLoad({
    required this.subjectId,
    required this.completed,
    required this.total,
  });

  final String subjectId;
  final int completed;
  final int total;
}

class SyllabusState {
  const SyllabusState({
    required this.subjects,
    required this.lectures,
    required this.historyHandled,
  });

  final List<Subject> subjects;
  final List<Lecture> lectures;
  final bool historyHandled;

  Subject? subjectById(String id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<Subject> subjectsOfPaper(String paper) =>
      subjects.where((s) => s.paper == paper).toList();

  List<Lecture> lecturesOf(String subjectId) {
    final list = lectures.where((l) => l.subjectId == subjectId).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  SubjectStats statsOf(String subjectId) {
    var total = 0;
    var done = 0;
    for (final l in lectures) {
      if (l.subjectId != subjectId) continue;
      total++;
      if (l.completed) done++;
    }
    return SubjectStats(total, done);
  }

  SubjectStats get overall {
    final ids = subjects.map((s) => s.id).toSet();
    var total = 0;
    var done = 0;
    for (final l in lectures) {
      if (!ids.contains(l.subjectId)) continue;
      total++;
      if (l.completed) done++;
    }
    return SubjectStats(total, done);
  }
}

class SyllabusController extends Notifier<SyllabusState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  SyllabusState build() => _load();

  SyllabusState _load() {
    final subjects =
        _db.all(Collections.subjects).map(Subject.fromJson).toList();
    subjects.sort((a, b) => a.order.compareTo(b.order));
    final lectures =
        _db.all(Collections.lectures).map(Lecture.fromJson).toList();
    return SyllabusState(
      subjects: subjects,
      lectures: lectures,
      historyHandled: SettingsStore.getBool(SettingsKeys.gsHistoryHandled),
    );
  }

  /// Re-read everything from storage (e.g. after a backup restore).
  void reload() => state = _load();

  // ---------- Subjects ----------

  Future<void> addSubject(String name, String paper) async {
    final nextOrder = state.subjects.isEmpty
        ? 1
        : state.subjects.map((s) => s.order).reduce(math.max) + 1;
    final subject = Subject(
      id: _uuid.v4(),
      name: name.trim(),
      paper: paper,
      order: nextOrder,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.put(Collections.subjects, subject.id, subject.toJson());
    state = _load();
  }

  Future<void> updateSubject(Subject subject) async {
    await _db.put(Collections.subjects, subject.id, subject.toJson());
    state = _load();
  }

  /// Deletes the subject and all of its lectures.
  Future<void> deleteSubject(String id) async {
    for (final l in state.lecturesOf(id)) {
      await _db.delete(Collections.lectures, l.id);
    }
    await _db.delete(Collections.subjects, id);
    state = _load();
  }

  // ---------- Lectures ----------

  int _nextLectureOrder(String subjectId) {
    final existing = state.lecturesOf(subjectId);
    return existing.isEmpty ? 1 : existing.last.order + 1;
  }

  Future<void> addLecture(String subjectId, String title) async {
    final lecture = Lecture(
      id: _uuid.v4(),
      subjectId: subjectId,
      title: title.trim(),
      order: _nextLectureOrder(subjectId),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.put(Collections.lectures, lecture.id, lecture.toJson());
    state = _load();
  }

  /// Adds [count] lectures titled "Lecture N" continuing the numbering.
  Future<void> addLectures(String subjectId, int count) async {
    var order = _nextLectureOrder(subjectId);
    final now = DateTime.now().toIso8601String();
    for (var i = 0; i < count; i++) {
      final lecture = Lecture(
        id: _uuid.v4(),
        subjectId: subjectId,
        title: 'Lecture $order',
        order: order,
        createdAt: now,
      );
      await _db.put(Collections.lectures, lecture.id, lecture.toJson());
      order++;
    }
    state = _load();
  }

  Lecture? _lectureById(String id) {
    for (final l in state.lectures) {
      if (l.id == id) return l;
    }
    return null;
  }

  Future<void> editLecture(String id, String title) async {
    final l = _lectureById(id);
    if (l == null) return;
    final updated = l.copyWith(title: title.trim());
    await _db.put(Collections.lectures, id, updated.toJson());
    state = _load();
  }

  Future<void> toggleLecture(String id) async {
    final l = _lectureById(id);
    if (l == null) return;
    final updated = l.toggled(DateTime.now());
    await _db.put(Collections.lectures, id, updated.toJson());
    state = _load();
  }

  Future<void> deleteLecture(String id) async {
    await _db.delete(Collections.lectures, id);
    state = _load();
  }

  // ---------- Previously reported counts ----------

  /// Creates lectures for subjects that have none yet. Never touches a
  /// subject that already has lectures. Returns how many subjects loaded.
  Future<int> loadHistorical(List<HistoricalLoad> rows) async {
    var loaded = 0;
    final now = DateTime.now().toIso8601String();
    for (final row in rows) {
      if (row.total <= 0) continue;
      if (state.subjectById(row.subjectId) == null) continue;
      if (state.lecturesOf(row.subjectId).isNotEmpty) continue;
      for (var i = 1; i <= row.total; i++) {
        final lecture = Lecture(
          id: _uuid.v4(),
          subjectId: row.subjectId,
          title: 'Lecture $i',
          order: i,
          completed: i <= row.completed,
          completedAt: null, // real completion date unknown
          createdAt: now,
        );
        await _db.put(Collections.lectures, lecture.id, lecture.toJson());
      }
      loaded++;
    }
    await SettingsStore.setBool(SettingsKeys.gsHistoryHandled, true);
    state = _load();
    return loaded;
  }

  Future<void> markHistoryHandled() async {
    await SettingsStore.setBool(SettingsKeys.gsHistoryHandled, true);
    state = _load();
  }
}

final syllabusProvider =
    NotifierProvider<SyllabusController, SyllabusState>(SyllabusController.new);
