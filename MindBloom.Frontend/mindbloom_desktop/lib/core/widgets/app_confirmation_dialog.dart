import 'package:flutter/material.dart';

class AppConfirmationDialog {
  AppConfirmationDialog._();

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Potvrdi',
    String cancelText = 'Odustani',
    bool destructive = false,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                icon ??
                    (destructive
                        ? Icons.warning_amber_rounded
                        : Icons.help_outline),
                color: destructive ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title)),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: Text(cancelText),
            ),
            destructive
                ? FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: Text(confirmText),
                  )
                : FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: Text(confirmText),
                  ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
