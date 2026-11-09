import '../../../core/storage/db.dart';
import '../../../core/storage/settings_store.dart';
import '../models/syllabus_models.dart';
import 'seed_data.dart';

/// Creates the empty GS subject structure once. Never runs again after the
/// first time, so subjects you delete or rename are never re-created.
Future<void> seedGsSubjectsIfNeeded() async {
  if (SettingsStore.getBool(SettingsKeys.gsSeeded)) return;

  final db = Db.instance;
  if (db.all(Collections.subjects).isEmpty) {
    final now = DateTime.now().toIso8601String();
    for (var i = 0; i < gsSeed.length; i++) {
      final s = gsSeed[i];
      final subject = Subject(
        id: s.id,
        name: s.name,
        paper: s.paper,
        order: i + 1,
        createdAt: now,
      );
      await db.put(Collections.subjects, subject.id, subject.toJson());
    }
  }
  await SettingsStore.setBool(SettingsKeys.gsSeeded, true);
}
