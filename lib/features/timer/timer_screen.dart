import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/durations.dart';
import '../../core/widgets/dialogs.dart';
import '../../core/widgets/page_body.dart';
import '../../core/widgets/tick_builder.dart';
import '../../core/widgets/undo_snackbar.dart';
import 'category_ui.dart';
import 'models/session_models.dart';
import 'session_dialogs.dart';
import 'sessions_controller.dart';
import 'timer_controller.dart';
import 'timer_logic.dart';

const Color _warn = Color(0xFFD97706);

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  final TextEditingController _label = TextEditingController();
  String _idleCategory = StudyCategory.gs;
  bool _showAll = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------- timer actions ----------

  Future<void> _start() async {
    final ok = await ref
        .read(timerProvider.notifier)
        .start(category: _idleCategory, label: _label.text);
    if (ok) _label.clear();
  }

  Future<void> _stop() async {
    final ctrl = ref.read(timerProvider.notifier);
    // Freeze the clock first so the dialog never costs (or adds) time.
    await ctrl.pause();
    final t = ref.read(timerProvider);
    if (t == null || !mounted) return;
    final elapsed = t.elapsedSec(_now());

    final result = await showFinishDialog(
      context,
      elapsedSec: elapsed,
      category: t.category,
      label: t.label,
    );
    if (!mounted || result == null) return; // stays paused, nothing lost

    if (result.discard) {
      final sure = await confirmDialog(
        context,
        title: 'Discard this session?',
        message: 'The ${formatHm(elapsed)} you tracked will not be saved.',
        confirmLabel: 'Discard',
      );
      if (!mounted || !sure) return;
      await ctrl.discard();
      return;
    }

    final saved = await ctrl.finish(
      durationSec: result.durationSec,
      category: result.category,
      label: result.label,
      note: result.note,
    );
    if (!mounted || saved == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${formatHm(saved.durationSec)} session')),
    );
  }

  Future<void> _rename(ActiveTimer t) async {
    final v = await promptText(
      context,
      title: 'What are you studying?',
      label: 'Label',
      initial: t.label,
    );
    if (v == null || !mounted) return;
    await ref.read(timerProvider.notifier).updateMeta(label: v);
  }

  // ---------- session actions ----------

  Future<void> _addManual() async {
    final input = await showSessionDialog(context);
    if (input == null || !mounted) return;
    await ref.read(sessionsProvider.notifier).addManual(
          date: input.date,
          minutes: input.durationSec ~/ 60,
          category: input.category,
          label: input.label,
          note: input.note,
        );
  }

  Future<void> _edit(StudySession s) async {
    final input = await showSessionDialog(context, existing: s);
    if (input == null || !mounted) return;
    final old = DateTime.tryParse(s.startedAt) ?? DateTime.now();
    final d = input.date;
    final newStart = DateTime(d.year, d.month, d.day, old.hour, old.minute);
    await ref.read(sessionsProvider.notifier).update(s.copyWith(
          date: dateKey(d),
          startedAt: newStart.toIso8601String(),
          durationSec: input.durationSec,
          category: input.category,
          label: input.label,
          note: input.note,
        ));
  }

  Future<void> _delete(StudySession s) async {
    final ctrl = ref.read(sessionsProvider.notifier);
    await ctrl.remove(s.id);
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: 'Session deleted',
      onUndo: () => ctrl.add(s),
    );
  }

  // ---------- build ----------

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(timerProvider);
    final sessions = ref.watch(sessionsProvider).sessions;
    final today = dateOnly(DateTime.now());
    final days = lastNDays(sessions, today, 7);
    final todaySec = totalSecOnDate(sessions, dateKey(today));
    final weekSec = days.fold<int>(0, (a, d) => a + d.sec);

    return Scaffold(
      appBar: AppBar(title: const Text('Study Timer')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManual,
        icon: const Icon(Icons.add),
        label: const Text('Add session'),
      ),
      body: PageBody(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            _timerCard(timer),
            if (timer != null) _longWarning(timer),
            const SizedBox(height: 12),
            _SummaryCard(todaySec: todaySec, weekSec: weekSec, days: days),
            ..._sessionList(sessions, today),
          ],
        ),
      ),
    );
  }

  Widget _timerCard(ActiveTimer? t) {
    final running = t?.running ?? false;
    final ctrl = ref.read(timerProvider.notifier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TickBuilder(
              active: running,
              builder: (context, nowMs) {
                final sec = t == null ? 0 : t.elapsedSec(nowMs);
                return Text(
                  formatClock(sec),
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: running ? AppColors.teal : null,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              t == null ? 'Ready' : (running ? 'Running' : 'Paused'),
              style: TextStyle(
                color: t != null && !running ? _warn : AppColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            CategoryChips(
              selected: t?.category ?? _idleCategory,
              onChanged: (c) {
                if (t == null) {
                  setState(() => _idleCategory = c);
                } else {
                  ctrl.updateMeta(category: c);
                }
              },
            ),
            const SizedBox(height: 12),
            if (t == null)
              TextField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What are you studying? (optional)',
                ),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(t.label.isEmpty ? 'No label' : t.label),
                trailing: IconButton(
                  tooltip: 'Edit label',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _rename(t),
                ),
              ),
            const SizedBox(height: 16),
            if (t == null)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (running) {
                          ctrl.pause();
                        } else {
                          ctrl.resume();
                        }
                      },
                      icon: Icon(running ? Icons.pause : Icons.play_arrow),
                      label: Text(running ? 'Pause' : 'Resume'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop & save'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _longWarning(ActiveTimer t) {
    return TickBuilder(
      active: t.running,
      builder: (context, nowMs) {
        final sec = t.elapsedSec(nowMs);
        if (sec < kLongTimerSec) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: _warn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This timer has tracked ${formatHm(sec)}. If you '
                      'forgot to stop it, press Stop and enter the time you '
                      'really studied.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sessionList(List<StudySession> sessions, DateTime today) {
    final keys = sessions.map((s) => s.date).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final cutoff = dateKey(addDays(today, -6));
    final visible = _showAll
        ? keys
        : keys.where((k) => k.compareTo(cutoff) >= 0).toList();
    final hidden = keys.length - visible.length;

    final out = <Widget>[];
    for (final k in visible) {
      final day = parseDateKey(k);
      final list = sessionsOnDate(sessions, k);
      final total = list.fold<int>(0, (a, s) => a + s.durationSec);
      final ago = daysBetween(day, today);
      final title = ago == 0
          ? 'Today'
          : ago == 1
              ? 'Yesterday'
              : DateFormat('EEE, d MMM yyyy').format(day);
      out.add(Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatHm(total),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ));
      for (final s in list) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _SessionTile(
            session: s,
            onEdit: () => _edit(s),
            onDelete: () => _delete(s),
          ),
        ));
      }
    }

    if (keys.isEmpty) {
      out.add(const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text(
          'No sessions yet. Start the timer, or tap "Add session" to log '
          'time by hand.',
          style: TextStyle(color: AppColors.muted),
        ),
      ));
    } else if (hidden > 0) {
      out.add(Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => _showAll = true),
          child: Text('Show $hidden older day${hidden == 1 ? '' : 's'}'),
        ),
      ));
    }
    return out;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.todaySec,
    required this.weekSec,
    required this.days,
  });

  final int todaySec;
  final int weekSec;
  final List<DayTotal> days;

  Widget _stat(String label, String value) => Expanded(
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final maxSec = days.fold<int>(0, (a, d) => math.max(a, d.sec));
    final todayKey = dateKey(dateOnly(DateTime.now()));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _stat('Today', formatHm(todaySec)),
                _stat('Last 7 days', formatHm(weekSec)),
                _stat('Daily average', formatHm(weekSec ~/ 7)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            d.sec == 0 ? '' : formatHm(d.sec),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: maxSec == 0
                                ? 3.0
                                : math.max(3.0, 52.0 * d.sec / maxSec),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: dateKey(d.day) == todayKey
                                  ? AppColors.teal
                                  : AppColors.violet,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('E').format(d.day),
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.onEdit,
    required this.onDelete,
  });

  final StudySession session;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final color = categoryColor(s.category);
    final parts = <String>[
      if (s.label.isNotEmpty) StudyCategory.label(s.category),
      if (s.manual) 'added by hand',
      if (s.note.isNotEmpty) s.note,
    ];
    return Card(
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.18),
          child: Icon(categoryIcon(s.category), color: color, size: 20),
        ),
        title: Text(s.label.isEmpty ? StudyCategory.label(s.category) : s.label),
        subtitle: parts.isEmpty
            ? null
            : Text(
                parts.join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatHm(s.durationSec),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
