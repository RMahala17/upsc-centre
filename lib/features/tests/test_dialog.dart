import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/utils/dates.dart';
import '../../core/utils/parsing.dart';
import 'models/test_models.dart';
import 'test_logic.dart';

Future<TestInput?> showTestDialog(
  BuildContext context, {
  TestRecord? existing,
}) {
  return showDialog<TestInput>(
    context: context,
    builder: (_) => _TestDialog(existing: existing),
  );
}

class _TestDialog extends StatefulWidget {
  const _TestDialog({this.existing});
  final TestRecord? existing;

  @override
  State<_TestDialog> createState() => _TestDialogState();
}

class _TestDialogState extends State<_TestDialog> {
  late String _category = widget.existing?.category ?? TestCategory.prelimsGs;
  late DateTime _date = widget.existing == null
      ? dateOnly(DateTime.now())
      : parseDateKey(widget.existing!.date);
  late bool _analysisDone = widget.existing?.analysisDone ?? false;

  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _series =
      TextEditingController(text: widget.existing?.series ?? '');
  late final TextEditingController _total = TextEditingController(
    text: _initialTotal(),
  );
  late final TextEditingController _max = TextEditingController(
    text: formatNumber(
      widget.existing?.maxMarks ?? TestCategory.defaultMaxMarks(_category),
    ),
  );
  late final TextEditingController _correct = TextEditingController(
    text: _hasMcqResult ? '${widget.existing!.correct}' : '',
  );
  late final TextEditingController _wrong = TextEditingController(
    text: _hasMcqResult ? '${widget.existing!.wrong}' : '',
  );
  late final TextEditingController _score = TextEditingController(
    text: (!_existingIsMcq && widget.existing?.score != null)
        ? formatNumber(widget.existing!.score!)
        : '',
  );
  late final TextEditingController _time = TextEditingController(
    text: (widget.existing?.timeMin ?? 0) > 0
        ? '${widget.existing!.timeMin}'
        : '',
  );
  late final TextEditingController _notes =
      TextEditingController(text: widget.existing?.notes ?? '');

  /// Once the user types their own totals we stop filling in defaults.
  late bool _totalTouched = widget.existing != null;
  late bool _maxTouched = widget.existing != null;

  String? _nameError;
  String? _totalError;
  String? _maxError;
  String? _countsError;
  String? _scoreError;
  String? _timeError;

  bool get _isEdit => widget.existing != null;
  bool get _isMcq => TestCategory.isMcq(_category);
  bool get _existingIsMcq =>
      widget.existing != null && TestCategory.isMcq(widget.existing!.category);
  bool get _hasMcqResult => _existingIsMcq && widget.existing!.score != null;

  String _initialTotal() {
    final e = widget.existing;
    if (e != null && e.totalQuestions > 0) return '${e.totalQuestions}';
    final d = TestCategory.defaultTotalQuestions(_category);
    return d > 0 ? '$d' : '';
  }

  @override
  void dispose() {
    _name.dispose();
    _series.dispose();
    _total.dispose();
    _max.dispose();
    _correct.dispose();
    _wrong.dispose();
    _score.dispose();
    _time.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _setCategory(String c) {
    setState(() {
      _category = c;
      if (!_totalTouched) {
        final d = TestCategory.defaultTotalQuestions(c);
        _total.text = d > 0 ? '$d' : '';
      }
      if (!_maxTouched) {
        _max.text = formatNumber(TestCategory.defaultMaxMarks(c));
      }
    });
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

  int? _countOf(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? 0 : parseIntInRange(t, min: 0, max: 500);
  }

  /// Live score for the objective-test preview, or null when it cannot be
  /// worked out yet.
  String? _preview() {
    if (!_isMcq) return null;
    if (_correct.text.trim().isEmpty && _wrong.text.trim().isEmpty) return null;
    final total = parseIntInRange(_total.text, min: 1, max: 500);
    final max = parseDecimal(_max.text);
    final correct = _countOf(_correct);
    final wrong = _countOf(_wrong);
    if (total == null ||
        max == null ||
        max <= 0 ||
        correct == null ||
        wrong == null ||
        validateMcqCounts(total: total, correct: correct, wrong: wrong) !=
            null) {
      return null;
    }
    final score =
        mcqScore(correct: correct, wrong: wrong, total: total, maxMarks: max);
    final lost =
        negativeLost(wrong: wrong, total: total, maxMarks: max);
    final skipped = total - correct - wrong;
    return 'Score ${formatNumber(score)} / ${formatNumber(max)} · '
        '$skipped skipped · −${formatNumber(lost)} from wrong answers';
  }

  void _submit() {
    final name = _name.text.trim();
    final parsedMax = parseDecimal(_max.text);
    final maxOk = parsedMax != null && parsedMax > 0 && parsedMax <= 10000;
    // Only used when maxOk is true; otherwise we return before using it.
    final max = parsedMax ?? 0.0;
    final timeText = _time.text.trim();
    final time =
        timeText.isEmpty ? 0 : parseIntInRange(timeText, min: 0, max: 1440);

    int total = 0;
    int correct = 0;
    int wrong = 0;
    double? score;
    String? totalError;
    String? countsError;
    String? scoreError;

    if (_isMcq) {
      final t = parseIntInRange(_total.text, min: 1, max: 500);
      final c = _countOf(_correct);
      final w = _countOf(_wrong);
      if (t == null) {
        totalError = 'Enter 1–500.';
      } else {
        total = t;
      }
      final hasResult =
          _correct.text.trim().isNotEmpty || _wrong.text.trim().isNotEmpty;
      if (c == null || w == null) {
        countsError = 'Enter whole numbers from 0 to 500.';
      } else if (t != null && hasResult) {
        countsError = validateMcqCounts(total: t, correct: c, wrong: w);
        if (countsError == null && maxOk) {
          correct = c;
          wrong = w;
          score = mcqScore(correct: c, wrong: w, total: t, maxMarks: max);
        }
      }
    } else if (_score.text.trim().isNotEmpty) {
      final v = parseDecimal(_score.text);
      if (v == null || v < 0 || (maxOk && v > max)) {
        scoreError = maxOk
            ? 'Enter a number from 0 to ${formatNumber(max)}.'
            : 'Enter a valid score.';
      } else {
        score = v;
      }
    }

    setState(() {
      _nameError = name.isEmpty ? 'Enter a name.' : null;
      _maxError = maxOk ? null : 'Enter the maximum marks.';
      _timeError = time == null ? 'Enter 0–1440, or leave blank.' : null;
      _totalError = totalError;
      _countsError = countsError;
      _scoreError = scoreError;
    });
    if (name.isEmpty ||
        !maxOk ||
        time == null ||
        totalError != null ||
        countsError != null ||
        scoreError != null) {
      return;
    }

    Navigator.pop(
      context,
      TestInput(
        name: name,
        series: _series.text.trim(),
        category: _category,
        date: _date,
        totalQuestions: total,
        maxMarks: max,
        correct: correct,
        wrong: wrong,
        score: score,
        timeMin: time,
        // Analysis only makes sense once there is a result.
        analysisDone: _analysisDone && score != null,
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview();
    return AlertDialog(
      title: Text(_isEdit ? 'Edit test' : 'Add test'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: !_isEdit,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Test name',
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _series,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Test series / provider (optional)',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in TestCategory.all)
                    ChoiceChip(
                      label: Text(TestCategory.label(c)),
                      selected: c == _category,
                      onSelected: (_) => _setCategory(c),
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
                      controller: _time,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Minutes taken',
                        errorText: _timeError,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isMcq) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _total,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() => _totalTouched = true),
                        decoration: InputDecoration(
                          labelText: 'Questions',
                          errorText: _totalError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _max,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() => _maxTouched = true),
                        decoration: InputDecoration(
                          labelText: 'Max marks',
                          errorText: _maxError,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _correct,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Correct'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _wrong,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(labelText: 'Wrong'),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _countsError ??
                        preview ??
                        'Leave correct and wrong blank if the test is not '
                            'taken yet. Wrong answers cost one third of a '
                            'right answer.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _countsError != null
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _max,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => _maxTouched = true,
                        decoration: InputDecoration(
                          labelText: 'Max marks',
                          errorText: _maxError,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _score,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Score (blank = not marked)',
                          errorText: _scoreError,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Analysis: mistakes, weak topics (optional)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Analysis done'),
                value: _analysisDone,
                onChanged: (v) => setState(() => _analysisDone = v),
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
