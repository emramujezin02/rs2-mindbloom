import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/journal_entry_model.dart';
import '../viewmodels/journal_viewmodel.dart';

class EditJournalEntryPage extends StatefulWidget {
  final JournalEntryModel entry;

  const EditJournalEntryPage({super.key, required this.entry});

  @override
  State<EditJournalEntryPage> createState() => _EditJournalEntryPageState();
}

class _EditJournalEntryPageState extends State<EditJournalEntryPage> {
  final JournalViewModel _viewModel = AppInjection.createJournalViewModel();

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emotionController;

  late final TextEditingController _noteController;

  late int _mood;

  @override
  void initState() {
    super.initState();

    _mood = widget.entry.mood;

    _emotionController = TextEditingController(text: widget.entry.emotion);

    _noteController = TextEditingController(text: widget.entry.note);
  }

  @override
  void dispose() {
    _emotionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await _viewModel.updateEntry(
      id: widget.entry.id,
      mood: _mood,
      emotion: _emotionController.text.trim(),
      note: _noteController.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit journal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Mood', style: TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: _mood.toDouble(),
                min: 1,
                max: 5,
                divisions: 4,
                label: _mood.toString(),
                onChanged: (value) {
                  setState(() {
                    _mood = value.toInt();
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emotionController,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Emotion',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Emotion is required.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                minLines: 5,
                maxLines: 8,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              if (_viewModel.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _viewModel.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton.icon(
                onPressed: _viewModel.isSaving ? null : _save,
                icon: const Icon(Icons.save),
                label: _viewModel.isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
