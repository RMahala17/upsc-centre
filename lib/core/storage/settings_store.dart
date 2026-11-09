import 'db.dart';

class SettingsKeys {
  static const gsSeeded = 'gs_seeded';
  static const gsHistoryHandled = 'gs_history_handled';
  static const anthroDailyTarget = 'anthro_daily_target';
  static const anthroPlannedTotal = 'anthro_planned_total';

  /// The running / paused stopwatch. Device-local runtime state, so it is
  /// left out of backups (see BackupService).
  static const activeTimer = 'active_timer';
}

/// Small key/value settings kept in the `settings` collection.
class SettingsStore {
  static bool getBool(String key) {
    final v = Db.instance.get(Collections.settings, key);
    return v?['value'] == true;
  }

  static Future<void> setBool(String key, bool value) =>
      Db.instance.put(Collections.settings, key, {'value': value});

  static int getInt(String key, int defaultValue) {
    final v = Db.instance.get(Collections.settings, key)?['value'];
    return v is int ? v : defaultValue;
  }

  static Future<void> setInt(String key, int value) =>
      Db.instance.put(Collections.settings, key, {'value': value});
}
