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

const _journalDetailBackground = Color(0xFFFCFAFF);
const _journalDetailSurface = Color(0xFFFFFFFF);
const _journalDetailLavender = Color(0xFFF6F0FC);
const _journalDetailBorder = Color(0xFFE7DDF1);
const _journalDetailPrimary = Color(0xFF6D4F91);
const _journalDetailText = Color(0xFF372D45);
const _journalDetailMuted = Color(0xFF6C6278);
const _journalDetailRadius = 20.0;

class JournalEntryDetailsPage extends StatefulWidget {
  final int entryId;

  const JournalEntryDetailsPage({super.key, required this.entryId});

  @override
  State<JournalEntryDetailsPage> createState() =>
      _JournalEntryDetailsPageState();
}

class _JournalEntryDetailsPageState extends State<JournalEntryDetailsPage> {
  final JournalViewModel _viewModel = AppInjection.createJournalViewModel();

  JournalEntryModel? _entry;

  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _load();
  }

  @override
  void dispose() {
    _viewModel.dispose();

    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });

    final entry = await _viewModel.getEntry(widget.entryId);

    if (!mounted) {
      return;
    }

    setState(() {
      _entry = entry;
      _isLoading = false;
    });
  }

  Future<void> _edit() async {
    final entry = _entry;

    if (entry == null) {
      return;
    }

    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.editJournalEntry, arguments: entry);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _load();
    }
  }

  Future<void> _delete() async {
    if (_isDeleting) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete journal entry'),
          content: const Text(
            'Are you sure you want to delete this journal entry?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    final success = await _viewModel.deleteEntry(widget.entryId);

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isDeleting = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_viewModel.error ?? 'Unable to delete journal entry.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _journalDetailBackground,
        body: AppLoadingWidget.skeleton(
          message: 'Loading journal entry...',
          skeletonItemCount: 4,
        ),
      );
    }

    final entry = _entry;

    if (entry == null) {
      return Scaffold(
        backgroundColor: _journalDetailBackground,
        appBar: AppBar(
          title: const Text('Journal entry'),
          backgroundColor: _journalDetailBackground,
          surfaceTintColor: Colors.transparent,
        ),
        body: _viewModel.error == null
            ? const AppEmptyStateWidget(
                title: 'Journal entry unavailable',
                message: 'The requested journal entry is not available.',
                icon: Icons.notes_outlined,
              )
            : AppErrorWidget(
                title: 'Journal entry could not be loaded',
                error: _viewModel.error,
                onRetry: _load,
              ),
      );
    }

    final moodOption = moodOptionFor(entry.mood);

    return Scaffold(
      backgroundColor: _journalDetailBackground,
      appBar: AppBar(
        title: const Text('Journal entry'),
        backgroundColor: _journalDetailBackground,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: _isDeleting ? null : _edit,
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
          ),
          IconButton(
            onPressed: _isDeleting ? null : _delete,
            tooltip: 'Delete',
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _journalDetailLavender,
              borderRadius: BorderRadius.circular(_journalDetailRadius),
              border: Border.all(color: _journalDetailBorder),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: Colors.white,
                  child: Icon(
                    moodOption.icon,
                    size: 40,
                    color: _journalDetailPrimary,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  moodOption.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _journalDetailText,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  moodOption.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _journalDetailMuted,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          _JournalDetailSection(
            title: 'Entry details',
            children: [
              _JournalDetailRow(
                icon: Icons.psychology_outlined,
                label: 'Emotions',
                value: entry.emotions.isEmpty
                    ? 'No emotions selected.'
                    : entry.emotions.join(', '),
              ),
              _JournalDetailRow(
                icon: Icons.calendar_month_outlined,
                label: 'Created',
                value: DateFormat(
                  'dd.MM.yyyy. HH:mm',
                ).format(entry.createdAtUtc.toLocal()),
              ),
              if (entry.updatedAtUtc != null)
                _JournalDetailRow(
                  icon: Icons.update,
                  label: 'Last updated',
                  value: DateFormat(
                    'dd.MM.yyyy. HH:mm',
                  ).format(entry.updatedAtUtc!.toLocal()),
                ),
            ],
          ),

          const SizedBox(height: 18),

          _JournalDetailSection(
            title: 'Notes',
            children: [
              Text(
                entry.note.trim().isEmpty ? 'No notes added.' : entry.note,
                style: const TextStyle(
                  color: _journalDetailText,
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalDetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _JournalDetailSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _journalDetailSurface,
        borderRadius: BorderRadius.circular(_journalDetailRadius),
        border: Border.all(color: _journalDetailBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _journalDetailText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _JournalDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _JournalDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _journalDetailPrimary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _journalDetailMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: _journalDetailText,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
