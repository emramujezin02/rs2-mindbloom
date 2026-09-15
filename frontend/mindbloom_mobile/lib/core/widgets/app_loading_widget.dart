import 'package:flutter/material.dart';

class AppLoadingWidget extends StatelessWidget {
  final String? message;
  final bool useSkeleton;
  final int skeletonItemCount;
  final EdgeInsetsGeometry padding;

  const AppLoadingWidget({
    super.key,
    this.message,
    this.useSkeleton = false,
    this.skeletonItemCount = 4,
    this.padding = const EdgeInsets.all(16),
  });

  const AppLoadingWidget.skeleton({
    super.key,
    this.message,
    this.skeletonItemCount = 4,
    this.padding = const EdgeInsets.all(16),
  }) : useSkeleton = true;

  @override
  Widget build(BuildContext context) {
    if (useSkeleton) {
      return _buildSkeleton(context);
    }

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final placeholderColor = colorScheme.surfaceContainerHighest;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      itemCount: skeletonItemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonLine(widthFactor: 0.65, color: placeholderColor),
                      const SizedBox(height: 10),
                      _SkeletonLine(widthFactor: 0.9, color: placeholderColor),
                      const SizedBox(height: 8),
                      _SkeletonLine(widthFactor: 0.75, color: placeholderColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppLoadMoreIndicator extends StatelessWidget {
  final String loadingMessage;

  const AppLoadMoreIndicator({
    super.key,
    this.loadingMessage = 'Loading more...',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              loadingMessage,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class AppInlineLoadingIndicator extends StatelessWidget {
  final String? message;

  const AppInlineLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          if (message != null && message!.trim().isNotEmpty) ...[
            const SizedBox(width: 10),
            Flexible(child: Text(message!, textAlign: TextAlign.center)),
          ],
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final Color color;

  const _SkeletonLine({required this.widthFactor, required this.color});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
