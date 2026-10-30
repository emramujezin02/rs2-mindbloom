import 'package:flutter/material.dart';

/// null represents an omitted range, never a clickable page.
List<int?> articlePageLabels(int current, int total, {bool compact = false}) {
  if (total < 1) return [];
  final radius = compact ? 0 : 1;
  final pages = <int>{1, total, current};
  for (var i = current - radius; i <= current + radius; i++) {
    if (i >= 1 && i <= total) pages.add(i);
  }
  if (total <= (compact ? 3 : 7)) {
    pages.addAll(List.generate(total, (i) => i + 1));
  }
  final sorted = pages.toList()..sort();
  final result = <int?>[];
  for (final page in sorted) {
    if (result.isNotEmpty && page - result.last! > 1) result.add(null);
    result.add(page);
  }
  return result;
}

class ArticlePagination extends StatelessWidget {
  final int currentPage, totalPages;
  final bool isLoading;
  final ValueChanged<int> onPageChanged;
  const ArticlePagination({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages < 1) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final labels = articlePageLabels(
          currentPage,
          totalPages,
          compact: constraints.maxWidth < 480,
        );
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: 4,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: isLoading || currentPage <= 1
                    ? null
                    : () => onPageChanged(currentPage - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              for (final page in labels)
                if (page == null)
                  const Padding(padding: EdgeInsets.all(6), child: Text('…'))
                else
                  Semantics(
                    selected: page == currentPage,
                    child: TextButton(
                      key: ValueKey('article-page-$page'),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: page == currentPage
                            ? const Color(0xFFE8DEF3)
                            : null,
                      ),
                      onPressed: isLoading ? null : () => onPageChanged(page),
                      child: Text('$page'),
                    ),
                  ),
              IconButton(
                tooltip: 'Next page',
                onPressed: isLoading || currentPage >= totalPages
                    ? null
                    : () => onPageChanged(currentPage + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        );
      },
    );
  }
}
