import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/platform/platform_services.dart';
import '../../core/storage/backup_meta.dart';
import '../../core/storage/backup_service.dart';
import '../../core/storage/db.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/install_guide.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/section_card.dart';
import '../../core/widgets/theme_mode_button.dart';
import '../answers/answer_controller.dart';
import '../anthropology/anthro_controller.dart';
import '../currentaffairs/ca_controller.dart';
import '../dashboard/dashboard_logic.dart';
import '../planner/planner_controller.dart';
import '../pyq/pyq_controller.dart';
import '../revision/revision_controller.dart';
import '../syllabus/syllabus_controller.dart';
import '../tests/test_controller.dart';
import '../timer/sessions_controller.dart';
import 'backup_summary.dart';
import 'csv_export.dart';
import 'reload_all.dart';

/// One downloadable spreadsheet. The table is only built when needed.
class _CsvSource {
  const _CsvSource(this.title, this.count, this.build);
  final String title;
  final int count;
  final CsvTable Function() build;
}

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;
  bool? _persisted;
  bool _installed = false;
  ({String raw, DateTime? savedAt})? _snapshot;

  /// Record counts as of the latest build (used by the restore preview).
  Map<String, int> _counts = const {};

  @override
  void initState() {
    super.initState();
    _snapshot = BackupService().safetySnapshot();
    _installed = isInstalledApp();
    unawaited(_refreshPersisted());
  }

  Future<void> _refreshPersisted() async {
    final p = await isStoragePersistent();
    if (mounted) setState(() => _persisted = p);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _info(String title, String message) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------- backup ----------

  Future<void> _export({required bool download}) async {
    final json = BackupService().export();
    final now = DateTime.now();
    if (download && platformSupportsFiles) {
      final ok = await downloadTextFile(
        filename: backupFileName(now),
        content: json,
      );
      if (!mounted) return;
      if (ok) {
        await BackupMeta.markBackedUp(now);
        if (!mounted) return;
        setState(() {});
        _toast('Backup downloaded. Keep the file somewhere safe, such as '
            'Drive, or email it to yourself.');
        return;
      }
    }
    await Clipboard.setData(ClipboardData(text: json));
    await BackupMeta.markBackedUp(now);
    if (!mounted) return;
    setState(() {});
    _toast('Backup text copied. Paste it into a note or file and keep it '
        'somewhere safe.');
  }

  // ---------- restore ----------

  Future<void> _pickAndRestore() async {
    final raw = await pickTextFile();
    if (!mounted || raw == null) return;
    await _restoreFrom(raw);
  }

  Future<void> _pasteAndRestore() async {
    final raw = await showDialog<String>(
      context: context,
      builder: (_) => const _PasteDialog(),
    );
    if (!mounted || raw == null || raw.trim().isEmpty) return;
    await _restoreFrom(raw);
  }

  Future<void> _restoreFrom(String raw, {bool isUndo = false}) async {
    final svc = BackupService();
    final v = svc.validate(raw);
    if (!v.ok) {
      await _info(
        'Cannot restore',
        '${v.error ?? 'This is not a valid backup.'}\n\n'
            'Your data has not been changed.',
      );
      return;
    }
    final incoming = summarizeBackup(v.data!);
    final current = BackupSummary(counts: _counts);

    final go = await _confirmRestore(incoming, current, isUndo: isUndo);
    if (!go || !mounted) return;

    setState(() => _busy = true);
    final err = await svc.restore(raw);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      await _info(
        'Restore failed',
        '$err\n\nIf anything looks wrong, use "Undo last restore" on this '
            'screen.',
      );
      return;
    }
    reloadAllProviders(ref);
    if (!isUndo) {
      // The data on this device now equals that file, so it counts as backed
      // up as of when the file was made.
      await BackupMeta.markBackedUp(incoming.exportedAt ?? DateTime.now());
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _snapshot = svc.safetySnapshot();
    });
    _toast(isUndo
        ? 'Went back to the data from before the last restore.'
        : 'Restored ${incoming.total} records. Your previous data was kept '
            'in case you need to undo.');
  }

  Future<bool> _confirmRestore(
    BackupSummary incoming,
    BackupSummary current, {
    required bool isUndo,
  }) async {
    final when = incoming.exportedAt == null
        ? 'unknown date'
        : DateFormat('d MMM y, h:mm a').format(incoming.exportedAt!);
    final fewer = incoming.total < current.total;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isUndo ? 'Undo the last restore?' : 'Restore this backup?'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Made: $when'),
                const SizedBox(height: 10),
                if (incoming.rows.isEmpty)
                  const Text(
                    'This backup contains no records.',
                    style: TextStyle(color: kWarn),
                  )
                else
                  for (final (label, n) in incoming.rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text(label)),
                          Text(
                            '$n',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 14),
                Text(
                  'This replaces everything on this device now '
                  '(${current.total} records).',
                ),
                if (fewer) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'This file has fewer records than you have now, so you '
                    'may lose recent work.',
                    style: TextStyle(color: kWarn),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Your current data is kept for undo.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isUndo ? 'Undo restore' : 'Replace my data'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ---------- browser features ----------

  Future<void> _protect() async {
    await requestPersistentStorage();
    await _refreshPersisted();
    if (!mounted) return;
    _toast(_persisted == true
        ? 'Storage is now protected.'
        : 'The browser did not grant protection. Installing the app or '
            'bookmarking the site usually helps.');
  }

  Future<void> _install() async {
    await installOrGuide(context);
    if (!mounted) return;
    setState(() => _installed = isInstalledApp());
  }

  // ---------- CSV ----------

  Future<void> _exportCsv(_CsvSource s, {bool quiet = false}) async {
    final table = s.build();
    final now = DateTime.now();
    if (platformSupportsFiles) {
      final ok = await downloadTextFile(
        filename: csvFileName(table.id, now),
        content: encodeCsv(table),
        mime: 'text/csv',
      );
      if (!mounted) return;
      if (ok) {
        if (!quiet) _toast('${table.title}: ${table.rows.length} rows saved.');
        return;
      }
    }
    await Clipboard.setData(ClipboardData(text: encodeCsv(table, bom: false)));
    if (!mounted) return;
    if (!quiet) _toast('${table.title} copied as CSV text.');
  }

  Future<void> _exportAllCsv(List<_CsvSource> sources) async {
    var n = 0;
    for (final s in sources) {
      if (s.count == 0) continue;
      await _exportCsv(s, quiet: true);
      n++;
      if (!mounted) return;
      // Browsers can merge downloads that start in the same instant.
      await Future<void>.delayed(const Duration(milliseconds: 450));
    }
    if (!mounted) return;
    _toast(n == 0 ? 'Nothing to export yet.' : 'Saved $n spreadsheets.');
  }

  // ---------- build ----------

  Map<String, int> _liveCounts() {
    final gs = ref.watch(syllabusProvider);
    final an = ref.watch(anthroProvider);
    return {
      Collections.subjects: gs.subjects.length,
      Collections.lectures: gs.lectures.length,
      Collections.anthroChapters: an.chapters.length,
      Collections.anthroLectures: an.lectures.length,
      Collections.revisionCycles: ref.watch(revisionProvider).cycles.length,
      Collections.tasks: ref.watch(plannerProvider).tasks.length,
      Collections.sessions: ref.watch(sessionsProvider).sessions.length,
      Collections.answers: ref.watch(answerProvider).answers.length,
      Collections.pyqs: ref.watch(pyqProvider).pyqs.length,
      Collections.tests: ref.watch(testProvider).tests.length,
      Collections.notes: ref.watch(caProvider).notes.length,
    };
  }

  List<_CsvSource> _csvSources() {
    final gs = ref.watch(syllabusProvider);
    final an = ref.watch(anthroProvider);
    final sessions = ref.watch(sessionsProvider).sessions;
    final tasks = ref.watch(plannerProvider).tasks;
    final cycles = ref.watch(revisionProvider).cycles;
    final tests = ref.watch(testProvider).tests;
    final answers = ref.watch(answerProvider).answers;
    final pyqs = ref.watch(pyqProvider).pyqs;
    final notes = ref.watch(caProvider).notes;
    return [
      _CsvSource('Study sessions', sessions.length,
          () => sessionsTable(sessions)),
      _CsvSource('Planner tasks', tasks.length, () => tasksTable(tasks)),
      _CsvSource(
        'Lectures (GS and Anthropology)',
        gs.lectures.length + an.lectures.length,
        () => lecturesTable(
          subjects: gs.subjects,
          lectures: gs.lectures,
          chapters: an.chapters,
          anthroLectures: an.lectures,
        ),
      ),
      _CsvSource(
          'Revision cycles', cycles.length, () => revisionTable(cycles)),
      _CsvSource('Tests', tests.length, () => testsTable(tests)),
      _CsvSource('Answer writing', answers.length,
          () => answersTable(answers)),
      _CsvSource('PYQs', pyqs.length, () => pyqsTable(pyqs)),
      _CsvSource('Current affairs notes', notes.length,
          () => notesTable(notes)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _counts = _liveCounts();
    final sources = _csvSources();
    final today = dateOnly(DateTime.now());
    final live = BackupSummary(counts: _counts);

    // The seeded GS subjects alone are not "data worth backing up".
    final userRecords = live.total -
        (_counts[Collections.subjects] ?? 0) -
        (_counts[Collections.anthroChapters] ?? 0);
    final last = BackupMeta.lastBackupAt();
    final age = backupAgeDays(last, today);
    final stale = backupReminderDue(age, hasData: userRecords > 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Settings'),
        actions: const [ThemeModeButton()],
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            _backupCard(live, last, age, stale),
            const SizedBox(height: 12),
            _restoreCard(),
            if (_snapshot != null) ...[
              const SizedBox(height: 12),
              _undoCard(),
            ],
            const SizedBox(height: 12),
            _storageCard(),
            const SizedBox(height: 12),
            SectionCard(
              title: 'Appearance',
              child: const Align(
                alignment: Alignment.centerLeft,
                child: ThemeModeSelector(),
              ),
            ),
            const SizedBox(height: 12),
            _csvCard(sources),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Backup format version ${BackupService.schemaVersion}. Files '
                'from older versions of this app still restore; files from a '
                'newer version are refused so nothing is damaged.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backupCard(
    BackupSummary live,
    DateTime? last,
    int? age,
    bool stale,
  ) {
    return SectionCard(
      title: 'Backup',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            last == null
                ? 'No backup made yet.'
                : 'Last backup: ${DateFormat('d MMM y, h:mm a').format(last)}'
                    ' (${ageText(age ?? 0)})',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: stale ? kWarn : null,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your data lives only in this browser. Clearing site data or '
            'uninstalling the app erases it. A backup file is the only copy '
            'you control.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (live.rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                for (final (label, n) in live.rows)
                  Text(
                    '$label: $n',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (platformSupportsFiles)
                FilledButton.icon(
                  onPressed: _busy ? null : () => _export(download: true),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Download backup'),
                ),
              if (platformSupportsFiles)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _export(download: false),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy as text'),
                )
              else
                FilledButton.icon(
                  onPressed: _busy ? null : () => _export(download: false),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy backup text'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _restoreCard() {
    return SectionCard(
      title: 'Restore',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Load a backup file. You will see what is inside before anything '
            'is replaced, and your current data is kept so you can undo.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (platformSupportsFiles)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _pickAndRestore,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Choose backup file'),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pasteAndRestore,
                icon: const Icon(Icons.content_paste_outlined),
                label: const Text('Paste backup text'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _undoCard() {
    final snap = _snapshot!;
    final when = snap.savedAt == null
        ? 'before the last restore'
        : DateFormat('d MMM y, h:mm a').format(snap.savedAt!);
    return SectionCard(
      title: 'Undo last restore',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your data from $when was kept when you last restored.',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                _busy ? null : () => _restoreFrom(snap.raw, isUndo: true),
            icon: const Icon(Icons.undo),
            label: const Text('Go back to that data'),
          ),
        ],
      ),
    );
  }

  Widget _storageCard() {
    if (!platformSupportsFiles) return const SizedBox.shrink();
    final p = _persisted;
    final String status;
    final Color? color;
    if (p == true) {
      status = 'Protected: the browser has promised not to clear this app\'s '
          'data automatically.';
      color = AppColors.teal;
    } else if (p == false) {
      status = 'Not protected: the browser may clear this app\'s data when '
          'space runs low.';
      color = kWarn;
    } else {
      status = 'Storage protection is not available in this browser.';
      color = null;
    }

    return SectionCard(
      title: 'This browser',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 6),
          const Text(
            'Even when protected, clearing site data by hand still erases '
            'everything, so keep backups.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (p == false)
                OutlinedButton.icon(
                  onPressed: _protect,
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Request protection'),
                ),
              if (!_installed && canShowInstallHelp())
                FilledButton.tonalIcon(
                  onPressed: _install,
                  icon: const Icon(Icons.install_mobile_outlined),
                  label: const Text('Install app'),
                ),
            ],
          ),
          if (_installed)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Running as an installed app.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            )
          else if (!canInstallApp())
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'To install: in Chrome open the menu and choose "Install app"; '
                'on iPhone use Share, then "Add to Home Screen".',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _csvCard(List<_CsvSource> sources) {
    return SectionCard(
      title: 'Export to spreadsheet (CSV)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Opens in Excel or Google Sheets. For reading and analysis only: '
            'use a backup file to restore.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          for (final s in sources)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(s.title),
              subtitle: Text(
                '${s.count} row${s.count == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                tooltip: platformSupportsFiles ? 'Download CSV' : 'Copy CSV',
                icon: Icon(platformSupportsFiles
                    ? Icons.download_outlined
                    : Icons.copy_outlined),
                onPressed: s.count == 0 ? null : () => _exportCsv(s),
              ),
            ),
          if (platformSupportsFiles) ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              onPressed: () => _exportAllCsv(sources),
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Download all'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text != null) setState(() => _c.text = text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste backup text'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              minLines: 6,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Paste the whole backup here',
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_go_outlined),
              label: const Text('Paste from clipboard'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}
