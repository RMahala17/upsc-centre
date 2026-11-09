import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/core/storage/db.dart';
import 'package:upsc_command_centre/features/backup/backup_summary.dart';

void main() {
  group('summarizeBackup', () {
    test('counts records per collection and ignores settings', () {
      final s = summarizeBackup({
        'schemaVersion': 1,
        'exportedAt': DateTime(2026, 11, 9, 7, 54).toIso8601String(),
        'collections': {
          Collections.sessions: {'a': {}, 'b': {}},
          Collections.notes: {'n': {}},
          Collections.settings: {'x': {}, 'y': {}, 'z': {}},
        },
      });
      expect(s.counts[Collections.sessions], 2);
      expect(s.counts[Collections.notes], 1);
      expect(s.counts.containsKey(Collections.settings), isFalse);
      expect(s.total, 3);
      expect(s.schemaVersion, 1);
      expect(s.exportedAt, DateTime(2026, 11, 9, 7, 54));
    });

    test('rows follow the display order and skip empty collections', () {
      final s = summarizeBackup({
        'collections': {
          Collections.notes: {'n': {}},
          Collections.sessions: {'a': {}},
        },
      });
      expect(s.rows, [('Study sessions', 1), ('Current affairs notes', 1)]);
    });

    test('a file with no collections is empty, not an error', () {
      final s = summarizeBackup({'schemaVersion': 1});
      expect(s.total, 0);
      expect(s.rows, isEmpty);
      expect(s.exportedAt, isNull);
    });

    test('bad exportedAt is ignored', () {
      expect(summarizeBackup({'exportedAt': 'yesterday'}).exportedAt, isNull);
    });
  });

  group('helpers', () {
    test('backupFileName', () {
      expect(
        backupFileName(DateTime(2026, 11, 9, 7, 5)),
        'upsc-command-centre-backup-2026-11-09-0705.json',
      );
    });

    test('ageText', () {
      expect(ageText(0), 'today');
      expect(ageText(1), 'yesterday');
      expect(ageText(12), '12 days ago');
    });

    test('every record collection has a readable label', () {
      for (final c in kRecordCollections) {
        expect(collectionLabel(c), isNot(c), reason: c);
      }
    });
  });
}
