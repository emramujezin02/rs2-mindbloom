import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../journal/presentation/constants/mood_options.dart';
import '../viewmodels/private_journal_viewmodel.dart';

const _privateDetailBackground = Color(0xFFFCFAFF);
const _privateDetailSurface = Color(0xFFFFFFFF);
const _privateDetailLavender = Color(0xFFF6F0FC);
const _privateDetailBorder = Color(0xFFE7DDF1);
const _privateDetailPrimary = Color(0xFF6D4F91);
const _privateDetailText = Color(0xFF372D45);
const _privateDetailMuted = Color(0xFF6C6278);
const _privateDetailRadius = 20.0;

class PrivateJournalEntryDetailsPage extends StatefulWidget {
  final int entryId;

  const PrivateJournalEntryDetailsPage({super.key, required this.entryId});

  @override
  State<PrivateJournalEntryDetailsPage> createState() =>
      _PrivateJournalEntryDetailsPageState();
}

class _PrivateJournalEntryDetailsPageState
    extends State<PrivateJournalEntryDetailsPage> {
  final PrivateJournalViewModel _viewModel =
      AppInjection.createPrivateJournalViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_refresh);
    _viewModel.loadDetails(widget.entryId);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
    _viewModel.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _reload() {
    return _viewModel.loadDetails(widget.entryId);
  }

  Future<void> _edit() async {
    final entry = _viewModel.selectedEntry;
    if (entry == null) return;

    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.editPrivateJournalEntry, arguments: entry);

    if (mounted && result == true) {
      await _reload();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete private entry'),
          content: const Text(
            'Are you sure you want to delete this private journal entry? '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final success = await _viewModel.deleteEntry(widget.entryId);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_viewModel.error ?? 'Unable to delete entry.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = _viewModel.selectedEntry;

    return Scaffold(
      backgroundColor: _privateDetailBackground,
      appBar: AppBar(
        title: const Text('Private journal entry'),
        backgroundColor: _privateDetailBackground,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: entry == null || _viewModel.isDeleting ? null : _edit,
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: entry == null || _viewModel.isDeleting ? null : _delete,
            tooltip: 'Delete',
            icon: _viewModel.isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final entry = _viewModel.selectedEntry;

    if (_viewModel.isLoadingDetails && entry == null) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading private entry...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.detailsError != null && entry == null) {
      return AppErrorWidget(
        title: 'Private entry could not be loaded',
        error: _viewModel.detailsError,
        onRetry: _reload,
      );
    }

    if (entry == null) {
      return const AppEmptyStateWidget(
        title: 'Private entry unavailable',
        message: 'The requested private journal entry is not available.',
        icon: Icons.lock_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (_viewModel.detailsError != null)
            AppInlineError(
              title: 'Private entry could not be refreshed',
              error: _viewModel.detailsError,
              onRetry: _reload,
              margin: const EdgeInsets.only(bottom: 16),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _privateDetailLavender,
              borderRadius: BorderRadius.circular(_privateDetailRadius),
              border: Border.all(color: _privateDetailBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, color: _privateDetailPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This private journal text is visible only to your account.',
                    style: TextStyle(
                      color: _privateDetailText,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            entry.title,
            style: const TextStyle(
              color: _privateDetailText,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('dd.MM.yyyy.').format(entry.entryDateUtc.toLocal()),
            style: const TextStyle(
              color: _privateDetailMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _privateDetailSurface,
              borderRadius: BorderRadius.circular(_privateDetailRadius),
              border: Border.all(color: _privateDetailBorder),
            ),
            child: Text(
              entry.content,
              style: const TextStyle(
                color: _privateDetailText,
                fontSize: 16,
                height: 1.65,
              ),
            ),
          ),
          if (entry.mood != null) ...[
            const SizedBox(height: 24),
            _buildMoodCard(),
          ],
          const SizedBox(height: 20),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Created'),
            subtitle: Text(
              DateFormat(
                'dd.MM.yyyy. HH:mm',
              ).format(entry.createdAtUtc.toLocal()),
            ),
          ),
          if (entry.updatedAtUtc != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.update),
              title: const Text('Last updated'),
              subtitle: Text(
                DateFormat(
                  'dd.MM.yyyy. HH:mm',
                ).format(entry.updatedAtUtc!.toLocal()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoodCard() {
    final entry = _viewModel.selectedEntry!;
    final moodOption = moodOptionFor(entry.mood!);

    return Card(
      color: _privateDetailSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_privateDetailRadius),
        side: const BorderSide(color: _privateDetailBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Related mood entry',
              style: TextStyle(
                color: _privateDetailText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: _privateDetailLavender,
                child: Icon(moodOption.icon, color: _privateDetailPrimary),
              ),
              title: Text(moodOption.label),
              subtitle: Text(
                entry.emotions.isEmpty
                    ? 'No emotions selected.'
                    : entry.emotions.join(', '),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
