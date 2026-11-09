import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/utils/dates.dart';
import '../syllabus/models/syllabus_models.dart';
import 'models/revision_models.dart';
import 'revision_logic.dart';

class RevisionState {
  const RevisionState(this.cycles);
  final List<RevisionCycle> cycles;

  RevisionCycle? cycleById(String id) {
    for (final c in cycles) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class RevisionController extends Notifier<RevisionState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  RevisionState build() => _load();

  RevisionState _load() {
    final cycles =
        _db.all(Collections.revisionCycles).map(RevisionCycle.fromJson).toList();
    cycles.sort((a, b) {
      final c = a.startDate.compareTo(b.startDate);
      return c != 0 ? c : a.number.compareTo(b.number);
    });
    return RevisionState(cycles);
  }

  void reload() => state = _load();

  Future<void> _save(RevisionCycle c) async {
    await _db.put(Collections.revisionCycles, c.id, c.toJson());
    state = _load();
  }

  Future<String> createCycle({
    required RevisionTargetType type,
    required String targetId,
    required String targetName,
    required DateTime start,
    required int length,
    required List<String> topics,
  }) async {
    final cycle = RevisionCycle(
      id: _uuid.v4(),
      targetType: type,
      targetId: targetId,
      targetName: targetName,
      number: nextCycleNumber(state.cycles, type, targetId),
      startDate: dateKey(start),
      lengthDays: length,
      items: buildCycleItems(
        topics: topics,
        length: length,
        newId: () => _uuid.v4(),
      ),
      createdAt: DateTime.now().toIso8601String(),
    );
    await _save(cycle);
    return cycle.id;
  }

  Future<void> deleteCycle(String id) async {
    await _db.delete(Collections.revisionCycles, id);
    state = _load();
  }

  RevisionCycle? _cycle(String id) => state.cycleById(id);

  Future<void> updateSchedule(String id, DateTime start, int length) async {
    final c = _cycle(id);
    if (c == null) return;
    await _save(c.copyWith(
      startDate: dateKey(start),
      lengthDays: length,
      items: applyLength(c.items, length),
    ));
  }

  Future<void> setNotes(String id, String notes) async {
    final c = _cycle(id);
    if (c == null) return;
    await _save(c.copyWith(notes: notes.trim()));
  }

  Future<void> setPyqStatus(String id, TrackStatus status) async {
    final c = _cycle(id);
    if (c == null) return;
    await _save(c.copyWith(pyqStatus: status));
  }

  Future<void> completeCycle(String id, DateTime now) async {
    final c = _cycle(id);
    if (c == null) return;
    await _save(c.copyWith(completedDate: dateKey(now)));
  }

  Future<void> reopenCycle(String id) async {
    final c = _cycle(id);
    if (c == null) return;
    await _save(c.copyWith(clearCompleted: true));
  }

  // ---------- checklist ----------

  Future<void> toggleItem(String cycleId, String itemId) async {
    final c = _cycle(cycleId);
    if (c == null) return;
    final now = DateTime.now();
    await _save(c.copyWith(items: [
      for (final i in c.items) i.id == itemId ? i.toggled(now) : i,
    ]));
  }

  int _nextOrder(RevisionCycle c) =>
      c.items.isEmpty ? 1 : c.items.map((i) => i.order).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> addItems(String cycleId, List<String> titles, int day) async {
    final c = _cycle(cycleId);
    if (c == null || titles.isEmpty) return;
    var order = _nextOrder(c);
    final added = [
      for (final t in titles)
        RevisionItem(id: _uuid.v4(), title: t.trim(), day: day, order: order++),
    ];
    await _save(c.copyWith(items: [...c.items, ...added]));
  }

  Future<void> editItem(
    String cycleId,
    String itemId, {
    required String title,
    required int day,
  }) async {
    final c = _cycle(cycleId);
    if (c == null) return;
    await _save(c.copyWith(items: [
      for (final i in c.items)
        i.id == itemId ? i.copyWith(title: title.trim(), day: day) : i,
    ]));
  }

  Future<void> deleteItem(String cycleId, String itemId) async {
    final c = _cycle(cycleId);
    if (c == null) return;
    await _save(c.copyWith(items: c.items.where((i) => i.id != itemId).toList()));
  }

  Future<void> redistribute(String cycleId) async {
    final c = _cycle(cycleId);
    if (c == null) return;
    await _save(c.copyWith(items: redistributeTopics(c.items, c.lengthDays)));
  }
}

final revisionProvider =
    NotifierProvider<RevisionController, RevisionState>(RevisionController.new);
