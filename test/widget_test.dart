import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/core/storage/backup_service.dart';

void main() {
  final service = BackupService();

  test('rejects non-JSON backup', () {
    expect(service.validate('not json').ok, isFalse);
  });

  test('rejects backup from another app', () {
    expect(service.validate('{"app":"other","schemaVersion":1}').ok, isFalse);
  });

  test('rejects newer schema version', () {
    final raw =
        '{"app":"upsc_command_centre","schemaVersion":99,"collections":{}}';
    expect(service.validate(raw).ok, isFalse);
  });

  test('accepts a valid empty backup', () {
    final raw =
        '{"app":"upsc_command_centre","schemaVersion":1,"collections":{}}';
    expect(service.validate(raw).ok, isTrue);
  });
}
