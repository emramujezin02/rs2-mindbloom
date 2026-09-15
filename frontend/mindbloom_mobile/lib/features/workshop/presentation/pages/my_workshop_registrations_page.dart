import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
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

    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _reload() {
    return _viewModel.loadMyRegistrations();
  }

  Future<void> _openDetails(int workshopId) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopDetails, arguments: workshopId);

    if (!mounted) {
      return;
    }

    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My workshop registrations')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.myRegistrations.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading your workshop registrations...',
        skeletonItemCount: 4,
      );
    }

    if (_viewModel.error != null && _viewModel.myRegistrations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: AppErrorWidget(
          title: 'Workshop registrations could not be loaded',
          error: _viewModel.error,
          onRetry: _reload,
        ),
      );
    }

    if (_viewModel.myRegistrations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: const AppEmptyStateWidget(
          title: 'No active registrations',
          message: 'You do not have any active workshop registrations.',
          icon: Icons.event_available_outlined,
        ),
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          if (_viewModel.error != null)
            AppInlineError(
              title: 'Registrations could not be refreshed',
              error: _viewModel.error,
              onRetry: _reload,
              margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
            ),

          ..._viewModel.myRegistrations.map((workshop) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
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
              ),
            );
          }),

          if (_viewModel.isLoadingMore)
            const AppLoadMoreIndicator(
              loadingMessage: 'Loading more registrations...',
            )
          else if (_viewModel.registrationLoadMoreError != null)
            AppLoadMoreError(
              error: _viewModel.registrationLoadMoreError,
              fallbackMessage:
                  'More workshop registrations could not be loaded.',
              onRetry: _viewModel.retryLoadMoreMyRegistrations,
            )
          else if (_viewModel.hasMoreRegistrationPages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: OutlinedButton.icon(
                onPressed: _viewModel.loadMoreMyRegistrations,
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'All registrations have been loaded.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
