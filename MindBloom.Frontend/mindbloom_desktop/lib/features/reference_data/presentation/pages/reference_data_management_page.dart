import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/therapy_approach_model.dart';
import '../../../../app/di/injection.dart';
import '../../data/models/therapist_specialization_model.dart';
import '../viewmodels/reference_data_management_viewmodel.dart';
import '../../data/models/article_category_reference_model.dart';

enum _ReferenceDataSection {
  specializations,
  therapyApproaches,
  articleCategories,
}

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
  _ReferenceDataSection _selectedSection =
      _ReferenceDataSection.specializations;
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

  Future<void> _openCreateArticleCategoryDialog() async {
    final result = await showDialog<_ArticleCategoryFormResult>(
      context: context,
      builder: (_) {
        return const _ArticleCategoryFormDialog();
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await _viewModel.createArticleCategory(
      name: result.name,
      description: result.description,
      isActive: result.isActive,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article category created successfully.')),
      );
    }
  }

  Future<void> _openEditArticleCategoryDialog(
    ArticleCategoryReferenceModel category,
  ) async {
    final result = await showDialog<_ArticleCategoryFormResult>(
      context: context,
      builder: (_) {
        return _ArticleCategoryFormDialog(category: category);
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await _viewModel.updateArticleCategory(
      id: category.id,
      name: result.name,
      description: result.description,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article category updated successfully.')),
      );
    }
  }

  Future<void> _confirmArticleCategoryStatusChange(
    ArticleCategoryReferenceModel category,
  ) async {
    final nextStatus = !category.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            nextStatus
                ? 'Activate article category'
                : 'Deactivate article category',
          ),
          content: Text(
            nextStatus
                ? 'Are you sure you want to activate "${category.name}"?'
                : 'Are you sure you want to deactivate "${category.name}"? '
                      'Existing articles will keep this category, but it will no longer '
                      'be available for new article selections.',
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

    final success = await _viewModel.updateArticleCategoryStatus(
      category: category,
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
                ? 'Article category activated successfully.'
                : 'Article category deactivated successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteArticleCategory(
    ArticleCategoryReferenceModel category,
  ) async {
    if (category.articleCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This category is used by ${category.articleCount} article(s). '
            'Deactivate it instead.',
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete article category'),
          content: Text('Are you sure you want to delete "${category.name}"?'),
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

    final success = await _viewModel.deleteArticleCategory(category.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Article category deleted successfully.')),
      );
    }
  }

  Future<void> _loadCurrentSection({int? requestedPage}) async {
    switch (_selectedSection) {
      case _ReferenceDataSection.specializations:
        await _viewModel.loadSpecializations(requestedPage: requestedPage);

        break;

      case _ReferenceDataSection.therapyApproaches:
        await _viewModel.loadTherapyApproaches(requestedPage: requestedPage);

        break;

      case _ReferenceDataSection.articleCategories:
        await _viewModel.loadArticleCategories(requestedPage: requestedPage);

        break;
    }
  }

  Future<void> _changeSection(_ReferenceDataSection section) async {
    if (_selectedSection == section) {
      return;
    }

    setState(() {
      _selectedSection = section;

      _searchController.clear();
    });

    switch (section) {
      case _ReferenceDataSection.specializations:
        _viewModel.search = '';
        break;

      case _ReferenceDataSection.therapyApproaches:
        _viewModel.therapyApproachSearch = '';
        break;

      case _ReferenceDataSection.articleCategories:
        _viewModel.articleCategorySearch = '';
        break;
    }

    await _loadCurrentSection(requestedPage: 1);
  }

  Future<void> _openCreateTherapyApproachDialog() async {
    final result = await showDialog<_TherapyApproachFormResult>(
      context: context,
      builder: (_) {
        return const _TherapyApproachFormDialog();
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await _viewModel.createTherapyApproach(
      name: result.name,
      description: result.description,
      isActive: result.isActive,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapy approach created successfully.')),
      );
    }
  }

  Future<void> _openEditTherapyApproachDialog(
    TherapyApproachModel approach,
  ) async {
    final result = await showDialog<_TherapyApproachFormResult>(
      context: context,
      builder: (_) {
        return _TherapyApproachFormDialog(approach: approach);
      },
    );

    if (result == null || !mounted) {
      return;
    }

    final success = await _viewModel.updateTherapyApproach(
      id: approach.id,
      name: result.name,
      description: result.description,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapy approach updated successfully.')),
      );
    }
  }

  Future<void> _confirmTherapyApproachStatusChange(
    TherapyApproachModel approach,
  ) async {
    final nextStatus = !approach.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            nextStatus
                ? 'Activate therapy approach'
                : 'Deactivate therapy approach',
          ),
          content: Text(
            nextStatus
                ? 'Are you sure you want to activate "${approach.name}"?'
                : 'Are you sure you want to deactivate "${approach.name}"? Existing therapists and clients will keep this value, but it will no longer be offered for new selections.',
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

    final success = await _viewModel.updateTherapyApproachStatus(
      approach: approach,
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
                ? 'Therapy approach activated successfully.'
                : 'Therapy approach deactivated successfully.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDeleteTherapyApproach(
    TherapyApproachModel approach,
  ) async {
    final totalUsage = approach.therapistCount + approach.clientCount;

    if (totalUsage > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This therapy approach is used by '
            '${approach.therapistCount} therapist(s) and '
            '${approach.clientCount} client(s). '
            'Deactivate it instead.',
          ),
        ),
      );

      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete therapy approach'),
          content: Text('Are you sure you want to delete "${approach.name}"?'),
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

    final success = await _viewModel.deleteTherapyApproach(approach.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Therapy approach deleted successfully.')),
      );
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
    final isSpecializations =
        _selectedSection == _ReferenceDataSection.specializations;

    final isTherapyApproaches =
        _selectedSection == _ReferenceDataSection.therapyApproaches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reference data',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSpecializations
                        ? 'Manage therapist specializations used throughout the application.'
                        : 'Manage therapy approaches used by therapists and clients.',
                  ),
                ],
              ),
            ),

            ElevatedButton.icon(
              onPressed: _viewModel.isActionLoading
                  ? null
                  : isSpecializations
                  ? _openCreateDialog
                  : isTherapyApproaches
                  ? _openCreateTherapyApproachDialog
                  : _openCreateArticleCategoryDialog,
              icon: const Icon(Icons.add),
              label: Text(
                isSpecializations
                    ? 'Add specialization'
                    : isTherapyApproaches
                    ? 'Add therapy approach'
                    : 'Add article category',
              ),
            ),
            Text(
              isSpecializations
                  ? 'Manage therapist specializations used throughout the application.'
                  : isTherapyApproaches
                  ? 'Manage therapy approaches used by therapists and clients.'
                  : 'Manage article categories used by educational articles.',
            ),
          ],
        ),

        const SizedBox(height: 20),

        SegmentedButton<_ReferenceDataSection>(
          segments: const [
            ButtonSegment<_ReferenceDataSection>(
              value: _ReferenceDataSection.specializations,
              icon: Icon(Icons.psychology_outlined),
              label: Text('Therapist specializations'),
            ),
            ButtonSegment<_ReferenceDataSection>(
              value: _ReferenceDataSection.therapyApproaches,
              icon: Icon(Icons.route_outlined),
              label: Text('Therapy approaches'),
            ),
            ButtonSegment<_ReferenceDataSection>(
              value: _ReferenceDataSection.articleCategories,
              icon: Icon(Icons.category_outlined),
              label: Text('Article categories'),
            ),
          ],
          selected: {_selectedSection},
          onSelectionChanged: _viewModel.isLoading
              ? null
              : (selection) {
                  _changeSection(selection.first);
                },
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final isSpecializations =
        _selectedSection == _ReferenceDataSection.specializations;

    final isTherapyApproaches =
        _selectedSection == _ReferenceDataSection.therapyApproaches;

    final activeFilter = isSpecializations
        ? _viewModel.activeFilter
        : isTherapyApproaches
        ? _viewModel.therapyApproachActiveFilter
        : _viewModel.articleCategoryActiveFilter;

    final pageSize = isSpecializations
        ? _viewModel.pageSize
        : isTherapyApproaches
        ? _viewModel.therapyApproachPageSize
        : _viewModel.articleCategoryPageSize;

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
              labelText: isSpecializations
                  ? 'Search specializations'
                  : isTherapyApproaches
                  ? 'Search therapy approaches'
                  : 'Search article categories',
              hintText: 'Name or description',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () async {
                        _searchController.clear();

                        setState(() {});

                        if (isSpecializations) {
                          await _viewModel.clearSearch();
                        } else if (isTherapyApproaches) {
                          _viewModel.therapyApproachSearch = '';

                          await _viewModel.loadTherapyApproaches(
                            requestedPage: 1,
                          );
                        } else {
                          _viewModel.articleCategorySearch = '';

                          await _viewModel.loadArticleCategories(
                            requestedPage: 1,
                          );
                        }
                      },
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {});

              if (isSpecializations) {
                _viewModel.updateSearch(value);
              } else if (isTherapyApproaches) {
                _viewModel.therapyApproachSearch = value.trim();

                _viewModel.loadTherapyApproaches(requestedPage: 1);
              } else {
                _viewModel.articleCategorySearch = value.trim();

                _viewModel.loadArticleCategories(requestedPage: 1);
              }
            },
          ),
        ),

        SizedBox(
          width: 200,
          child: DropdownButtonFormField<bool?>(
            initialValue: activeFilter,
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
                : (value) async {
                    if (isSpecializations) {
                      await _viewModel.updateActiveFilter(value);
                    } else if (isTherapyApproaches) {
                      _viewModel.therapyApproachActiveFilter = value;

                      await _viewModel.loadTherapyApproaches(requestedPage: 1);
                    } else {
                      _viewModel.articleCategoryActiveFilter = value;

                      await _viewModel.loadArticleCategories(requestedPage: 1);
                    }
                  },
          ),
        ),

        SizedBox(
          width: 130,
          child: DropdownButtonFormField<int>(
            initialValue: pageSize,
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
                : (value) async {
                    if (value == null) {
                      return;
                    }

                    if (isSpecializations) {
                      await _viewModel.changePageSize(value);
                    } else if (isTherapyApproaches) {
                      _viewModel.therapyApproachPageSize = value;

                      await _viewModel.loadTherapyApproaches(requestedPage: 1);
                    } else {
                      _viewModel.articleCategoryPageSize = value;

                      await _viewModel.loadArticleCategories(requestedPage: 1);
                    }
                  },
          ),
        ),

        IconButton(
          tooltip: 'Refresh',
          onPressed: _viewModel.isLoading
              ? null
              : () {
                  _loadCurrentSection();
                },
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedSection) {
      case _ReferenceDataSection.specializations:
        return _buildSpecializationsContent();

      case _ReferenceDataSection.therapyApproaches:
        return _buildTherapyApproachesContent();

      case _ReferenceDataSection.articleCategories:
        return _buildArticleCategoriesContent();
    }
  }

  Widget _buildArticleCategoriesContent() {
    if (_viewModel.isLoading && _viewModel.articleCategories.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.articleCategories.isEmpty) {
      return const Center(
        child: Text('No article categories match the selected filters.'),
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
              DataColumn(label: Text('Articles')),
              DataColumn(label: Text('Used by')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _viewModel.articleCategories
                .map(_buildArticleCategoryRow)
                .toList(),
          ),
        ),
      ),
    );
  }

  DataRow _buildArticleCategoryRow(ArticleCategoryReferenceModel category) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 360,
            child: Text(
              category.description ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text(category.articleCount.toString())),
        DataCell(
          Text(
            category.articleCount == 0
                ? 'Not currently used'
                : 'Used by ${category.articleCount} article(s)',
          ),
        ),
        DataCell(
          Chip(
            avatar: Icon(
              category.isActive ? Icons.check_circle : Icons.block,
              size: 18,
            ),
            label: Text(category.isActive ? 'Active' : 'Inactive'),
          ),
        ),
        DataCell(Text(formatter.format(category.createdAtUtc.toLocal()))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit article category',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _openEditArticleCategoryDialog(category);
                      },
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: category.isActive ? 'Deactivate' : 'Activate',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _confirmArticleCategoryStatusChange(category);
                      },
                icon: Icon(
                  category.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),
              IconButton(
                tooltip: category.articleCount > 0
                    ? 'Article category is in use'
                    : 'Delete article category',
                onPressed:
                    _viewModel.isActionLoading || category.articleCount > 0
                    ? null
                    : () {
                        _confirmDeleteArticleCategory(category);
                      },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecializationsContent() {
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

  Widget _buildTherapyApproachesContent() {
    if (_viewModel.isLoading && _viewModel.therapyApproaches.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.therapyApproaches.isEmpty) {
      return const Center(
        child: Text('No therapy approaches match the selected filters.'),
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
              DataColumn(label: Text('Clients')),
              DataColumn(label: Text('Used by')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _viewModel.therapyApproaches
                .map(_buildTherapyApproachRow)
                .toList(),
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

  DataRow _buildTherapyApproachRow(TherapyApproachModel approach) {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    final totalUsage = approach.therapistCount + approach.clientCount;

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 220,
            child: Text(
              approach.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),

        DataCell(
          SizedBox(
            width: 360,
            child: Text(
              approach.description ?? '—',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),

        DataCell(Text(approach.therapistCount.toString())),

        DataCell(Text(approach.clientCount.toString())),

        DataCell(
          Text(
            totalUsage == 0
                ? 'Not currently used'
                : 'Used by '
                      '${approach.therapistCount} therapist(s) '
                      'and '
                      '${approach.clientCount} client(s)',
          ),
        ),

        DataCell(
          Chip(
            avatar: Icon(
              approach.isActive ? Icons.check_circle : Icons.block,
              size: 18,
            ),
            label: Text(approach.isActive ? 'Active' : 'Inactive'),
          ),
        ),

        DataCell(Text(formatter.format(approach.createdAtUtc.toLocal()))),

        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit therapy approach',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _openEditTherapyApproachDialog(approach);
                      },
                icon: const Icon(Icons.edit_outlined),
              ),

              IconButton(
                tooltip: approach.isActive ? 'Deactivate' : 'Activate',
                onPressed: _viewModel.isActionLoading
                    ? null
                    : () {
                        _confirmTherapyApproachStatusChange(approach);
                      },
                icon: Icon(
                  approach.isActive
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
              ),

              IconButton(
                tooltip: totalUsage > 0
                    ? 'Therapy approach is in use'
                    : 'Delete therapy approach',
                onPressed: _viewModel.isActionLoading || totalUsage > 0
                    ? null
                    : () {
                        _confirmDeleteTherapyApproach(approach);
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
    final isSpecializations =
        _selectedSection == _ReferenceDataSection.specializations;

    final isTherapyApproaches =
        _selectedSection == _ReferenceDataSection.therapyApproaches;

    final pageNumber = isSpecializations
        ? _viewModel.pageNumber
        : isTherapyApproaches
        ? _viewModel.therapyApproachPageNumber
        : _viewModel.articleCategoryPageNumber;

    final totalPages = isSpecializations
        ? _viewModel.totalPages
        : isTherapyApproaches
        ? _viewModel.therapyApproachTotalPages
        : _viewModel.articleCategoryTotalPages;

    final totalCount = isSpecializations
        ? _viewModel.totalCount
        : isTherapyApproaches
        ? _viewModel.therapyApproachTotalCount
        : _viewModel.articleCategoryTotalCount;

    final displayedTotalPages = totalPages == 0 ? 1 : totalPages;

    return Row(
      children: [
        Text('Total: $totalCount'),

        const Spacer(),

        IconButton(
          tooltip: 'Previous page',
          onPressed: !_viewModel.isLoading && pageNumber > 1
              ? () async {
                  if (isSpecializations) {
                    await _viewModel.previousPage();
                  } else if (isTherapyApproaches) {
                    await _viewModel.loadTherapyApproaches(
                      requestedPage: pageNumber - 1,
                    );
                  } else {
                    await _viewModel.loadArticleCategories(
                      requestedPage: pageNumber - 1,
                    );
                  }
                }
              : null,
          icon: const Icon(Icons.chevron_left),
        ),

        Text(
          'Page $pageNumber of '
          '$displayedTotalPages',
        ),

        IconButton(
          tooltip: 'Next page',
          onPressed: !_viewModel.isLoading && pageNumber < totalPages
              ? () async {
                  if (isSpecializations) {
                    await _viewModel.nextPage();
                  } else if (isTherapyApproaches) {
                    await _viewModel.loadTherapyApproaches(
                      requestedPage: pageNumber + 1,
                    );
                  } else {
                    await _viewModel.loadArticleCategories(
                      requestedPage: pageNumber + 1,
                    );
                  }
                }
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

class _TherapyApproachFormDialog extends StatefulWidget {
  final TherapyApproachModel? approach;

  const _TherapyApproachFormDialog({this.approach});

  @override
  State<_TherapyApproachFormDialog> createState() =>
      _TherapyApproachFormDialogState();
}

class _TherapyApproachFormDialogState
    extends State<_TherapyApproachFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late final TextEditingController _descriptionController;

  late bool _isActive;

  bool get _isEditing => widget.approach != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.approach?.name ?? '');

    _descriptionController = TextEditingController(
      text: widget.approach?.description ?? '',
    );

    _isActive = widget.approach?.isActive ?? true;
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
      _TherapyApproachFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit therapy approach' : 'Add therapy approach',
      ),
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
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              if (!_isEditing) ...[
                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text(
                    'Active values can be selected in new forms.',
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
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
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}

class _TherapyApproachFormResult {
  final String name;

  final String? description;

  final bool isActive;

  const _TherapyApproachFormResult({
    required this.name,
    required this.description,
    required this.isActive,
  });
}

class _ArticleCategoryFormDialog extends StatefulWidget {
  final ArticleCategoryReferenceModel? category;

  const _ArticleCategoryFormDialog({this.category});

  @override
  State<_ArticleCategoryFormDialog> createState() =>
      _ArticleCategoryFormDialogState();
}

class _ArticleCategoryFormDialogState
    extends State<_ArticleCategoryFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;

  late final TextEditingController _descriptionController;

  late bool _isActive;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.category?.name ?? '');

    _descriptionController = TextEditingController(
      text: widget.category?.description ?? '',
    );

    _isActive = widget.category?.isActive ?? true;
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
      _ArticleCategoryFormResult(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Edit article category' : 'Add article category',
      ),
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
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),

              if (!_isEditing) ...[
                const SizedBox(height: 12),

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  subtitle: const Text(
                    'Active categories can be selected when creating new articles.',
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ],
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
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}

class _ArticleCategoryFormResult {
  final String name;

  final String? description;

  final bool isActive;

  const _ArticleCategoryFormResult({
    required this.name,
    required this.description,
    required this.isActive,
  });
}
