import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mindbloom_desktop/core/widgets/app_table_pagination.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../data/models/admin_membership_model.dart';
import '../viewmodels/membership_management_viewmodel.dart';
import '../../data/models/admin_membership_plan_model.dart';
import '../../data/models/membership_plan_request.dart';
import '../viewmodels/membership_plan_management_viewmodel.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../core/widgets/admin_table_action_menu.dart';
import '../../../../core/widgets/admin_table_container.dart';
import '../../../../core/widgets/admin_table_state.dart';
import '../../../../core/widgets/app_error_banner.dart';
import '../../../../core/widgets/app_responsive_dialog_content.dart';

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
    final now = DateTime.now();

    final initialDate = isFrom
        ? (_expiresFrom ?? _expiresTo ?? now)
        : (_expiresTo ?? _expiresFrom ?? now);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isFrom
          ? 'Odaberite početni datum isteka'
          : 'Odaberite završni datum isteka',
      cancelText: 'Odustani',
      confirmText: 'Odaberi',
    );

    if (selected == null || !mounted) {
      return;
    }

    if (isFrom && _expiresTo != null && selected.isAfter(_expiresTo!)) {
      _showError('Početni datum isteka ne može biti nakon završnog datuma.');
      return;
    }

    if (!isFrom && _expiresFrom != null && selected.isBefore(_expiresFrom!)) {
      _showError('Završni datum isteka ne može biti prije početnog datuma.');
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
                isEditing ? 'Uredi plan članarine' : 'Kreiraj plan članarine',
              ),
              content: AppResponsiveDialogContent(
                preferredWidth: 620,
                child: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<int>(
                        initialValue: selectedPlanType,
                        decoration: const InputDecoration(
                          labelText: 'Tip plana',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 1, child: Text('10 sesija')),
                          DropdownMenuItem(value: 2, child: Text('20 sesija')),
                          DropdownMenuItem(value: 3, child: Text('30 sesija')),
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
                        maxLength: 150,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Naziv',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          return AppValidators.textLength(
                            value,
                            fieldName: 'Naziv',
                            maxLength: 150,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descriptionController,
                        minLines: 3,
                        maxLines: 5,
                        maxLength: 1000,
                        decoration: const InputDecoration(
                          labelText: 'Opis',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) {
                          return AppValidators.textLength(
                            value,
                            fieldName: 'Opis',
                            maxLength: 1000,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 520;

                          final priceField = TextFormField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Cijena',
                              suffixText: 'KM',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              return AppValidators.price(
                                value,
                                fieldName: 'Cijena',
                                allowZero: false,
                              );
                            },
                          );

                          final durationField = TextFormField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Trajanje (mjeseci)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = AppValidators.parseInteger(value);

                              if (parsed == null) {
                                return 'Unesite ispravno trajanje.';
                              }

                              if (parsed <= 0) {
                                return 'Trajanje mora biti veće od 0.';
                              }

                              return null;
                            },
                          );

                          if (compact) {
                            return Column(
                              children: [
                                priceField,
                                const SizedBox(height: 12),
                                durationField,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: priceField),
                              const SizedBox(width: 12),
                              Expanded(child: durationField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 520;

                          final sessionsField = TextFormField(
                            controller: sessionsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Broj uključenih sesija',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = AppValidators.parseInteger(value);

                              if (parsed == null) {
                                return 'Unesite ispravan broj sesija.';
                              }

                              if (parsed <= 0) {
                                return 'Broj sesija mora biti veći od 0.';
                              }

                              return null;
                            },
                          );

                          final discountField = TextFormField(
                            controller: discountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Popust (%)',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed = AppValidators.parseDecimal(value);

                              if (parsed == null) {
                                return 'Unesite ispravan popust.';
                              }

                              if (parsed < 0 || parsed > 100) {
                                return 'Popust mora biti između 0 i 100%.';
                              }

                              return null;
                            },
                          );

                          if (compact) {
                            return Column(
                              children: [
                                sessionsField,
                                const SizedBox(height: 12),
                                discountField,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: sessionsField),
                              const SizedBox(width: 12),
                              Expanded(child: discountField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: benefitsController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Pogodnosti',
                          hintText: 'Unesite jednu pogodnost po redu.',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      if (!isEditing) ...[
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Odmah aktivan'),
                          subtitle: const Text(
                            'Plan će biti dostupan korisnicima odmah nakon kreiranja.',
                          ),
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
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Odustani'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    FocusScope.of(dialogContext).unfocus();

                    if (!formKey.currentState!.validate()) {
                      return;
                    }

                    final price = AppValidators.parseDecimal(
                      priceController.text,
                    );
                    final duration = AppValidators.parseInteger(
                      durationController.text,
                    );
                    final sessions = AppValidators.parseInteger(
                      sessionsController.text,
                    );
                    final discount = AppValidators.parseDecimal(
                      discountController.text,
                    );

                    if (price == null ||
                        duration == null ||
                        sessions == null ||
                        discount == null) {
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
                        price: price,
                        durationMonths: duration,
                        includedSessions: sessions,
                        discountPercentage: discount,
                        benefits: benefits,
                        isActive: isActive,
                      ),
                    );
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: Text(isEditing ? 'Spremi izmjene' : 'Kreiraj'),
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
            isEditing
                ? 'Plan članarine je uspješno izmijenjen.'
                : 'Plan članarine je uspješno kreiran.',
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
          title: Text(plan.isActive ? 'Deaktiviraj plan' : 'Aktiviraj plan'),
          content: AppResponsiveDialogContent(
            preferredWidth: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plan.isActive
                      ? 'Klijenti više neće moći kupiti ovaj plan. Postojeće članarine neće biti promijenjene.'
                      : 'Klijenti će ponovo moći kupiti ovaj plan.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Razlog (opcionalno)',
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
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(plan.isActive ? 'Deaktiviraj' : 'Aktiviraj'),
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
          title: const Text('Ukloni plan'),
          content: const Text(
            'Ako je ovaj plan već korišten, neće biti trajno obrisan. '
            'Umjesto toga bit će deaktiviran kako bi postojeće članarine ostale sačuvane.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Nastavi'),
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
          content: Text('Plan članarine je uklonjen ili deaktiviran.'),
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
        final screenSize = MediaQuery.sizeOf(dialogContext);

        final width = screenSize.width > 850
            ? 750.0
            : (screenSize.width - 80).clamp(280.0, 750.0);

        final height = screenSize.height > 700
            ? 500.0
            : (screenSize.height * 0.62).clamp(220.0, 500.0);

        return AlertDialog(
          title: Text(
            'History — ${plan.name}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          content: SizedBox(
            width: width,
            height: height,
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
                            if (item.previousValues != null &&
                                item.previousValues!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SelectableText(
                                'Previous: ${item.previousValues}',
                              ),
                            ],
                            if (item.newValues != null &&
                                item.newValues!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              SelectableText('New: ${item.newValues}'),
                            ],
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

  bool get _hasActiveMembershipFilters {
    return _searchController.text.trim().isNotEmpty ||
        _viewModel.planType != null ||
        _viewModel.membershipStatus != null ||
        _viewModel.paymentStatus != null ||
        _expiresFrom != null ||
        _expiresTo != null;
  }

  String _membershipPlanLabel(int value) {
    switch (value) {
      case 1:
        return '10 sesija';
      case 2:
        return '20 sesija';
      case 3:
        return '30 sesija';
      default:
        return value.toString();
    }
  }

  String _membershipStatusLabel(String value) {
    switch (value) {
      case 'Active':
        return 'Aktivna';
      case 'Inactive':
        return 'Neaktivna';
      case 'PendingPayment':
        return 'Čeka plaćanje';
      case 'Expired':
        return 'Istekla';
      case 'Depleted':
        return 'Iskorištena';
      default:
        return value;
    }
  }

  String _membershipPaymentStatusLabel(int value) {
    switch (value) {
      case 1:
        return 'Na čekanju';
      case 2:
        return 'Plaćeno';
      case 3:
        return 'Neuspjelo';
      case 4:
        return 'Refundirano';
      case 5:
        return 'Refundacija na čekanju';
      case 6:
        return 'Refundacija neuspjela';
      default:
        return value.toString();
    }
  }

  Widget _buildActiveMembershipFilters() {
    if (!_hasActiveMembershipFilters) {
      return const SizedBox.shrink();
    }

    final formatter = DateFormat('dd.MM.yyyy.');

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_searchController.text.trim().isNotEmpty)
          Chip(label: Text('Pretraga: ${_searchController.text.trim()}')),
        if (_viewModel.planType != null)
          Chip(
            label: Text('Plan: ${_membershipPlanLabel(_viewModel.planType!)}'),
          ),
        if (_viewModel.membershipStatus != null)
          Chip(
            label: Text(
              'Status: ${_membershipStatusLabel(_viewModel.membershipStatus!)}',
            ),
          ),
        if (_viewModel.paymentStatus != null)
          Chip(
            label: Text(
              'Plaćanje: ${_membershipPaymentStatusLabel(_viewModel.paymentStatus!)}',
            ),
          ),
        if (_expiresFrom != null)
          Chip(label: Text('Ističe od: ${formatter.format(_expiresFrom!)}')),
        if (_expiresTo != null)
          Chip(label: Text('Ističe do: ${formatter.format(_expiresTo!)}')),
        ActionChip(
          avatar: const Icon(Icons.filter_alt_off, size: 18),
          label: const Text('Resetuj filtere'),
          onPressed: _viewModel.isLoading ? null : _clearFilters,
        ),
      ],
    );
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

          if (_hasActiveMembershipFilters) ...[
            const SizedBox(height: 12),
            _buildActiveMembershipFilters(),
          ],

          if (_viewModel.error != null &&
              _viewModel.memberships.isNotEmpty) ...[
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
              AdminTableContainer(
                minimumWidth: 1100,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Naziv')),
                    DataColumn(label: Text('Tip')),
                    DataColumn(label: Text('Cijena')),
                    DataColumn(label: Text('Trajanje')),
                    DataColumn(label: Text('Sesije')),
                    DataColumn(label: Text('Popust')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Akcije')),
                  ],
                  rows: _planViewModel.plans.map(_buildPlanRow).toList(),
                ),
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
          AdminTableActionMenu<String>(
            enabled: !_planViewModel.isSaving,
            actions: [
              const AdminTableAction<String>(
                value: 'edit',
                label: 'Uredi',
                icon: Icons.edit_outlined,
              ),
              AdminTableAction<String>(
                value: 'status',
                label: plan.isActive ? 'Deaktiviraj' : 'Aktiviraj',
                icon: plan.isActive
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                destructive: plan.isActive,
              ),
              const AdminTableAction<String>(
                value: 'history',
                label: 'Historija',
                icon: Icons.history,
              ),
              const AdminTableAction<String>(
                value: 'delete',
                label: 'Ukloni',
                icon: Icons.delete_outline,
                destructive: true,
              ),
            ],
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _showPlanDialog(plan: plan);
                  break;

                case 'status':
                  _changePlanStatus(plan);
                  break;

                case 'history':
                  _showPlanHistory(plan);
                  break;

                case 'delete':
                  _deletePlan(plan);
                  break;
              }
            },
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
                onChanged: _viewModel.updateSearch,
                decoration: const InputDecoration(
                  labelText: 'Pretraga',
                  hintText: 'ID, klijent ili terapeut',
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
      return const AdminTableLoadingState(message: 'Učitavanje članarina...');
    }

    if (_viewModel.error != null && _viewModel.memberships.isEmpty) {
      return AdminTableErrorState(
        message: _viewModel.error!,
        onRetry: () {
          _viewModel.loadMemberships();
        },
      );
    }

    if (_viewModel.memberships.isEmpty) {
      return const AdminTableEmptyState(
        icon: Icons.card_membership_outlined,
        title: 'Nema članarina',
        message: 'Nijedna članarina ne odgovara odabranim filterima.',
      );
    }

    return AdminTableContainer(
      minimumWidth: 1450,
      child: DataTable(
        showCheckboxColumn: false,
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Klijent')),
          DataColumn(label: Text('Terapeut')),
          DataColumn(label: Text('Plan')),
          DataColumn(label: Text('Sesije')),
          DataColumn(label: Text('Status članarine')),
          DataColumn(label: Text('Status plaćanja')),
          DataColumn(label: Text('Cijena')),
          DataColumn(label: Text('Ističe')),
          DataColumn(label: Text('Akcije')),
        ],
        rows: _viewModel.memberships.map(_buildRow).toList(),
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
          AdminTableActionMenu<String>(
            enabled: !_viewModel.isLoading,
            actions: const [
              AdminTableAction<String>(
                value: 'details',
                label: 'Detalji',
                icon: Icons.visibility_outlined,
              ),
            ],
            onSelected: (value) {
              if (value == 'details') {
                _openDetails(membership.id);
              }
            },
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
