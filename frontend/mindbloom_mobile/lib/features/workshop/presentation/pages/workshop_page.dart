import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../data/models/workshop_model.dart';
import '../viewmodels/workshop_viewmodel.dart';

class WorkshopPage extends StatefulWidget {
  const WorkshopPage({super.key});

  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _WorkshopPageState extends State<WorkshopPage> {
  final WorkshopViewModel _viewModel = AppInjection.createWorkshopViewModel();

  final TextEditingController _searchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _scrollController.addListener(_onScroll);

    _viewModel.loadWorkshops();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _scrollController.removeListener(_onScroll);

    _searchController.dispose();
    _scrollController.dispose();
    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 150) {
      _viewModel.loadMoreWorkshops();
    }
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();

    await _viewModel.loadWorkshops(search: _searchController.text.trim());
  }

  Future<void> _clearSearch() async {
    _searchController.clear();

    FocusScope.of(context).unfocus();

    await _viewModel.loadWorkshops();
  }

  Future<void> _refresh() {
    return _viewModel.loadWorkshops(search: _viewModel.currentSearch);
  }

  Future<void> _openWorkshop(int workshopId) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopDetails, arguments: workshopId);

    if (!mounted) {
      return;
    }

    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workshops'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed(AppRouter.myWorkshopRegistrations);
            },
            tooltip: 'My registrations',
            icon: const Icon(Icons.event_available),
          ),
          IconButton(
            onPressed: _viewModel.isLoading ? null : _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    enabled: !_viewModel.isLoading,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      _search();
                    },
                    decoration: const InputDecoration(
                      labelText: 'Search workshops',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _viewModel.isLoading ? null : _search,
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  onPressed: _viewModel.isLoading ? null : _clearSearch,
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.workshops.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading workshops...',
        skeletonItemCount: 5,
      );
    }

    if (_viewModel.error != null && _viewModel.workshops.isEmpty) {
      return AppErrorWidget(
        title: 'Workshops could not be loaded',
        error: _viewModel.error,
        onRetry: _refresh,
      );
    }

    if (_viewModel.workshops.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: AppEmptyStateWidget(
          title: _viewModel.currentSearch.trim().isNotEmpty
              ? 'No matching workshops'
              : 'No workshops available',
          message: _viewModel.currentSearch.trim().isNotEmpty
              ? 'No workshops match your search. Try another search term.'
              : 'There are currently no available workshops.',
          icon: _viewModel.currentSearch.trim().isNotEmpty
              ? Icons.search_off_outlined
              : Icons.groups_outlined,
          actionLabel: _viewModel.currentSearch.trim().isNotEmpty
              ? 'Clear search'
              : 'Refresh',
          onAction: _viewModel.currentSearch.trim().isNotEmpty
              ? _clearSearch
              : _refresh,
        ),
      );
    }

    final extraItems =
        (_viewModel.error != null ? 1 : 0) + (_viewModel.hasMorePages ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        itemCount: _viewModel.workshops.length + extraItems,
        itemBuilder: (context, index) {
          if (_viewModel.error != null && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppInlineError(
                title: 'Workshops could not be refreshed',
                error: _viewModel.error,
                onRetry: _refresh,
              ),
            );
          }

          final adjustedIndex = index - (_viewModel.error != null ? 1 : 0);

          if (adjustedIndex >= _viewModel.workshops.length) {
            if (_viewModel.isLoadingMore) {
              return const AppLoadMoreIndicator(
                loadingMessage: 'Loading more workshops...',
              );
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _viewModel.loadMoreWorkshops,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load more'),
                ),
              ),
            );
          }

          final workshop = _viewModel.workshops[adjustedIndex];

          return _WorkshopCard(
            workshop: workshop,
            onTap: () {
              _openWorkshop(workshop.id);
            },
          );
        },
      ),
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  final WorkshopModel workshop;
  final VoidCallback onTap;

  const _WorkshopCard({required this.workshop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workshop.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (workshop.isRegistered) const Icon(Icons.check_circle),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                workshop.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.calendar_month, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(formatter.format(workshop.startUtc.toLocal())),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    workshop.isOnline ? Icons.video_call : Icons.location_on,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(workshop.type),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people, size: 18),
                  const SizedBox(width: 8),
                  Text('${workshop.availableSeats} available seats'),
                  const Spacer(),
                  Text(
                    '${workshop.price.toStringAsFixed(2)} KM',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (workshop.isRegistered) ...[
                const SizedBox(height: 10),
                const Text(
                  'You are registered',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
