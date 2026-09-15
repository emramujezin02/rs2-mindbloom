import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/admin_page_header.dart';
import 'package:mindbloom_desktop/core/widgets/admin_status_badge.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../viewmodels/therapist_verification_viewmodel.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';

class TherapistVerificationPage extends StatefulWidget {
  const TherapistVerificationPage({super.key});

  @override
  State<TherapistVerificationPage> createState() =>
      _TherapistVerificationPageState();
}

class _TherapistVerificationPageState extends State<TherapistVerificationPage> {
  final TherapistVerificationViewModel _viewModel =
      AppInjection.createTherapistVerificationViewModel();

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onChanged);

    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onChanged);

    _viewModel.dispose();

    _searchController.dispose();

    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openDetails(int therapistId) async {
    final result = await Navigator.of(
      context,
    ).pushNamed(AppRouter.therapistVerificationDetails, arguments: therapistId);

    if (!mounted) {
      return;
    }

    if (result == true) {
      await _viewModel.load(page: 1);
    }
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _viewModel.status != 'Pending';
  }

  Widget _buildActiveFilters() {
    if (!_hasActiveFilters) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (_searchController.text.trim().isNotEmpty)
            Chip(label: Text('Pretraga: ${_searchController.text.trim()}')),
          if (_viewModel.status != null && _viewModel.status != 'Pending')
            Chip(
              label: Text(
                'Status: ${_therapistStatusLabel(_viewModel.status!)}',
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Resetuj filtere'),
            onPressed: _viewModel.isLoading
                ? null
                : () async {
                    _searchController.clear();

                    await _viewModel.clearFilters();
                  },
          ),
        ],
      ),
    );
  }

  String _therapistStatusLabel(String value) {
    switch (value) {
      case 'Pending':
        return 'Na čekanju';
      case 'Approved':
        return 'Odobren';
      case 'Rejected':
        return 'Odbijen';
      case 'RequiresChanges':
        return 'Potrebne izmjene';
      default:
        return value;
    }
  }

  AdminStatusTone _therapistStatusTone(String value) {
    switch (value) {
      case 'Approved':
        return AdminStatusTone.success;
      case 'Pending':
      case 'RequiresChanges':
        return AdminStatusTone.warning;
      case 'Rejected':
        return AdminStatusTone.danger;
      default:
        return AdminStatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: AdminPageHeader(
            title: 'Therapist Verification',
            subtitle:
                'Review therapist applications, documents and approval status.',
            icon: Icons.verified_user_outlined,
            trailing: OutlinedButton.icon(
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
                      _viewModel.load();
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ),
        ),
        _buildFilters(),
        _buildActiveFilters(),
        if (_viewModel.errorMessage != null && _viewModel.therapists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: AppErrorBanner(
              message: _viewModel.errorMessage!,
              onDismiss: _viewModel.clearError,
            ),
          ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 920;

            final searchField = TextField(
              controller: _searchController,
              onChanged: _viewModel.updateSearch,
              onSubmitted: (value) {
                _viewModel.searchTherapists(value);
              },
              decoration: const InputDecoration(
                labelText: 'Pretraži terapeute',
                hintText: 'Ime, email ili specijalizacija',
                prefixIcon: Icon(Icons.search),
              ),
            );

            final statusFilter = DropdownButtonFormField<String?>(
              initialValue: _viewModel.status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Svi statusi'),
                ),
                DropdownMenuItem<String?>(
                  value: 'Pending',
                  child: Text('Na čekanju'),
                ),
                DropdownMenuItem<String?>(
                  value: 'Approved',
                  child: Text('Odobren'),
                ),
                DropdownMenuItem<String?>(
                  value: 'Rejected',
                  child: Text('Odbijen'),
                ),
                DropdownMenuItem<String?>(
                  value: 'RequiresChanges',
                  child: Text('Potrebne izmjene'),
                ),
              ],
              onChanged: _viewModel.isLoading
                  ? null
                  : (value) {
                      _viewModel.filterByStatus(value);
                    },
            );

            final searchButton = ElevatedButton.icon(
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
                      _viewModel.searchTherapists(_searchController.text);
                    },
              icon: const Icon(Icons.search),
              label: const Text('Pretraži'),
            );

            final resetButton = OutlinedButton.icon(
              onPressed: _viewModel.isLoading
                  ? null
                  : () async {
                      _searchController.clear();

                      await _viewModel.clearFilters();
                    },
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Resetuj filtere'),
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  statusFilter,
                  const SizedBox(height: 12),
                  searchButton,
                  const SizedBox(height: 10),
                  resetButton,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: searchField),
                const SizedBox(width: 12),
                SizedBox(width: 220, child: statusFilter),
                const SizedBox(width: 12),
                SizedBox(height: 56, child: searchButton),
                const SizedBox(width: 10),
                SizedBox(height: 56, child: resetButton),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.therapists.isEmpty) {
      return const AdminTableLoadingState(
        message: 'Učitavanje prijava terapeuta...',
      );
    }

    if (_viewModel.errorMessage != null && _viewModel.therapists.isEmpty) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.load();
        },
      );
    }

    if (_viewModel.therapists.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.verified_user_outlined,
        title: 'Nema prijava terapeuta',
        message: 'Nijedna prijava ne odgovara odabranim filterima.',
      );
    }

    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AdminTableContainer(
              minimumWidth: 1250,
              child: DataTable(
                columnSpacing: 28,
                headingRowHeight: 54,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 72,
                columns: const [
                  DataColumn(label: Text('Terapeut')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Specijalizacija')),
                  DataColumn(label: Text('Iskustvo')),
                  DataColumn(label: Text('Dokumenti')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Prijavljen')),
                  DataColumn(label: Text('Akcije')),
                ],
                rows: _viewModel.therapists.map((therapist) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                therapist.fullName.trim().isEmpty
                                    ? '?'
                                    : therapist.fullName
                                          .trim()[0]
                                          .toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 180,
                              child: Text(
                                therapist.fullName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(SelectableText(therapist.email)),
                      DataCell(
                        SizedBox(
                          width: 190,
                          child: Text(
                            therapist.specialization,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text('${therapist.experienceYears} god.')),
                      DataCell(Text(therapist.documentCount.toString())),
                      DataCell(
                        AdminStatusBadge(
                          label: _therapistStatusLabel(
                            therapist.verificationStatus,
                          ),
                          tone: _therapistStatusTone(
                            therapist.verificationStatus,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          formatter.format(therapist.registeredAtUtc.toLocal()),
                        ),
                      ),
                      DataCell(
                        AdminTableActionMenu<String>(
                          enabled: !_viewModel.isLoading,
                          actions: const [
                            AdminTableAction<String>(
                              value: 'details',
                              label: 'Pregledaj prijavu',
                              icon: Icons.visibility_outlined,
                            ),
                          ],
                          onSelected: (value) {
                            if (value == 'details') {
                              _openDetails(therapist.therapistId);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        _buildPagination(),
      ],
    );
  }

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: AdminTablePagination(
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
      ),
    );
  }
}
