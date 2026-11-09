import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/storage/settings_store.dart';
import '../../core/utils/dates.dart';
import 'models/session_models.dart';
import 'sessions_controller.dart';
import 'timer_logic.dart';

/// Holds the single running / paused stopwatch (null = no timer).
///
/// Every change is written to storage BEFORE the state updates, and the app
/// reads it back on launch, so a timer survives a closed tab, a killed app
/// or a phone restart.
class TimerController extends Notifier<ActiveTimer?> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;

  @override
  ActiveTimer? build() => _read();

  ActiveTimer? _read() => ActiveTimer.tryParse(
        _db.get(Collections.settings, SettingsKeys.activeTimer),
      );

  void reload() => state = _read();

  Future<void> _write(ActiveTimer? t) async {
    if (t == null) {
      await _db.delete(Collections.settings, SettingsKeys.activeTimer);
    } else {
      await _db.put(Collections.settings, SettingsKeys.activeTimer, t.toJson());
    }
    state = t;
  }

  /// Returns false (and changes nothing) if a timer already exists.
  Future<bool> start({
    required String category,
    String label = '',
    String? taskId,
  }) async {
    if (state != null) return false;
    await _write(ActiveTimer.start(
      _nowMs(),
      category: category,
      label: label.trim(),
      taskId: taskId,
    ));
    return true;
  }

  Future<void> pause() async {
    final t = state;
    if (t == null || !t.running) return;
    await _write(t.paused(_nowMs()));
  }

  Future<void> resume() async {
    final t = state;
    if (t == null || t.running) return;
    await _write(t.resumed(_nowMs()));
  }

  Future<void> updateMeta({String? category, String? label}) async {
    final t = state;
    if (t == null) return;
    await _write(t.withMeta(category: category, label: label?.trim()));
  }

  /// Throws the running timer away without saving anything.
  Future<void> discard() => _write(null);

  /// Saves the timer as a session, then clears it. The session is written
  /// first, so a crash in between can never lose the time.
  Future<StudySession?> finish({
    required int durationSec,
    required String category,
    required String label,
    required String note,
  }) async {
    final t = state;
    if (t == null) return null;
    final started = DateTime.fromMillisecondsSinceEpoch(t.sessionStartMs);
    final session = StudySession(
      id: _uuid.v4(),
      date: dateKey(started),
      startedAt: started.toIso8601String(),
      durationSec: durationSec,
      category: category,
      label: label.trim(),
      taskId: t.taskId,
      note: note.trim(),
      createdAt: DateTime.now().toIso8601String(),
    );
    await ref.read(sessionsProvider.notifier).add(session);
    await _write(null);
    return session;
  }
}

final timerProvider =
    NotifierProvider<TimerController, ActiveTimer?>(TimerController.new);
