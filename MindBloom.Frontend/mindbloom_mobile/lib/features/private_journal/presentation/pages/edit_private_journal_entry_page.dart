import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../journal/data/models/journal_entry_model.dart';
import '../../../journal/presentation/constants/mood_options.dart';
import '../../data/models/private_journal_entry_model.dart';
import '../viewmodels/private_journal_viewmodel.dart';

class EditPrivateJournalEntryPage
    extends StatefulWidget {
  final PrivateJournalEntryModel entry;

  const EditPrivateJournalEntryPage({
    super.key,
    required this.entry,
  });

  @override
  State<EditPrivateJournalEntryPage>
      createState() =>
          _EditPrivateJournalEntryPageState();
}

class _EditPrivateJournalEntryPageState
    extends State<
        EditPrivateJournalEntryPage> {
  final PrivateJournalViewModel _viewModel =
      AppInjection.createPrivateJournalViewModel();

  final GlobalKey<FormState> _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _titleController;

  late final TextEditingController
      _contentController;

  late DateTime _entryDate;

  int? _selectedMoodEntryId;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);

    _titleController =
        TextEditingController(
      text: widget.entry.title,
    );

    _contentController =
        TextEditingController(
      text: widget.entry.content,
    );

    _entryDate =
        widget.entry.entryDateUtc.toLocal();

    _selectedMoodEntryId =
        widget.entry.moodEntryId;

    _viewModel.loadMoodEntries();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);

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
  }

  Future<void> _save() async {
    if (_viewModel.isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success =
        await _viewModel.updateEntry(
      id: widget.entry.id,
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
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Private journal entry updated.',
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
              'Unable to update entry.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Edit private entry',
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
              TextFormField(
                controller:
                    _titleController,
                maxLength: 150,
                enabled:
                    !_viewModel.isSaving,
                decoration:
                    const InputDecoration(
                  labelText: 'Title',
                  border:
                      OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '')
                      .isEmpty) {
                    return 'Title is required.';
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
                  alignLabelWithHint: true,
                  border:
                      OutlineInputBorder(),
                ),
                validator: (value) {
                  if ((value?.trim() ?? '')
                      .isEmpty) {
                    return 'Journal content is required.';
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
                  style: const TextStyle(
                    color: Colors.red,
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
                      : 'Save changes',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodSelection() {
    if (_viewModel.isLoadingMoodEntries) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return DropdownButtonFormField<int?>(
      initialValue: _selectedMoodEntryId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Related mood entry',
        border: OutlineInputBorder(),
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
            },
    );
  }

  String _moodEntryLabel(
    JournalEntryModel entry,
  ) {
    final mood =
        moodOptionFor(entry.mood);

    final date = DateFormat(
      'dd.MM.yyyy.',
    ).format(
      entry.createdAtUtc.toLocal(),
    );

    return '$date · ${mood.label} · '
        '${entry.emotions.join(', ')}';
  }
}