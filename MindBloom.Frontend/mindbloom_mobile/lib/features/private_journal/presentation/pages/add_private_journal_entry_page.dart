import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../journal/data/models/journal_entry_model.dart';
import '../../../journal/presentation/constants/mood_options.dart';
import '../../data/services/private_journal_draft_service.dart';
import '../viewmodels/private_journal_viewmodel.dart';

class AddPrivateJournalEntryPage
    extends StatefulWidget {
  const AddPrivateJournalEntryPage({
    super.key,
  });

  @override
  State<AddPrivateJournalEntryPage>
      createState() =>
          _AddPrivateJournalEntryPageState();
}

class _AddPrivateJournalEntryPageState
    extends State<AddPrivateJournalEntryPage> {
  final PrivateJournalViewModel _viewModel =
      AppInjection.createPrivateJournalViewModel();

  final PrivateJournalDraftService
      _draftService =
      PrivateJournalDraftService();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  final TextEditingController
      _titleController =
      TextEditingController();

  final TextEditingController
      _contentController =
      TextEditingController();

  DateTime _entryDate = DateTime.now();

  int? _selectedMoodEntryId;

  Timer? _draftTimer;

  bool _isLoadingDraft = true;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _titleController.addListener(
      _scheduleDraftSave,
    );

    _contentController.addListener(
      _scheduleDraftSave,
    );

    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _restoreDraft(),
      _viewModel.loadMoodEntries(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingDraft = false;
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();

    _viewModel.removeListener(_refresh);

    _titleController.removeListener(
      _scheduleDraftSave,
    );

    _contentController.removeListener(
      _scheduleDraftSave,
    );

    _titleController.dispose();
    _contentController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _restoreDraft() async {
    final draft =
        await _draftService.load();

    if (draft == null || !mounted) {
      return;
    }

    _titleController.text = draft.title;
    _contentController.text =
        draft.content;
    _entryDate = draft.entryDate;
    _selectedMoodEntryId =
        draft.moodEntryId;
  }

  void _scheduleDraftSave() {
    if (_isLoadingDraft) {
      return;
    }

    _draftTimer?.cancel();

    _draftTimer = Timer(
      const Duration(milliseconds: 500),
      _saveDraft,
    );
  }

  Future<void> _saveDraft() async {
    final title =
        _titleController.text.trim();

    final content =
        _contentController.text.trim();

    if (title.isEmpty &&
        content.isEmpty &&
        _selectedMoodEntryId == null) {
      await _draftService.clear();
      return;
    }

    await _draftService.save(
      PrivateJournalDraft(
        title: _titleController.text,
        content: _contentController.text,
        entryDate: _entryDate,
        moodEntryId:
            _selectedMoodEntryId,
      ),
    );
  }

  Future<void> _selectDate() async {
    final selected =
        await showDatePicker(
      context: context,
      initialDate: _entryDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _entryDate = DateTime(
        selected.year,
        selected.month,
        selected.day,
        _entryDate.hour,
        _entryDate.minute,
      );
    });

    await _saveDraft();
  }

  Future<void> _save() async {
    if (_viewModel.isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success =
        await _viewModel.createEntry(
      title: _titleController.text,
      content: _contentController.text,
      entryDate: _entryDate,
      moodEntryId:
          _selectedMoodEntryId,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      await _draftService.clear();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Private journal entry saved.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          _viewModel.error ??
              'Unable to save entry.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDraft) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'New private journal entry',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: ListTile(
                  leading:
                      Icon(Icons.lock_outline),
                  title: Text(
                    'Private by default',
                  ),
                  subtitle: Text(
                    'Your therapist cannot '
                    'automatically see this text.',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller:
                    _titleController,
                maxLength: 150,
                enabled:
                    !_viewModel.isSaving,
                decoration:
                    const InputDecoration(
                  labelText: 'Title',
                  hintText:
                      'Give this entry a title',
                  border:
                      OutlineInputBorder(),
                ),
                validator: (value) {
                  final normalized =
                      value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return 'Title is required.';
                  }

                  if (normalized.length > 150) {
                    return 'Title may contain at most 150 characters.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller:
                    _contentController,
                minLines: 10,
                maxLines: 20,
                maxLength: 10000,
                enabled:
                    !_viewModel.isSaving,
                decoration:
                    const InputDecoration(
                  labelText: 'Content',
                  hintText:
                      'Write your thoughts privately...',
                  alignLabelWithHint: true,
                  border:
                      OutlineInputBorder(),
                ),
                validator: (value) {
                  final normalized =
                      value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return 'Journal content is required.';
                  }

                  if (normalized.length >
                      10000) {
                    return 'Content may contain at most 10000 characters.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_month,
                  ),
                  title: const Text(
                    'Entry date',
                  ),
                  subtitle: Text(
                    DateFormat(
                      'dd.MM.yyyy.',
                    ).format(_entryDate),
                  ),
                  trailing: const Icon(
                    Icons.edit_calendar,
                  ),
                  onTap: _viewModel.isSaving
                      ? null
                      : _selectDate,
                ),
              ),
              const SizedBox(height: 12),
              _buildMoodSelection(),
              if (_viewModel.error !=
                  null) ...[
                const SizedBox(height: 12),
                Text(
                  _viewModel.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed:
                    _viewModel.isSaving
                    ? null
                    : _save,
                icon: _viewModel.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _viewModel.isSaving
                      ? 'Saving...'
                      : 'Save entry',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'An unfinished entry is saved '
                'locally on this device as a draft.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSelection() {
    if (_viewModel.isLoadingMoodEntries) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child:
                CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Related mood entry',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Optional. Link this private '
              'entry to one of your mood and '
              'emotion tracker entries.',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue:
                  _selectedMoodEntryId,
              isExpanded: true,
              decoration:
                  const InputDecoration(
                border:
                    OutlineInputBorder(),
                labelText: 'Mood entry',
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    'No linked mood entry',
                  ),
                ),
                ..._viewModel.moodEntries.map(
                  (entry) =>
                      DropdownMenuItem<int?>(
                    value: entry.id,
                    child: Text(
                      _moodEntryLabel(entry),
                      overflow:
                          TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _viewModel.isSaving
                  ? null
                  : (value) {
                      setState(() {
                        _selectedMoodEntryId =
                            value;
                      });

                      _saveDraft();
                    },
            ),
          ],
        ),
      ),
    );
  }

  String _moodEntryLabel(
    JournalEntryModel entry,
  ) {
    final mood =
        moodOptionFor(entry.mood);

    final emotions =
        entry.emotions.isEmpty
        ? 'No emotions'
        : entry.emotions.join(', ');

    final date = DateFormat(
      'dd.MM.yyyy. HH:mm',
    ).format(
      entry.createdAtUtc.toLocal(),
    );

    return '$date · ${mood.label} · $emotions';
  }
}