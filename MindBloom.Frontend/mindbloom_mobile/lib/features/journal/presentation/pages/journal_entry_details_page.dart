import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/journal_entry_model.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    final success = await _viewModel.deleteEntry(widget.entryId);

    if (!mounted || !success) {
      return;
    }

    Navigator.of(context).pop(true);
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
          child: Text(_viewModel.error ?? 'Journal entry could not be loaded.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal entry'),
        actions: [
          IconButton(onPressed: _edit, icon: const Icon(Icons.edit)),
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 40,
            child: Text(
              entry.mood.toString(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(Icons.mood),
            title: const Text('Emotion'),
            subtitle: Text(entry.emotion),
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
          const SizedBox(height: 16),
          const Text(
            'Notes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(entry.note.isEmpty ? 'No notes added.' : entry.note),
        ],
      ),
    );
  }
}
