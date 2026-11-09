import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/exam_papers.dart';
import '../../core/utils/parsing.dart';
import '../revision/revision_logic.dart' show parseItemLines;
import 'models/pyq_models.dart';
import 'pyq_logic.dart';

/// [existing] switches the dialog to edit mode (one question). When adding,
/// [defaultYear] and [suggestions] make repeat entry quicker.
Future<PyqInput?> showPyqDialog(
  BuildContext context, {
  Pyq? existing,
  required int defaultYear,
  required List<String> suggestions,
}) {
  return showDialog<PyqInput>(
    context: context,
    builder: (_) => _PyqDialog(
      existing: existing,
      defaultYear: defaultYear,
      suggestions: suggestions,
    ),
  );
}

class _PyqDialog extends StatefulWidget {
  const _PyqDialog({
    this.existing,
    required this.defaultYear,
    required this.suggestions,
  });

  final Pyq? existing;
  final int defaultYear;
  final List<String> suggestions;

  @override
  State<_PyqDialog> createState() => _PyqDialogState();
}

class _PyqDialogState extends State<_PyqDialog> {
  late String _exam = widget.existing?.exam ?? PyqExam.prelims;
  late String _paper = widget.existing?.paper ?? ExamPaper.prelimsGs;

  late final TextEditingController _questions =
      TextEditingController(text: widget.existing?.question ?? '');
  late final TextEditingController _year = TextEditingController(
    text: '${widget.existing?.year ?? widget.defaultYear}',
  );
  late final TextEditingController _topic =
      TextEditingController(text: widget.existing?.topic ?? '');
  late final TextEditingController _marks = TextEditingController(
    text: (widget.existing?.marks ?? 0) > 0 ? '${widget.existing!.marks}' : '',
  );
  late final TextEditingController _note =
      TextEditingController(text: widget.existing?.note ?? '');

  String? _questionsError;
  String? _yearError;
  String? _marksError;

  bool get _isEdit => widget.existing != null;

  int get _maxYear => DateTime.now().year + 1;

  @override
  void dispose() {
    _questions.dispose();
    _year.dispose();
    _topic.dispose();
    _marks.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setExam(String e) {
    if (e == _exam) return;
    setState(() {
      _exam = e;
      _paper = papersFor(e).first;
    });
  }

  void _submit() {
    final questions = _isEdit
        ? [_questions.text.trim()].where((q) => q.isNotEmpty).toList()
        : parseItemLines(_questions.text);
    final year = parseYear(_year.text, maxYear: _maxYear);
    final marksText = _marks.text.trim();
    final marks = (_exam == PyqExam.prelims || marksText.isEmpty)
        ? 0
        : parseIntInRange(marksText, min: 1, max: 250);

    setState(() {
      _questionsError = questions.isEmpty ? 'Enter a question.' : null;
      _yearError = year == null ? 'Enter a year from 1990 to $_maxYear.' : null;
      _marksError = marks == null ? 'Enter 1–250, or leave blank.' : null;
    });
    if (questions.isEmpty || year == null || marks == null) return;

    Navigator.pop(
      context,
      PyqInput(
        exam: _exam,
        paper: _paper,
        year: year,
        topic: _topic.text.trim(),
        marks: marks,
        questions: questions,
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit question' : 'Add questions'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<String>(
                segments: [
                  for (final e in PyqExam.all)
                    ButtonSegment(value: e, label: Text(PyqExam.label(e))),
                ],
                selected: {_exam},
                onSelectionChanged: (s) => _setExam(s.first),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in papersFor(_exam))
                    ChoiceChip(
                      label: Text(ExamPaper.label(p)),
                      selected: p == _paper,
                      onSelected: (_) => setState(() => _paper = p),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Year',
                        errorText: _yearError,
                      ),
                    ),
                  ),
                  if (_exam == PyqExam.mains) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _marks,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          labelText: 'Marks (optional)',
                          errorText: _marksError,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questions,
                autofocus: !_isEdit,
                minLines: _isEdit ? 2 : 3,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _isEdit ? 'Question' : 'Questions (one per line)',
                  errorText: _questionsError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topic,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Topic (optional)',
                ),
              ),
              if (widget.suggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in widget.suggestions)
                      ActionChip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _topic.text = s),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
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
