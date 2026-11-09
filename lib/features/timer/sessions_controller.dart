import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/utils/dates.dart';
import 'models/session_models.dart';

class SessionsState {
  const SessionsState(this.sessions);

  /// Most recent first.
  final List<StudySession> sessions;
}

class SessionsController extends Notifier<SessionsState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  SessionsState build() => _load();

  SessionsState _load() {
    final list =
        _db.all(Collections.sessions).map(StudySession.fromJson).toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return SessionsState(list);
  }

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  /// Insert or overwrite. Also used to undo a delete.
  Future<void> add(StudySession s) async {
    await _db.put(Collections.sessions, s.id, s.toJson());
    state = _load();
  }

  Future<void> update(StudySession s) => add(s);

  Future<void> remove(String id) async {
    await _db.delete(Collections.sessions, id);
    state = _load();
  }

  /// Hand-entered session (forgot to start the timer, studied offline...).
  Future<void> addManual({
    required DateTime date,
    required int minutes,
    required String category,
    String label = '',
    String note = '',
    String? taskId,
  }) async {
    final now = DateTime.now();
    final day = dateOnly(date);
    final started = DateTime(day.year, day.month, day.day, now.hour, now.minute);
    await add(StudySession(
      id: _uuid.v4(),
      date: dateKey(day),
      startedAt: started.toIso8601String(),
      durationSec: minutes * 60,
      category: category,
      label: label.trim(),
      taskId: taskId,
      note: note.trim(),
      manual: true,
      createdAt: now.toIso8601String(),
    ));
  }
}

final sessionsProvider =
    NotifierProvider<SessionsController, SessionsState>(SessionsController.new);
