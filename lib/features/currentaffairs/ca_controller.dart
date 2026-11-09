import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/utils/dates.dart';
import 'ca_logic.dart';
import 'models/ca_models.dart';

class CaState {
  const CaState(this.notes);

  /// Newest day first.
  final List<CaNote> notes;
}

class CaController extends Notifier<CaState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  CaState build() => _load();

  CaState _load() {
    final list = _db.all(Collections.notes).map(CaNote.fromJson).toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
    return CaState(list);
  }

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  Future<void> _save(CaNote n) => _db.put(Collections.notes, n.id, n.toJson());

  CaNote? _byId(String id) {
    for (final n in state.notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<void> add(CaInput i) async {
    final title = i.title.trim();
    if (title.isEmpty) return;
    await _save(CaNote(
      id: _uuid.v4(),
      date: dateKey(i.date),
      title: title,
      summary: i.summary.trim(),
      source: i.source.trim(),
      scope: i.scope,
      topic: i.topic,
      exams: CaExam.normalizeList(i.exams),
      createdAt: DateTime.now().toIso8601String(),
    ));
    state = _load();
  }

  Future<void> edit(String id, CaInput i) async {
    final n = _byId(id);
    final title = i.title.trim();
    if (n == null || title.isEmpty) return;
    final dateChanged = n.date != dateKey(i.date);
    var updated = n.copyWith(
      date: dateKey(i.date),
      title: title,
      summary: i.summary.trim(),
      source: i.source.trim(),
      scope: i.scope,
      topic: i.topic,
      exams: CaExam.normalizeList(i.exams),
    );
    // Revision timing hangs off the note's date, so moving the note restarts
    // its schedule.
    if (dateChanged) updated = resetRevisions(updated);
    await _save(updated);
    state = _load();
  }

  Future<void> toggleStar(String id) async {
    final n = _byId(id);
    if (n == null) return;
    await _save(n.copyWith(starred: !n.starred));
    state = _load();
  }

  Future<void> markRevised(String id) async {
    final n = _byId(id);
    if (n == null) return;
    await _save(applyRevision(n, DateTime.now()));
    state = _load();
  }

  Future<void> clearRevisions(String id) async {
    final n = _byId(id);
    if (n == null) return;
    await _save(resetRevisions(n));
    state = _load();
  }

  Future<void> remove(String id) async {
    await _db.delete(Collections.notes, id);
    state = _load();
  }

  /// Insert or overwrite. Also used to undo a delete.
  Future<void> restore(CaNote n) async {
    await _save(n);
    state = _load();
  }
}

final caProvider =
    NotifierProvider<CaController, CaState>(CaController.new);
