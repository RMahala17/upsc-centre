import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/storage/db.dart';
import '../../core/utils/dates.dart';
import 'answer_logic.dart';
import 'models/answer_models.dart';

class AnswerState {
  const AnswerState(this.answers);
  final List<AnswerEntry> answers;
}

class AnswerController extends Notifier<AnswerState> {
  static const _uuid = Uuid();
  final Db _db = Db.instance;

  @override
  AnswerState build() => _load();

  AnswerState _load() => AnswerState(
        _db.all(Collections.answers).map(AnswerEntry.fromJson).toList(),
      );

  /// Re-read from storage (e.g. after a backup restore).
  void reload() => state = _load();

  Future<void> _save(AnswerEntry a) =>
      _db.put(Collections.answers, a.id, a.toJson());

  AnswerEntry? _byId(String id) {
    for (final a in state.answers) {
      if (a.id == id) return a;
    }
    return null;
  }

  Future<void> add(AnswerInput i) async {
    await _save(AnswerEntry(
      id: _uuid.v4(),
      date: dateKey(i.date),
      paper: i.paper,
      question: i.question.trim(),
      topic: i.topic.trim(),
      marks: i.marks,
      wordLimit: i.wordLimit,
      minutes: i.minutes,
      score: i.score,
      feedback: i.feedback.trim(),
      status: deriveAnswerStatus(
        current: null,
        score: i.score,
        needsRewrite: i.needsRewrite,
      ),
      createdAt: DateTime.now().toIso8601String(),
    ));
    state = _load();
  }

  Future<void> edit(String id, AnswerInput i) async {
    final a = _byId(id);
    if (a == null) return;
    await _save(a.copyWith(
      date: dateKey(i.date),
      paper: i.paper,
      question: i.question.trim(),
      topic: i.topic.trim(),
      marks: i.marks,
      wordLimit: i.wordLimit,
      minutes: i.minutes,
      score: i.score,
      feedback: i.feedback.trim(),
      status: deriveAnswerStatus(
        current: a.status,
        score: i.score,
        needsRewrite: i.needsRewrite,
      ),
    ));
    state = _load();
  }

  /// After the answer has been written again.
  Future<void> markRewritten(String id) async {
    final a = _byId(id);
    if (a == null) return;
    await _save(a.copyWith(status: AnswerStatus.rewritten));
    state = _load();
  }

  Future<void> remove(String id) async {
    await _db.delete(Collections.answers, id);
    state = _load();
  }

  /// Insert or overwrite. Also used to undo a delete.
  Future<void> restore(AnswerEntry a) async {
    await _save(a);
    state = _load();
  }
}

final answerProvider =
    NotifierProvider<AnswerController, AnswerState>(AnswerController.new);
