import 'package:flutter/material.dart';

class AppLoadingOverlay extends StatelessWidget {
  final Widget child;

  final bool isLoading;

  final String message;

  const AppLoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message = 'Spremanje...',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AbsorbPointer(absorbing: isLoading, child: child),

        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: 0.72),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 22,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 14),
                        Text(message, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
