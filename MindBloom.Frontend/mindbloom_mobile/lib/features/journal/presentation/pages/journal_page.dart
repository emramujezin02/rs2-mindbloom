import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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

  Future<void> _addEntry() async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.addJournalEntry);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await viewModel.loadEntries();
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
      await viewModel.loadEntries();
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
            onPressed: _openPeriodFilter,
            icon: Icon(
              hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null && viewModel.entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: viewModel.loadEntries,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (viewModel.entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: viewModel.loadEntries,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 180),
            Icon(Icons.sentiment_neutral, size: 54),
            SizedBox(height: 16),
            Center(child: Text('No journal entries found.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: viewModel.loadEntries,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: viewModel.entries.length + (viewModel.hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == viewModel.entries.length) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ElevatedButton(
                  onPressed: viewModel.isLoadingMore
                      ? null
                      : viewModel.loadMore,
                  child: viewModel.isLoadingMore
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load more'),
                ),
              ),
            );
          }

          final entry = viewModel.entries[index];

          final moodOption = moodOptionFor(entry.mood);

          return Card(
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
                    entry.note.trim().isEmpty ? 'No notes added.' : entry.note,
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
          );
        },
      ),
    );
  }
}
