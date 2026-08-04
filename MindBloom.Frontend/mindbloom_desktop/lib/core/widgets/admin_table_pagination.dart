import 'package:flutter/material.dart';

class AdminTablePagination extends StatelessWidget {
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  final bool isLoading;

  final VoidCallback? onPreviousPage;
  final VoidCallback? onNextPage;

  final ValueChanged<int>? onPageSizeChanged;

  final List<int> pageSizeOptions;

  const AdminTablePagination({
    super.key,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.isLoading,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
    this.pageSizeOptions = const [10, 20, 50],
  });

  @override
  Widget build(BuildContext context) {
    final displayedPage = totalPages == 0 ? 0 : pageNumber;

    final firstItem = totalCount == 0 ? 0 : ((pageNumber - 1) * pageSize) + 1;

    final possibleLastItem = pageNumber * pageSize;

    final lastItem = possibleLastItem > totalCount
        ? totalCount
        : possibleLastItem;

    final canGoPrevious =
        !isLoading &&
        totalPages > 0 &&
        pageNumber > 1 &&
        onPreviousPage != null;

    final canGoNext =
        !isLoading &&
        totalPages > 0 &&
        pageNumber < totalPages &&
        onNextPage != null;

    final effectivePageSizeOptions = pageSizeOptions.contains(pageSize)
        ? pageSizeOptions
        : [pageSize, ...pageSizeOptions];

    final resultText = totalCount == 0
        ? 'Ukupno: 0'
        : '$firstItem–$lastItem od $totalCount';

    final pageSizeSelector = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Redova po stranici:'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: pageSize,
          items: effectivePageSizeOptions
              .map(
                (value) =>
                    DropdownMenuItem<int>(value: value, child: Text('$value')),
              )
              .toList(),
          onChanged: isLoading || onPageSizeChanged == null
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }

                  if (value == pageSize) {
                    return;
                  }

                  onPageSizeChanged!(value);
                },
        ),
      ],
    );

    final pageNavigation = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Stranica '
            '$displayedPage '
            'od '
            '$totalPages',
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          tooltip: 'Prethodna stranica',
          onPressed: canGoPrevious ? onPreviousPage : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Sljedeća stranica',
          onPressed: canGoNext ? onNextPage : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(resultText),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [pageSizeSelector, pageNavigation],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Text(resultText),

                const Spacer(),

                pageSizeSelector,

                const SizedBox(width: 20),

                pageNavigation,
              ],
            );
          },
        ),
      ),
    );
  }
}
