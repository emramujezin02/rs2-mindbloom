import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../data/models/admin_user_model.dart';
import '../viewmodels/admin_users_viewmodel.dart';
import '../widgets/user_details_dialog.dart';
import '../widgets/edit_user_dialog.dart';

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(shouldBlock ? 'Deactivate user' : 'Activate user'),
          content: Text(
            shouldBlock
                ? 'Are you sure you want to deactivate '
                      '${user.fullName}? The user will no longer '
                      'be able to access the application.'
                : 'Are you sure you want to activate '
                      '${user.fullName}? The user will regain '
                      'access to the application.',
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
              child: Text(shouldBlock ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
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
            shouldBlock
                ? 'User deactivated successfully.'
                : 'User activated successfully.',
          ),
        ),
      );
    } else if (_viewModel.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_viewModel.errorMessage!)));
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
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
              onSubmitted: (_) {
                _applyFilters();
              },
              decoration: const InputDecoration(
                labelText: 'Search users',
                hintText: 'Name or email',
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _viewModel.errorMessage!,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.users.isEmpty && _viewModel.errorMessage != null) {
      return _buildErrorState();
    }

    if (_viewModel.users.isEmpty) {
      return const Center(child: Text('No users match the selected filters.'));
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: constraints.maxWidth < 1100
                            ? 1100
                            : constraints.maxWidth,
                        child: _buildDataTable(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        _buildPagination(),
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
        final isUpdating =
            _viewModel.isUpdatingStatus && _viewModel.updatingUserId == user.id;

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'View details',
                    child: IconButton(
                      onPressed: () async {
                        final success = await _viewModel.loadUserDetails(
                          user.id,
                        );

                        if (!mounted) {
                          return;
                        }

                        if (!success || _viewModel.selectedUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                _viewModel.errorMessage ??
                                    'Unable to load user details.',
                              ),
                            ),
                          );

                          return;
                        }

                        await showDialog(
                          context: context,
                          builder: (_) =>
                              UserDetailsDialog(user: _viewModel.selectedUser!),
                        );
                      },
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  ),
                  Tooltip(
                    message: 'Edit user',
                    child: IconButton(
                      onPressed: _viewModel.isUpdatingUser
                          ? null
                          : () {
                              _editUser(user);
                            },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                  Tooltip(
                    message: 'Send password reset',
                    child: IconButton(
                      onPressed:
                          _viewModel.isSendingPasswordReset &&
                              _viewModel.passwordResetUserId == user.id
                          ? null
                          : () {
                              _sendPasswordReset(user);
                            },
                      icon:
                          _viewModel.isSendingPasswordReset &&
                              _viewModel.passwordResetUserId == user.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.lock_reset),
                    ),
                  ),
                  Tooltip(
                    message: user.isActive
                        ? 'Deactivate user'
                        : 'Activate user',
                    child: IconButton(
                      onPressed: isUpdating
                          ? null
                          : () {
                              _confirmStatusChange(user);
                            },
                      icon: isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              user.isActive
                                  ? Icons.person_off
                                  : Icons.person_add_alt_1,
                            ),
                    ),
                  ),
                  Tooltip(
                    message: 'Permanent deletion is not allowed',
                    child: IconButton(
                      onPressed: () {
                        _showDeleteNotAllowed(user);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPagination() {
    final firstItem = _viewModel.totalCount == 0
        ? 0
        : (_viewModel.pageNumber - 1) * _viewModel.pageSize + 1;

    final possibleLastItem = _viewModel.pageNumber * _viewModel.pageSize;

    final lastItem = possibleLastItem > _viewModel.totalCount
        ? _viewModel.totalCount
        : possibleLastItem;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Text(
                '$firstItem–$lastItem of '
                '${_viewModel.totalCount}',
              ),
              const Spacer(),
              const Text('Rows per page:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _viewModel.pageSize,
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
              const SizedBox(width: 18),
              Text(
                _viewModel.totalPages == 0
                    ? 'Page 0 of 0'
                    : 'Page '
                          '${_viewModel.pageNumber} '
                          'of '
                          '${_viewModel.totalPages}',
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Previous page',
                onPressed: _viewModel.hasPreviousPage && !_viewModel.isLoading
                    ? _viewModel.goToPreviousPage
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: _viewModel.hasNextPage && !_viewModel.isLoading
                    ? _viewModel.goToNextPage
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 64),
            const SizedBox(height: 16),
            Text(
              _viewModel.errorMessage ?? 'Users could not be loaded.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () {
                _viewModel.loadUsers();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
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
