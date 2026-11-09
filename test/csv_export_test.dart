import 'package:flutter_test/flutter_test.dart';
import 'package:upsc_command_centre/features/answers/models/answer_models.dart';
import 'package:upsc_command_centre/features/anthropology/models/anthro_models.dart';
import 'package:upsc_command_centre/features/backup/csv_export.dart';
import 'package:upsc_command_centre/features/currentaffairs/models/ca_models.dart';
import 'package:upsc_command_centre/features/planner/models/planner_models.dart';
import 'package:upsc_command_centre/features/pyq/models/pyq_models.dart';
import 'package:upsc_command_centre/features/revision/models/revision_models.dart';
import 'package:upsc_command_centre/features/syllabus/models/syllabus_models.dart';
import 'package:upsc_command_centre/features/tests/models/test_models.dart';
import 'package:upsc_command_centre/features/timer/models/session_models.dart';

void main() {
  group('encoding', () {
    test('quotes commas, quotes, new lines and edge spaces', () {
      const t = CsvTable('x', 'X', [
        'a',
        'b'
      ], [
        ['x,y', 'say "hi"'],
        ['line\nbreak', ' pad'],
        ['plain', 'text'],
      ]);
      expect(
        encodeCsv(t, bom: false),
        'a,b\r\n"x,y","say ""hi"""\r\n"line\nbreak"," pad"\r\nplain,text\r\n',
      );
    });

    test('adds a byte-order mark by default so Excel reads Hindi', () {
      const t = CsvTable('x', 'X', ['h'], [
        ['ठीक है'],
      ]);
      final s = encodeCsv(t);
      expect(s.startsWith('﻿'), isTrue);
      expect(s.contains('ठीक है'), isTrue);
    });

    test('an empty table is just the header', () {
      const t = CsvTable('x', 'X', ['a', 'b'], []);
      expect(encodeCsv(t, bom: false), 'a,b\r\n');
    });

    test('safeText stops spreadsheet formulas', () {
      expect(safeText('=SUM(A1)'), "'=SUM(A1)");
      expect(safeText('+91 98765'), "'+91 98765");
      expect(safeText('-5% growth'), "'-5% growth");
      expect(safeText('@home'), "'@home");
      expect(safeText('Normal'), 'Normal');
      expect(safeText(''), '');
      expect(safeText('ठीक है'), 'ठीक है');
    });

    test('csvFileName', () {
      expect(csvFileName('tests', DateTime(2026, 11, 9)),
          'upsc-tests-2026-11-09.csv');
    });
  });

  group('tables', () {
    test('sessions', () {
      final t = sessionsTable([
        StudySession(
          id: 'b',
          date: '2026-11-08',
          startedAt: DateTime(2026, 11, 8, 14).toIso8601String(),
          durationSec: 600,
          category: StudyCategory.anthro,
          label: '=evil',
          manual: true,
          createdAt: '',
        ),
        StudySession(
          id: 'a',
          date: '2026-11-08',
          startedAt: DateTime(2026, 11, 8, 9, 5).toIso8601String(),
          durationSec: 5400,
          category: StudyCategory.gs,
          createdAt: '',
        ),
      ]);
      expect(t.rows.length, 2);
      // Oldest start first.
      expect(t.rows[0][1], '2026-11-08 09:05');
      expect(t.rows[0][2], '90');
      expect(t.rows[0][3], StudyCategory.label(StudyCategory.gs));
      expect(t.rows[0][6], 'timer');
      expect(t.rows[1][2], '10');
      expect(t.rows[1][4], "'=evil");
      expect(t.rows[1][6], 'typed in');
    });

    test('tests: score and percent', () {
      final t = testsTable([
        TestRecord(
          id: '1',
          name: 'Mock 1',
          category: TestCategory.prelimsGs,
          date: '2026-11-01',
          maxMarks: 200,
          score: 120,
          createdAt: '',
        ),
        TestRecord(
          id: '2',
          name: 'Mock 2',
          category: TestCategory.prelimsGs,
          date: '2026-11-05',
          maxMarks: 200,
          createdAt: '',
        ),
      ]);
      expect(t.header[8], 'score');
      expect(t.header[9], 'percent');
      expect(t.rows[0][8], '120');
      expect(t.rows[0][9], '60');
      expect(t.rows[1][8], '');
      expect(t.rows[1][9], '');
    });

    test('answers: percent only when scored', () {
      final t = answersTable([
        const AnswerEntry(
          id: '1',
          date: '2026-11-01',
          paper: 'gs1',
          question: 'Q1',
          marks: 10,
          score: 6,
          createdAt: '',
        ),
        const AnswerEntry(
          id: '2',
          date: '2026-11-02',
          paper: 'gs1',
          question: 'Q2',
          createdAt: '',
        ),
      ]);
      expect(t.header[7], 'percent');
      expect(t.rows[0][6], '6');
      expect(t.rows[0][7], '60');
      expect(t.rows[1][6], '');
      expect(t.rows[1][7], '');
    });

    test('lectures: GS first, then Anthropology, only existing parents', () {
      final done = DateTime(2026, 11, 3, 10).toIso8601String();
      final t = lecturesTable(
        subjects: [
          Subject(id: 's', name: 'Polity', paper: 'GS2', order: 1, createdAt: ''),
        ],
        lectures: [
          Lecture(
            id: 'l1',
            subjectId: 's',
            title: 'Preamble',
            order: 1,
            completed: true,
            completedAt: done,
            createdAt: '',
          ),
          Lecture(
            id: 'orphan',
            subjectId: 'gone',
            title: 'Deleted subject',
            order: 1,
            createdAt: '',
          ),
        ],
        chapters: [
          const Chapter(
            id: 'c',
            paper: 'paper1',
            name: 'Evolution',
            order: 1,
            createdAt: '',
          ),
        ],
        anthroLectures: [
          Lecture(
            id: 'al',
            subjectId: 'c',
            title: 'Intro',
            order: 1,
            createdAt: '',
          ),
        ],
      );
      expect(t.rows.length, 2);
      expect(t.rows[0][0], 'GS');
      expect(t.rows[0][2], 'Polity');
      expect(t.rows[0][5], 'yes');
      expect(t.rows[0][6], '2026-11-03');
      expect(t.rows[1][0], 'Anthropology');
      expect(t.rows[1][2], 'Evolution');
      expect(t.rows[1][5], 'no');
      expect(t.rows[1][6], '');
    });

    test('current affairs notes', () {
      final t = notesTable([
        const CaNote(
          id: 'n',
          date: '2026-11-08',
          title: 'UP budget',
          scope: CaScope.state,
          topic: CaTopic.economy,
          exams: [CaExam.uppcs],
          createdAt: '',
        ),
      ]);
      expect(t.rows.single[1], CaScope.label(CaScope.state));
      expect(t.rows.single[3], 'UPPCS');
      expect(t.rows.single[5], 'UP budget');
    });

    test('every row has as many cells as the header', () {
      final tables = <CsvTable>[
        sessionsTable([
          StudySession(
            id: '1',
            date: '2026-11-08',
            startedAt: '2026-11-08T09:00:00',
            durationSec: 60,
            category: StudyCategory.gs,
            createdAt: '',
          ),
        ]),
        tasksTable([
          const PlannerTask(
            id: 't',
            date: '2026-11-08',
            title: 'Task',
            category: StudyCategory.gs,
            order: 1,
            createdAt: '',
          ),
        ]),
        revisionTable([
          const RevisionCycle(
            id: 'c',
            targetType: RevisionTargetType.gs,
            targetId: 's',
            targetName: 'Polity',
            number: 1,
            startDate: '2026-11-01',
            lengthDays: 7,
            createdAt: '',
          ),
        ]),
        pyqsTable([
          const Pyq(
            id: 'p',
            exam: PyqExam.prelims,
            year: 2024,
            paper: 'gs1',
            question: 'Q',
            order: 1,
            createdAt: '',
          ),
        ]),
        testsTable([
          const TestRecord(
            id: 'x',
            name: 'T',
            category: TestCategory.prelimsGs,
            date: '2026-11-01',
            maxMarks: 100,
            createdAt: '',
          ),
        ]),
      ];
      for (final t in tables) {
        expect(t.rows, isNotEmpty, reason: t.id);
        for (final r in t.rows) {
          expect(r.length, t.header.length, reason: t.id);
        }
      }
    });
  });
}
