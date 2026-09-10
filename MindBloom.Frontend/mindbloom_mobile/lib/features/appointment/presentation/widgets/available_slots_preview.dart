import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_loading_widget.dart';

const _slotsSurface = Color(0xFFFFFFFF);
const _slotsLavender = Color(0xFFF6F0FC);
const _slotsBorder = Color(0xFFE7DDF1);
const _slotsPrimary = Color(0xFF6D4F91);
const _slotsText = Color(0xFF372D45);
const _slotsMuted = Color(0xFF6C6278);
const _slotsRadius = 18.0;

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
      return const _SlotCard(
        child: AppInlineLoadingIndicator(
          message: 'Loading available appointments...',
        ),
      );
    }

    if (groupedSlots.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SlotCard(
            child: Column(
              children: [
                Icon(Icons.event_busy_outlined, size: 38, color: _slotsPrimary),
                SizedBox(height: 10),
                Text(
                  'No available appointments were found in the next 14 days.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _slotsMuted, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onShowAllSlots,
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Show all appointments'),
            ),
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

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SlotCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _slotsLavender,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                          color: _slotsPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatDate(date),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _slotsText,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
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
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onShowAllSlots,
            icon: const Icon(Icons.calendar_month_outlined),
            label: const Text('Show all appointments'),
          ),
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

class _SlotCard extends StatelessWidget {
  final Widget child;

  const _SlotCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _slotsSurface,
        borderRadius: BorderRadius.circular(_slotsRadius),
        border: Border.all(color: _slotsBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
