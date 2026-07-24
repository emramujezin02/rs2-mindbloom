import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AvailableSlotsPreview extends StatelessWidget {
  final bool isLoading;

  final Map<DateTime, List<DateTime>> groupedSlots;

  final ValueChanged<DateTime> onBookSlot;

  final VoidCallback onShowAllSlots;

  const AvailableSlotsPreview({
    super.key,
    required this.isLoading,
    required this.groupedSlots,
    required this.onBookSlot,
    required this.onShowAllSlots,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (groupedSlots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.event_busy_outlined, size: 38),
                  SizedBox(height: 10),
                  Text(
                    'No available appointments were found in the next 14 days.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onShowAllSlots,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Show all appointments'),
          ),
        ],
      );
    }

    final groups = groupedSlots.entries.toList()
      ..sort((first, second) => first.key.compareTo(second.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...groups.map((group) {
          final date = group.key;
          final slots = group.value;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: slots.map((slot) {
                      return OutlinedButton.icon(
                        onPressed: () => onBookSlot(slot),
                        icon: const Icon(Icons.schedule, size: 18),
                        label: Text(DateFormat('HH:mm').format(slot)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          );
        }),
        OutlinedButton.icon(
          onPressed: onShowAllSlots,
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('Show all appointments'),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final normalizedDate = DateTime(date.year, date.month, date.day);

    if (normalizedDate == today) {
      return 'Today, '
          '${DateFormat('dd.MM.yyyy.').format(date)}';
    }

    if (normalizedDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow, '
          '${DateFormat('dd.MM.yyyy.').format(date)}';
    }

    return DateFormat('EEEE, dd.MM.yyyy.').format(date);
  }
}
