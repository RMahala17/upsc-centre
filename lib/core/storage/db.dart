import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// Every collection the app persists. Adding a collection later is safe:
/// old backups simply won't contain it.
class Collections {
  static const subjects = 'subjects';
  static const lectures = 'lectures';
  static const revisionCycles = 'revision_cycles';
  static const tasks = 'tasks';
  static const sessions = 'sessions';
  static const answers = 'answers';
  static const pyqs = 'pyqs';
  static const tests = 'tests';
  static const notes = 'notes';
  static const anthroChapters = 'anthro_chapters';
  static const anthroLectures = 'anthro_lectures';
  static const settings = 'settings';

  static const all = [
    subjects,
    lectures,
    revisionCycles,
    tasks,
    sessions,
    answers,
    pyqs,
    tests,
    notes,
    anthroChapters,
    anthroLectures,
    settings,
  ];
}

/// Thin local-first store. Each collection is a Hive box of id -> JSON map.
class Db {
  Db._();
  static final Db instance = Db._();

  final Map<String, Box<dynamic>> _boxes = {};

  Future<void> init() async {
    await Hive.initFlutter();
    for (final name in Collections.all) {
      _boxes[name] = await Hive.openBox<dynamic>(name);
    }
  }

  Box<dynamic> _box(String c) {
    final b = _boxes[c];
    if (b == null) throw StateError('Unknown collection: $c');
    return b;
  }

  static Map<String, dynamic> _toMap(dynamic v) =>
      jsonDecode(jsonEncode(v)) as Map<String, dynamic>;

  List<Map<String, dynamic>> all(String c) =>
      _box(c).values.map(_toMap).toList();

  Map<String, dynamic>? get(String c, String id) {
    final v = _box(c).get(id);
    return v == null ? null : _toMap(v);
  }

  Future<void> put(String c, String id, Map<String, dynamic> data) =>
      _box(c).put(id, data);

  Future<void> delete(String c, String id) => _box(c).delete(id);

  Stream<BoxEvent> watch(String c) => _box(c).watch();

  /// Snapshot of one collection as id -> map (used by backup).
  Map<String, Map<String, dynamic>> snapshot(String c) {
    final box = _box(c);
    return {for (final k in box.keys) k.toString(): _toMap(box.get(k))};
  }

  /// Replace a whole collection (used by restore, after validation).
  Future<void> replaceCollection(
    String c,
    Map<String, Map<String, dynamic>> data,
  ) async {
    final box = _box(c);
    await box.clear();
    await box.putAll(data);
  }
}
