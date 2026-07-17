import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/workshop_model.dart';
import '../viewmodels/workshop_management_viewmodel.dart';

class WorkshopManagementPage extends StatefulWidget {
  const WorkshopManagementPage({super.key});

  @override
  State<WorkshopManagementPage> createState() => _WorkshopManagementPageState();
}

class _WorkshopManagementPageState extends State<WorkshopManagementPage> {
  final WorkshopManagementViewModel _viewModel =
      AppInjection.createWorkshopManagementViewModel();

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadWorkshops();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _searchController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _applyFilters() async {
    _viewModel.search = _searchController.text.trim();

    await _viewModel.loadWorkshops(resetPage: true);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    _viewModel.clearFilters();

    await _viewModel.loadWorkshops(resetPage: true);
  }

  Future<void> _selectFromDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _viewModel.fromUtc?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (selectedDate == null) {
      return;
    }

    _viewModel.fromUtc = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    setState(() {});
  }

  Future<void> _selectToDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _viewModel.toUtc?.toLocal() ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );

    if (selectedDate == null) {
      return;
    }

    _viewModel.toUtc = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      23,
      59,
      59,
    );

    setState(() {});
  }

  Future<void> _openCreatePage() async {
    final changed = await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopManagementForm);

    if (changed == true) {
      await _viewModel.loadWorkshops();
    }
  }

  Future<void> _openEditPage(WorkshopModel workshop) async {
    final changed = await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopManagementForm, arguments: workshop.id);

    if (changed == true) {
      await _viewModel.loadWorkshops();
    }
  }

  Future<void> _openDetails(WorkshopModel workshop) async {
    final changed = await Navigator.of(
      context,
    ).pushNamed(AppRouter.workshopManagementDetails, arguments: workshop.id);

    if (changed == true) {
      await _viewModel.loadWorkshops();
    }
  }

  Future<void> _showCancelDialog(WorkshopModel workshop) async {
    final reasonController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel workshop'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: TextFormField(
                controller: reasonController,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Cancellation reason',
                  hintText: 'Enter the reason for cancelling this workshop.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  final reason = value?.trim() ?? '';

                  if (reason.isEmpty) {
                    return 'Cancellation reason is required.';
                  }

                  if (reason.length < 5) {
                    return 'Reason must contain at least 5 characters.';
                  }

                  return null;
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (!formKey.currentState!.validate()) {
                  return;
                }

                Navigator.of(dialogContext).pop(reasonController.text.trim());
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel workshop'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || !mounted) {
      return;
    }

    final success = await _viewModel.cancelWorkshop(
      workshopId: workshop.id,
      reason: reason,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop cancelled successfully.')),
      );
    }
  }

  Future<void> _showDeleteDialog(WorkshopModel workshop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete workshop'),
          content: Text(
            'Are you sure you want to delete "${workshop.title}"?\n\n'
            'A workshop with active registrations cannot be deleted. '
            'Such a workshop must be cancelled instead.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Back'),
            ),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.deleteWorkshop(workshop.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workshop deleted successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd.MM.yyyy.');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Workshops management',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Create, edit, cancel and review workshop registrations.',
                  ),
                ],
              ),
              FilledButton.icon(
                onPressed: _openCreatePage,
                icon: const Icon(Icons.add),
                label: const Text('Create workshop'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search',
                        hintText: 'Title, description or organizer',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        _applyFilters();
                      },
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _viewModel.selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All types'),
                        ),
                        DropdownMenuItem<int?>(value: 1, child: Text('Online')),
                        DropdownMenuItem<int?>(
                          value: 2,
                          child: Text('In person'),
                        ),
                      ],
                      onChanged: (value) {
                        _viewModel.selectedType = value;
                      },
                    ),
                  ),
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<int?>(
                      initialValue: _viewModel.selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All statuses'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 1,
                          child: Text('Scheduled'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 2,
                          child: Text('Cancelled'),
                        ),
                        DropdownMenuItem<int?>(
                          value: 3,
                          child: Text('Completed'),
                        ),
                      ],
                      onChanged: (value) {
                        _viewModel.selectedStatus = value;
                      },
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectFromDate,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _viewModel.fromUtc == null
                          ? 'From date'
                          : 'From: ${dateFormatter.format(_viewModel.fromUtc!)}',
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _selectToDate,
                    icon: const Icon(Icons.event),
                    label: Text(
                      _viewModel.toUtc == null
                          ? 'To date'
                          : 'To: ${dateFormatter.format(_viewModel.toUtc!)}',
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _viewModel.isLoading ? null : _applyFilters,
                    icon: const Icon(Icons.filter_alt),
                    label: const Text('Apply'),
                  ),
                  TextButton.icon(
                    onPressed: _viewModel.isLoading ? null : _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ],
              ),
            ),
          ),
          if (_viewModel.error != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _viewModel.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Expanded(child: _buildContent()),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.workshops.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.workshops.isEmpty) {
      return const Card(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Text('No workshops match the selected filters.'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _viewModel.loadWorkshops,
      child: ListView.separated(
        itemCount: _viewModel.workshops.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _WorkshopCard(
            workshop: _viewModel.workshops[index],
            onDetails: _openDetails,
            onEdit: _openEditPage,
            onCancel: _showCancelDialog,
            onDelete: _showDeleteDialog,
          );
        },
      ),
    );
  }

  Widget _buildPagination() {
    final displayedTotalPages = _viewModel.totalPages < 1
        ? 1
        : _viewModel.totalPages;

    return Row(
      children: [
        Text('${_viewModel.totalCount} workshops'),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _viewModel.isLoading || _viewModel.pageNumber <= 1
              ? null
              : _viewModel.previousPage,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page ${_viewModel.pageNumber} of $displayedTotalPages'),
        IconButton(
          tooltip: 'Next page',
          onPressed:
              _viewModel.isLoading ||
                  _viewModel.pageNumber >= _viewModel.totalPages
              ? null
              : _viewModel.nextPage,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _WorkshopCard extends StatelessWidget {
  final WorkshopModel workshop;

  final ValueChanged<WorkshopModel> onDetails;

  final ValueChanged<WorkshopModel> onEdit;

  final ValueChanged<WorkshopModel> onCancel;

  final ValueChanged<WorkshopModel> onDelete;

  const _WorkshopCard({
    required this.workshop,
    required this.onDetails,
    required this.onEdit,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              child: Icon(
                workshop.isOnline
                    ? Icons.video_camera_front_outlined
                    : Icons.location_on_outlined,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        workshop.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(label: Text(workshop.status)),
                      Chip(label: Text(workshop.type)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    workshop.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      Text(
                        'Start: ${formatter.format(workshop.startUtc.toLocal())}',
                      ),
                      Text('Organizer: ${workshop.organizerName}'),
                      Text(
                        'Registrations: ${workshop.registeredCount}/${workshop.capacity}',
                      ),
                      Text('Available: ${workshop.availableSeats}'),
                      Text('Price: ${workshop.price.toStringAsFixed(2)} KM'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'details':
                    onDetails(workshop);
                    break;

                  case 'edit':
                    onEdit(workshop);
                    break;

                  case 'cancel':
                    onCancel(workshop);
                    break;

                  case 'delete':
                    onDelete(workshop);
                    break;
                }
              },
              itemBuilder: (context) {
                return [
                  const PopupMenuItem(
                    value: 'details',
                    child: ListTile(
                      leading: Icon(Icons.visibility_outlined),
                      title: Text('Details'),
                    ),
                  ),
                  if (workshop.isScheduled)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                      ),
                    ),
                  if (workshop.isScheduled)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: ListTile(
                        leading: Icon(Icons.cancel_outlined),
                        title: Text('Cancel'),
                      ),
                    ),
                  if (workshop.registeredCount == 0)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }
}
