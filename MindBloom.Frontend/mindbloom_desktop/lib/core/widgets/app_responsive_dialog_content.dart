import 'package:flutter/material.dart';

class AppResponsiveDialogContent extends StatelessWidget {
  final Widget child;

  final double preferredWidth;

  final double maximumHeightFactor;

  const AppResponsiveDialogContent({
    super.key,
    required this.child,
    this.preferredWidth = 560,
    this.maximumHeightFactor = 0.78,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    final horizontalMargin = screenSize.width < 480 ? 32.0 : 64.0;
    final availableWidth = screenSize.width - horizontalMargin;
    final width = preferredWidth < availableWidth
        ? preferredWidth
        : availableWidth;

    final preferredHeight = screenSize.height * maximumHeightFactor;
    final maxViewportHeight = screenSize.height - 32;
    final height = preferredHeight < maxViewportHeight
        ? preferredHeight
        : maxViewportHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: width,
        maxHeight: height,
      ),
      child: SingleChildScrollView(child: child),
    );
  }
}
