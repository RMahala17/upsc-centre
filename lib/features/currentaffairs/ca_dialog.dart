import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/dates.dart';
import 'models/ca_models.dart';

/// [existing] switches the dialog to edit mode. [sourceSuggestions] are quick
/// picks for the source field.
Future<CaInput?> showCaDialog(
  BuildContext context, {
  CaNote? existing,
  DateTime? defaultDate,
  required List<String> sourceSuggestions,
}) {
  return showDialog<CaInput>(
    context: context,
    builder: (_) => _CaDialog(
      existing: existing,
      defaultDate: defaultDate,
      sourceSuggestions: sourceSuggestions,
    ),
  );
}

class _CaDialog extends StatefulWidget {
  const _CaDialog({
    this.existing,
    this.defaultDate,
    required this.sourceSuggestions,
  });

  final CaNote? existing;
  final DateTime? defaultDate;
  final List<String> sourceSuggestions;

  @override
  State<_CaDialog> createState() => _CaDialogState();
}

class _CaDialogState extends State<_CaDialog> {
  late DateTime _date = widget.existing != null
      ? parseDateKey(widget.existing!.date)
      : dateOnly(widget.defaultDate ?? DateTime.now());
  late String _scope = widget.existing?.scope ?? CaScope.national;
  late String _topic = widget.existing?.topic ?? CaTopic.polity;
  late Set<String> _exams = widget.existing != null
      ? widget.existing!.exams.toSet()
      : CaExam.defaultsFor(CaScope.national).toSet();

  /// Once the user picks exams by hand, changing the scope stops resetting
  /// them.
  bool _examsTouched = false;

  late final TextEditingController _title =
      TextEditingController(text: widget.existing?.title ?? '');
  late final TextEditingController _summary =
      TextEditingController(text: widget.existing?.summary ?? '');
  late final TextEditingController _source =
      TextEditingController(text: widget.existing?.source ?? '');

  String? _titleError;
  String? _examError;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _source.dispose();
    super.dispose();
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

  void _setScope(String s) {
    setState(() {
      _scope = s;
      if (!_examsTouched && !_isEdit) {
        _exams = CaExam.defaultsFor(s).toSet();
      }
    });
  }

  void _toggleExam(String e, bool on) {
    setState(() {
      _examsTouched = true;
      if (on) {
        _exams.add(e);
      } else {
        _exams.remove(e);
      }
      _examError = null;
    });
  }

  void _submit() {
    final title = _title.text.trim();
    setState(() {
      _titleError = title.isEmpty ? 'Enter a headline.' : null;
      _examError = _exams.isEmpty ? 'Pick at least one exam.' : null;
    });
    if (title.isEmpty || _exams.isEmpty) return;

    Navigator.pop(
      context,
      CaInput(
        date: _date,
        title: title,
        summary: _summary.text.trim(),
        source: _source.text.trim(),
        scope: _scope,
        topic: _topic,
        exams: [for (final e in CaExam.all) if (_exams.contains(e)) e],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit note' : 'Add current affairs note'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(DateFormat('EEE, d MMM y').format(_date)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                autofocus: !_isEdit,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Headline',
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _summary,
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Key points (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Scope', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in CaScope.all)
                    ChoiceChip(
                      label: Text(CaScope.label(s)),
                      selected: s == _scope,
                      onSelected: (_) => _setScope(s),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Topic', style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in CaTopic.all)
                    ChoiceChip(
                      label: Text(CaTopic.label(t)),
                      selected: t == _topic,
                      onSelected: (_) => setState(() => _topic = t),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Useful for',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in CaExam.all)
                    FilterChip(
                      label: Text(CaExam.label(e)),
                      selected: _exams.contains(e),
                      onSelected: (v) => _toggleExam(e, v),
                    ),
                ],
              ),
              if (_examError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _examError!,
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: _source,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Source (optional)',
                ),
              ),
              if (widget.sourceSuggestions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in widget.sourceSuggestions)
                      ActionChip(
                        label: Text(s),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _source.text = s),
                      ),
                  ],
                ),
              ],
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
