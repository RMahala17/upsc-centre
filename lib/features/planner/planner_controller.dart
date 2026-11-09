import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/utils/dates.dart';
import 'models/planner_models.dart';
import 'planner_logic.dart';

class PlannerState {
  const PlannerState(this.tasks);
  final List<PlannerTask> tasks;
}

class PlannerController extends Notifier<PlannerState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  PlannerState build() => _load();

  PlannerState _load() {
    final list = _db.all(Collections.tasks).map(PlannerTask.fromJson).toList();
    return PlannerState(list);
  }

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  Future<void> _save(PlannerTask t) =>
      _db.put(Collections.tasks, t.id, t.toJson());

  int _nextOrder(String key) {
    var maxOrder = 0;
    for (final t in state.tasks) {
      if (t.date == key) maxOrder = math.max(maxOrder, t.order);
    }
    return maxOrder + 1;
  }

  /// Adds one task per title, in order, to the given day.
  Future<void> add({
    required DateTime date,
    required List<String> titles,
    required String category,
    required int plannedMin,
  }) async {
    final key = dateKey(date);
    var order = _nextOrder(key);
    final now = DateTime.now().toIso8601String();
    for (final raw in titles) {
      final title = raw.trim();
      if (title.isEmpty) continue;
      await _save(PlannerTask(
        id: _uuid.v4(),
        date: key,
        title: title,
        category: category,
        plannedMin: plannedMin,
        order: order++,
        createdAt: now,
      ));
    }
    state = _load();
  }

  /// Insert or overwrite. Also used to undo a delete.
  Future<void> restore(PlannerTask t) async {
    await _save(t);
    state = _load();
  }

  Future<void> edit(
    String id, {
    required String title,
    required String category,
    required int plannedMin,
  }) async {
    final t = _byId(id);
    if (t == null) return;
    await _save(t.copyWith(
      title: title.trim(),
      category: category,
      plannedMin: plannedMin,
    ));
    state = _load();
  }

  PlannerTask? _byId(String id) {
    for (final t in state.tasks) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> toggle(String id) async {
    final t = _byId(id);
    if (t == null) return;
    await _save(t.toggled(DateTime.now()));
    state = _load();
  }

  Future<void> remove(String id) async {
    await _db.delete(Collections.tasks, id);
    state = _load();
  }

  /// Moves one task to the end of another day's list.
  Future<void> moveToDate(String id, DateTime date) async {
    final t = _byId(id);
    if (t == null) return;
    final key = dateKey(date);
    if (t.date == key) return;
    await _save(t.copyWith(
      date: key,
      order: _nextOrder(key),
      carryCount: t.carryCount + 1,
    ));
    state = _load();
  }

  /// Moves every unfinished task from earlier days onto [toDate].
  /// Returns how many tasks were moved.
  Future<int> carryOver(DateTime toDate) async {
    final key = dateKey(toDate);
    final pending = unfinishedBefore(state.tasks, key);
    if (pending.isEmpty) return 0;
    var order = _nextOrder(key);
    for (final t in pending) {
      await _save(t.copyWith(
        date: key,
        order: order++,
        carryCount: t.carryCount + 1,
      ));
    }
    state = _load();
    return pending.length;
  }
}

final plannerProvider =
    NotifierProvider<PlannerController, PlannerState>(PlannerController.new);
