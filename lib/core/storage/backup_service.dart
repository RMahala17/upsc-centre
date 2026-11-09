import 'dart:convert';

import 'db.dart';
import 'settings_store.dart';

class BackupValidation {
  final bool ok;
  final String? error;
  final Map<String, dynamic>? data;

  const BackupValidation.ok(this.data)
      : ok = true,
        error = null;

  const BackupValidation.fail(this.error)
      : ok = false,
        data = null;
}

class BackupService {
  static const appId = 'upsc_command_centre';
  static const schemaVersion = 1;
  static const safetyKey = 'pre_restore_snapshot';

  BackupService([Db? db]) : _dbOverride = db;

  final Db? _dbOverride;
  Db get _db => _dbOverride ?? Db.instance;

  /// Snapshot of one collection for export. Device-local runtime entries are
  /// left out of settings: the running stopwatch (restoring an old one would
  /// resurrect a stale timer) and the pre-restore safety copy (it would nest
  /// inside every later backup and make the file grow each time).
  Map<String, Map<String, dynamic>> _snapshotForExport(String c) {
    final snap = _db.snapshot(c);
    if (c == Collections.settings) {
      snap.remove(SettingsKeys.activeTimer);
      snap.remove(safetyKey);
    }
    return snap;
  }

  /// Full backup as a JSON string.
  String export() {
    final collections = <String, dynamic>{
      for (final c in Collections.all) c: _snapshotForExport(c),
    };
    return const JsonEncoder.withIndent('  ').convert({
      'app': appId,
      'schemaVersion': schemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'collections': collections,
    });
  }

  /// Checks a backup WITHOUT touching current data.
  BackupValidation validate(String raw) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return const BackupValidation.fail('File is not valid JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      return const BackupValidation.fail('Unexpected backup structure.');
    }
    if (decoded['app'] != appId) {
      return const BackupValidation.fail(
          'This is not a UPSC Command Centre backup.');
    }
    final version = decoded['schemaVersion'];
    if (version is! int) {
      return const BackupValidation.fail('Missing schema version.');
    }
    if (version > schemaVersion) {
      return BackupValidation.fail(
          'Backup is from a newer app version (v$version). Update the app first.');
    }
    final cols = decoded['collections'];
    if (cols is! Map<String, dynamic>) {
      return const BackupValidation.fail('Missing collections.');
    }
    for (final entry in cols.entries) {
      final records = entry.value;
      if (records is! Map<String, dynamic>) {
        return BackupValidation.fail('Collection "${entry.key}" is malformed.');
      }
      for (final r in records.entries) {
        if (r.value is! Map<String, dynamic>) {
          return BackupValidation.fail(
              'Record "${r.key}" in "${entry.key}" is malformed.');
        }
      }
    }
    return BackupValidation.ok(decoded);
  }

  /// The copy of the data kept just before the last restore, if there is one.
  ({String raw, DateTime? savedAt})? safetySnapshot() {
    final v = _db.get(Collections.settings, safetyKey);
    final raw = v?['value'];
    if (raw is! String) return null;
    return (
      raw: raw,
      savedAt: DateTime.tryParse(v?['savedAt']?.toString() ?? '')?.toLocal(),
    );
  }

  /// Validates, keeps a safety snapshot of current data, then replaces data.
  /// Returns null on success, or an error message (current data untouched
  /// if validation fails).
  Future<String?> restore(String raw) async {
    final result = validate(raw);
    if (!result.ok) return result.error;

    final cols = result.data!['collections'] as Map<String, dynamic>;
    final safety = export();

    try {
      // Keep the safety copy BEFORE anything is replaced, so even a failure
      // half-way through can be undone.
      await _db.put(Collections.settings, safetyKey, {
        'value': safety,
        'savedAt': DateTime.now().toIso8601String(),
      });
      for (final c in Collections.all) {
        final records = (cols[c] as Map<String, dynamic>?) ?? {};
        final converted = <String, Map<String, dynamic>>{
          for (final e in records.entries)
            e.key: Map<String, dynamic>.from(e.value as Map),
        };
        if (c == Collections.settings) {
          // Keep the stopwatch that is running right now; a backup must not
          // overwrite it (or bring back an old one).
          converted.remove(SettingsKeys.activeTimer);
          final liveTimer =
              _db.get(Collections.settings, SettingsKeys.activeTimer);
          if (liveTimer != null) {
            converted[SettingsKeys.activeTimer] = liveTimer;
          }
          converted[safetyKey] = {
            'value': safety,
            'savedAt': DateTime.now().toIso8601String(),
          };
        }
        await _db.replaceCollection(c, converted);
      }
      return null;
    } catch (e) {
      return 'Restore failed: $e';
    }
  }
}
