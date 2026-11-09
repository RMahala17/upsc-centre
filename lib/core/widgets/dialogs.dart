import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  String confirmLabel = 'Save',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: label,
      initial: initial,
      confirmLabel: confirmLabel,
      numeric: false,
    ),
  );
}

/// Returns an int between [min] and [max], or null if cancelled.
Future<int?> promptInt(
  BuildContext context, {
  required String title,
  required String label,
  int min = 1,
  int max = 200,
  String confirmLabel = 'Add',
}) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => _PromptDialog(
      title: title,
      label: '$label ($min–$max)',
      initial: '',
      confirmLabel: confirmLabel,
      numeric: true,
    ),
  );
  if (text == null) return null;
  final n = int.tryParse(text);
  if (n == null || n < min || n > max) return null;
  return n;
}

class _PromptDialog extends StatefulWidget {
  final String title;
  final String label;
  final String initial;
  final String confirmLabel;
  final bool numeric;
  const _PromptDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
    required this.numeric,
  });

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
        inputFormatters:
            widget.numeric ? [FilteringTextInputFormatter.digitsOnly] : null,
        textCapitalization: widget.numeric
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
