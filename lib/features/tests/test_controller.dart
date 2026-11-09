import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/utils/dates.dart';
import 'models/test_models.dart';

class TestState {
  const TestState(this.tests);
  final List<TestRecord> tests;
}

class TestController extends Notifier<TestState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  TestState build() => _load();

  TestState _load() =>
      TestState(_db.all(Collections.tests).map(TestRecord.fromJson).toList());

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  Future<void> _save(TestRecord t) =>
      _db.put(Collections.tests, t.id, t.toJson());

  TestRecord? _byId(String id) {
    for (final t in state.tests) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> add(TestInput i) async {
    await _save(TestRecord(
      id: _uuid.v4(),
      name: i.name.trim(),
      series: i.series.trim(),
      category: i.category,
      date: dateKey(i.date),
      totalQuestions: i.totalQuestions,
      maxMarks: i.maxMarks,
      correct: i.correct,
      wrong: i.wrong,
      score: i.score,
      timeMin: i.timeMin,
      analysisDone: i.analysisDone,
      notes: i.notes.trim(),
      createdAt: DateTime.now().toIso8601String(),
    ));
    state = _load();
  }

  Future<void> edit(String id, TestInput i) async {
    final t = _byId(id);
    if (t == null) return;
    await _save(t.copyWith(
      name: i.name.trim(),
      series: i.series.trim(),
      category: i.category,
      date: dateKey(i.date),
      totalQuestions: i.totalQuestions,
      maxMarks: i.maxMarks,
      correct: i.correct,
      wrong: i.wrong,
      score: i.score,
      timeMin: i.timeMin,
      analysisDone: i.analysisDone,
      notes: i.notes.trim(),
    ));
    state = _load();
  }

  Future<void> toggleAnalysis(String id) async {
    final t = _byId(id);
    if (t == null) return;
    await _save(t.copyWith(analysisDone: !t.analysisDone));
    state = _load();
  }

  Future<void> remove(String id) async {
    await _db.delete(Collections.tests, id);
    state = _load();
  }

  /// Insert or overwrite. Also used to undo a delete.
  Future<void> restore(TestRecord t) async {
    await _save(t);
    state = _load();
  }
}

final testProvider =
    NotifierProvider<TestController, TestState>(TestController.new);
