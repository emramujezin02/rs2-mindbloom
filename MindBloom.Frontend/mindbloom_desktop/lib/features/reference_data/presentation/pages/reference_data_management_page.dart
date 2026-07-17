import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/therapist_specialization_model.dart';
import '../viewmodels/reference_data_management_viewmodel.dart';

class ReferenceDataManagementPage extends StatefulWidget {
  const ReferenceDataManagementPage({super.key});

  @override
  State<ReferenceDataManagementPage> createState() =>
      _ReferenceDataManagementPageState();
}

class _ReferenceDataManagementPageState
    extends State<ReferenceDataManagementPage> {
  late final ReferenceDataManagementViewModel _viewModel;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createReferenceDataManagementViewModel();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadSpecializations();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    _viewModel.dispose();

    _searchController.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_SpecializationFormResult>(
      context: context,
      builder: (_) {
        return const _SpecializationFormDialog();
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await _viewModel.createSpecialization(
      name: result.name,
      description: result.description,
      isActive: result.isActive,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Therapist specialization created successfully.'),
        ),
      );
    }
  }

  Future<void> _openEditDialog(
    TherapistSpecializationModel specialization,
  ) async {
    final result = await showDialog<_SpecializationFormResult>(
      context: context,
      builder: (_) {
        return _SpecializationFormDialog(specialization: specialization);
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await _viewModel.updateSpecialization(
      id: specialization.id,
      name: result.name,
      description: result.description,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Therapist specialization updated successfully.'),
        ),
      );
    }
  }

  Future<void> _confirmStatusChange(
    TherapistSpecializationModel specialization,
  ) async {
    final nextStatus = !specialization.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            nextStatus
                ? 'Activate specialization'
                : 'Deactivate specialization',
          ),
          content: Text(
            nextStatus
                ? 'Are you sure you want to activate "${specialization.name}"?'
                : 'Are you sure you want to deactivate "${specialization.name}"? Existing therapists will keep the specialization, but it will no longer be available for new selections.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(nextStatus ? 'Activate' : 'Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.updateStatus(
      specialization: specialization,
      isActive: nextStatus,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextStatus
                ? 'Specialization activated successfully.'
                : 'Specialization deactivated successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    TherapistSpecializationModel specialization,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete specialization'),
          content: Text(
            'Are you sure you want to delete "${specialization.name}"?\n\n'
            'A specialization used by therapists cannot be deleted. It must be deactivated instead.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
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

    final success = await _viewModel.deleteSpecialization(specialization.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specialization deleted successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildFilters(),
          const SizedBox(height: 16),
          if (_viewModel.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _viewModel.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(child: _buildContent()),
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reference data',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Manage therapist specializations used throughout the application.',
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _viewModel.isActionLoading ? null : _openCreateDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add specialization'),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 360,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Search specializations',
              hintText: 'Name or description',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () async {
                        _searchController.clear();

                        setState(() {});

                        await _viewModel.clearSearch();
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {});

              _viewModel.updateSearch(value);
            },
          ),
        ),
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<bool?>(
            initialValue: _viewModel.activeFilter,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem<bool?>(value: null, child: Text('All statuses')),
              DropdownMenuItem<bool?>(value: true, child: Text('Active')),
              DropdownMenuItem<bool?>(value: false, child: Text('Inactive')),
            ],
            onChanged: _viewModel.isLoading
                ? null
                : _viewModel.updateActiveFilter,
          ),
        ),
        SizedBox(
          width: 130,
          child: DropdownButtonFormField<int>(
            initialValue: _viewModel.pageSize,
            decoration: const InputDecoration(
              labelText: 'Page size',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 50, child: Text('50')),
            ],
            onChanged: _viewModel.isLoading
                ? null
                : (value) {
                    if (value != null) {
                      _viewModel.changePageSize(value);
                    }
                  },
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _viewModel.isLoading
              ? null
              : () {
                  _viewModel.loadSpecializations();
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.specializations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.specializations.isEmpty) {
      return const Center(
        child: Text('No specializations match the selected filters.'),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Description')),
              DataColumn(label: Text('Therapists')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _viewModel.specializations.map(_buildRow).toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildRow(TherapistSpecializationModel specialization) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              specialization.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 360,
            child: Text(
              specialization.description ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(specialization.therapistCount.toString())),
        DataCell(
          Chip(
            avatar: Icon(
              specialization.isActive ? Icons.check_circle : Icons.block,
              size: 18,
            ),
            label: Text(specialization.isActive ? 'Active' : 'Inactive'),
          ),
        ),
        DataCell(Text(formatter.format(specialization.createdAtUtc.toLocal()))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit specialization',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _openEditDialog(specialization);
                      },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: specialization.isActive ? 'Deactivate' : 'Activate',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _confirmStatusChange(specialization);
                      },
                icon: Icon(
                  specialization.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              IconButton(
                tooltip: specialization.therapistCount > 0
                    ? 'Specialization is in use'
                    : 'Delete specialization',
                onPressed:
                    _viewModel.isActionLoading ||
                        specialization.therapistCount > 0
                    ? null
                    : () {
                        _confirmDelete(specialization);
                      },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPagination() {
    final displayedTotalPages = _viewModel.totalPages == 0
        ? 1
        : _viewModel.totalPages;

    return Row(
      children: [
        Text('Total: ${_viewModel.totalCount}'),
        const Spacer(),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _viewModel.canGoPrevious && !_viewModel.isLoading
              ? _viewModel.previousPage
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('Page ${_viewModel.pageNumber} of $displayedTotalPages'),
        IconButton(
          tooltip: 'Next page',
          onPressed: _viewModel.canGoNext && !_viewModel.isLoading
              ? _viewModel.nextPage
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _SpecializationFormDialog extends StatefulWidget {
  final TherapistSpecializationModel? specialization;

  const _SpecializationFormDialog({this.specialization});

  @override
  State<_SpecializationFormDialog> createState() =>
      _SpecializationFormDialogState();
}

class _SpecializationFormDialogState extends State<_SpecializationFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late final TextEditingController _descriptionController;

  late bool _isActive;

  bool get _isEditing {
    return widget.specialization != null;
  }

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.specialization?.name ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.specialization?.description ?? '',
    );

    _isActive = widget.specialization?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();

    _descriptionController.dispose();

    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop(
      _SpecializationFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit specialization' : 'Add specialization'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final normalized = value?.trim() ?? '';

                  if (normalized.isEmpty) {
                    return 'Name is required.';
                  }

                  if (normalized.length < 2) {
                    return 'Name must contain at least 2 characters.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              if (!_isEditing)
                SwitchListTile(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: Text(
                    _isActive
                        ? 'The specialization will immediately be available for selection.'
                        : 'The specialization will be created as inactive.',
                  ),
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save),
          label: Text(_isEditing ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}

class _SpecializationFormResult {
  final String name;

  final String description;

  final bool isActive;

  const _SpecializationFormResult({
    required this.name,
    required this.description,
    required this.isActive,
  });
}
