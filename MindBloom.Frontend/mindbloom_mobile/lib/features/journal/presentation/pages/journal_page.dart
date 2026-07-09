import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/journal_viewmodel.dart';

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
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {},
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: viewModel.entries.length,
              itemBuilder: (context, index) {
                final entry = viewModel.entries[index];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: ListTile(
                    title: Text(entry.emotion),
                    subtitle: Text(entry.note),
                    trailing: Text(entry.mood.toString()),
                  ),
                );
              },
            ),
    );
  }
}
