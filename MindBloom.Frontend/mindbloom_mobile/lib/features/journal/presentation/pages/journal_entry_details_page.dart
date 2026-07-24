import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/journal_entry_model.dart';
import '../constants/mood_options.dart';
import '../viewmodels/journal_viewmodel.dart';

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entry = _entry;

    if (entry == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journal entry')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _viewModel.error ?? 'Journal entry could not be loaded.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final moodOption = moodOptionFor(entry.mood);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal entry'),
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
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              child: Icon(moodOption.icon, size: 44),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            moodOption.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 4),

          Text(moodOption.description, textAlign: TextAlign.center),

          const SizedBox(height: 24),

          ListTile(
            leading: const Icon(Icons.psychology_outlined),
            title: const Text('Emotions'),
            subtitle: Text(
              entry.emotions.isEmpty
                  ? 'No emotions selected.'
                  : entry.emotions.join(', '),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Created'),
            subtitle: Text(
              DateFormat(
                'dd.MM.yyyy. HH:mm',
              ).format(entry.createdAtUtc.toLocal()),
            ),
          ),

          if (entry.updatedAtUtc != null)
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Last updated'),
              subtitle: Text(
                DateFormat(
                  'dd.MM.yyyy. HH:mm',
                ).format(entry.updatedAtUtc!.toLocal()),
              ),
            ),

          const SizedBox(height: 16),

          const Text(
            'Notes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(entry.note.trim().isEmpty ? 'No notes added.' : entry.note),
        ],
      ),
    );
  }
}
