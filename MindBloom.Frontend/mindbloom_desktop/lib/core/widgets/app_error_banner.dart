import 'package:flutter/material.dart';

class AppErrorBanner extends StatelessWidget {
  final String message;

  final VoidCallback? onDismiss;

  const AppErrorBanner({super.key, required this.message, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Zatvori',
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              color: colorScheme.onErrorContainer,
            ),
          ],
        ],
      ),
    );
  }
}
