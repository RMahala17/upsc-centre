import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/storage/settings_store.dart';
import '../syllabus/models/syllabus_models.dart';
import 'anthro_logic.dart';
import 'models/anthro_models.dart';

const int kDefaultAnthroTarget = 2;
const int kDefaultAnthroPlanned = 176;

class AnthroState {
  const AnthroState({
    required this.chapters,
    required this.lectures,
    required this.dailyTarget,
    required this.plannedTotal,
  });

  final List<Chapter> chapters;
  final List<Lecture> lectures; // subjectId == chapter id
  final int dailyTarget;
  final int plannedTotal;

  Chapter? chapterById(String id) {
    for (final c in chapters) {
      if (c.id == id) return c;
    }
    return null;
  }

  List<Chapter> chaptersOfPaper(String paper) =>
      chapters.where((c) => c.paper == paper).toList();

  List<Lecture> lecturesOf(String chapterId) {
    final list = lectures.where((l) => l.subjectId == chapterId).toList();
    list.sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  /// Only lectures whose chapter still exists.
  List<Lecture> get _live {
    final ids = chapters.map((c) => c.id).toSet();
    return lectures.where((l) => ids.contains(l.subjectId)).toList();
  }

  SubjectStats statsOfChapter(String chapterId) {
    var total = 0;
    var done = 0;
    for (final l in lectures) {
      if (l.subjectId != chapterId) continue;
      total++;
      if (l.completed) done++;
    }
    return SubjectStats(total, done);
  }

  SubjectStats statsOfPaper(String paper) {
    final ids = chaptersOfPaper(paper).map((c) => c.id).toSet();
    var total = 0;
    var done = 0;
    for (final l in lectures) {
      if (!ids.contains(l.subjectId)) continue;
      total++;
      if (l.completed) done++;
    }
    return SubjectStats(total, done);
  }

  int get entered => _live.length;
  int get completed => _live.where((l) => l.completed).length;

  /// Progress is measured against the planned total, or the entered count
  /// if the chapters already hold more lectures than planned.
  int get denominator => math.max(plannedTotal, entered);
  int get remaining => denominator - completed;
  double get fraction => denominator == 0 ? 0 : completed / denominator;
  int get percent => (fraction * 100).round();
  int get unentered => math.max(0, plannedTotal - entered);

  int completedOn(DateTime day) {
    var n = 0;
    for (final l in _live) {
      if (!l.completed || l.completedAt == null) continue;
      final d = DateTime.tryParse(l.completedAt!)?.toLocal();
      if (d == null) continue;
      if (d.year == day.year && d.month == day.month && d.day == day.day) n++;
    }
    return n;
  }

  PaceEstimate? pace(DateTime now) =>
      computePace(lectures: _live, now: now, remaining: remaining);

  DateTime? targetFinish(DateTime now) =>
      targetEta(remaining: remaining, dailyTarget: dailyTarget, now: now);
}

class AnthroController extends Notifier<AnthroState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  AnthroState build() => _load();

  AnthroState _load() {
    final chapters =
        _db.all(Collections.anthroChapters).map(Chapter.fromJson).toList();
    chapters.sort((a, b) => a.order.compareTo(b.order));
    final lectures =
        _db.all(Collections.anthroLectures).map(Lecture.fromJson).toList();
    return AnthroState(
      chapters: chapters,
      lectures: lectures,
      dailyTarget: SettingsStore.getInt(
          SettingsKeys.anthroDailyTarget, kDefaultAnthroTarget),
      plannedTotal: SettingsStore.getInt(
          SettingsKeys.anthroPlannedTotal, kDefaultAnthroPlanned),
    );
  }

  void reload() => state = _load();

  Future<void> saveSettings({required int target, required int planned}) async {
    await SettingsStore.setInt(SettingsKeys.anthroDailyTarget, target);
    await SettingsStore.setInt(SettingsKeys.anthroPlannedTotal, planned);
    state = _load();
  }

  // ---------- Chapters ----------

  int _nextChapterOrder() => state.chapters.isEmpty
      ? 1
      : state.chapters.map((c) => c.order).reduce(math.max) + 1;

  Future<String> _createChapter(String paper, String name, int order) async {
    final chapter = Chapter(
      id: _uuid.v4(),
      paper: paper,
      name: name.trim(),
      order: order,
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.put(Collections.anthroChapters, chapter.id, chapter.toJson());
    return chapter.id;
  }

  Future<void> _createLectures(String chapterId, int from, int count) async {
    final now = DateTime.now().toIso8601String();
    for (var i = 0; i < count; i++) {
      final n = from + i;
      final lecture = Lecture(
        id: _uuid.v4(),
        subjectId: chapterId,
        title: 'Lecture $n',
        order: n,
        createdAt: now,
      );
      await _db.put(Collections.anthroLectures, lecture.id, lecture.toJson());
    }
  }

  Future<void> addChapter(String paper, String name, int lectureCount) async {
    final id = await _createChapter(paper, name, _nextChapterOrder());
    await _createLectures(id, 1, lectureCount);
    state = _load();
  }

  /// Returns (chapters created, lectures created).
  Future<(int, int)> addChaptersBulk(
    String paper,
    List<ParsedChapter> items,
  ) async {
    var order = _nextChapterOrder();
    var lectureTotal = 0;
    for (final item in items) {
      final id = await _createChapter(paper, item.name, order);
      await _createLectures(id, 1, item.lectures);
      lectureTotal += item.lectures;
      order++;
    }
    state = _load();
    return (items.length, lectureTotal);
  }

  Future<void> updateChapter(Chapter chapter) async {
    await _db.put(Collections.anthroChapters, chapter.id, chapter.toJson());
    state = _load();
  }

  /// Deletes the chapter and all of its lectures.
  Future<void> deleteChapter(String id) async {
    for (final l in state.lecturesOf(id)) {
      await _db.delete(Collections.anthroLectures, l.id);
    }
    await _db.delete(Collections.anthroChapters, id);
    state = _load();
  }

  // ---------- Lectures ----------

  int _nextLectureOrder(String chapterId) {
    final existing = state.lecturesOf(chapterId);
    return existing.isEmpty ? 1 : existing.last.order + 1;
  }

  Future<void> addLecture(String chapterId, String title) async {
    final lecture = Lecture(
      id: _uuid.v4(),
      subjectId: chapterId,
      title: title.trim(),
      order: _nextLectureOrder(chapterId),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _db.put(Collections.anthroLectures, lecture.id, lecture.toJson());
    state = _load();
  }

  Future<void> addLectures(String chapterId, int count) async {
    await _createLectures(chapterId, _nextLectureOrder(chapterId), count);
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
    await _db.put(
        Collections.anthroLectures, id, l.copyWith(title: title.trim()).toJson());
    state = _load();
  }

  Future<void> toggleLecture(String id) async {
    final l = _lectureById(id);
    if (l == null) return;
    await _db.put(
        Collections.anthroLectures, id, l.toggled(DateTime.now()).toJson());
    state = _load();
  }

  Future<void> deleteLecture(String id) async {
    await _db.delete(Collections.anthroLectures, id);
    state = _load();
  }
}

final anthroProvider =
    NotifierProvider<AnthroController, AnthroState>(AnthroController.new);
