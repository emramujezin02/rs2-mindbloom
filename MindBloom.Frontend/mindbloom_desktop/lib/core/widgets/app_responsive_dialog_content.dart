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

    final availableWidth = screenSize.width - 64;

    final availableHeight = screenSize.height * maximumHeightFactor;

    final width = preferredWidth < availableWidth
        ? preferredWidth
        : availableWidth;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: availableHeight),
      child: SingleChildScrollView(child: child),
    );
  }
}
