import 'package:flutter/material.dart';

/// The app's destructive confirmation: one line of copy with a cancel and a
/// red confirm action.
///
/// The stock `AlertDialog` leaves the actions well above the bottom edge, so
/// the padding is tightened here: the buttons sit close to the dialog's lower
/// border instead of floating in the middle.
Future<bool> showDeleteConfirmDialog(
  BuildContext context, {
  required String message,
  required String cancelLabel,
  required String deleteLabel,
  Key dialogKey = const ValueKey('delete-confirm'),
  Key cancelKey = const ValueKey('delete-confirm-cancel'),
  Key deleteKey = const ValueKey('delete-confirm-delete'),
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: dialogKey,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      content: Text(message),
      actions: [
        TextButton(
          key: cancelKey,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          key: deleteKey,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          child: Text(deleteLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
