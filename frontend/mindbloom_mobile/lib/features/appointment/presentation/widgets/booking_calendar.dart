import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Date-only values are calendar coordinates in Sarajevo, never device instants.
class BookingCalendar extends StatefulWidget {
  final DateTime today;
  final DateTime lastDate;
  final DateTime? selectedDate;
  final bool Function(DateTime) isSelectable;
  final ValueChanged<DateTime> onSelected;

  const BookingCalendar({
    super.key,
    required this.today,
    required this.lastDate,
    required this.selectedDate,
    required this.isSelectable,
    required this.onSelected,
  });

  @override
  State<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<BookingCalendar> {
  late DateTime month;

  @override
  void initState() {
    super.initState();
    final date = widget.selectedDate ?? widget.today;
    month = DateTime.utc(date.year, date.month);
  }

  bool sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstMonth = DateTime.utc(widget.today.year, widget.today.month);
    final lastMonth = DateTime.utc(widget.lastDate.year, widget.lastDate.month);
    final offset = month.weekday - 1;
    final days = DateTime.utc(month.year, month.month + 1, 0).day;
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              key: const Key('previous-month'),
              tooltip: 'Prethodni mjesec',
              onPressed: month.isAfter(firstMonth)
                  ? () => setState(
                      () => month = DateTime.utc(month.year, month.month - 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat.yMMMM().format(month),
                key: const Key('calendar-month'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              key: const Key('next-month'),
              tooltip: 'Sljedeći mjesec',
              onPressed: month.isBefore(lastMonth)
                  ? () => setState(
                      () => month = DateTime.utc(month.year, month.month + 1),
                    )
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final label in [
              'Pon',
              'Uto',
              'Sri',
              'Čet',
              'Pet',
              'Sub',
              'Ned',
            ])
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 44,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: offset + days,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            final date = DateTime.utc(
              month.year,
              month.month,
              index - offset + 1,
            );
            final enabled =
                !date.isBefore(widget.today) &&
                !date.isAfter(widget.lastDate) &&
                widget.isSelectable(date);
            final selected = sameDay(widget.selectedDate, date);
            final today = sameDay(widget.today, date);
            return Semantics(
              selected: selected,
              label:
                  '${DateFormat('dd.MM.yyyy.').format(date)}${today ? ', danas' : ''}',
              child: TextButton(
                key: Key('day-${DateFormat('yyyy-MM-dd').format(date)}'),
                onPressed: enabled ? () => widget.onSelected(date) : null,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: selected ? colors.primary : null,
                  foregroundColor: selected ? colors.onPrimary : colors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: today
                        ? BorderSide(color: colors.primary)
                        : BorderSide.none,
                  ),
                ),
                child: Text('${date.day}'),
              ),
            );
          },
        ),
      ],
    );
  }
}
