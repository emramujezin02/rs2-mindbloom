import 'package:flutter/material.dart';

class AdminTableContainer extends StatefulWidget {
  final Widget child;

  final double minimumWidth;

  const AdminTableContainer({
    super.key,
    required this.child,
    this.minimumWidth = 1000,
  });

  @override
  State<AdminTableContainer> createState() => _AdminTableContainerState();
}

class _AdminTableContainerState extends State<AdminTableContainer> {
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : widget.minimumWidth;

          final contentWidth = availableWidth < widget.minimumWidth
              ? widget.minimumWidth
              : availableWidth;

          return Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            trackVisibility: availableWidth < widget.minimumWidth,
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: contentWidth, child: widget.child),
            ),
          );
        },
      ),
    );
  }
}
