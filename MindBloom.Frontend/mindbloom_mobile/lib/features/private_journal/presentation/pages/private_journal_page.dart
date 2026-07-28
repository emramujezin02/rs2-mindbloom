import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../viewmodels/private_journal_viewmodel.dart';

class PrivateJournalPage extends StatefulWidget {
  const PrivateJournalPage({super.key});

  @override
  State<PrivateJournalPage> createState() => _PrivateJournalPageState();
}

class _PrivateJournalPageState extends State<PrivateJournalPage> {
  final PrivateJournalViewModel _viewModel =
      AppInjection.createPrivateJournalViewModel();

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.loadEntries();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _searchController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();

    await _viewModel.search(_searchController.text);
  }

  Future<void> _clearSearch() async {
    _searchController.clear();

    FocusScope.of(context).unfocus();

    await _viewModel.clearSearch();
  }

  Future<void> _openDateFilter() async {
    DateTime? selectedFrom = _viewModel.fromDate;
    DateTime? selectedTo = _viewModel.toDate;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by date'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('From'),
                    subtitle: Text(
                      selectedFrom == null
                          ? 'Not selected'
                          : DateFormat('dd.MM.yyyy.').format(selectedFrom!),
                    ),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedFrom ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );

                      if (selected != null) {
                        setDialogState(() {
                          selectedFrom = selected;

                          if (selectedTo != null &&
                              selectedTo!.isBefore(selected)) {
                            selectedTo = null;
                          }
                        });
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event),
                    title: const Text('To'),
                    subtitle: Text(
                      selectedTo == null
                          ? 'Not selected'
                          : DateFormat('dd.MM.yyyy.').format(selectedTo!),
                    ),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedTo ?? DateTime.now(),
                        firstDate: selectedFrom ?? DateTime(2020),
                        lastDate: DateTime.now(),
                      );

                      if (selected != null) {
                        setDialogState(() {
                          selectedTo = selected;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop('clear');
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop('cancel');
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop('apply');
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (result == 'clear') {
      await _viewModel.clearDateFilter();
    }

    if (result == 'apply') {
      await _viewModel.applyDateFilter(from: selectedFrom, to: selectedTo);
    }
  }

  Future<void> _addEntry() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.addPrivateJournalEntry);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _viewModel.loadEntries();
    }
  }

  Future<void> _openEntry(int id) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.privateJournalEntryDetails, arguments: id);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _viewModel.loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasDateFilter =
        _viewModel.fromDate != null || _viewModel.toDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Private journal'),
        actions: [
          IconButton(
            onPressed: _openDateFilter,
            tooltip: 'Filter by date',
            icon: Icon(
              hasDateFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const Card(
            margin: EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Your private space'),
              subtitle: Text(
                'Journal text is not '
                'automatically shared with '
                'your therapist.',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) {
                _search();
              },
              decoration: InputDecoration(
                labelText: 'Search private journal',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.clear),
                      ),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.entries.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading private journal...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.error != null && _viewModel.entries.isEmpty) {
      return AppErrorWidget(
        title: 'Private journal could not be loaded',
        error: _viewModel.error,
        onRetry: _viewModel.loadEntries,
      );
    }

    if (_viewModel.entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _viewModel.loadEntries,
        child: const AppEmptyStateWidget(
          title: 'No private journal entries',
          message: 'Create your first private entry using the + button.',
          icon: Icons.menu_book_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.loadEntries,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Private journal could not be refreshed',
              error: _viewModel.error,
              onRetry: _viewModel.loadEntries,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ..._viewModel.entries.map(
            (entry) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: () {
                  _openEntry(entry.id);
                },
                leading: const CircleAvatar(child: Icon(Icons.lock_outline)),
                title: Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(
                      entry.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat(
                        'dd.MM.yyyy.',
                      ).format(entry.entryDateUtc.toLocal()),
                    ),
                    if (entry.mood != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Linked mood: '
                        '${entry.mood}/5'
                        '${entry.emotions.isEmpty ? '' : ' · ${entry.emotions.join(', ')}'}',
                      ),
                    ],
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
          if (_viewModel.isLoadingMore)
            const AppLoadMoreIndicator(
              loadingMessage: 'Loading more private entries...',
            )
          else if (_viewModel.loadMoreError != null)
            AppLoadMoreError(
              error: _viewModel.loadMoreError,
              fallbackMessage: 'More private entries could not be loaded.',
              onRetry: _viewModel.retryLoadMore,
            )
          else if (_viewModel.hasMorePages)
            Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton.icon(
                onPressed: _viewModel.loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            ),
        ],
      ),
    );
  }
}
