import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';
import '../../data/models/therapy_approach_model.dart';
import '../../../../app/di/injection.dart';
import '../../data/models/therapist_specialization_model.dart';
import '../viewmodels/reference_data_management_viewmodel.dart';
import '../../data/models/article_category_reference_model.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';

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
        return _ArticleCategoryFormDialog(
          existingNames: _viewModel.articleCategories
              .map((item) => item.name)
              .toList(),
        );
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
        const SnackBar(
          content: Text('Kategorija članaka je uspješno kreirana.'),
        ),
      );
    }
  }

  Future<void> _openEditArticleCategoryDialog(
    ArticleCategoryReferenceModel category,
  ) async {
    final result = await showDialog<_ArticleCategoryFormResult>(
      context: context,
      builder: (_) {
        return _ArticleCategoryFormDialog(
          category: category,
          existingNames: _viewModel.articleCategories
              .map((item) => item.name)
              .toList(),
        );
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

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: nextStatus
          ? 'Aktiviraj kategoriju članka'
          : 'Deaktiviraj kategoriju članka',
      message: nextStatus
          ? 'Da li ste sigurni da želite aktivirati "${category.name}"?'
          : 'Da li ste sigurni da želite deaktivirati "${category.name}"? '
                'Postojeći članci će zadržati ovu kategoriju, ali ona više neće biti dostupna za nove članke.',
      confirmText: nextStatus ? 'Aktiviraj' : 'Deaktiviraj',
      destructive: !nextStatus,
    );

    if (!confirmed || !mounted) {
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
                ? 'Kategorija članka je aktivirana.'
                : 'Kategorija članka je deaktivirana.',
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
            'Kategoriju koristi ${category.articleCount} članaka. '
            'Umjesto brisanja deaktivirajte kategoriju.',
          ),
        ),
      );

      return;
    }

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Obriši kategoriju članka',
      message: 'Da li ste sigurni da želite obrisati "${category.name}"?',
      confirmText: 'Obriši',
      destructive: true,
      icon: Icons.delete_outline,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await _viewModel.deleteArticleCategory(category.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kategorija članka je obrisana.')),
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
        return _TherapyApproachFormDialog(
          existingNames: _viewModel.therapyApproaches
              .map((item) => item.name)
              .toList(),
        );
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
        return _TherapyApproachFormDialog(
          approach: approach,
          existingNames: _viewModel.therapyApproaches
              .map((item) => item.name)
              .toList(),
        );
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

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: nextStatus
          ? 'Aktiviraj terapijski pravac'
          : 'Deaktiviraj terapijski pravac',
      message: nextStatus
          ? 'Da li ste sigurni da želite aktivirati "${approach.name}"?'
          : 'Da li ste sigurni da želite deaktivirati "${approach.name}"? '
                'Postojeći terapeuti i klijenti će zadržati ovu vrijednost, '
                'ali ona više neće biti dostupna za nove izbore.',
      confirmText: nextStatus ? 'Aktiviraj' : 'Deaktiviraj',
      destructive: !nextStatus,
    );

    if (!confirmed || !mounted) {
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
                ? 'Terapijski pravac je aktiviran.'
                : 'Terapijski pravac je deaktiviran.',
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
            'Terapijski pravac koristi ${approach.therapistCount} terapeuta '
            'i ${approach.clientCount} klijenata. '
            'Umjesto brisanja deaktivirajte terapijski pravac.',
          ),
        ),
      );

      return;
    }

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Obriši terapijski pravac',
      message: 'Da li ste sigurni da želite obrisati "${approach.name}"?',
      confirmText: 'Obriši',
      destructive: true,
      icon: Icons.delete_outline,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await _viewModel.deleteTherapyApproach(approach.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Terapijski pravac je obrisan.')),
      );
    }
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_SpecializationFormResult>(
      context: context,
      builder: (_) {
        return _SpecializationFormDialog(
          existingNames: _viewModel.specializations
              .map((item) => item.name)
              .toList(),
        );
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
        return _SpecializationFormDialog(
          specialization: specialization,
          existingNames: _viewModel.specializations
              .map((item) => item.name)
              .toList(),
        );
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

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: nextStatus
          ? 'Aktiviraj specijalizaciju'
          : 'Deaktiviraj specijalizaciju',
      message: nextStatus
          ? 'Da li ste sigurni da želite aktivirati "${specialization.name}"?'
          : 'Da li ste sigurni da želite deaktivirati "${specialization.name}"? '
                'Postojeći terapeuti će zadržati specijalizaciju, ali ona više neće biti dostupna za nove izbore.',
      confirmText: nextStatus ? 'Aktiviraj' : 'Deaktiviraj',
      destructive: !nextStatus,
    );

    if (!confirmed || !mounted) {
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
                ? 'Specijalizacija je aktivirana.'
                : 'Specijalizacija je deaktivirana.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    TherapistSpecializationModel specialization,
  ) async {
    if (specialization.therapistCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Specijalizaciju koristi ${specialization.therapistCount} terapeuta. '
            'Umjesto brisanja deaktivirajte specijalizaciju.',
          ),
        ),
      );

      return;
    }

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: 'Obriši specijalizaciju',
      message: 'Da li ste sigurni da želite obrisati "${specialization.name}"?',
      confirmText: 'Obriši',
      destructive: true,
      icon: Icons.delete_outline,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await _viewModel.deleteSpecialization(specialization.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Specijalizacija je obrisana.')),
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
              child: AppErrorBanner(
                message: _viewModel.errorMessage!,
                onDismiss: _viewModel.clearError,
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
                    'Referentni podaci',
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
                    ? 'Dodaj specijalizaciju'
                    : isTherapyApproaches
                    ? 'Dodaj terapijski pravac'
                    : 'Dodaj kategoriju članka',
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
              label: Text('Specijalizacije terapeuta'),
            ),
            ButtonSegment<_ReferenceDataSection>(
              value: _ReferenceDataSection.therapyApproaches,
              icon: Icon(Icons.route_outlined),
              label: Text('Therapy approaches'),
            ),
            ButtonSegment<_ReferenceDataSection>(
              value: _ReferenceDataSection.articleCategories,
              icon: Icon(Icons.category_outlined),
              label: Text('Kategorije članaka'),
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
                  ? 'Pretraži specijalizacije'
                  : isTherapyApproaches
                  ? 'Pretraži terapijske pravce'
                  : 'Pretraži kategorije članaka',
              hintText: 'Naziv ili opis',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Očisti pretragu',
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
              DropdownMenuItem<bool?>(value: null, child: Text('Svi statusi')),
              DropdownMenuItem<bool?>(value: true, child: Text('Aktivno')),
              DropdownMenuItem<bool?>(value: false, child: Text('Neaktivno')),
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
      return const AdminTableLoadingState(
        message: 'Učitavanje kategorija članaka...',
      );
    }

    if (_viewModel.articleCategories.isEmpty &&
        _viewModel.errorMessage != null) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.loadArticleCategories();
        },
      );
    }

    if (_viewModel.articleCategories.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.category_outlined,
        title: 'Nema kategorija članaka',
        message: 'Nijedna kategorija članka ne odgovara odabranim filterima.',
      );
    }

    return AdminTableContainer(
      minimumWidth: 1150,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Naziv')),
          DataColumn(label: Text('Opis')),
          DataColumn(label: Text('Članci')),
          DataColumn(label: Text('Koristi se')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Kreirano')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _viewModel.articleCategories
            .map(_buildArticleCategoryRow)
            .toList(),
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
            label: Text(category.isActive ? 'Aktivno' : 'Neaktivno'),
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
      return const AdminTableLoadingState(
        message: 'Učitavanje specijalizacija...',
      );
    }

    if (_viewModel.specializations.isEmpty && _viewModel.errorMessage != null) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.loadSpecializations();
        },
      );
    }

    if (_viewModel.specializations.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.psychology_outlined,
        title: 'Nema specijalizacija',
        message: 'Nijedna specijalizacija ne odgovara odabranim filterima.',
      );
    }

    return AdminTableContainer(
      minimumWidth: 1100,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Naziv')),
          DataColumn(label: Text('Opis')),
          DataColumn(label: Text('Terapeuti')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Kreirano')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _viewModel.specializations.map(_buildRow).toList(),
      ),
    );
  }

  Widget _buildTherapyApproachesContent() {
    if (_viewModel.isLoading && _viewModel.therapyApproaches.isEmpty) {
      return const AdminTableLoadingState(
        message: 'Učitavanje terapijskih pravaca...',
      );
    }

    if (_viewModel.therapyApproaches.isEmpty &&
        _viewModel.errorMessage != null) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.loadTherapyApproaches();
        },
      );
    }

    if (_viewModel.therapyApproaches.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.route_outlined,
        title: 'Nema terapijskih pravaca',
        message: 'Nijedan terapijski pravac ne odgovara odabranim filterima.',
      );
    }

    return AdminTableContainer(
      minimumWidth: 1250,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Naziv')),
          DataColumn(label: Text('Opis')),
          DataColumn(label: Text('Terapeuti')),
          DataColumn(label: Text('Klijenti')),
          DataColumn(label: Text('Koristi se')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('Kreirano')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _viewModel.therapyApproaches
            .map(_buildTherapyApproachRow)
            .toList(),
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

    final pageSize = isSpecializations
        ? _viewModel.pageSize
        : isTherapyApproaches
        ? _viewModel.therapyApproachPageSize
        : _viewModel.articleCategoryPageSize;

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

    return AdminTablePagination(
      pageNumber: pageNumber,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages,
      isLoading: _viewModel.isLoading,

      onPreviousPage: pageNumber > 1
          ? () {
              if (isSpecializations) {
                _viewModel.previousPage();
              } else if (isTherapyApproaches) {
                _viewModel.loadTherapyApproaches(requestedPage: pageNumber - 1);
              } else {
                _viewModel.loadArticleCategories(requestedPage: pageNumber - 1);
              }
            }
          : null,

      onNextPage: pageNumber < totalPages
          ? () {
              if (isSpecializations) {
                _viewModel.nextPage();
              } else if (isTherapyApproaches) {
                _viewModel.loadTherapyApproaches(requestedPage: pageNumber + 1);
              } else {
                _viewModel.loadArticleCategories(requestedPage: pageNumber + 1);
              }
            }
          : null,

      onPageSizeChanged: (value) {
        if (isSpecializations) {
          _viewModel.changeSpecializationPageSize(value);
        } else if (isTherapyApproaches) {
          _viewModel.changeTherapyApproachPageSize(value);
        } else {
          _viewModel.changeArticleCategoryPageSize(value);
        }
      },
    );
  }
}

class _SpecializationFormDialog extends StatefulWidget {
  final TherapistSpecializationModel? specialization;
  final List<String> existingNames;

  const _SpecializationFormDialog({
    this.specialization,
    required this.existingNames,
  });

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
      title: Text(
        _isEditing ? 'Uredi specijalizaciju' : 'Dodaj specijalizaciju',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Naziv',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final lengthError = AppValidators.textLength(
                    value,
                    fieldName: 'Naziv',
                    minLength: 2,
                    maxLength: 150,
                  );

                  if (lengthError != null) {
                    return lengthError;
                  }

                  return AppValidators.uniqueText(
                    value,
                    fieldName: 'Specijalizacija',
                    existingValues: widget.existingNames,
                    currentValue: widget.specialization?.name,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 6,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  return AppValidators.maxLength(
                    value,
                    fieldName: 'Opis',
                    maximum: 500,
                  );
                },
              ),
              if (!_isEditing)
                SwitchListTile(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktivna'),
                  subtitle: Text(
                    _isActive
                        ? 'Specijalizacija će odmah biti dostupna za izbor.'
                        : 'Specijalizacija će biti kreirana kao neaktivna.',
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
          child: const Text('Odustani'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(_isEditing ? 'Spremi izmjene' : 'Kreiraj'),
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
  final List<String> existingNames;

  const _TherapyApproachFormDialog({
    this.approach,
    required this.existingNames,
  });

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
        _isEditing ? 'Uredi terapijski pravac' : 'Dodaj terapijski pravac',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Naziv',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final lengthError = AppValidators.textLength(
                    value,
                    fieldName: 'Naziv',
                    minLength: 2,
                    maxLength: 150,
                  );

                  if (lengthError != null) {
                    return lengthError;
                  }

                  return AppValidators.uniqueText(
                    value,
                    fieldName: 'Terapijski pravac',
                    existingValues: widget.existingNames,
                    currentValue: widget.approach?.name,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  return AppValidators.maxLength(
                    value,
                    fieldName: 'Opis',
                    maximum: 1000,
                  );
                },
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktivan'),
                  subtitle: const Text(
                    'Aktivne vrijednosti mogu se birati u novim formama.',
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
          child: const Text('Odustani'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(_isEditing ? 'Spremi izmjene' : 'Kreiraj'),
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
  final List<String> existingNames;

  const _ArticleCategoryFormDialog({
    this.category,
    required this.existingNames,
  });

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
        _isEditing ? 'Uredi kategoriju članka' : 'Dodaj kategoriju članka',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                maxLength: 150,
                decoration: const InputDecoration(
                  labelText: 'Naziv',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final lengthError = AppValidators.textLength(
                    value,
                    fieldName: 'Naziv',
                    minLength: 2,
                    maxLength: 150,
                  );

                  if (lengthError != null) {
                    return lengthError;
                  }

                  return AppValidators.uniqueText(
                    value,
                    fieldName: 'Kategorija članka',
                    existingValues: widget.existingNames,
                    currentValue: widget.category?.name,
                  );
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Opis',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  return AppValidators.maxLength(
                    value,
                    fieldName: 'Opis',
                    maximum: 1000,
                  );
                },
              ),
              if (!_isEditing) ...[
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktivna'),
                  subtitle: const Text(
                    'Aktivne kategorije mogu se birati pri kreiranju novih članaka.',
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
          child: const Text('Odustani'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.save_outlined),
          label: Text(_isEditing ? 'Spremi izmjene' : 'Kreiraj'),
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
