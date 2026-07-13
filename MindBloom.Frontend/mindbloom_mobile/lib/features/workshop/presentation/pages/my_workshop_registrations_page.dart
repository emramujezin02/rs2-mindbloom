import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/workshop_viewmodel.dart';

class MyWorkshopRegistrationsPage extends StatefulWidget {
  const MyWorkshopRegistrationsPage({super.key});

  @override
  State<MyWorkshopRegistrationsPage> createState() =>
      _MyWorkshopRegistrationsPageState();
}

class _MyWorkshopRegistrationsPageState
    extends State<MyWorkshopRegistrationsPage> {
  final WorkshopViewModel _viewModel = AppInjection.createWorkshopViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadMyRegistrations();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openDetails(int workshopId) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopDetails, arguments: workshopId);

    if (!mounted) {
      return;
    }

    await _viewModel.loadMyRegistrations();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My workshop registrations')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.myRegistrations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _viewModel.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_viewModel.myRegistrations.isEmpty) {
      return const Center(
        child: Text('You do not have active workshop registrations.'),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return RefreshIndicator(
      onRefresh: _viewModel.loadMyRegistrations,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount:
            _viewModel.myRegistrations.length +
            (_viewModel.hasMoreRegistrationPages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _viewModel.myRegistrations.length) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ElevatedButton(
                  onPressed: _viewModel.isLoadingMore
                      ? null
                      : _viewModel.loadMoreMyRegistrations,
                  child: _viewModel.isLoadingMore
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Load more'),
                ),
              ),
            );
          }

          final workshop = _viewModel.myRegistrations[index];

          return Card(
            child: ListTile(
              onTap: () {
                _openDetails(workshop.id);
              },
              leading: Icon(
                workshop.isOnline ? Icons.video_call : Icons.location_on,
              ),
              title: Text(workshop.title),
              subtitle: Text(
                '${formatter.format(workshop.startUtc.toLocal())}\n'
                '${workshop.availableSeats} available seats',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
            ),
          );
        },
      ),
    );
  }
}
