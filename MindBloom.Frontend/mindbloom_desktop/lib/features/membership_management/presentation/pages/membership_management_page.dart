import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/admin_membership_model.dart';
import '../viewmodels/membership_management_viewmodel.dart';
import '../../data/models/admin_membership_plan_model.dart';
import '../../data/models/membership_plan_request.dart';
import '../viewmodels/membership_plan_management_viewmodel.dart';

class MembershipManagementPage extends StatefulWidget {
  const MembershipManagementPage({super.key});

  @override
  State<MembershipManagementPage> createState() =>
      _MembershipManagementPageState();
}

class _MembershipManagementPageState extends State<MembershipManagementPage> {
  late final MembershipManagementViewModel _viewModel;
  late final MembershipPlanManagementViewModel _planViewModel;
  final TextEditingController _searchController = TextEditingController();
  DateTime? _expiresFrom;
  DateTime? _expiresTo;

  @override
  void initState() {
    super.initState();

    _viewModel = AppInjection.createMembershipManagementViewModel();
    _planViewModel = AppInjection.createMembershipPlanManagementViewModel();
    _viewModel.addListener(_onViewModelChanged);
    _planViewModel.addListener(_onViewModelChanged);
    _viewModel.loadMemberships();
    _planViewModel.loadPlans();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _planViewModel.removeListener(_onViewModelChanged);
    _searchController.dispose();
    _viewModel.dispose();
    _planViewModel.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _search() async {
    await _viewModel.applySearch(_searchController.text);
  }

  Future<void> _selectExpirationDate({required bool isFrom}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? _expiresFrom ?? DateTime.now()
          : _expiresTo ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      if (isFrom) {
        _expiresFrom = selected;
      } else {
        _expiresTo = selected;
      }
    });

    await _viewModel.setExpirationRange(from: _expiresFrom, to: _expiresTo);
  }

  Future<void> _clearFilters() async {
    _searchController.clear();

    setState(() {
      _expiresFrom = null;
      _expiresTo = null;
    });

    await _viewModel.clearFilters();
  }

  Future<void> _showPlanDialog({AdminMembershipPlanModel? plan}) async {
    final isEditing = plan != null;

    final nameController = TextEditingController(text: plan?.name ?? '');

    final descriptionController = TextEditingController(
      text: plan?.description ?? '',
    );

    final priceController = TextEditingController(
      text: plan == null ? '' : plan.price.toStringAsFixed(2),
    );

    final durationController = TextEditingController(
      text: plan?.durationMonths.toString() ?? '',
    );

    final sessionsController = TextEditingController(
      text: plan?.includedSessions.toString() ?? '',
    );

    final discountController = TextEditingController(
      text: plan == null ? '0' : plan.discountPercentage.toStringAsFixed(2),
    );

    final benefitsController = TextEditingController(
      text: plan?.benefits.join('\n') ?? '',
    );

    int selectedPlanType = plan?.planType ?? 1;

    bool isActive = plan?.isActive ?? true;

    final formKey = GlobalKey<FormState>();

    final result = await showDialog<MembershipPlanRequest>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit membership plan' : 'Create membership plan',
              ),
              content: SizedBox(
                width: 620,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: selectedPlanType,
                          decoration: const InputDecoration(
                            labelText: 'Plan type',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 1,
                              child: Text('10 sessions'),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: Text('20 sessions'),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: Text('30 sessions'),
                            ),
                          ],
                          onChanged: isEditing
                              ? null
                              : (value) {
                                  if (value == null) {
                                    return;
                                  }

                                  setDialogState(() {
                                    selectedPlanType = value;
                                  });
                                },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final normalized = value?.trim() ?? '';

                            if (normalized.isEmpty) {
                              return 'Name is required.';
                            }

                            if (normalized.length > 150) {
                              return 'Maximum 150 characters.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: descriptionController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                          validator: (value) {
                            final normalized = value?.trim() ?? '';

                            if (normalized.isEmpty) {
                              return 'Description is required.';
                            }

                            if (normalized.length > 1000) {
                              return 'Maximum 1000 characters.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Price',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final parsed = double.tryParse(
                                    value?.replaceAll(',', '.') ?? '',
                                  );

                                  if (parsed == null) {
                                    return 'Invalid price.';
                                  }

                                  if (parsed <= 0) {
                                    return 'Price must be greater than zero.';
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextFormField(
                                controller: durationController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Duration (months)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final parsed = int.tryParse(value ?? '');

                                  if (parsed == null || parsed <= 0) {
                                    return 'Duration must be greater than zero.';
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: sessionsController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Included sessions',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final parsed = int.tryParse(value ?? '');

                                  if (parsed == null || parsed <= 0) {
                                    return 'Sessions must be greater than zero.';
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextFormField(
                                controller: discountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Discount (%)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  final parsed = double.tryParse(
                                    value?.replaceAll(',', '.') ?? '',
                                  );

                                  if (parsed == null) {
                                    return 'Invalid discount.';
                                  }

                                  if (parsed < 0 || parsed > 100) {
                                    return 'Discount must be between 0 and 100.';
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        TextFormField(
                          controller: benefitsController,
                          minLines: 4,
                          maxLines: 8,
                          decoration: const InputDecoration(
                            labelText: 'Benefits',
                            hintText: 'Enter one benefit per line.',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),

                        if (!isEditing) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active immediately'),
                            value: isActive,
                            onChanged: (value) {
                              setDialogState(() {
                                isActive = value;
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),

                FilledButton(
                  onPressed: () {
                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final benefits = benefitsController.text
                        .split('\n')
                        .map((value) => value.trim())
                        .where((value) => value.isNotEmpty)
                        .toList();

                    Navigator.of(dialogContext).pop(
                      MembershipPlanRequest(
                        planType: selectedPlanType,
                        name: nameController.text.trim(),
                        description: descriptionController.text.trim(),
                        price: double.parse(
                          priceController.text.replaceAll(',', '.'),
                        ),
                        durationMonths: int.parse(durationController.text),
                        includedSessions: int.parse(sessionsController.text),
                        discountPercentage: double.parse(
                          discountController.text.replaceAll(',', '.'),
                        ),
                        benefits: benefits,
                        isActive: isActive,
                      ),
                    );
                  },
                  child: Text(isEditing ? 'Save changes' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    durationController.dispose();
    sessionsController.dispose();
    discountController.dispose();
    benefitsController.dispose();

    if (result == null || !mounted) {
      return;
    }

    final success = isEditing
        ? await _planViewModel.updatePlan(planId: plan.id, request: result)
        : await _planViewModel.createPlan(result);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Membership plan updated.' : 'Membership plan created.',
          ),
        ),
      );
    } else if (_planViewModel.error != null) {
      _showError(_planViewModel.error!);
    }
  }

  Future<void> _changePlanStatus(AdminMembershipPlanModel plan) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(plan.isActive ? 'Deactivate plan' : 'Activate plan'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plan.isActive
                      ? 'Clients will no longer be able to purchase this plan. Existing memberships will not be changed.'
                      : 'Clients will be able to purchase this plan again.',
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(plan.isActive ? 'Deactivate' : 'Activate'),
            ),
          ],
        );
      },
    );

    final reason = reasonController.text.trim();

    reasonController.dispose();

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _planViewModel.updateStatus(
      planId: plan.id,
      isActive: !plan.isActive,
      reason: reason.isEmpty ? null : reason,
    );

    if (!mounted) {
      return;
    }

    if (!success && _planViewModel.error != null) {
      _showError(_planViewModel.error!);
    }
  }

  Future<void> _deletePlan(AdminMembershipPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove plan'),
          content: const Text(
            'If this plan has already been used, it will not be deleted. '
            'It will be deactivated instead so existing memberships remain safe.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _planViewModel.deletePlan(plan.id);

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membership plan removed or deactivated.'),
        ),
      );
    } else if (_planViewModel.error != null) {
      _showError(_planViewModel.error!);
    }
  }

  Future<void> _showPlanHistory(AdminMembershipPlanModel plan) async {
    await _planViewModel.loadHistory(plan.id);

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final formatter = DateFormat('dd.MM.yyyy. HH:mm');

        return AlertDialog(
          title: Text('History — ${plan.name}'),
          content: SizedBox(
            width: 750,
            height: 500,
            child: _planViewModel.history.isEmpty
                ? const Center(child: Text('No change history available.'))
                : ListView.separated(
                    itemCount: _planViewModel.history.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _planViewModel.history[index];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          item.action,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Changed by: ${item.changedByName}'),
                            Text(formatter.format(item.changedAtUtc.toLocal())),
                            if (item.reason != null &&
                                item.reason!.trim().isNotEmpty)
                              Text('Reason: ${item.reason}'),
                            if (item.previousValues != null) ...[
                              const SizedBox(height: 6),
                              SelectableText(
                                'Previous: ${item.previousValues}',
                              ),
                            ],
                            if (item.newValues != null)
                              SelectableText('New: ${item.newValues}'),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
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

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

          _buildMembershipPlansSection(),

          const SizedBox(height: 24),

          const Divider(),

          const SizedBox(height: 16),

          const Text(
            'User memberships',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          _buildFilters(),

          const SizedBox(height: 16),

          Expanded(child: _buildContent()),

          const SizedBox(height: 12),

          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Membership management',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 4),
            Text('Review memberships, payments and session usage.'),
          ],
        ),
        Chip(
          avatar: const Icon(Icons.card_membership, size: 18),
          label: Text('${_viewModel.totalCount} memberships'),
        ),
      ],
    );
  }

  Widget _buildMembershipPlansSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Membership plans',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _planViewModel.isSaving
                      ? null
                      : () {
                          _showPlanDialog();
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Create plan'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_planViewModel.isLoading && _planViewModel.plans.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_planViewModel.error != null &&
                _planViewModel.plans.isEmpty)
              Column(
                children: [
                  Text(
                    _planViewModel.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _planViewModel.loadPlans,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try again'),
                  ),
                ],
              )
            else if (_planViewModel.plans.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: Text('No membership plans found.')),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Price')),
                          DataColumn(label: Text('Duration')),
                          DataColumn(label: Text('Sessions')),
                          DataColumn(label: Text('Discount')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _planViewModel.plans.map(_buildPlanRow).toList(),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  DataRow _buildPlanRow(AdminMembershipPlanModel plan) {
    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 190,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  plan.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),

        DataCell(Text(plan.planTypeLabel)),

        DataCell(Text('${plan.price.toStringAsFixed(2)} USD')),

        DataCell(Text('${plan.durationMonths} months')),

        DataCell(Text(plan.includedSessions.toString())),

        DataCell(Text('${plan.discountPercentage.toStringAsFixed(2)}%')),

        DataCell(
          Chip(
            avatar: Icon(
              plan.isActive ? Icons.check_circle : Icons.cancel,
              size: 18,
            ),
            label: Text(plan.isActive ? 'Active' : 'Inactive'),
          ),
        ),

        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit',
                onPressed: _planViewModel.isSaving
                    ? null
                    : () {
                        _showPlanDialog(plan: plan);
                      },
                icon: const Icon(Icons.edit),
              ),

              IconButton(
                tooltip: plan.isActive ? 'Deactivate' : 'Activate',
                onPressed: _planViewModel.isSaving
                    ? null
                    : () {
                        _changePlanStatus(plan);
                      },
                icon: Icon(
                  plan.isActive ? Icons.pause_circle : Icons.play_circle,
                ),
              ),

              IconButton(
                tooltip: 'History',
                onPressed: () {
                  _showPlanHistory(plan);
                },
                icon: const Icon(Icons.history),
              ),

              IconButton(
                tooltip: 'Delete',
                onPressed: _planViewModel.isSaving
                    ? null
                    : () {
                        _deletePlan(plan);
                      },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  hintText: 'ID, client or therapist',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  _search();
                },
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int?>(
                initialValue: _viewModel.planType,
                decoration: const InputDecoration(
                  labelText: 'Plan',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(value: null, child: Text('All plans')),
                  DropdownMenuItem<int?>(value: 1, child: Text('10 sessions')),
                  DropdownMenuItem<int?>(value: 2, child: Text('20 sessions')),
                  DropdownMenuItem<int?>(value: 3, child: Text('30 sessions')),
                ],
                onChanged: (value) {
                  _viewModel.setPlanType(value);
                },
              ),
            ),
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<String?>(
                initialValue: _viewModel.membershipStatus,
                decoration: const InputDecoration(
                  labelText: 'Membership status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Active',
                    child: Text('Active'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Inactive',
                    child: Text('Inactive'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'PendingPayment',
                    child: Text('Pending payment'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Expired',
                    child: Text('Expired'),
                  ),
                  DropdownMenuItem<String?>(
                    value: 'Depleted',
                    child: Text('Depleted'),
                  ),
                ],
                onChanged: (value) {
                  _viewModel.setMembershipStatus(value);
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<int?>(
                initialValue: _viewModel.paymentStatus,
                decoration: const InputDecoration(
                  labelText: 'Payment status',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All payments'),
                  ),
                  DropdownMenuItem<int?>(value: 1, child: Text('Pending')),
                  DropdownMenuItem<int?>(value: 2, child: Text('Paid')),
                  DropdownMenuItem<int?>(value: 3, child: Text('Failed')),
                  DropdownMenuItem<int?>(value: 4, child: Text('Refunded')),
                  DropdownMenuItem<int?>(
                    value: 5,
                    child: Text('Refund pending'),
                  ),
                  DropdownMenuItem<int?>(
                    value: 6,
                    child: Text('Refund failed'),
                  ),
                ],
                onChanged: (value) {
                  _viewModel.setPaymentStatus(value);
                },
              ),
            ),

            OutlinedButton.icon(
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
                      _selectExpirationDate(isFrom: true);
                    },
              icon: const Icon(Icons.date_range),
              label: Text(
                _expiresFrom == null
                    ? 'Expires from'
                    : DateFormat('dd.MM.yyyy.').format(_expiresFrom!),
              ),
            ),

            OutlinedButton.icon(
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
                      _selectExpirationDate(isFrom: false);
                    },
              icon: const Icon(Icons.event),
              label: Text(
                _expiresTo == null
                    ? 'Expires to'
                    : DateFormat('dd.MM.yyyy.').format(_expiresTo!),
              ),
            ),
            FilledButton.icon(
              onPressed: _viewModel.isLoading ? null : _search,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            OutlinedButton.icon(
              onPressed: _viewModel.isLoading ? null : _clearFilters,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Clear'),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: _viewModel.isLoading
                  ? null
                  : () {
                      _viewModel.loadMemberships();
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_viewModel.isLoading && _viewModel.memberships.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.memberships.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 12),
            Text(_viewModel.error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                _viewModel.loadMemberships();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (_viewModel.memberships.isEmpty) {
      return const Center(
        child: Text('No memberships match the selected filters.'),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('Client')),
                  DataColumn(label: Text('Therapist')),
                  DataColumn(label: Text('Plan')),
                  DataColumn(label: Text('Sessions')),
                  DataColumn(label: Text('Membership status')),
                  DataColumn(label: Text('Payment status')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Expires')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _viewModel.memberships.map(_buildRow).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  DataRow _buildRow(AdminMembershipModel membership) {
    final dateFormatter = DateFormat('dd.MM.yyyy.');

    final progress = membership.totalSessions <= 0
        ? 0.0
        : membership.remainingSessions / membership.totalSessions;

    return DataRow(
      onSelectChanged: (_) {
        _openDetails(membership.id);
      },
      cells: [
        DataCell(Text('#${membership.id}')),
        DataCell(
          _PersonCell(
            name: membership.clientName,
            email: membership.clientEmail,
          ),
        ),
        DataCell(
          _PersonCell(
            name: membership.therapistName,
            email: membership.therapistEmail,
          ),
        ),
        DataCell(Text(_formatPlan(membership.planType))),
        DataCell(
          SizedBox(
            width: 150,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${membership.remainingSessions}'
                  ' / '
                  '${membership.totalSessions}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                LinearProgressIndicator(value: progress.clamp(0.0, 1.0)),
              ],
            ),
          ),
        ),
        DataCell(_StatusChip(value: membership.membershipStatus)),
        DataCell(_StatusChip(value: membership.paymentStatus)),
        DataCell(Text('${membership.price.toStringAsFixed(2)} USD')),
        DataCell(
          Text(
            membership.expiresAtUtc == null
                ? '—'
                : dateFormatter.format(membership.expiresAtUtc!.toLocal()),
          ),
        ),
        DataCell(
          IconButton(
            tooltip: 'Open details',
            onPressed: () {
              _openDetails(membership.id);
            },
            icon: const Icon(Icons.visibility),
          ),
        ),
      ],
    );
  }

  void _openDetails(int membershipId) {
    Navigator.of(
      context,
    ).pushNamed(AppRouter.membershipManagementDetails, arguments: membershipId);
  }

  Widget _buildPagination() {
    final displayedPage = _viewModel.totalPages == 0
        ? 0
        : _viewModel.pageNumber;

    return Row(
      children: [
        Text(
          'Page $displayedPage '
          'of ${_viewModel.totalPages}',
        ),
        const Spacer(),
        Text('${_viewModel.totalCount} total'),
        const SizedBox(width: 16),
        IconButton(
          tooltip: 'Previous page',
          onPressed: _viewModel.hasPreviousPage && !_viewModel.isLoading
              ? _viewModel.previousPage
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: _viewModel.hasNextPage && !_viewModel.isLoading
              ? _viewModel.nextPage
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _formatPlan(String planType) {
    switch (planType) {
      case 'TenSessions':
        return '10 sessions';

      case 'TwentySessions':
        return '20 sessions';

      case 'ThirtySessions':
        return '30 sessions';

      default:
        return planType;
    }
  }
}

class _PersonCell extends StatelessWidget {
  final String name;

  final String email;

  const _PersonCell({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 170),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            email,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String value;

  const _StatusChip({required this.value});

  @override
  Widget build(BuildContext context) {
    IconData icon;

    switch (value.toLowerCase()) {
      case 'active':
      case 'paid':
      case 'consumed':
        icon = Icons.check_circle;
        break;

      case 'pending':
      case 'pendingpayment':
      case 'refundpending':
      case 'reserved':
        icon = Icons.schedule;
        break;

      case 'restored':
      case 'refunded':
        icon = Icons.replay;
        break;

      case 'expired':
      case 'depleted':
      case 'inactive':
      case 'failed':
      case 'refundfailed':
        icon = Icons.cancel;
        break;

      default:
        icon = Icons.info_outline;
    }

    return Chip(avatar: Icon(icon, size: 17), label: Text(_formatValue(value)));
  }

  String _formatValue(String value) {
    switch (value) {
      case 'PendingPayment':
        return 'Pending payment';

      case 'RefundPending':
        return 'Refund pending';

      case 'RefundFailed':
        return 'Refund failed';

      case 'NotCreated':
        return 'Not created';

      default:
        return value;
    }
  }
}
