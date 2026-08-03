import 'package:flutter/material.dart';

class AdminTableAction<T> {
  final T value;

  final String label;

  final IconData icon;

  final bool destructive;

  final bool enabled;

  const AdminTableAction({
    required this.value,
    required this.label,
    required this.icon,
    this.destructive = false,
    this.enabled = true,
  });
}

class AdminTableActionMenu<T> extends StatelessWidget {
  final List<AdminTableAction<T>> actions;

  final ValueChanged<T> onSelected;

  final bool enabled;

  const AdminTableActionMenu({
    super.key,
    required this.actions,
    required this.onSelected,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      enabled: enabled,
      tooltip: 'Akcije',
      icon: const Icon(Icons.more_vert),
      onSelected: onSelected,
      itemBuilder: (context) {
        return actions.map((action) {
          final foregroundColor = action.destructive
              ? Theme.of(context).colorScheme.error
              : null;

          return PopupMenuItem<T>(
            value: action.value,
            enabled: action.enabled,
            child: Row(
              children: [
                Icon(
                  action.icon,
                  size: 20,
                  color: action.enabled
                      ? foregroundColor
                      : Theme.of(context).disabledColor,
                ),
                const SizedBox(width: 10),
                Text(
                  action.label,
                  style: TextStyle(
                    color: action.enabled
                        ? foregroundColor
                        : Theme.of(context).disabledColor,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
