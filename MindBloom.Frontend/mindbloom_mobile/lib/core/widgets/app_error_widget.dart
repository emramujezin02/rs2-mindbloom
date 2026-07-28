import 'package:flutter/material.dart';

import 'app_error_message.dart';

class AppErrorWidget extends StatelessWidget {
  final String title;
  final Object? error;
  final String fallbackMessage;
  final Future<void> Function()? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool scrollable;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

  const AppErrorWidget({
    super.key,
    required this.title,
    this.error,
    this.fallbackMessage = AppErrorMessage.generic,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline,
    this.scrollable = true,
    this.footer,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            AppErrorMessage.from(error, fallback: fallbackMessage),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                onRetry!();
              },
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel),
            ),
          ],
        ],
      ),
    );

    if (!scrollable) {
      return Center(child: content);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 80),
        content,
        const SizedBox(height: 80),
        ?footer,
      ],
    );
  }
}

class AppInlineError extends StatelessWidget {
  final Object? error;
  final String fallbackMessage;
  final Future<void> Function()? onRetry;
  final String retryLabel;
  final String? title;
  final EdgeInsetsGeometry margin;

  const AppInlineError({
    super.key,
    this.error,
    this.fallbackMessage = AppErrorMessage.generic,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.title,
    this.margin = const EdgeInsets.symmetric(vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.trim().isNotEmpty) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  AppErrorMessage.from(error, fallback: fallbackMessage),
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ],
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                onRetry!();
              },
              child: Text(retryLabel),
            ),
          ],
        ],
      ),
    );
  }
}

class AppLoadMoreError extends StatelessWidget {
  final Object? error;
  final String fallbackMessage;
  final Future<void> Function() onRetry;

  const AppLoadMoreError({
    super.key,
    this.error,
    this.fallbackMessage = 'More results could not be loaded.',
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return AppInlineError(
      error: error,
      fallbackMessage: fallbackMessage,
      retryLabel: 'Retry',
      onRetry: onRetry,
      title: 'Could not load more',
      margin: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}
