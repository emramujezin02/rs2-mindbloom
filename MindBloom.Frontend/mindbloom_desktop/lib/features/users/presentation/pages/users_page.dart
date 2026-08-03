import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/admin_user_model.dart';
import '../viewmodels/admin_users_viewmodel.dart';
import '../widgets/user_details_dialog.dart';
import '../widgets/edit_user_dialog.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_confirmation_dialog.dart';
import '../../../../core/widgets/app_error_banner.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final AdminUsersViewModel _viewModel =
      AppInjection.createAdminUsersViewModel();

  final TextEditingController _searchController = TextEditingController();

  String? _selectedRole;

  String _selectedStatus = 'all';

  DateTime? _registeredFrom;

  DateTime? _registeredTo;

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);

    _viewModel.loadUsers();
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

  bool? _getBlockedFilter() {
    switch (_selectedStatus) {
      case 'active':
        return false;

      case 'blocked':
        return true;

      default:
        return null;
    }
  }

  Future<void> _applyFilters() async {
    await _viewModel.applyFilters(
      search: _searchController.text,
      role: _selectedRole,
      isBlocked: _getBlockedFilter(),
      registeredFrom: _registeredFrom,
      registeredTo: _registeredTo,
    );
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _selectedRole = null;
      _selectedStatus = 'all';
      _registeredFrom = null;
      _registeredTo = null;
    });

    await _viewModel.clearFilters();
  }

  Future<void> _selectRegisteredFrom() async {
    final initialDate = _registeredFrom ?? _registeredTo ?? DateTime.now();

    final lastDate = _registeredTo ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(lastDate) ? lastDate : initialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _registeredFrom = picked;
    });
  }

  Future<void> _selectRegisteredTo() async {
    final now = DateTime.now();

    final firstDate = _registeredFrom ?? DateTime(2020);

    final initialDate = _registeredTo ?? _registeredFrom ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(now) ? now : initialDate,
      firstDate: firstDate,
      lastDate: now,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _registeredTo = picked;
    });
  }

  String _formatFilterDate(DateTime? date) {
    if (date == null) {
      return '';
    }

    return DateFormat('dd.MM.yyyy.').format(date);
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: value == null
              ? const Icon(Icons.arrow_drop_down)
              : IconButton(
                  tooltip: 'Clear date',
                  onPressed: onClear,
                  icon: const Icon(Icons.clear),
                ),
        ),
        child: Text(
          value == null ? 'Select date' : _formatFilterDate(value),
          style: TextStyle(
            color: value == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : null,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmStatusChange(AdminUserModel user) async {
    final shouldBlock = user.isActive;

    final confirmed = await AppConfirmationDialog.show(
      context,
      title: shouldBlock ? 'Deaktiviraj korisnika' : 'Aktiviraj korisnika',
      message: shouldBlock
          ? 'Da li ste sigurni da želite deaktivirati korisnika '
                '${user.fullName}? Korisnik više neće moći pristupiti aplikaciji.'
          : 'Da li ste sigurni da želite aktivirati korisnika '
                '${user.fullName}? Korisniku će ponovo biti omogućen pristup aplikaciji.',
      confirmText: shouldBlock ? 'Deaktiviraj' : 'Aktiviraj',
      destructive: shouldBlock,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final success = await _viewModel.updateUserStatus(
      user: user,
      isBlocked: shouldBlock,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldBlock ? 'Korisnik je deaktiviran.' : 'Korisnik je aktiviran.',
          ),
        ),
      );
    }
  }

  Future<void> _showDeleteNotAllowed(AdminUserModel user) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('User deletion is not allowed'),
          content: Text(
            '${user.fullName} cannot be permanently deleted. '
            'User accounts may be referenced by appointments, '
            'payments, reviews, memberships and audit records.\n\n'
            'Deactivate the account instead.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendPasswordReset(AdminUserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Send password reset'),
          content: Text('Send a password reset email to ${user.fullName}?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Send'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.sendPasswordReset(user.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent successfully.'),
        ),
      );
    } else if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_viewModel.errorMessage!)));
    }
  }

  Future<void> _editUser(AdminUserModel user) async {
    final detailsLoaded = await _viewModel.loadUserDetails(user.id);

    if (!mounted) {
      return;
    }

    if (!detailsLoaded || _viewModel.selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _viewModel.errorMessage ?? 'Unable to load user details.',
          ),
        ),
      );

      return;
    }

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return EditUserDialog(
          user: _viewModel.selectedUser!,
          isSaving: _viewModel.isUpdatingUser,
          onSave: (request) {
            return _viewModel.updateUser(user.id, request);
          },
        );
      },
    );

    if (!mounted || updated != true) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User updated successfully.')));
  }

  bool get _hasActiveFilters {
    return _searchController.text.trim().isNotEmpty ||
        _selectedRole != null ||
        _selectedStatus != 'all' ||
        _registeredFrom != null ||
        _registeredTo != null;
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
            Chip(
              avatar: const Icon(Icons.search, size: 18),
              label: Text('Pretraga: ${_searchController.text.trim()}'),
            ),
          if (_selectedRole != null) Chip(label: Text('Uloga: $_selectedRole')),
          if (_selectedStatus != 'all')
            Chip(
              label: Text(
                _selectedStatus == 'active'
                    ? 'Status: Aktivan'
                    : 'Status: Deaktiviran',
              ),
            ),
          if (_registeredFrom != null)
            Chip(
              label: Text(
                'Registrovan od: ${_formatFilterDate(_registeredFrom)}',
              ),
            ),
          if (_registeredTo != null)
            Chip(
              label: Text(
                'Registrovan do: ${_formatFilterDate(_registeredTo)}',
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.filter_alt_off, size: 18),
            label: const Text('Resetuj filtere'),
            onPressed: _viewModel.isLoading ? null : _clearFilters,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        _buildActiveFilters(),
        if (_viewModel.errorMessage != null) _buildInlineError(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 1000;

            final searchField = TextField(
              controller: _searchController,
              onChanged: _viewModel.updateSearch,
              onSubmitted: (_) {
                _applyFilters();
              },
              decoration: const InputDecoration(
                labelText: 'Pretraži korisnike',
                hintText: 'Ime ili email',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            );

            final roleFilter = DropdownButtonFormField<String>(
              key: ValueKey(_selectedRole),
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem<String>(value: null, child: Text('All roles')),
                DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                DropdownMenuItem(value: 'Therapist', child: Text('Therapist')),
                DropdownMenuItem(value: 'Client', child: Text('Client')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
              },
            );

            final statusFilter = DropdownButtonFormField<String>(
              key: ValueKey(_selectedStatus),
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All statuses')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'blocked', child: Text('Deactivated')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value ?? 'all';
                });
              },
            );

            final registeredFromField = _buildDateField(
              label: 'Registered from',
              value: _registeredFrom,
              onTap: _selectRegisteredFrom,
              onClear: () {
                setState(() {
                  _registeredFrom = null;
                });
              },
            );

            final registeredToField = _buildDateField(
              label: 'Registered to',
              value: _registeredTo,
              onTap: _selectRegisteredTo,
              onClear: () {
                setState(() {
                  _registeredTo = null;
                });
              },
            );

            final buttons = Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _applyFilters,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _viewModel.isLoading ? null : _clearFilters,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            );

            if (compact) {
              return Column(
                children: [
                  searchField,
                  const SizedBox(height: 12),
                  roleFilter,
                  const SizedBox(height: 12),
                  statusFilter,
                  const SizedBox(height: 12),
                  registeredFromField,
                  const SizedBox(height: 12),
                  registeredToField,
                  const SizedBox(height: 12),
                  buttons,
                ],
              );
            }

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(flex: 3, child: searchField),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: roleFilter),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: statusFilter),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: registeredFromField),
                    const SizedBox(width: 12),
                    Expanded(child: registeredToField),
                    const SizedBox(width: 12),
                    SizedBox(width: 260, child: buttons),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInlineError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AppErrorBanner(message: _viewModel.errorMessage!),
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.users.isEmpty) {
      return const AdminTableLoadingState(message: 'Učitavanje korisnika...');
    }

    if (_viewModel.users.isEmpty && _viewModel.errorMessage != null) {
      return AdminTableErrorState(
        message: _viewModel.errorMessage!,
        onRetry: () {
          _viewModel.loadUsers();
        },
      );
    }

    if (_viewModel.users.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.people_outline,
        title: 'Nema korisnika',
        message: 'Nijedan korisnik ne odgovara odabranim filterima.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AdminTableContainer(
              minimumWidth: 1100,
              child: _buildDataTable(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: _buildPagination(),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    final formatter = DateFormat('dd.MM.yyyy. HH:mm');

    return DataTable(
      columnSpacing: 28,
      headingRowHeight: 54,
      dataRowMinHeight: 60,
      dataRowMaxHeight: 72,
      columns: const [
        DataColumn(label: Text('User')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Role')),
        DataColumn(label: Text('Email verified')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Created')),
        DataColumn(label: Text('Actions')),
      ],
      rows: _viewModel.users.map((user) {
        return DataRow(
          cells: [
            DataCell(
              Row(
                children: [
                  CircleAvatar(
                    child: Text(
                      user.fullName.trim().isEmpty
                          ? '?'
                          : user.fullName.trim()[0].toUpperCase(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user.fullName.isEmpty ? 'Unnamed user' : user.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            DataCell(SelectableText(user.email)),
            DataCell(_RoleBadge(role: user.role)),
            DataCell(
              Icon(
                user.isEmailVerified ? Icons.verified : Icons.warning_amber,
                color: user.isEmailVerified ? Colors.green : Colors.orange,
              ),
            ),
            DataCell(_StatusBadge(isActive: user.isActive)),
            DataCell(Text(formatter.format(user.createdAtUtc.toLocal()))),
            DataCell(
              AdminTableActionMenu<String>(
                enabled:
                    !_viewModel.isUpdatingStatus &&
                    !_viewModel.isUpdatingUser &&
                    !_viewModel.isSendingPasswordReset,
                actions: [
                  const AdminTableAction<String>(
                    value: 'details',
                    label: 'Detalji',
                    icon: Icons.visibility_outlined,
                  ),
                  const AdminTableAction<String>(
                    value: 'edit',
                    label: 'Uredi',
                    icon: Icons.edit_outlined,
                  ),
                  const AdminTableAction<String>(
                    value: 'password',
                    label: 'Pošalji reset lozinke',
                    icon: Icons.lock_reset,
                  ),
                  AdminTableAction<String>(
                    value: 'status',
                    label: user.isActive ? 'Deaktiviraj' : 'Aktiviraj',
                    icon: user.isActive
                        ? Icons.person_off
                        : Icons.person_add_alt_1,
                    destructive: user.isActive,
                  ),
                  const AdminTableAction<String>(
                    value: 'deleteInfo',
                    label: 'Brisanje nije dozvoljeno',
                    icon: Icons.delete_outline,
                  ),
                ],
                onSelected: (action) async {
                  switch (action) {
                    case 'details':
                      final success = await _viewModel.loadUserDetails(user.id);

                      if (!mounted) {
                        return;
                      }

                      if (!success || _viewModel.selectedUser == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _viewModel.errorMessage ??
                                  'Detalje korisnika nije moguće učitati.',
                            ),
                          ),
                        );

                        return;
                      }

                      await showDialog<void>(
                        context: context,
                        builder: (_) {
                          return UserDetailsDialog(
                            user: _viewModel.selectedUser!,
                          );
                        },
                      );

                      break;

                    case 'edit':
                      await _editUser(user);
                      break;

                    case 'password':
                      await _sendPasswordReset(user);
                      break;

                    case 'status':
                      await _confirmStatusChange(user);
                      break;

                    case 'deleteInfo':
                      await _showDeleteNotAllowed(user);
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

  Widget _buildPagination() {
    return AdminTablePagination(
      pageNumber: _viewModel.pageNumber,
      pageSize: _viewModel.pageSize,
      totalCount: _viewModel.totalCount,
      totalPages: _viewModel.totalPages,
      isLoading: _viewModel.isLoading,
      onPreviousPage: _viewModel.hasPreviousPage
          ? _viewModel.goToPreviousPage
          : null,
      onNextPage: _viewModel.hasNextPage ? _viewModel.goToNextPage : null,
      onPageSizeChanged: _viewModel.changePageSize,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(role), visualDensity: VisualDensity.compact);
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        isActive ? Icons.check_circle : Icons.block,
        size: 18,
        color: isActive ? Colors.green : Colors.red,
      ),
      label: Text(isActive ? 'Active' : 'Deactivated'),
      visualDensity: VisualDensity.compact,
    );
  }
}
