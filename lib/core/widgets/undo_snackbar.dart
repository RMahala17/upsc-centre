import 'package:flutter/material.dart';

/// Shows a message with an Undo action. Used instead of permanent deletes so
/// one accidental tap never loses a record.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ),
  );
}
