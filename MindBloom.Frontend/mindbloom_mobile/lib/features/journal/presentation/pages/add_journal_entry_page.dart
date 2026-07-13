import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/journal_viewmodel.dart';

class AddJournalEntryPage extends StatefulWidget {
  const AddJournalEntryPage({super.key});

  @override
  State<AddJournalEntryPage> createState() => _AddJournalEntryPageState();
}

class _AddJournalEntryPageState extends State<AddJournalEntryPage> {
  final JournalViewModel _viewModel = AppInjection.createJournalViewModel();

  final _formKey = GlobalKey<FormState>();

  final _emotionController = TextEditingController();
  final _noteController = TextEditingController();

  int _mood = 3;

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

    final success = await _viewModel.createEntry(
      mood: _mood,
      emotion: _emotionController.text.trim(),
      note: _noteController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_viewModel.error ?? 'Unable to save journal.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("New Journal Entry")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Mood",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

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

              const SizedBox(height: 20),

              TextFormField(
                controller: _emotionController,
                decoration: const InputDecoration(
                  labelText: "Emotion",
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Emotion is required.";
                  }

                  return null;
                },
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _noteController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: "Notes",
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _viewModel.isSaving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: _viewModel.isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
