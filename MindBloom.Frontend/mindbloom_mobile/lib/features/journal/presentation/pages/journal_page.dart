import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
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
          child: Text(
            viewModel.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (viewModel.entries.isEmpty) {
      return const Center(child: Text('You do not have journal entries yet.'));
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

          return Card(
            child: ListTile(
              onTap: () {
                _openEntry(entry.id);
              },
              leading: CircleAvatar(child: Text(entry.mood.toString())),
              title: Text(entry.emotion),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.note.isEmpty ? 'No notes added.' : entry.note,
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
