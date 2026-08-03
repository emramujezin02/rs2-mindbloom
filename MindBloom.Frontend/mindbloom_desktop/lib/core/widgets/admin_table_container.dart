import 'package:flutter/material.dart';

class AdminTableContainer extends StatelessWidget {
  final Widget child;

  final double minimumWidth;

  const AdminTableContainer({
    super.key,
    required this.child,
    this.minimumWidth = 1000,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: constraints.maxWidth < minimumWidth
                    ? minimumWidth
                    : constraints.maxWidth,
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}
