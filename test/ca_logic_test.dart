import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/core/utils/streaks.dart';
import 'package:upsc_command_centre/features/currentaffairs/ca_logic.dart';
import 'package:upsc_command_centre/features/currentaffairs/models/ca_models.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';

int _n = 0;

CaNote _note(
  String date, {
  String title = 'Headline',
  String scope = CaScope.national,
  String topic = CaTopic.polity,
  List<String> exams = const [CaExam.upsc, CaExam.uppcs],
  bool starred = false,
  int revisions = 0,
  String? lastRevisedAt,
  String source = '',
}) =>
    CaNote(
      id: 'n${_n++}',
      date: date,
      title: title,
      scope: scope,
      topic: topic,
      exams: exams,
      starred: starred,
      revisions: revisions,
      lastRevisedAt: lastRevisedAt,
      source: source,
      createdAt: '2026-11-08T10:00:0${_n % 10}',
    );

StudySession _session(String date, String category, int sec) => StudySession(
      id: 's${_n++}',
      date: date,
      startedAt: '${date}T09:00:00',
      durationSec: sec,
      category: category,
      createdAt: '',
    );

void main() {
  final today = DateTime(2026, 11, 8);

  group('revision schedule', () {
    test('first revision is due 7 days after the note date', () {
      final n = _note('2026-11-01');
      expect(nextRevisionDate(n), DateTime(2026, 11, 8));
      expect(isDueForRevision(n, DateTime(2026, 11, 7)), isFalse);
      expect(isDueForRevision(n, DateTime(2026, 11, 8)), isTrue);
      expect(caDaysOverdue(n, DateTime(2026, 11, 8)), 0);
      expect(caDaysOverdue(n, DateTime(2026, 11, 10)), 2);
      expect(caDaysOverdue(n, DateTime(2026, 11, 6)), 0);
    });

    test('later revisions count from the previous revision', () {
      final n = _note('2026-11-01');
      final revised = applyRevision(n, DateTime(2026, 11, 20, 9));
      expect(revised.revisions, 1);
      expect(nextRevisionDate(revised), DateTime(2026, 12, 11));
      // Revising 12 days late does not leave it due again straight away.
      expect(isDueForRevision(revised, DateTime(2026, 11, 21)), isFalse);
    });

    test('three revisions finish the schedule', () {
      var n = _note('2026-01-01');
      n = applyRevision(n, DateTime(2026, 1, 8, 9));
      n = applyRevision(n, DateTime(2026, 1, 29, 9));
      n = applyRevision(n, DateTime(2026, 3, 30, 9));
      expect(n.revisions, 3);
      expect(isFullyRevised(n), isTrue);
      expect(nextRevisionDate(n), isNull);
      expect(isDueForRevision(n, DateTime(2030, 1, 1)), isFalse);
      expect(applyRevision(n, DateTime(2026, 4, 1)).revisions, 3);
    });

    test('resetRevisions clears the schedule', () {
      final n = applyRevision(_note('2026-11-01'), DateTime(2026, 11, 8, 9));
      final r = resetRevisions(n);
      expect(r.revisions, 0);
      expect(r.lastRevisedAt, isNull);
    });

    test('dueNotes puts the most overdue first', () {
      final a = _note('2026-10-01'); // due 10-08
      final b = _note('2026-10-20'); // due 10-27
      final c = _note('2026-11-07'); // not due
      final due = dueNotes([c, b, a], today);
      expect(due.map((n) => n.id), [a.id, b.id]);
    });

    test('upcomingNotes lists revisions due in the next 7 days', () {
      final soon = _note('2026-11-04'); // due 11-11
      final later = _note('2026-11-07'); // due 11-14
      final far = _note('2026-11-09'); // due 11-16: more than 7 days away
      final dueNow = _note('2026-11-01'); // due today: not "upcoming"
      final up = upcomingNotes([far, later, soon, dueNow], today);
      expect(up.map((n) => n.id), [soon.id, later.id]);
    });
  });

  group('filtering and stats', () {
    test('filterNotes by scope, topic, exam, star and text', () {
      final a = _note('2026-11-08',
          title: 'UP budget', scope: CaScope.state, exams: [CaExam.uppcs]);
      final b = _note('2026-11-07',
          title: 'RBI policy', topic: CaTopic.economy, starred: true);
      final c = _note('2026-11-06', title: 'G20 summit', scope: CaScope.international);
      final all = [c, a, b];

      expect(filterNotes(all).map((n) => n.id), [a.id, b.id, c.id]);
      expect(filterNotes(all, scope: CaScope.state).single.id, a.id);
      expect(filterNotes(all, topic: CaTopic.economy).single.id, b.id);
      expect(filterNotes(all, exam: CaExam.upsc).map((n) => n.id), [b.id, c.id]);
      expect(filterNotes(all, starredOnly: true).single.id, b.id);
      expect(filterNotes(all, query: 'g20').single.id, c.id);
      expect(filterNotes(all, query: 'nothing'), isEmpty);
    });

    test('summarizeCa counts the last 7 days, stars and due notes', () {
      final all = [
        _note('2026-11-08'),
        _note('2026-11-02'), // inside 7 days (11-02..11-08)
        _note('2026-11-01', starred: true), // outside, due today
        _note('2026-10-01', revisions: 3),
      ];
      final s = summarizeCa(all, today);
      expect(s.total, 4);
      expect(s.last7Days, 2);
      expect(s.starred, 1);
      expect(s.due, 1);
      expect(s.fullyRevised, 1);
    });

    test('countBy sorts by size then key', () {
      final all = [
        _note('2026-11-08', topic: CaTopic.economy),
        _note('2026-11-08', topic: CaTopic.polity),
        _note('2026-11-08', topic: CaTopic.polity),
        _note('2026-11-08', topic: CaTopic.ethics),
      ];
      final c = countBy(all, (n) => n.topic);
      expect(c.map((k) => k.key), [CaTopic.polity, CaTopic.economy, CaTopic.ethics]);
      expect(c.first.count, 2);
    });

    test('notesPerDay covers every day, oldest first', () {
      final all = [_note('2026-11-08'), _note('2026-11-08'), _note('2026-11-06')];
      final d = notesPerDay(all, today, 4);
      expect(d.map((e) => e.count), [0, 1, 0, 2]);
      expect(d.first.day, DateTime(2026, 11, 5));
      expect(d.last.day, today);
    });

    test('notesPerMonth returns a fixed run of months', () {
      final all = [_note('2026-11-08'), _note('2026-10-03'), _note('2026-10-04')];
      final m = notesPerMonth(all, today, months: 3);
      expect(m.map((e) => e.key), ['2026-09', '2026-10', '2026-11']);
      expect(m.map((e) => e.count), [0, 2, 1]);
    });

    test('notesPerMonth crosses a year boundary', () {
      final m = notesPerMonth([], DateTime(2026, 2, 10), months: 4);
      expect(m.map((e) => e.key), ['2025-11', '2025-12', '2026-01', '2026-02']);
    });
  });

  group('streak and sources', () {
    test('caActiveDays joins notes with current affairs sessions only', () {
      final days = caActiveDays(
        [_note('2026-11-08')],
        [
          _session('2026-11-07', StudyCategory.currentAffairs, 900),
          _session('2026-11-06', StudyCategory.gs, 900),
          _session('2026-11-05', StudyCategory.currentAffairs, 0),
        ],
      );
      expect(days, {'2026-11-08', '2026-11-07'});
      expect(currentStreak(days, today), 2);
    });

    test('currentStreak starts from yesterday when today is empty', () {
      expect(currentStreak({'2026-11-07', '2026-11-06'}, today), 2);
      expect(currentStreak({'2026-11-05'}, today), 0);
      expect(currentStreak(<String>{}, today), 0);
    });

    test('longestStreak finds the best run and ignores bad keys', () {
      final days = {
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
        '2026-10-10',
        '2026-10-11',
        'garbage',
      };
      expect(longestStreak(days), 3);
      expect(longestStreak(<String>{}), 0);
      expect(longestStreak({'2026-10-01'}), 1);
    });

    test('sourceSuggestions puts used sources first without duplicates', () {
      final all = [
        _note('2026-11-08', source: 'Dainik Jagran'),
        _note('2026-11-08', source: 'Dainik Jagran'),
        _note('2026-11-08', source: 'PIB'),
      ];
      final s = sourceSuggestions(all);
      expect(s.first, 'Dainik Jagran');
      expect(s[1], 'PIB');
      expect(s.toSet().length, s.length);
      expect(s, contains('The Hindu'));
    });
  });

  group('models', () {
    test('exam list normalizes unknown input to both exams', () {
      expect(CaExam.normalizeList(null), [CaExam.upsc, CaExam.uppcs]);
      expect(CaExam.normalizeList(['x']), [CaExam.upsc, CaExam.uppcs]);
      expect(CaExam.normalizeList(['uppcs', 'junk']), [CaExam.uppcs]);
      expect(CaExam.normalizeList(['uppcs', 'upsc']), [CaExam.upsc, CaExam.uppcs]);
    });

    test('state news defaults to UPPCS only', () {
      expect(CaExam.defaultsFor(CaScope.state), [CaExam.uppcs]);
      expect(CaExam.defaultsFor(CaScope.national), [CaExam.upsc, CaExam.uppcs]);
    });

    test('a note survives a JSON round trip', () {
      final n = _note(
        '2026-11-08',
        title: 'Title',
        scope: CaScope.state,
        topic: CaTopic.schemes,
        exams: [CaExam.uppcs],
        starred: true,
        revisions: 2,
        lastRevisedAt: '2026-11-08T10:00:00.000',
        source: 'PIB',
      );
      final back = CaNote.fromJson(n.toJson());
      expect(back.toJson(), n.toJson());
    });

    test('unknown scope and topic fall back safely', () {
      final n = CaNote.fromJson({
        'id': 'x',
        'date': '2026-11-08',
        'title': 'T',
        'scope': 'mars',
        'topic': 'gossip',
      });
      expect(n.scope, CaScope.national);
      expect(n.topic, CaTopic.other);
      expect(n.exams, [CaExam.upsc, CaExam.uppcs]);
      expect(n.revisions, 0);
    });
  });
}
