import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import 'models/pyq_models.dart';
import 'pyq_logic.dart';

class PyqState {
  const PyqState(this.pyqs);
  final List<Pyq> pyqs;
}

class PyqController extends Notifier<PyqState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  PyqState build() => _load();

  PyqState _load() =>
      PyqState(_db.all(Collections.pyqs).map(Pyq.fromJson).toList());

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  Future<void> _save(Pyq p) => _db.put(Collections.pyqs, p.id, p.toJson());

  Pyq? _byId(String id) {
    for (final p in state.pyqs) {
      if (p.id == id) return p;
    }
    return null;
  }

  int _nextOrder(String exam, int year) {
    var maxOrder = 0;
    for (final p in state.pyqs) {
      if (p.exam == exam && p.year == year) {
        maxOrder = math.max(maxOrder, p.order);
      }
    }
    return maxOrder + 1;
  }

  /// One question per entry in [PyqInput.questions]. Returns how many were
  /// added.
  Future<int> add(PyqInput i) async {
    var order = _nextOrder(i.exam, i.year);
    final now = DateTime.now().toIso8601String();
    var added = 0;
    for (final raw in i.questions) {
      final q = raw.trim();
      if (q.isEmpty) continue;
      await _save(Pyq(
        id: _uuid.v4(),
        exam: i.exam,
        year: i.year,
        paper: i.paper,
        question: q,
        topic: i.topic.trim(),
        marks: i.exam == PyqExam.mains ? i.marks : 0,
        note: i.note.trim(),
        order: order++,
        createdAt: now,
      ));
      added++;
    }
    state = _load();
    return added;
  }

  Future<void> edit(String id, PyqInput i) async {
    final p = _byId(id);
    if (p == null || i.questions.isEmpty) return;
    final examChanged = p.exam != i.exam || p.year != i.year;
    await _save(p.copyWith(
      exam: i.exam,
      year: i.year,
      paper: i.paper,
      question: i.questions.first.trim(),
      topic: i.topic.trim(),
      marks: i.exam == PyqExam.mains ? i.marks : 0,
      note: i.note.trim(),
      order: examChanged ? _nextOrder(i.exam, i.year) : null,
      // A Prelims result means nothing on a Mains question.
      lastResult: i.exam == PyqExam.prelims ? p.lastResult : null,
    ));
    state = _load();
  }

  Future<void> attempt(String id, {String? result}) async {
    final p = _byId(id);
    if (p == null) return;
    await _save(applyAttempt(p, DateTime.now(), result: result));
    state = _load();
  }

  Future<void> master(String id) async {
    final p = _byId(id);
    if (p == null) return;
    await _save(markMastered(p));
    state = _load();
  }

  Future<void> reset(String id) async {
    final p = _byId(id);
    if (p == null) return;
    await _save(resetPyq(p));
    state = _load();
  }

  Future<void> toggleStar(String id) async {
    final p = _byId(id);
    if (p == null) return;
    await _save(p.copyWith(starred: !p.starred));
    state = _load();
  }

  Future<void> remove(String id) async {
    await _db.delete(Collections.pyqs, id);
    state = _load();
  }

  /// Insert or overwrite. Also used to undo a delete.
  Future<void> restore(Pyq p) async {
    await _save(p);
    state = _load();
  }
}

final pyqProvider =
    NotifierProvider<PyqController, PyqState>(PyqController.new);
