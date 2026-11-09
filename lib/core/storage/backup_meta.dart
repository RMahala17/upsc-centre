import 'db.dart';

/// When the last backup file was exported. The dashboard reads this to show a
/// backup reminder; the backup screen (Stage 8) must call [markBackedUp]
/// right after a successful export.
class BackupMeta {
  static const lastBackupKey = 'last_backup_at';

  static DateTime? lastBackupAt() {
    final v = Db.instance.get(Collections.settings, lastBackupKey)?['value'];
    if (v is! String) return null;
    return DateTime.tryParse(v)?.toLocal();
  }

  static Future<void> markBackedUp([DateTime? at]) => Db.instance.put(
        Collections.settings,
        lastBackupKey,
        {'value': (at ?? DateTime.now()).toIso8601String()},
      );
}
