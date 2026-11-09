import 'package:flutter/material.dart';

import 'models/syllabus_models.dart';

class SubjectInput {
  final String name;
  final String paper;
  const SubjectInput(this.name, this.paper);
}

Future<SubjectInput?> showSubjectDialog(
  BuildContext context, {
  Subject? existing,
}) {
  return showDialog<SubjectInput>(
    context: context,
    builder: (_) => _SubjectDialog(existing: existing),
  );
}

class _SubjectDialog extends StatefulWidget {
  final Subject? existing;
  const _SubjectDialog({this.existing});

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _paper = widget.existing?.paper ?? GsPaper.all.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final n = _name.text.trim();
    if (n.isEmpty) return;
    Navigator.pop(context, SubjectInput(n, _paper));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return AlertDialog(
      title: Text(editing ? 'Edit subject' : 'Add subject'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Subject name'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Paper'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _paper,
                isExpanded: true,
                items: [
                  for (final p in GsPaper.all)
                    DropdownMenuItem(value: p, child: Text(GsPaper.title(p))),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _paper = v);
                },
              ),
            ),
          ),
        ],
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
