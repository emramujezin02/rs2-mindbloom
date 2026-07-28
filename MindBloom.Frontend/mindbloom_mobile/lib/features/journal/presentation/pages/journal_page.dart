import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../constants/mood_options.dart';
import '../viewmodels/journal_viewmodel.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final JournalViewModel viewModel = AppInjection.createJournalViewModel();

  @override
  void initState() {
    super.initState();

    viewModel.addListener(_refresh);
    viewModel.loadEntries();
  }

  @override
  void dispose() {
    viewModel.removeListener(_refresh);
    viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() {
    return viewModel.loadEntries();
  }

  Future<void> _addEntry() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.addJournalEntry);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _reload();
    }
  }

  Future<void> _openEntry(int id) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.journalEntryDetails, arguments: id);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _reload();
    }
  }

  Future<void> _openPeriodFilter() async {
    DateTime? selectedFrom = viewModel.fromDate;
    DateTime? selectedTo = viewModel.toDate;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter by period'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_outlined),
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
                    leading: const Icon(Icons.event_outlined),
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
      await viewModel.clearPeriod();
      return;
    }

    if (result == 'apply') {
      await viewModel.applyPeriod(from: selectedFrom, to: selectedTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = viewModel.fromDate != null || viewModel.toDate != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood and emotions'),
        actions: [
          IconButton(
            tooltip: 'Filter by period',
            onPressed: viewModel.isLoading ? null : _openPeriodFilter,
            icon: Icon(
              hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: viewModel.isLoading ? null : _addEntry,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading && viewModel.entries.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading mood and emotion entries...',
        skeletonItemCount: 5,
      );
    }

    if (viewModel.error != null && viewModel.entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: AppErrorWidget(
          title: 'Journal entries could not be loaded',
          error: viewModel.error,
          onRetry: _reload,
        ),
      );
    }

    if (viewModel.entries.isEmpty) {
      final hasFilter = viewModel.fromDate != null || viewModel.toDate != null;

      return RefreshIndicator(
        onRefresh: _reload,
        child: AppEmptyStateWidget(
          title: hasFilter ? 'No entries in this period' : 'No journal entries',
          message: hasFilter
              ? 'No mood or emotion entries match the selected period.'
              : 'Record your mood and emotions to start building your journal.',
          icon: Icons.sentiment_neutral_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (viewModel.error != null)
            AppInlineError(
              title: viewModel.isLoadingMore
                  ? 'More journal entries could not be loaded'
                  : 'Journal entries could not be refreshed',
              error: viewModel.error,
              onRetry: viewModel.isLoadingMore ? viewModel.loadMore : _reload,
              margin: const EdgeInsets.only(bottom: 12),
            ),
          ...viewModel.entries.map((entry) {
            final moodOption = moodOptionFor(entry.mood);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  onTap: () {
                    _openEntry(entry.id);
                  },
                  leading: CircleAvatar(child: Icon(moodOption.icon)),
                  title: Text(moodOption.label),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        entry.emotions.isEmpty
                            ? 'No emotions selected.'
                            : entry.emotions.join(', '),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.note.trim().isEmpty
                            ? 'No notes added.'
                            : entry.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat(
                          'dd.MM.yyyy. HH:mm',
                        ).format(entry.createdAtUtc.toLocal()),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (viewModel.isLoadingMore)
            const AppLoadMoreIndicator(
              loadingMessage: 'Loading more entries...',
            )
          else if (viewModel.hasMorePages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: OutlinedButton.icon(
                onPressed: viewModel.loadMore,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'All journal entries have been loaded.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
