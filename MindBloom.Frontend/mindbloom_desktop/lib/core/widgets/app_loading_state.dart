import 'package:flutter/material.dart';

class AppLoadingState extends StatelessWidget {
  final String message;

  final double indicatorSize;

  const AppLoadingState({
    super.key,
    this.message = 'Učitavanje...',
    this.indicatorSize = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: indicatorSize,
              height: indicatorSize,
              child: const CircularProgressIndicator(),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
