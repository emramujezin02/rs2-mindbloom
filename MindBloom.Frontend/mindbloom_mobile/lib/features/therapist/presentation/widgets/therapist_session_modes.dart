import 'package:flutter/material.dart';

class TherapistSessionModes extends StatelessWidget {
  final bool offersOnline;
  final bool offersInPerson;
  final bool compact;

  const TherapistSessionModes({
    super.key,
    required this.offersOnline,
    required this.offersInPerson,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!offersOnline && !offersInPerson) {
      return const Text(
        'Session type not specified',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }

    final chips = <Widget>[];

    if (offersOnline) {
      chips.add(
        _SessionModeChip(
          icon: Icons.videocam_outlined,
          label: 'Online',
          compact: compact,
        ),
      );
    }

    if (offersInPerson) {
      chips.add(
        _SessionModeChip(
          icon: Icons.people_outline,
          label: 'In person',
          compact: compact,
        ),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

class _SessionModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const _SessionModeChip({
    required this.icon,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 12,
        vertical: compact ? 5 : 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: compact ? 16 : 19,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
