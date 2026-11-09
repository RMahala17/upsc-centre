import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/syllabus/models/syllabus_models.dart';

void main() {
  test('stats with zero lectures show 0%, not a fake value', () {
    const s = SubjectStats(0, 0);
    expect(s.percent, 0);
    expect(s.remaining, 0);
  });

  test('stats compute remaining and percent', () {
    const s = SubjectStats(12, 8);
    expect(s.remaining, 4);
    expect(s.percent, 67);
  });

  test('toggling a lecture sets then clears completedAt', () {
    final l = Lecture(
      id: 'a',
      subjectId: 's',
      title: 'Lecture 1',
      order: 1,
      createdAt: '2026-11-08T00:00:00.000',
    );
    final done = l.toggled(DateTime(2026, 11, 8, 10));
    expect(done.completed, isTrue);
    expect(done.completedAt, isNotNull);
    final undone = done.toggled(DateTime(2026, 11, 8, 11));
    expect(undone.completed, isFalse);
    expect(undone.completedAt, isNull);
  });

  test('subject survives a JSON round trip', () {
    const s = Subject(
      id: 'x',
      name: 'Geography',
      paper: 'GS1',
      order: 3,
      notes: TrackStatus.inProgress,
      pyq: TrackStatus.done,
      createdAt: '2026-11-08T00:00:00.000',
    );
    final back = Subject.fromJson(s.toJson());
    expect(back.name, 'Geography');
    expect(back.notes, TrackStatus.inProgress);
    expect(back.pyq, TrackStatus.done);
  });
}
