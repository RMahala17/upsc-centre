import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/durations.dart';
import 'category_ui.dart';
import 'models/session_models.dart';
import 'timer_logic.dart';

// ---------------------------------------------------------------------------
// Add / edit a session by hand
// ---------------------------------------------------------------------------

class SessionInput {
  const SessionInput({
    required this.date,
    required this.durationSec,
    required this.category,
    required this.label,
    required this.note,
  });

  final DateTime date;
  final int durationSec;
  final String category;
  final String label;
  final String note;
}

Future<SessionInput?> showSessionDialog(
  BuildContext context, {
  StudySession? existing,
  DateTime? date,
}) {
  return showDialog<SessionInput>(
    context: context,
    builder: (_) => _SessionDialog(existing: existing, date: date),
  );
}

class _SessionDialog extends StatefulWidget {
  const _SessionDialog({this.existing, this.date});
  final StudySession? existing;
  final DateTime? date;

  @override
  State<_SessionDialog> createState() => _SessionDialogState();
}

class _SessionDialogState extends State<_SessionDialog> {
  late DateTime _date = dateOnly(
    widget.existing != null
        ? parseDateKey(widget.existing!.date)
        : (widget.date ?? DateTime.now()),
  );
  late String _category = widget.existing?.category ?? StudyCategory.gs;
  late final String _initialMinutes = widget.existing == null
      ? ''
      : '${math.max(1, (widget.existing!.durationSec / 60).round())}';
  late final TextEditingController _minutes =
      TextEditingController(text: _initialMinutes);
  late final TextEditingController _label =
      TextEditingController(text: widget.existing?.label ?? '');
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final last = dateOnly(DateTime.now());
    final initial = _date.isAfter(last) ? last : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: last,
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  void _submit() {
    final text = _minutes.text.trim();
    final mins = int.tryParse(text);
    if (mins == null || mins < 1 || mins > kMaxSessionMinutes) {
      setState(() => _error = 'Enter 1–$kMaxSessionMinutes minutes.');
      return;
    }
    // Untouched minutes keep the exact recorded seconds.
    final unchanged = widget.existing != null && text == _initialMinutes;
    Navigator.pop(
      context,
      SessionInput(
        date: _date,
        durationSec: unchanged ? widget.existing!.durationSec : mins * 60,
        category: _category,
        label: _label.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit session' : 'Add session'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minutes,
                autofocus: !isEdit,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Minutes studied',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              CategoryChips(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What did you study? (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stop the stopwatch: save (with a chance to correct the time) or discard
// ---------------------------------------------------------------------------

class FinishResult {
  const FinishResult.save({
    required this.durationSec,
    required this.category,
    required this.label,
    required this.note,
  }) : discard = false;

  const FinishResult.discard()
      : discard = true,
        durationSec = 0,
        category = StudyCategory.other,
        label = '',
        note = '';

  final bool discard;
  final int durationSec;
  final String category;
  final String label;
  final String note;
}

/// Returns null if cancelled (the timer then stays paused, nothing lost).
Future<FinishResult?> showFinishDialog(
  BuildContext context, {
  required int elapsedSec,
  required String category,
  required String label,
}) {
  return showDialog<FinishResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FinishDialog(
      elapsedSec: elapsedSec,
      category: category,
      label: label,
    ),
  );
}

class _FinishDialog extends StatefulWidget {
  const _FinishDialog({
    required this.elapsedSec,
    required this.category,
    required this.label,
  });

  final int elapsedSec;
  final String category;
  final String label;

  @override
  State<_FinishDialog> createState() => _FinishDialogState();
}

class _FinishDialogState extends State<_FinishDialog> {
  late String _category = widget.category;
  late final int _prefill = math.max(1, (widget.elapsedSec / 60).round());
  late final TextEditingController _minutes =
      TextEditingController(text: '$_prefill');
  late final TextEditingController _label =
      TextEditingController(text: widget.label);
  final TextEditingController _note = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _minutes.dispose();
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final mins = int.tryParse(_minutes.text.trim());
    if (mins == null || mins < 1 || mins > kMaxSessionMinutes) {
      setState(() => _error =
          'Enter 1–$kMaxSessionMinutes minutes. If you forgot to stop the '
          'timer, type the time you really studied.');
      return;
    }
    // Untouched minutes keep the exact tracked seconds.
    final seconds = mins == _prefill && widget.elapsedSec > 0
        ? widget.elapsedSec
        : mins * 60;
    Navigator.pop(
      context,
      FinishResult.save(
        durationSec: seconds,
        category: _category,
        label: _label.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save this session?'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tracked: ${formatClock(widget.elapsedSec)}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Minutes to save',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 12),
              CategoryChips(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What did you study? (optional)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, const FinishResult.discard()),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('Discard'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
