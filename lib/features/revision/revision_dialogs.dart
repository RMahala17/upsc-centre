import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import 'revision_logic.dart';
import 'revision_targets.dart';

String _d(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);

Future<DateTime?> _pickDate(BuildContext context, DateTime initial) {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2035),
  );
}

// ---------------- New cycle ----------------

class NewCycleInput {
  final RevisionTarget target;
  final DateTime start;
  final int length;
  final List<String> topics;
  const NewCycleInput(this.target, this.start, this.length, this.topics);
}

Future<NewCycleInput?> showNewCycleDialog(
  BuildContext context, {
  required List<RevisionTarget> targets,
  RevisionTarget? initial,
}) {
  return showDialog<NewCycleInput>(
    context: context,
    builder: (_) => _NewCycleDialog(targets: targets, initial: initial),
  );
}

class _NewCycleDialog extends StatefulWidget {
  final List<RevisionTarget> targets;
  final RevisionTarget? initial;
  const _NewCycleDialog({required this.targets, this.initial});

  @override
  State<_NewCycleDialog> createState() => _NewCycleDialogState();
}

class _NewCycleDialogState extends State<_NewCycleDialog> {
  late RevisionTarget _target = widget.initial ?? widget.targets.first;
  DateTime _start = dateOnly(DateTime.now());
  final TextEditingController _length =
      TextEditingController(text: '$kDefaultCycleDays');
  bool _onlyCompleted = true;
  String? _error;

  @override
  void dispose() {
    _length.dispose();
    super.dispose();
  }

  List<String> get _topics =>
      _onlyCompleted ? _target.completedTopics : _target.allTopics;

  void _submit() {
    final n = int.tryParse(_length.text.trim());
    if (n == null || n < kMinCycleDays || n > kMaxCycleDays) {
      setState(() =>
          _error = 'Cycle length must be $kMinCycleDays–$kMaxCycleDays days.');
      return;
    }
    Navigator.pop(context, NewCycleInput(_target, _start, n, _topics));
  }

  @override
  Widget build(BuildContext context) {
    final topics = _topics;
    final noteHint = _onlyCompleted &&
        topics.isEmpty &&
        _target.allTopics.isNotEmpty;

    return AlertDialog(
      title: const Text('New revision cycle'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Subject'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _target.key,
                  isExpanded: true,
                  items: [
                    for (final t in widget.targets)
                      DropdownMenuItem(
                        value: t.key,
                        child: Text(t.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (k) {
                    if (k == null) return;
                    setState(() {
                      _target = widget.targets.firstWhere((t) => t.key == k);
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(_d(_start)),
              trailing: const Icon(Icons.calendar_today_outlined, size: 20),
              onTap: () async {
                final picked = await _pickDate(context, _start);
                if (picked != null && mounted) {
                  setState(() => _start = dateOnly(picked));
                }
              },
            ),
            TextField(
              controller: _length,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Cycle length in days ($kMinCycleDays–$kMaxCycleDays)',
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Only completed lectures / chapters'),
              value: _onlyCompleted,
              onChanged: (v) => setState(() => _onlyCompleted = v),
            ),
            Text(
              '${topics.length} topic${topics.length == 1 ? '' : 's'} will be '
              'added to the checklist. PYQ and self-test items are added '
              'automatically; you can edit everything afterwards.',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            if (noteHint)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Nothing is completed yet here. Turn the switch off to '
                  'include everything.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

// ---------------- Edit schedule ----------------

Future<(DateTime, int)?> showScheduleDialog(
  BuildContext context, {
  required DateTime start,
  required int length,
}) {
  return showDialog<(DateTime, int)>(
    context: context,
    builder: (_) => _ScheduleDialog(start: start, length: length),
  );
}

class _ScheduleDialog extends StatefulWidget {
  final DateTime start;
  final int length;
  const _ScheduleDialog({required this.start, required this.length});

  @override
  State<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends State<_ScheduleDialog> {
  late DateTime _start = widget.start;
  late final TextEditingController _length =
      TextEditingController(text: '${widget.length}');
  String? _error;

  @override
  void dispose() {
    _length.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_length.text.trim());
    if (n == null || n < kMinCycleDays || n > kMaxCycleDays) {
      setState(() =>
          _error = 'Cycle length must be $kMinCycleDays–$kMaxCycleDays days.');
      return;
    }
    Navigator.pop(context, (_start, n));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit schedule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start date'),
            subtitle: Text(_d(_start)),
            trailing: const Icon(Icons.calendar_today_outlined, size: 20),
            onTap: () async {
              final picked = await _pickDate(context, _start);
              if (picked != null && mounted) {
                setState(() => _start = dateOnly(picked));
              }
            },
          ),
          TextField(
            controller: _length,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Cycle length in days'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Changing the length moves the PYQ and self-test items to the '
            'last two days.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

// ---------------- Add / edit item ----------------

Future<(String, int)?> showItemDialog(
  BuildContext context, {
  required int length,
  String initialTitle = '',
  int initialDay = 1,
  required String dialogTitle,
}) {
  return showDialog<(String, int)>(
    context: context,
    builder: (_) => _ItemDialog(
      length: length,
      initialTitle: initialTitle,
      initialDay: initialDay.clamp(1, length),
      dialogTitle: dialogTitle,
    ),
  );
}

class _ItemDialog extends StatefulWidget {
  final int length;
  final String initialTitle;
  final int initialDay;
  final String dialogTitle;
  const _ItemDialog({
    required this.length,
    required this.initialTitle,
    required this.initialDay,
    required this.dialogTitle,
  });

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final TextEditingController _title =
      TextEditingController(text: widget.initialTitle);
  late int _day = widget.initialDay;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _title.text.trim();
    if (t.isEmpty) return;
    Navigator.pop(context, (t, _day));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.dialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Topic / chapter'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          _DayPicker(
            length: widget.length,
            day: _day,
            onChanged: (d) => setState(() => _day = d),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _DayPicker extends StatelessWidget {
  final int length;
  final int day;
  final ValueChanged<int> onChanged;
  const _DayPicker({
    required this.length,
    required this.day,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Plan day'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: day,
          isExpanded: true,
          items: [
            for (var i = 1; i <= length; i++)
              DropdownMenuItem(value: i, child: Text('Day $i')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ---------------- Paste items ----------------

Future<(List<String>, int)?> showPasteItemsDialog(
  BuildContext context, {
  required int length,
  required int initialDay,
}) {
  return showDialog<(List<String>, int)>(
    context: context,
    builder: (_) => _PasteItemsDialog(
      length: length,
      initialDay: initialDay.clamp(1, length),
    ),
  );
}

class _PasteItemsDialog extends StatefulWidget {
  final int length;
  final int initialDay;
  const _PasteItemsDialog({required this.length, required this.initialDay});

  @override
  State<_PasteItemsDialog> createState() => _PasteItemsDialogState();
}

class _PasteItemsDialogState extends State<_PasteItemsDialog> {
  final TextEditingController _c = TextEditingController();
  late int _day = widget.initialDay;
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final items = parseItemLines(_c.text);
    if (items.isEmpty) {
      setState(() => _error = 'No items found. Enter one per line.');
      return;
    }
    Navigator.pop(context, (items, _day));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste checklist items'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One topic or chapter per line.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              autofocus: true,
              minLines: 5,
              maxLines: 10,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            _DayPicker(
              length: widget.length,
              day: _day,
              onChanged: (d) => setState(() => _day = d),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

// ---------------- Notes ----------------

Future<String?> showNotesDialog(BuildContext context, {required String initial}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _NotesDialog(initial: initial),
  );
}

class _NotesDialog extends StatefulWidget {
  final String initial;
  const _NotesDialog({required this.initial});

  @override
  State<_NotesDialog> createState() => _NotesDialogState();
}

class _NotesDialogState extends State<_NotesDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cycle notes'),
      content: TextField(
        controller: _c,
        autofocus: true,
        minLines: 5,
        maxLines: 12,
        keyboardType: TextInputType.multiline,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(alignLabelWithHint: true),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _c.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
