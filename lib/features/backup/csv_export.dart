import '../../core/utils/dates.dart';
import '../../core/utils/exam_papers.dart';
import '../../core/utils/parsing.dart';
import '../answers/models/answer_models.dart';
import '../anthropology/models/anthro_models.dart';
import '../currentaffairs/models/ca_models.dart';
import '../planner/models/planner_models.dart';
import '../pyq/models/pyq_models.dart';
import '../revision/models/revision_models.dart';
import '../syllabus/models/syllabus_models.dart';
import '../tests/models/test_models.dart';
import '../tests/test_logic.dart';
import '../timer/models/session_models.dart';

/// One spreadsheet-ready table.
class CsvTable {
  const CsvTable(this.id, this.title, this.header, this.rows);

  /// Used in the file name, e.g. "sessions".
  final String id;
  final String title;
  final List<String> header;
  final List<List<String>> rows;
}

String csvFileName(String id, DateTime now) =>
    'upsc-$id-${dateKey(now)}.csv';

/// Spreadsheet programs treat a cell starting with = + - @ as a formula. Text
/// typed by the user gets a leading apostrophe so it stays text. (Numbers are
/// written without this.)
String safeText(String s) {
  if (s.isEmpty) return s;
  const risky = ['=', '+', '-', '@', '\t', '\r'];
  return risky.contains(s[0]) ? "'$s" : s;
}

String _quote(String s) {
  final needs = s.contains(',') ||
      s.contains('"') ||
      s.contains('\n') ||
      s.contains('\r') ||
      s.startsWith(' ') ||
      s.endsWith(' ');
  return needs ? '"${s.replaceAll('"', '""')}"' : s;
}

/// CSV text. [bom] adds the UTF-8 byte-order mark so Excel shows Hindi and
/// other non-English text correctly.
String encodeCsv(CsvTable t, {bool bom = true}) {
  final lines = <String>[
    t.header.map(_quote).join(','),
    for (final r in t.rows) r.map(_quote).join(','),
  ];
  return '${bom ? '﻿' : ''}${lines.join('\r\n')}\r\n';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "2026-11-09 07:54" in local time, or "" for missing / invalid input.
String _stamp(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  return '${dateKey(d)} ${_two(d.hour)}:${_two(d.minute)}';
}

String _day(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  return d == null ? '' : dateKey(d);
}

String _yn(bool b) => b ? 'yes' : 'no';

CsvTable sessionsTable(Iterable<StudySession> sessions) {
  final list = sessions.toList()
    ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
  return CsvTable(
    'sessions',
    'Study sessions',
    const [
      'date',
      'started_at',
      'duration_minutes',
      'category',
      'label',
      'note',
      'entry',
    ],
    [
      for (final s in list)
        [
          s.date,
          _stamp(s.startedAt),
          formatNumber(s.durationSec / 60),
          StudyCategory.label(s.category),
          safeText(s.label),
          safeText(s.note),
          s.manual ? 'typed in' : 'timer',
        ],
    ],
  );
}

CsvTable tasksTable(Iterable<PlannerTask> tasks) {
  final list = tasks.toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
  return CsvTable(
    'planner-tasks',
    'Planner tasks',
    const [
      'date',
      'title',
      'category',
      'planned_minutes',
      'done',
      'done_at',
      'times_carried_over',
    ],
    [
      for (final t in list)
        [
          t.date,
          safeText(t.title),
          StudyCategory.label(t.category),
          '${t.plannedMin}',
          _yn(t.done),
          _stamp(t.doneAt),
          '${t.carryCount}',
        ],
    ],
  );
}

CsvTable lecturesTable({
  required Iterable<Subject> subjects,
  required Iterable<Lecture> lectures,
  required Iterable<Chapter> chapters,
  required Iterable<Lecture> anthroLectures,
}) {
  final rows = <List<String>>[];

  List<Lecture> of(Iterable<Lecture> all, String id) =>
      all.where((l) => l.subjectId == id).toList()
        ..sort((a, b) => a.order.compareTo(b.order));

  final subs = subjects.toList()
    ..sort((a, b) {
      final c = a.paper.compareTo(b.paper);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
  for (final s in subs) {
    for (final l in of(lectures, s.id)) {
      rows.add([
        'GS',
        GsPaper.title(s.paper),
        safeText(s.name),
        '${l.order}',
        safeText(l.title),
        _yn(l.completed),
        l.completed ? _day(l.completedAt) : '',
      ]);
    }
  }

  final chs = chapters.toList()
    ..sort((a, b) {
      final c = a.paper.compareTo(b.paper);
      return c != 0 ? c : a.order.compareTo(b.order);
    });
  for (final c in chs) {
    for (final l in of(anthroLectures, c.id)) {
      rows.add([
        'Anthropology',
        AnthroPaper.title(c.paper),
        safeText(c.name),
        '${l.order}',
        safeText(l.title),
        _yn(l.completed),
        l.completed ? _day(l.completedAt) : '',
      ]);
    }
  }

  return CsvTable(
    'lectures',
    'Lectures (GS and Anthropology)',
    const [
      'area',
      'paper',
      'subject_or_chapter',
      'lecture_no',
      'title',
      'completed',
      'completed_on',
    ],
    rows,
  );
}

CsvTable revisionTable(Iterable<RevisionCycle> cycles) {
  final list = cycles.toList()
    ..sort((a, b) {
      final c = a.startDate.compareTo(b.startDate);
      return c != 0 ? c : a.number.compareTo(b.number);
    });
  return CsvTable(
    'revision-cycles',
    'Revision cycles',
    const [
      'target',
      'cycle_no',
      'start_date',
      'length_days',
      'completed_date',
      'items_total',
      'items_done',
    ],
    [
      for (final c in list)
        [
          safeText(c.targetName),
          '${c.number}',
          c.startDate,
          '${c.lengthDays}',
          c.completedDate ?? '',
          '${c.items.length}',
          '${c.items.where((i) => i.done).length}',
        ],
    ],
  );
}

CsvTable testsTable(Iterable<TestRecord> tests) {
  final list = tests.toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });
  return CsvTable(
    'tests',
    'Tests',
    const [
      'date',
      'name',
      'series',
      'category',
      'questions',
      'correct',
      'wrong',
      'max_marks',
      'score',
      'percent',
      'time_minutes',
      'analysis_done',
      'notes',
    ],
    [
      for (final t in list)
        [
          t.date,
          safeText(t.name),
          safeText(t.series),
          TestCategory.label(t.category),
          '${t.totalQuestions}',
          '${t.correct}',
          '${t.wrong}',
          formatNumber(t.maxMarks),
          t.score == null ? '' : formatNumber(t.score!),
          percentOf(t) == null ? '' : formatNumber(percentOf(t)!),
          '${t.timeMin}',
          _yn(t.analysisDone),
          safeText(t.notes),
        ],
    ],
  );
}

CsvTable answersTable(Iterable<AnswerEntry> answers) {
  final list = answers.toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });
  return CsvTable(
    'answers',
    'Answer writing',
    const [
      'date',
      'paper',
      'topic',
      'marks',
      'word_limit',
      'minutes',
      'score',
      'percent',
      'status',
      'question',
      'feedback',
    ],
    [
      for (final a in list)
        [
          a.date,
          ExamPaper.label(a.paper),
          safeText(a.topic),
          '${a.marks}',
          '${a.wordLimit}',
          '${a.minutes}',
          a.score == null ? '' : formatNumber(a.score!),
          (a.score == null || a.marks <= 0)
              ? ''
              : formatNumber(a.score! / a.marks * 100),
          AnswerStatus.label(a.status),
          safeText(a.question),
          safeText(a.feedback),
        ],
    ],
  );
}

CsvTable pyqsTable(Iterable<Pyq> pyqs) {
  final list = pyqs.toList()
    ..sort((a, b) {
      final e = a.exam.compareTo(b.exam);
      if (e != 0) return e;
      final y = b.year.compareTo(a.year);
      return y != 0 ? y : a.order.compareTo(b.order);
    });
  return CsvTable(
    'pyqs',
    'PYQs',
    const [
      'exam',
      'year',
      'paper',
      'topic',
      'marks',
      'status',
      'last_result',
      'attempts',
      'last_attempt',
      'starred',
      'question',
      'note',
    ],
    [
      for (final p in list)
        [
          PyqExam.label(p.exam),
          '${p.year}',
          ExamPaper.label(p.paper),
          safeText(p.topic),
          '${p.marks}',
          PyqStatus.label(p.status),
          p.lastResult ?? '',
          '${p.attempts}',
          _stamp(p.lastAttemptAt),
          _yn(p.starred),
          safeText(p.question),
          safeText(p.note),
        ],
    ],
  );
}

CsvTable notesTable(Iterable<CaNote> notes) {
  final list = notes.toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });
  return CsvTable(
    'current-affairs',
    'Current affairs notes',
    const [
      'date',
      'scope',
      'topic',
      'useful_for',
      'source',
      'headline',
      'key_points',
      'revisions_done',
      'last_revised',
      'starred',
    ],
    [
      for (final n in list)
        [
          n.date,
          CaScope.label(n.scope),
          CaTopic.label(n.topic),
          n.exams.map(CaExam.label).join(' + '),
          safeText(n.source),
          safeText(n.title),
          safeText(n.summary),
          '${n.revisions}',
          _stamp(n.lastRevisedAt),
          _yn(n.starred),
        ],
    ],
  );
}
