import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/admin_page_header.dart';
import 'package:mindbloom_desktop/core/widgets/admin_status_badge.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/workshop_model.dart';
import '../viewmodels/workshop_management_viewmodel.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';

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

    await _viewModel.applyFilters();
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    await _viewModel.clearFilters();

    if (mounted) {
      setState(() {});
    }
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

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _viewModel.selectedType != null ||
        _viewModel.selectedStatus != null ||
        _viewModel.fromUtc != null ||
        _viewModel.toUtc != null;
  }

  Widget _buildActiveFilters() {
    if (!_hasActiveFilters) {
      return const SizedBox.shrink();
    }

    final formatter = DateFormat('dd.MM.yyyy.');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_searchController.text.trim().isNotEmpty)
          Chip(label: Text('Pretraga: ${_searchController.text.trim()}')),
        if (_viewModel.selectedType != null)
          Chip(
            label: Text(
              _viewModel.selectedType == 1 ? 'Tip: Online' : 'Tip: Uživo',
            ),
          ),
        if (_viewModel.selectedStatus != null)
          Chip(
            label: Text(
              'Status: ${_workshopStatusLabel(_viewModel.selectedStatus!)}',
            ),
          ),
        if (_viewModel.fromUtc != null)
          Chip(label: Text('Od: ${formatter.format(_viewModel.fromUtc!)}')),
        if (_viewModel.toUtc != null)
          Chip(label: Text('Do: ${formatter.format(_viewModel.toUtc!)}')),
        ActionChip(
          avatar: const Icon(Icons.filter_alt_off, size: 18),
          label: const Text('Resetuj filtere'),
          onPressed: _viewModel.isLoading ? null : _clearFilters,
        ),
      ],
    );
  }

  String _workshopStatusLabel(int value) {
    switch (value) {
      case 1:
        return 'Zakazana';
      case 2:
        return 'Otkazana';
      case 3:
        return 'Završena';
      case 4:
        return 'Neaktivna';
      default:
        return value.toString();
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
          content: AppResponsiveDialogContent(
            preferredWidth: 480,
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
    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Obriši radionicu',
      message:
          'Da li ste sigurni da želite obrisati "${workshop.title}"?\n\n'
          'Radionica sa aktivnim prijavama ne može biti obrisana. '
          'Takvu radionicu je potrebno otkazati.',
      confirmText: 'Obriši',
      destructive: true,
      icon: Icons.delete_outline,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await _viewModel.deleteWorkshop(workshop.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Radionica je obrisana.')));
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
          AdminPageHeader(
            title: 'Workshops management',
            subtitle: 'Create, edit, cancel and review workshop registrations.',
            icon: Icons.event_available_outlined,
            trailing: FilledButton.icon(
              onPressed: _openCreatePage,
              icon: const Icon(Icons.add),
              label: const Text('Create workshop'),
            ),
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
                      onChanged: _viewModel.updateSearch,
                      onSubmitted: (_) {
                        _applyFilters();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Pretraga',
                        hintText: 'Naziv, opis ili organizator',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
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
                        DropdownMenuItem<int?>(
                          value: 4,
                          child: Text('Inactive'),
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
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            _buildActiveFilters(),
          ],
          if (_viewModel.error != null) ...[
            const SizedBox(height: 12),
            AppErrorBanner(
              message: _viewModel.error!,
              onDismiss: _viewModel.clearError,
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
      return const AdminTableLoadingState(message: 'Učitavanje radionica...');
    }

    if (_viewModel.workshops.isEmpty && _viewModel.error != null) {
      return AdminTableErrorState(
        message: _viewModel.error!,
        onRetry: () {
          _viewModel.loadWorkshops();
        },
      );
    }

    if (_viewModel.workshops.isEmpty) {
      return AdminTableEmptyState(
        icon: Icons.event_available_outlined,
        title: _hasActiveFilters ? 'Nema rezultata' : 'Nema radionica',
        message: _hasActiveFilters
            ? 'Nijedna radionica ne odgovara odabranim filterima.'
            : 'Trenutno nema kreiranih radionica.',
        onResetFilters: _hasActiveFilters ? _clearFilters : null,
      );
    }

    return AdminTableContainer(
      minimumWidth: 1450,
      child: _buildWorkshopTable(),
    );
  }

  Widget _buildWorkshopTable() {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return DataTable(
      columnSpacing: 28,
      horizontalMargin: 24,
      headingRowHeight: 54,
      dataRowMinHeight: 64,
      dataRowMaxHeight: 78,
      columns: const [
        DataColumn(label: Text('Radionica')),
        DataColumn(label: Text('Tip')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Početak')),
        DataColumn(label: Text('Trajanje')),
        DataColumn(label: Text('Predavač')),
        DataColumn(label: Text('Prijave')),
        DataColumn(label: Text('Cijena')),
        DataColumn(label: Text('Akcije')),
      ],
      rows: _viewModel.workshops.map((workshop) {
        return DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: 300,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshop.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workshop.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            DataCell(Text(workshop.isOnline ? 'Online' : 'Uživo')),
            DataCell(
              AdminStatusBadge(
                label: workshop.status,
                tone: _statusTone(workshop.status),
                icon: _statusIcon(workshop.status),
              ),
            ),
            DataCell(Text(formatter.format(workshop.startUtc.toLocal()))),
            DataCell(Text(_formatWorkshopDuration(workshop.duration))),
            DataCell(
              SizedBox(
                width: 180,
                child: Text(
                  workshop.presenterName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(Text('${workshop.registeredCount}/${workshop.capacity}')),
            DataCell(Text('${workshop.price.toStringAsFixed(2)} KM')),
            DataCell(
              AdminTableActionMenu<String>(
                enabled: !_viewModel.isActionLoading,
                actions: [
                  const AdminTableAction<String>(
                    value: 'details',
                    label: 'Detalji',
                    icon: Icons.visibility_outlined,
                  ),
                  AdminTableAction<String>(
                    value: 'edit',
                    label: 'Uredi',
                    icon: Icons.edit_outlined,
                    enabled: workshop.isScheduled,
                  ),
                  AdminTableAction<String>(
                    value: 'cancel',
                    label: 'Otkaži radionicu',
                    icon: Icons.cancel_outlined,
                    destructive: true,
                    enabled: workshop.isScheduled,
                  ),
                  AdminTableAction<String>(
                    value: 'delete',
                    label: 'Obriši',
                    icon: Icons.delete_outline,
                    destructive: true,
                    enabled: workshop.registeredCount == 0,
                  ),
                ],
                onSelected: (action) {
                  switch (action) {
                    case 'details':
                      _openDetails(workshop);
                      break;

                    case 'edit':
                      _openEditPage(workshop);
                      break;

                    case 'cancel':
                      _showCancelDialog(workshop);
                      break;

                    case 'delete':
                      _showDeleteDialog(workshop);
                      break;
                  }
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatWorkshopDuration(Duration duration) {
    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0 && minutes > 0) {
      return '$hours h $minutes min';
    }

    if (hours > 0) {
      return '$hours h';
    }

    return '$minutes min';
  }

  Widget _buildPagination() {
    return AdminTablePagination(
      pageNumber: _viewModel.pageNumber,
      pageSize: _viewModel.pageSize,
      totalCount: _viewModel.totalCount,
      totalPages: _viewModel.totalPages,
      isLoading: _viewModel.isLoading,
      onPreviousPage: _viewModel.hasPreviousPage
          ? _viewModel.previousPage
          : null,
      onNextPage: _viewModel.hasNextPage ? _viewModel.nextPage : null,
      onPageSizeChanged: _viewModel.changePageSize,
    );
  }
}

AdminStatusTone _statusTone(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized == 'scheduled' || normalized == 'active') {
    return AdminStatusTone.success;
  }

  if (normalized == 'completed') {
    return AdminStatusTone.info;
  }

  if (normalized == 'cancelled' || normalized == 'inactive') {
    return AdminStatusTone.danger;
  }

  return AdminStatusTone.neutral;
}

IconData _statusIcon(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized == 'scheduled' || normalized == 'active') {
    return Icons.event_available;
  }

  if (normalized == 'completed') {
    return Icons.check_circle;
  }

  if (normalized == 'cancelled' || normalized == 'inactive') {
    return Icons.cancel;
  }

  return Icons.info_outline;
}
