import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'anthro_logic.dart';
import 'models/anthro_models.dart';

// ---------------- Add / edit chapter ----------------

class ChapterInput {
  final String name;
  final String paper;
  final int lectureCount;
  const ChapterInput(this.name, this.paper, this.lectureCount);
}

Future<ChapterInput?> showChapterDialog(
  BuildContext context, {
  Chapter? existing,
  String? paper,
}) {
  return showDialog<ChapterInput>(
    context: context,
    builder: (_) => _ChapterDialog(existing: existing, paper: paper),
  );
}

class _ChapterDialog extends StatefulWidget {
  final Chapter? existing;
  final String? paper;
  const _ChapterDialog({this.existing, this.paper});

  @override
  State<_ChapterDialog> createState() => _ChapterDialogState();
}

class _ChapterDialogState extends State<_ChapterDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  final TextEditingController _count = TextEditingController();
  late String _paper =
      widget.existing?.paper ?? widget.paper ?? AnthroPaper.paper1;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    super.dispose();
  }

  void _submit() {
    final n = _name.text.trim();
    if (n.isEmpty) {
      setState(() => _error = 'Enter a chapter name.');
      return;
    }
    var count = 0;
    if (widget.existing == null && _count.text.trim().isNotEmpty) {
      final c = int.tryParse(_count.text.trim());
      if (c == null || c < 0 || c > 200) {
        setState(() => _error = 'Lectures must be between 0 and 200.');
        return;
      }
      count = c;
    }
    Navigator.pop(context, ChapterInput(n, _paper, count));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit chapter' : 'Add chapter'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Chapter name'),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Paper'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _paper,
                  isExpanded: true,
                  items: [
                    for (final p in AnthroPaper.all)
                      DropdownMenuItem(
                          value: p, child: Text(AnthroPaper.title(p))),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _paper = v);
                  },
                ),
              ),
            ),
            if (!editing) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _count,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Number of lectures (optional)',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
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
        FilledButton(
          onPressed: _submit,
          child: Text(editing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ---------------- Paste a chapter list ----------------

Future<List<ParsedChapter>?> showPasteChaptersDialog(
  BuildContext context, {
  required String paperTitle,
}) {
  return showDialog<List<ParsedChapter>>(
    context: context,
    builder: (_) => _PasteDialog(paperTitle: paperTitle),
  );
}

class _PasteDialog extends StatefulWidget {
  final String paperTitle;
  const _PasteDialog({required this.paperTitle});

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final TextEditingController _c = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final items = parseChapterList(_c.text);
    if (items.isEmpty) {
      setState(() => _error = 'No chapters found. Enter one per line.');
      return;
    }
    Navigator.pop(context, items);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Paste chapters: ${widget.paperTitle}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'One chapter per line. Add the lecture count after a comma, '
              '| or " - ". Lines without a count get 0 lectures.\n\n'
              'Example:\nHuman Evolution, 8\nGenetics | 6\nCulture and Society',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              autofocus: true,
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              decoration: const InputDecoration(alignLabelWithHint: true),
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
        FilledButton(onPressed: _submit, child: const Text('Add chapters')),
      ],
    );
  }
}

// ---------------- Targets ----------------

Future<(int, int)?> showAnthroSettingsDialog(
  BuildContext context, {
  required int target,
  required int planned,
}) {
  return showDialog<(int, int)>(
    context: context,
    builder: (_) => _SettingsDialog(target: target, planned: planned),
  );
}

class _SettingsDialog extends StatefulWidget {
  final int target;
  final int planned;
  const _SettingsDialog({required this.target, required this.planned});

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  late final TextEditingController _target =
      TextEditingController(text: '${widget.target}');
  late final TextEditingController _planned =
      TextEditingController(text: '${widget.planned}');
  String? _error;

  @override
  void dispose() {
    _target.dispose();
    _planned.dispose();
    super.dispose();
  }

  void _submit() {
    final t = int.tryParse(_target.text.trim());
    final p = int.tryParse(_planned.text.trim());
    if (t == null || t < 1 || t > 20) {
      setState(() => _error = 'Daily target must be between 1 and 20.');
      return;
    }
    if (p == null || p < 1 || p > 500) {
      setState(() => _error = 'Total lectures must be between 1 and 500.');
      return;
    }
    Navigator.pop(context, (t, p));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Targets'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _target,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration:
                const InputDecoration(labelText: 'Daily target (lectures)'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _planned,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'Total lectures in the course'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
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
