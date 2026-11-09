import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../revision/revision_logic.dart' show parseItemLines;
import '../timer/category_ui.dart';
import '../timer/models/session_models.dart';
import 'models/planner_models.dart';
import 'planner_logic.dart';

class TaskInput {
  const TaskInput({
    required this.titles,
    required this.category,
    required this.plannedMin,
  });

  /// One entry when editing; one per line when adding.
  final List<String> titles;
  final String category;
  final int plannedMin;
}

Future<TaskInput?> showTaskDialog(
  BuildContext context, {
  PlannerTask? existing,
}) {
  return showDialog<TaskInput>(
    context: context,
    builder: (_) => _TaskDialog(existing: existing),
  );
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({this.existing});
  final PlannerTask? existing;

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late String _category = widget.existing?.category ?? StudyCategory.gs;
  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _minutes = TextEditingController(
    text: (widget.existing?.plannedMin ?? 0) > 0
        ? '${widget.existing!.plannedMin}'
        : '',
  );
  String? _titleError;
  String? _minutesError;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _submit() {
    final titles = _isEdit
        ? [_title.text.trim()].where((t) => t.isNotEmpty).toList()
        : parseItemLines(_title.text);
    final planned = parsePlannedMinutes(_minutes.text);
    setState(() {
      _titleError = titles.isEmpty ? 'Enter a task.' : null;
      _minutesError = planned == null ? 'Enter 0–1440 minutes, or leave blank.' : null;
    });
    if (titles.isEmpty || planned == null) return;
    Navigator.pop(
      context,
      TaskInput(titles: titles, category: _category, plannedMin: planned),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit task' : 'Add tasks'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                minLines: 1,
                maxLines: _isEdit ? 1 : 6,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Task' : 'Task (one per line)',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 12),
              CategoryChips(
                selected: _category,
                onChanged: (c) => setState(() => _category = c),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _isEdit
                      ? 'Planned minutes (optional)'
                      : 'Planned minutes per task (optional)',
                  errorText: _minutesError,
                ),
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
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
