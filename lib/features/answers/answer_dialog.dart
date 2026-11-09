import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/exam_papers.dart';
import '../../core/utils/parsing.dart';
import 'answer_logic.dart';
import 'models/answer_models.dart';

Future<AnswerInput?> showAnswerDialog(
  BuildContext context, {
  AnswerEntry? existing,
}) {
  return showDialog<AnswerInput>(
    context: context,
    builder: (_) => _AnswerDialog(existing: existing),
  );
}

class _AnswerDialog extends StatefulWidget {
  const _AnswerDialog({this.existing});
  final AnswerEntry? existing;

  @override
  State<_AnswerDialog> createState() => _AnswerDialogState();
}

class _AnswerDialogState extends State<_AnswerDialog> {
  late String _paper = widget.existing?.paper ?? ExamPaper.gs1;
  late DateTime _date = widget.existing == null
      ? dateOnly(DateTime.now())
      : parseDateKey(widget.existing!.date);
  late bool _needsRewrite =
      widget.existing?.status == AnswerStatus.needsRewrite;

  late final TextEditingController _question =
      TextEditingController(text: widget.existing?.question ?? '');
  late final TextEditingController _topic =
      TextEditingController(text: widget.existing?.topic ?? '');
  late final TextEditingController _marks =
      TextEditingController(text: '${widget.existing?.marks ?? 10}');
  late final TextEditingController _words = TextEditingController(
    text: '${widget.existing?.wordLimit ?? suggestedWordLimit(ExamPaper.gs1, 10)}',
  );
  late final TextEditingController _minutes = TextEditingController(
    text: (widget.existing?.minutes ?? 0) > 0
        ? '${widget.existing!.minutes}'
        : '',
  );
  late final TextEditingController _score = TextEditingController(
    text: widget.existing?.score == null
        ? ''
        : formatNumber(widget.existing!.score!),
  );
  late final TextEditingController _feedback =
      TextEditingController(text: widget.existing?.feedback ?? '');

  /// Once the user types their own word limit we stop suggesting one.
  late bool _wordsTouched = widget.existing != null;

  String? _questionError;
  String? _marksError;
  String? _wordsError;
  String? _minutesError;
  String? _scoreError;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _question.dispose();
    _topic.dispose();
    _marks.dispose();
    _words.dispose();
    _minutes.dispose();
    _score.dispose();
    _feedback.dispose();
    super.dispose();
  }

  void _refreshSuggestedWords() {
    if (_wordsTouched) return;
    final marks = parseIntInRange(_marks.text, min: 1, max: 250);
    if (marks == null) return;
    _words.text = '${suggestedWordLimit(_paper, marks)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = dateOnly(picked));
  }

  void _submit() {
    final question = _question.text.trim();
    final marks = parseIntInRange(_marks.text, min: 1, max: 250);
    final wordsText = _words.text.trim();
    final words = wordsText.isEmpty
        ? 0
        : parseIntInRange(wordsText, min: 0, max: 5000);
    final minText = _minutes.text.trim();
    final minutes =
        minText.isEmpty ? 0 : parseIntInRange(minText, min: 0, max: 600);
    final score =
        parseScore(_score.text, marks: marks ?? 250); // re-checked below

    setState(() {
      _questionError = question.isEmpty ? 'Enter the question.' : null;
      _marksError = marks == null ? 'Enter 1–250.' : null;
      _wordsError = words == null ? 'Enter 0–5000, or leave blank.' : null;
      _minutesError = minutes == null ? 'Enter 0–600, or leave blank.' : null;
      _scoreError = !score.ok ? 'Enter a number from 0 to ${marks ?? 250}.' : null;
    });
    if (question.isEmpty ||
        marks == null ||
        words == null ||
        minutes == null ||
        !score.ok) {
      return;
    }
    Navigator.pop(
      context,
      AnswerInput(
        date: _date,
        paper: _paper,
        question: question,
        topic: _topic.text.trim(),
        marks: marks,
        wordLimit: words,
        minutes: minutes,
        score: score.value,
        feedback: _feedback.text.trim(),
        needsRewrite: _needsRewrite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit answer' : 'Log an answer'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _question,
                autofocus: !_isEdit,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Question',
                  errorText: _questionError,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in ExamPaper.mains)
                    ChoiceChip(
                      label: Text(ExamPaper.label(p)),
                      selected: p == _paper,
                      onSelected: (_) => setState(() {
                        _paper = p;
                        _refreshSuggestedWords();
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _topic,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Topic (optional)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _marks,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setState(_refreshSuggestedWords),
                      decoration: InputDecoration(
                        labelText: 'Marks',
                        errorText: _marksError,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _words,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => _wordsTouched = true,
                      decoration: InputDecoration(
                        labelText: 'Word limit',
                        errorText: _wordsError,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.event, size: 18),
                      label: Text(DateFormat('d MMM yyyy').format(_date)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _minutes,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Minutes taken',
                        errorText: _minutesError,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _score,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Score (leave blank if not evaluated yet)',
                  errorText: _scoreError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _feedback,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Feedback / what to improve (optional)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Needs rewrite'),
                value: _needsRewrite,
                onChanged: (v) => setState(() => _needsRewrite = v),
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
