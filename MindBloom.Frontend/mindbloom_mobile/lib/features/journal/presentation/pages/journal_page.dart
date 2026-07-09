import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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

  Future<void> _addEntry() async {
    final result = await Navigator.pushNamed(
      context,
      AppRouter.addJournalEntry,
    );

    if (result == true) {
      await viewModel.loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Journal")),
      floatingActionButton: FloatingActionButton(
        onPressed: _addEntry,
        child: const Icon(Icons.add),
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
                    leading: CircleAvatar(child: Text(entry.mood.toString())),
                    title: Text(entry.emotion),
                    subtitle: Text(entry.note),
                  ),
                );
              },
            ),
    );
  }
}
