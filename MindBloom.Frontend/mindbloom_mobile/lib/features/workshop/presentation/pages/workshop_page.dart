import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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

  Future<void> _openWorkshop(int workshopId) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopDetails, arguments: workshopId);

    if (!mounted) {
      return;
    }

    await _viewModel.loadWorkshops(search: _viewModel.currentSearch);
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
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
                IconButton(
                  onPressed: _clearSearch,
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
    if (_viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.workshops.isEmpty) {
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

    if (_viewModel.workshops.isEmpty) {
      return const Center(child: Text('No workshops were found.'));
    }

    return RefreshIndicator(
      onRefresh: () =>
          _viewModel.loadWorkshops(search: _viewModel.currentSearch),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount:
            _viewModel.workshops.length + (_viewModel.hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _viewModel.workshops.length) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: _viewModel.isLoadingMore
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _viewModel.loadMoreWorkshops,
                        child: const Text('Load more'),
                      ),
              ),
            );
          }

          final workshop = _viewModel.workshops[index];

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
