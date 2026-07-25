import 'package:flutter/material.dart';

import '../../../../app/di/injection.dart';
import '../../../../app/router/app_router.dart';
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

    _viewModel.loadPlans(widget.therapist.id);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);

    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _purchase(MembershipPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm membership purchase'),
          content: Text(
            'You are purchasing ${plan.name} for '
            '${plan.price.toStringAsFixed(2)} KM.\n\n'
            'The price is calculated by the server. '
            'Your membership will become active only after Stripe confirms the payment.',
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

    if (_viewModel.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_viewModel.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership packages')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading && _viewModel.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_viewModel.error != null && _viewModel.plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _viewModel.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  _viewModel.loadPlans(widget.therapist.id);
                },
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_viewModel.plans.isEmpty) {
      return const Center(child: Text('No membership packages are available.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),

      itemCount: _viewModel.plans.length,

      separatorBuilder: (context, index) => const SizedBox(height: 12),

      itemBuilder: (context, index) {
        final plan = _viewModel.plans[index];

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
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
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
                    onPressed: _viewModel.isPurchasing || !plan.isActive
                        ? null
                        : () {
                            _purchase(plan);
                          },
                    icon: _viewModel.isPurchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.payment),
                    label: Text(
                      _viewModel.isPurchasing
                          ? 'Processing payment...'
                          : 'Purchase with Stripe',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
