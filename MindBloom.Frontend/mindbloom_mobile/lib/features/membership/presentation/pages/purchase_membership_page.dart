import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
import '../../../../core/widgets/app_empty_state_widget.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading_widget.dart';
import '../../../therapist/data/models/therapist_model.dart';
import '../../data/models/membership_plan_model.dart';
import '../viewmodels/membership_viewmodel.dart';

class PurchaseMembershipPage extends StatefulWidget {
  final TherapistModel therapist;

  const PurchaseMembershipPage({super.key, required this.therapist});

  @override
  State<PurchaseMembershipPage> createState() => _PurchaseMembershipPageState();
}

class _PurchaseMembershipPageState extends State<PurchaseMembershipPage> {
  final MembershipViewModel _viewModel =
      AppInjection.createMembershipViewModel();

  @override
  void initState() {
    super.initState();

    _viewModel.addListener(_onViewModelChanged);
    _loadPlans();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadPlans() {
    return _viewModel.loadPlans(widget.therapist.id);
  }

  Future<void> _purchase(MembershipPlanModel plan) async {
    if (_viewModel.isPurchasing) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm membership purchase'),
          content: Text(
            'You are purchasing ${plan.name} for '
            '${plan.price.toStringAsFixed(2)} KM.\n\n'
            'The price is calculated by the server. '
            'Your membership will become active only after '
            'Stripe confirms the payment.',
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
              child: const Text('Continue to payment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final success = await _viewModel.purchaseMembership(
      therapistId: widget.therapist.id,
      planType: plan.planType,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Membership purchased and activated successfully.'),
        ),
      );

      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRouter.myMemberships, (route) => false);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_viewModel.error ?? 'Unable to purchase membership.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Membership packages'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _viewModel.isLoading ? null : _loadPlans,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.plans.isEmpty) {
      return const AppLoadingWidget.skeleton(
        message: 'Loading membership packages...',
        skeletonItemCount: 4,
      );
    }

    if (_viewModel.error != null && _viewModel.plans.isEmpty) {
      return AppErrorWidget(
        title: 'Membership packages could not be loaded',
        error: _viewModel.error,
        onRetry: _loadPlans,
      );
    }

    if (_viewModel.plans.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPlans,
        child: const AppEmptyStateWidget(
          title: 'No membership packages',
          message:
              'This therapist currently has no active membership packages.',
          icon: Icons.card_membership_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlans,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: _viewModel.plans.length + (_viewModel.error != null ? 1 : 0),
        separatorBuilder: (context, index) {
          return const SizedBox(height: 12);
        },
        itemBuilder: (context, index) {
          if (_viewModel.error != null && index == 0) {
            return AppInlineError(
              title: 'Membership packages could not be refreshed',
              error: _viewModel.error,
              onRetry: _loadPlans,
            );
          }

          final planIndex = index - (_viewModel.error != null ? 1 : 0);
          final plan = _viewModel.plans[planIndex];

          return _MembershipPlanCard(
            plan: plan,
            isPurchasing: _viewModel.isPurchasing,
            onPurchase: () => _purchase(plan),
          );
        },
      ),
    );
  }
}

class _MembershipPlanCard extends StatelessWidget {
  final MembershipPlanModel plan;
  final bool isPurchasing;
  final VoidCallback onPurchase;

  const _MembershipPlanCard({
    required this.plan,
    required this.isPurchasing,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.card_membership, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    plan.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(plan.description, style: const TextStyle(height: 1.4)),
            ],
            const SizedBox(height: 16),
            _PlanInfoRow(
              icon: Icons.event_available,
              text: '${plan.totalSessions} included sessions',
            ),
            const SizedBox(height: 8),
            _PlanInfoRow(
              icon: Icons.redeem,
              text:
                  '${plan.freeSessions} free '
                  '${plan.freeSessions == 1 ? 'session' : 'sessions'}',
            ),
            const SizedBox(height: 8),
            _PlanInfoRow(
              icon: Icons.schedule,
              text: 'Valid for ${plan.durationMonths} months',
            ),
            if (plan.benefits.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Benefits',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...plan.benefits.map(
                (benefit) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, size: 19),
                      const SizedBox(width: 8),
                      Expanded(child: Text(benefit)),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 28),
            Text(
              'Total price: '
              '${plan.price.toStringAsFixed(2)} KM',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            Text(
              'Price per session: '
              '${plan.pricePerSession.toStringAsFixed(2)} KM',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isPurchasing || !plan.isActive ? null : onPurchase,
                icon: isPurchasing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.payment),
                label: Text(
                  isPurchasing
                      ? 'Processing payment...'
                      : 'Purchase with Stripe',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanInfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PlanInfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    );
  }
}
