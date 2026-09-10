import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/journal_entry_model.dart';
import '../constants/mood_options.dart';
import '../viewmodels/journal_viewmodel.dart';

const _journalBackground = Color(0xFFFCFAFF);
const _journalSurface = Color(0xFFFFFFFF);
const _journalLavender = Color(0xFFF6F0FC);
const _journalBorder = Color(0xFFE7DDF1);
const _journalPrimary = Color(0xFF6D4F91);
const _journalText = Color(0xFF372D45);
const _journalMuted = Color(0xFF6C6278);
const _journalRadius = 20.0;

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
      backgroundColor: _journalBackground,
      appBar: AppBar(
        title: const Text('Mood and emotions'),
        backgroundColor: _journalBackground,
        surfaceTintColor: Colors.transparent,
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
        backgroundColor: _journalPrimary,
        foregroundColor: Colors.white,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MoodJournalCard(
                entry: entry,
                onTap: () {
                  _openEntry(entry.id);
                },
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

class _MoodJournalCard extends StatelessWidget {
  final JournalEntryModel entry;
  final VoidCallback onTap;

  const _MoodJournalCard({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final moodOption = moodOptionFor(entry.mood);
    final note = entry.note.trim();
    final emotions = entry.emotions.isEmpty
        ? 'No emotions selected.'
        : entry.emotions.join(', ');
    final created = DateFormat(
      'dd.MM.yyyy. HH:mm',
    ).format(entry.createdAtUtc.toLocal());

    return Material(
      color: _journalSurface,
      borderRadius: BorderRadius.circular(_journalRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_journalRadius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_journalRadius),
            border: Border.all(color: _journalBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _journalLavender,
                child: Icon(moodOption.icon, color: _journalPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            moodOption.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _journalText,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right,
                          color: _journalMuted,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      emotions,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _journalMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      note.isEmpty ? 'No notes added.' : note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _journalText, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      created,
                      style: const TextStyle(
                        color: _journalMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
