import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../core/validation/app_validators.dart';
import '../constants/mood_options.dart';
import '../viewmodels/journal_viewmodel.dart';

class AddJournalEntryPage extends StatefulWidget {
  const AddJournalEntryPage({super.key});

  @override
  State<AddJournalEntryPage> createState() => _AddJournalEntryPageState();
}

class _AddJournalEntryPageState extends State<AddJournalEntryPage> {
  final JournalViewModel _viewModel = AppInjection.createJournalViewModel();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final Set<String> _selectedEmotions = {};

  final TextEditingController _noteController = TextEditingController();

  int _mood = 3;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);

    _noteController.dispose();

    _viewModel.dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save() async {
    if (_viewModel.isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.createEntry(
      mood: _mood,
      emotions: _selectedEmotions.toList(),
      note: _noteController.text.trim(),
    );

    if (!success && mounted) {
      _formKey.currentState?.validate();
    }

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Journal entry saved successfully.')),
      );

      Navigator.of(context).pop(true);

      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_viewModel.error ?? 'Unable to save journal entry.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMood = moodOptionFor(_mood);

    return Scaffold(
      appBar: AppBar(title: const Text('New journal entry')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Mood',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _mood.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: selectedMood.label,
                onChanged: _viewModel.isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _mood = value.toInt();
                        });
                      },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(selectedMood.icon, size: 36),
                title: Text(selectedMood.label),
                subtitle: Text(selectedMood.description),
              ),
              const SizedBox(height: 20),
              FormField<Set<String>>(
                initialValue: _selectedEmotions,
                validator: (_) {
                  if (_selectedEmotions.isEmpty) {
                    return 'Select at least one emotion.';
                  }

                  if (_selectedEmotions.length > 5) {
                    return 'You may select at most 5 emotions.';
                  }

                  return null;
                },
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emotions',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: emotionOptions.map((emotion) {
                          final selected = _selectedEmotions.contains(emotion);

                          return FilterChip(
                            label: Text(emotion),
                            selected: selected,
                            onSelected: _viewModel.isSaving
                                ? null
                                : (value) {
                                    setState(() {
                                      if (value) {
                                        if (_selectedEmotions.length < 5) {
                                          _selectedEmotions.add(emotion);
                                        }
                                      } else {
                                        _selectedEmotions.remove(emotion);
                                      }
                                    });

                                    field.didChange(
                                      Set<String>.from(_selectedEmotions),
                                    );

                                    field.validate();
                                  },
                          );
                        }).toList(),
                      ),
                      if (field.hasError) ...[
                        const SizedBox(height: 8),
                        Text(
                          field.errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _noteController,
                minLines: 4,
                maxLines: 7,
                maxLength: 500,
                enabled: !_viewModel.isSaving,
                decoration: const InputDecoration(
                  labelText: 'Short note',
                  hintText: 'Add a short note about your day.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return _viewModel.fieldError('Note') ??
                      AppValidators.journalNote(value);
                },
              ),
              if (_viewModel.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _viewModel.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _viewModel.isSaving ? null : _save,
                icon: _viewModel.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_viewModel.isSaving ? 'Saving...' : 'Save entry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
