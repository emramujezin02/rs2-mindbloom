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

        final screenSize = MediaQuery.sizeOf(dialogContext);

        final maxWidth = screenSize.width > 560 ? 480.0 : screenSize.width - 64;

        final maxHeight = screenSize.height * 0.70;

        return AlertDialog(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon ??
                    (destructive
                        ? Icons.warning_amber_rounded
                        : Icons.help_outline),
                color: destructive ? colorScheme.error : colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            child: SingleChildScrollView(child: Text(message)),
          ),
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
                    child: Text(confirmText, overflow: TextOverflow.ellipsis),
                  )
                : FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: Text(confirmText, overflow: TextOverflow.ellipsis),
                  ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
