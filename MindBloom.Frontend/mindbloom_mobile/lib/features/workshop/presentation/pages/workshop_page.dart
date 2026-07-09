import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../viewmodels/workshop_viewmodel.dart';

class WorkshopPage extends StatefulWidget {
  const WorkshopPage({super.key});

  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends State<WorkshopPage> {
  final WorkshopViewModel _viewModel = AppInjection.createWorkshopViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_refresh);
    _viewModel.loadWorkshops();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_refresh);
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
      appBar: AppBar(title: const Text("Workshops")),
      body: _viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _viewModel.workshops.length,
              itemBuilder: (context, index) {
                final workshop = _viewModel.workshops[index];

                return Card(
                  margin: const EdgeInsets.all(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          workshop.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(workshop.description),

                        const SizedBox(height: 12),

                        Text('Available seats: ${workshop.availableSeats}'),

                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              await _viewModel.register(workshop.id);

                              if (!context.mounted) {
                                return;
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Successfully registered."),
                                ),
                              );
                            },
                            child: const Text("Register"),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
